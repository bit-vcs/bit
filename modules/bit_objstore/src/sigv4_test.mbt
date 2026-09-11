///|
/// AWS example credentials, used by the published SigV4 test vectors.
fn config_of(
  endpoint : String,
  bucket : String,
  path_style : Bool,
  session_token : String?,
) -> S3Config {
  {
    endpoint,
    region: "us-east-1",
    bucket,
    access_key_id: "AKIAIOSFODNN7EXAMPLE",
    secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    session_token,
    path_style,
  }
}

///|
fn signature_of(req : SignedRequest) -> String {
  let auth = req.headers["Authorization"]
  match auth.find("Signature=") {
    Some(i) => String::unsafe_substring(auth, start=i + 10, end=auth.length())
    None => "<missing>"
  }
}

///|
test "sigv4: AWS documented GET Object vector" {
  // From the AWS SigV4 examples: GET /test.txt with a Range header, signed at
  // 20130524T000000Z. Both the canonical-request hash and the signature are
  // published, so this pins the whole chain.
  let config = config_of(
    "https://examplebucket.s3.amazonaws.com",
    "examplebucket",
    false,
    None,
  )
  let canonical = s3_canonical_request(
    config,
    "GET",
    "/test.txt",
    [],
    { "Range": "bytes=0-9" },
    Bytes::new(0),
    "20130524T000000Z",
  )
  inspect(
    hex_sha256(@utf8.encode(canonical)),
    content="7344ae5b7ee6c3e7e6b0fe0640412a37625d1fbfff95c48bbb2dc43964946972",
  )
  let signed = sign_s3_request(
    config,
    "GET",
    "/test.txt",
    [],
    { "Range": "bytes=0-9" },
    Bytes::new(0),
    "20130524T000000Z",
  )
  inspect(
    signature_of(signed),
    content="f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41",
  )
}

///|
test "sigv4: path-style PUT with If-Match is the CAS request we actually send" {
  let config = config_of(
    "https://s3.us-east-1.amazonaws.com",
    "mybucket",
    true,
    None,
  )
  let body = @utf8.encode("{\"head_seq\":1}")
  let signed = sign_s3_request(
    config,
    "PUT",
    "/mybucket/repos/acme/app/manifest.json",
    [],
    { "If-Match": "\"abc123\"", "Content-Type": "application/json" },
    body,
    "20260101T120000Z",
  )
  inspect(
    signature_of(signed),
    content="64aec84d7d9860630f3ec3c3f117d075af687b72dd1e7d36a612185a764a1a0b",
  )
  // The payload hash must be advertised, not just signed.
  inspect(
    signed.headers["x-amz-content-sha256"],
    content="32112442172ad3d7c60fc85edbbc65cf416f4cb047f20e5506c74b79f80b6067",
  )
  inspect(
    signed.url,
    content="https://s3.us-east-1.amazonaws.com/mybucket/repos/acme/app/manifest.json",
  )
}

///|
test "sigv4: query parameters are sorted and encoded" {
  let config = config_of(
    "https://s3.us-east-1.amazonaws.com",
    "mybucket",
    true,
    None,
  )
  let signed = sign_s3_request(
    config,
    "GET",
    "/mybucket",
    [
      ("list-type", "2"),
      ("prefix", "repos/acme/app/log/"),
      ("start-after", "repos/acme/app/log/0000000005"),
    ],
    Map([]),
    Bytes::new(0),
    "20260101T120000Z",
  )
  inspect(
    signature_of(signed),
    content="a940d8e722d8fb61c3a16ef4df0904a09d4e94446132c10122b0a9762b589a40",
  )
  // Slashes inside a query value are encoded; the ampersand order is sorted.
  inspect(
    signed.url,
    content="https://s3.us-east-1.amazonaws.com/mybucket?list-type=2&prefix=repos%2Facme%2Fapp%2Flog%2F&start-after=repos%2Facme%2Fapp%2Flog%2F0000000005",
  )
}

///|
test "uri_encode: unreserved characters survive, everything else is escaped" {
  inspect(uri_encode("abcXYZ019-._~", true), content="abcXYZ019-._~")
  inspect(uri_encode("a/b", true), content="a%2Fb")
  inspect(uri_encode("a/b", false), content="a/b")
  inspect(uri_encode("a b+c", true), content="a%20b%2Bc")
  // Multi-byte input is encoded per UTF-8 byte, not per character.
  inspect(uri_encode("é", true), content="%C3%A9")
}

///|
test "endpoint_host: host is taken with its port and without the path" {
  inspect(
    endpoint_host("https://s3.us-east-1.amazonaws.com"),
    content="s3.us-east-1.amazonaws.com",
  )
  inspect(endpoint_host("http://127.0.0.1:9000"), content="127.0.0.1:9000")
  inspect(endpoint_host("https://host:9000/prefix"), content="host:9000")
}

///|
test "endpoint_host: a scheme-less endpoint is rejected rather than guessed" {
  let failed = try {
    let _ = endpoint_host("s3.amazonaws.com")
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "sigv4: session token is signed when present" {
  let config = config_of(
    "https://s3.us-east-1.amazonaws.com",
    "examplebucket",
    true,
    Some("FQoGZXIvYXdzEBYaD"),
  )
  let signed = sign_s3_request(
    config,
    "GET",
    "/examplebucket/k",
    [],
    Map([]),
    Bytes::new(0),
    "20260101T120000Z",
  )
  inspect(signed.headers["x-amz-security-token"], content="FQoGZXIvYXdzEBYaD")
  inspect(
    signed.headers["Authorization"].contains("x-amz-security-token"),
    content="true",
  )
}
