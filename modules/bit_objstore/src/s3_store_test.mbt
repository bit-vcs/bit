///|
/// A scripted transport: records the requests it is handed and replays a
/// queue of canned replies. Lets the status-code mapping be tested exactly,
/// including the cases a live bucket will not produce on demand.
struct FakeTransport {
  replies : Array[HttpReply]
  seen : Array[(String, String, Map[String, String])]
  mut next : Int
}

///|
fn FakeTransport::new(replies : Array[HttpReply]) -> FakeTransport {
  { replies, seen: [], next: 0 }
}

///|
fn FakeTransport::store(self : FakeTransport, path_style : Bool) -> S3Store {
  let config : S3Config = {
    endpoint: "https://s3.us-east-1.amazonaws.com",
    region: "us-east-1",
    bucket: "b",
    access_key_id: "AKIAIOSFODNN7EXAMPLE",
    secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    session_token: None,
    path_style,
  }
  S3Store::new(
    config,
    (verb, url, headers, _body) => {
      self.seen.push((verb, url, headers))
      if self.next >= self.replies.length() {
        raise @bit.GitError::IoError("no scripted reply for \{verb} \{url}")
      }
      let reply = self.replies[self.next]
      self.next += 1
      reply
    },
    () => "20260101T120000Z",
  )
}

///|
fn reply(
  status : Int,
  headers? : Map[String, String] = Map([]),
  body? : String = "",
) -> HttpReply {
  { status, headers, body: @utf8.encode(body) }
}

///|
async test "s3: a 200 read carries the body and the unquoted version tag" {
  let fake = FakeTransport::new([
    reply(200, headers={ "ETag": "\"abc123\"" }, body="hello"),
  ])
  let store = fake.store(true)
  let got = store.get("repos/a/b/manifest.json")
  inspect(got, content="Found(5 bytes, abc123)")
  let (verb, url, _) = fake.seen[0]
  inspect(verb, content="GET")
  inspect(
    url,
    content="https://s3.us-east-1.amazonaws.com/b/repos/a/b/manifest.json",
  )
}

///|
async test "s3: virtual-host addressing drops the bucket from the path" {
  let fake = FakeTransport::new([reply(200, headers={ "ETag": "\"e\"" })])
  let store = fake.store(false)
  let _ = store.get("k/1")
  let (_, url, _) = fake.seen[0]
  inspect(url, content="https://s3.us-east-1.amazonaws.com/k/1")
}

///|
async test "s3: 404 is Missing, not an error" {
  let fake = FakeTransport::new([reply(404, body="<Error/>")])
  let store = fake.store(true)
  inspect(store.get("nope"), content="Missing")
}

///|
async test "s3: a conditional read sends If-None-Match and maps 304" {
  let fake = FakeTransport::new([reply(304)])
  let store = fake.store(true)
  inspect(store.get_if_none_match("m", "v1"), content="NotModified")
  let (_, _, headers) = fake.seen[0]
  // The quotes S3 requires are added back on the way out.
  inspect(headers["if-none-match"], content="\"v1\"")
}

///|
async test "s3: a range read sends a Range header and accepts 206" {
  let fake = FakeTransport::new([
    reply(206, headers={ "ETag": "\"e\"" }, body="0123"),
  ])
  let store = fake.store(true)
  inspect(
    store.get_range("wal/big.pack", { start: 100L, end: 103L }),
    content="Found(4 bytes, e)",
  )
  let (_, _, headers) = fake.seen[0]
  inspect(headers["range"], content="bytes=100-103")
}

///|
async test "s3: create-only write sends If-None-Match: *" {
  let fake = FakeTransport::new([reply(200, headers={ "ETag": "\"new\"" })])
  let store = fake.store(true)
  inspect(
    store.put("wal/p.pack", @utf8.encode("x"), PutCondition::IfNotExists),
    content="Applied(new)",
  )
  let (_, _, headers) = fake.seen[0]
  inspect(headers["if-none-match"], content="*")
}

///|
async test "s3: compare-and-swap sends If-Match and maps 412 to NotApplied" {
  let fake = FakeTransport::new([reply(412, body="PreconditionFailed")])
  let store = fake.store(true)
  inspect(
    store.put("manifest.json", @utf8.encode("{}"), PutCondition::IfMatch("v1")),
    content="NotApplied",
  )
  let (_, _, headers) = fake.seen[0]
  inspect(headers["if-match"], content="\"v1\"")
}

///|
async test "s3: 409 is a lost race, not a failure" {
  // S3 answers 409 ConditionalRequestConflict when a concurrent conditional
  // write won. The caller must re-read and retry, exactly as for a 412.
  let fake = FakeTransport::new([reply(409)])
  let store = fake.store(true)
  inspect(
    store.put("manifest.json", @utf8.encode("{}"), PutCondition::IfMatch("v1")),
    content="NotApplied",
  )
}

///|
async test "s3: 5xx and 429 leave the write indeterminate" {
  for status in [500, 502, 503, 429] {
    let fake = FakeTransport::new([reply(status)])
    let store = fake.store(true)
    inspect(
      store.put("k", @utf8.encode("v"), PutCondition::Unconditional),
      content="Unknown",
    )
  }
}

///|
async test "s3: a transport failure is indeterminate, not an error" {
  // The request left the client; whether it landed is unknowable from here.
  let fake = FakeTransport::new([])
  let store = fake.store(true)
  inspect(
    store.put("k", @utf8.encode("v"), PutCondition::Unconditional),
    content="Unknown",
  )
}

///|
async test "s3: a 200 without an ETag is Unknown rather than a guessed version" {
  // Naming a version we cannot know would poison the next compare-and-swap.
  let fake = FakeTransport::new([reply(200)])
  let store = fake.store(true)
  inspect(
    store.put("k", @utf8.encode("v"), PutCondition::Unconditional),
    content="Unknown",
  )
}

///|
async test "s3: a store that rejects conditional writes fails loudly" {
  let fake = FakeTransport::new([reply(400, body="InvalidArgument")])
  let store = fake.store(true)
  let message = try {
    let _ = store.put("k", @utf8.encode("v"), PutCondition::IfMatch("v1"))
    "<no error>"
  } catch {
    e => e.to_string()
  }
  inspect(message.contains("compare-and-swap"), content="true")
}

///|
async test "s3: delete accepts 204 and treats 404 as done" {
  for status in [200, 202, 204, 404] {
    let fake = FakeTransport::new([reply(status)])
    let store = fake.store(true)
    store.delete("k")
    let (verb, _, _) = fake.seen[0]
    inspect(verb, content="DELETE")
  }
}

///|
async test "s3: listing sends list-type=2 with prefix and cursor" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<ListBucketResult>
    #|<IsTruncated>false</IsTruncated>
    #|<Contents><Key>repos/a/log/1</Key><Size>12</Size><ETag>&quot;e1&quot;</ETag></Contents>
    #|<Contents><Key>repos/a/log/2</Key><Size>34</Size><ETag>&quot;e2&quot;</ETag></Contents>
    #|</ListBucketResult>
  let fake = FakeTransport::new([reply(200, body=xml)])
  let store = fake.store(true)
  let page = store.list("repos/a/log/", "repos/a/log/0")
  inspect(page.entries.length(), content="2")
  inspect(page.entries[0].key, content="repos/a/log/1")
  inspect(page.entries[0].size, content="12")
  inspect(page.entries[0].etag, content="e1")
  inspect(page.next is None, content="true")
  let (_, url, _) = fake.seen[0]
  inspect(url.contains("list-type=2"), content="true")
  inspect(url.contains("prefix=repos%2Fa%2Flog%2F"), content="true")
  inspect(url.contains("start-after=repos%2Fa%2Flog%2F0"), content="true")
}
