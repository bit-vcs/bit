///|
fn text(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn body_of(outcome : GetOutcome) -> String {
  match outcome {
    Found(body, _) => @utf8.decode_lossy(body[:])
    NotModified => "<not-modified>"
    Missing => "<missing>"
  }
}

///|
fn etag_of(outcome : GetOutcome) -> String {
  match outcome {
    Found(_, etag) => etag
    NotModified => "<not-modified>"
    Missing => "<missing>"
  }
}

///|
async test "mem store: round trip and absent keys" {
  let store = MemStore::new()
  inspect(body_of(store.get("a")), content="<missing>")
  let put = store.put("a", text("hello"), PutCondition::Unconditional)
  inspect(put.is_applied(), content="true")
  inspect(body_of(store.get("a")), content="hello")
}

///|
async test "mem store: create-only write loses cleanly to an existing key" {
  let store = MemStore::new()
  inspect(
    store.put("k", text("first"), PutCondition::IfNotExists).is_applied(),
    content="true",
  )
  let second = store.put("k", text("second"), PutCondition::IfNotExists)
  inspect(second, content="NotApplied")
  // The loser must not have overwritten the winner.
  inspect(body_of(store.get("k")), content="first")
}

///|
async test "mem store: compare-and-swap only lands on the expected version" {
  let store = MemStore::new()
  let first = store.put("m", text("v1"), PutCondition::IfNotExists)
  let etag1 = match first {
    Applied(e) => e
    _ => "<none>"
  }
  // A writer holding a stale version is refused.
  inspect(
    store.put("m", text("v2"), PutCondition::IfMatch("stale")),
    content="NotApplied",
  )
  inspect(body_of(store.get("m")), content="v1")
  // The holder of the current version wins.
  let second = store.put("m", text("v2"), PutCondition::IfMatch(etag1))
  inspect(second.is_applied(), content="true")
  inspect(body_of(store.get("m")), content="v2")
  // ...and the version it replaced is now stale for everyone else.
  inspect(
    store.put("m", text("v3"), PutCondition::IfMatch(etag1)),
    content="NotApplied",
  )
}

///|
async test "mem store: compare-and-swap against an absent key is refused" {
  let store = MemStore::new()
  inspect(
    store.put("gone", text("x"), PutCondition::IfMatch("anything")),
    content="NotApplied",
  )
}

///|
async test "mem store: the version tag is content-derived, as an S3 ETag is" {
  let store = MemStore::new()
  let a = store.put("x", text("same"), PutCondition::Unconditional)
  store.delete("x")
  let b = store.put("x", text("same"), PutCondition::Unconditional)
  // Rewriting identical bytes yields the same tag. Callers must not read a
  // changed tag as proof that a write happened.
  inspect(a == b, content="true")
}

///|
async test "mem store: conditional read reports NotModified for the current version" {
  let store = MemStore::new()
  let _ = store.put("c", text("body"), PutCondition::Unconditional)
  let etag = etag_of(store.get("c"))
  inspect(body_of(store.get_if_none_match("c", etag)), content="<not-modified>")
  inspect(body_of(store.get_if_none_match("c", "other")), content="body")
  inspect(body_of(store.get_if_none_match("absent", "x")), content="<missing>")
}

///|
async test "mem store: range reads clamp to the object" {
  let store = MemStore::new()
  let _ = store.put("r", text("0123456789"), PutCondition::Unconditional)
  inspect(body_of(store.get_range("r", { start: 0L, end: 3L })), content="0123")
  inspect(body_of(store.get_range("r", { start: 7L, end: 99L })), content="789")
  inspect(body_of(store.get_range("r", { start: 20L, end: 30L })), content="")
  inspect(body_of(store.get_range("r", { start: 5L, end: 4L })), content="")
}

///|
async test "mem store: delete is idempotent" {
  let store = MemStore::new()
  let _ = store.put("d", text("x"), PutCondition::Unconditional)
  store.delete("d")
  store.delete("d")
  inspect(body_of(store.get("d")), content="<missing>")
}

///|
async test "mem store: listing is prefix-scoped and byte-ordered" {
  let store = MemStore::new()
  // "log/10" must sort after "log/2" by byte order, and "a/b" before "ab".
  for key in ["log/2", "log/10", "log/1", "other/1", "a/b", "ab"] {
    let _ = store.put(key, text(key), PutCondition::Unconditional)
  }
  let page = store.list("log/", "")
  let keys : Array[String] = []
  for entry in page.entries {
    keys.push(entry.key)
  }
  inspect(keys.join(","), content="log/1,log/10,log/2")
  inspect(page.next is None, content="true")
}

///|
async test "mem store: listing pages and resumes after the cursor" {
  let store = MemStore::new()
  for key in ["p/a", "p/b", "p/c", "p/d", "p/e"] {
    let _ = store.put(key, text(key), PutCondition::Unconditional)
  }
  store.set_page_size(2)
  let first = store.list("p/", "")
  inspect(first.entries.length(), content="2")
  inspect(first.next.unwrap_or("<none>"), content="p/b")
  let all = list_all(store, "p/")
  let keys : Array[String] = []
  for entry in all {
    keys.push(entry.key)
  }
  inspect(keys.join(","), content="p/a,p/b,p/c,p/d,p/e")
}

///|
async test "mem store: a failed write leaves the store untouched" {
  let store = MemStore::new()
  let _ = store.put("k", text("before"), PutCondition::Unconditional)
  store.fail_next_puts(1)
  inspect(
    store.put("k", text("after"), PutCondition::Unconditional),
    content="Unknown",
  )
  inspect(body_of(store.get("k")), content="before")
}

///|
async test "mem store: a silenced write applies but reports Unknown" {
  // The nastier half of the indeterminate case: the store committed and the
  // caller was never told. A caller that treats Unknown as failure and
  // retries blindly would double-apply here.
  let store = MemStore::new()
  store.silence_next_puts(1)
  inspect(
    store.put("k", text("landed"), PutCondition::Unconditional),
    content="Unknown",
  )
  inspect(body_of(store.get("k")), content="landed")
}

///|
async test "put_immutable treats a lost create-only race as success" {
  let store = MemStore::new()
  let first = put_immutable(store, "wal/abc.pack", text("packdata"))
  inspect(first.is_applied(), content="true")
  // Same content-addressed key written concurrently: the loser wrote the same
  // bytes, so the push step it belongs to may safely continue.
  let second = put_immutable(store, "wal/abc.pack", text("packdata"))
  inspect(second.is_applied(), content="true")
}
