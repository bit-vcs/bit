///|
/// S3-compatible backend (AWS S3, Cloudflare R2, MinIO, Ceph).
///
/// The HTTP transport and the clock are injected rather than imported, so the
/// whole backend — including the status-code mapping that decides `Applied` /
/// `NotApplied` / `Unknown` — is testable without a network or a real bucket,
/// and so the same code can run on a native client or inside a Worker.

///|
/// Response of the injected transport: status, headers, body.
pub(all) struct HttpReply {
  status : Int
  headers : Map[String, String]
  body : Bytes
}

///|
pub struct S3Store {
  config : S3Config
  send : async (String, String, Map[String, String], Bytes) -> HttpReply raise @bit.GitError
  /// Returns the current time as `YYYYMMDDTHHMMSSZ`.
  now : () -> String
  /// Keys returned per listing page.
  page_size : Int
}

///|
pub fn S3Store::new(
  config : S3Config,
  send : async (String, String, Map[String, String], Bytes) -> HttpReply raise @bit.GitError,
  now : () -> String,
  page_size? : Int = 1000,
) -> S3Store {
  { config, send, now, page_size }
}

///|
/// Object path for a key, honouring path-style vs virtual-host addressing.
fn S3Store::object_path(self : S3Store, key : String) -> String {
  if self.config.path_style {
    "/\{self.config.bucket}/\{key}"
  } else {
    "/\{key}"
  }
}

///|
/// Bucket path, used by listings.
fn S3Store::bucket_path(self : S3Store) -> String {
  if self.config.path_style {
    "/\{self.config.bucket}"
  } else {
    "/"
  }
}

///|
/// Case-insensitive header lookup. Header casing varies by server, and R2 and
/// MinIO do not agree with AWS on it.
fn header_get(headers : Map[String, String], name : String) -> String? {
  let wanted = lowercase(name)
  for key, value in headers {
    if lowercase(key) == wanted {
      return Some(value)
    }
  }
  None
}

///|
/// S3 returns ETags wrapped in quotes; this API treats version tags as opaque
/// unquoted strings, so the quotes are stripped on the way in and restored on
/// the way out.
pub fn strip_etag_quotes(etag : String) -> String {
  let n = etag.length()
  if n >= 2 && etag[0] == '"' && etag[n - 1] == '"' {
    String::unsafe_substring(etag, start=1, end=n - 1)
  } else {
    etag
  }
}

///|
fn quote_etag(etag : String) -> String {
  if etag.length() >= 2 && etag[0] == '"' {
    etag
  } else {
    "\"\{etag}\""
  }
}

///|
/// Whether a status means the store never got a chance to decide.
///
/// A 5xx or a 429 leaves the write indeterminate: it may have been applied
/// before the failure. Reporting these as errors would tempt the caller into
/// a blind retry, which is how a WAL double-applies.
fn is_indeterminate(status : Int) -> Bool {
  status == 429 || status >= 500
}

///|
async fn S3Store::request(
  self : S3Store,
  verb : String,
  path : String,
  query : Array[(String, String)],
  headers : Map[String, String],
  body : Bytes,
) -> HttpReply raise @bit.GitError {
  let signed = sign_s3_request(
    self.config,
    verb,
    path,
    query,
    headers,
    body,
    (self.now)(),
  )
  (self.send)(signed.verb, signed.url, signed.headers, signed.body)
}

///|
fn reply_to_get(
  reply : HttpReply,
  key : String,
) -> GetOutcome raise @bit.GitError {
  if reply.status == 304 {
    return GetOutcome::NotModified
  }
  if reply.status == 404 {
    return GetOutcome::Missing
  }
  if reply.status == 200 || reply.status == 206 {
    let etag = match header_get(reply.headers, "etag") {
      Some(value) => strip_etag_quotes(value)
      None => ""
    }
    return GetOutcome::Found(reply.body, etag)
  }
  raise @bit.GitError::IoError("GET \{key} failed: HTTP \{reply.status}")
}

///|
pub impl ObjectStore for S3Store with fn get(self, key) {
  let reply = self.request(
    "GET",
    self.object_path(key),
    [],
    Map([]),
    Bytes::new(0),
  )
  reply_to_get(reply, key)
}

///|
pub impl ObjectStore for S3Store with fn get_range(self, key, range) {
  let headers : Map[String, String] = {
    "Range": "bytes=\{range.start}-\{range.end}",
  }
  let reply = self.request(
    "GET",
    self.object_path(key),
    [],
    headers,
    Bytes::new(0),
  )
  reply_to_get(reply, key)
}

///|
pub impl ObjectStore for S3Store with fn get_if_none_match(self, key, etag) {
  let headers : Map[String, String] = { "If-None-Match": quote_etag(etag) }
  let reply = self.request(
    "GET",
    self.object_path(key),
    [],
    headers,
    Bytes::new(0),
  )
  reply_to_get(reply, key)
}

///|
pub impl ObjectStore for S3Store with fn put(self, key, body, condition) {
  let headers : Map[String, String] = Map([])
  match condition {
    Unconditional => ()
    IfNotExists => headers["If-None-Match"] = "*"
    IfMatch(etag) => headers["If-Match"] = quote_etag(etag)
  }
  let reply = self.request("PUT", self.object_path(key), [], headers, body) catch {
    // A transport failure after the request left the client is exactly the
    // indeterminate case: the object may be there.
    _ => return PutOutcome::Unknown
  }
  if reply.status == 200 || reply.status == 201 {
    match header_get(reply.headers, "etag") {
      Some(value) => PutOutcome::Applied(strip_etag_quotes(value))
      // Without an ETag we cannot name the version we just wrote, and
      // guessing one would poison the next compare-and-swap. Make the caller
      // re-read instead.
      None => PutOutcome::Unknown
    }
  } else if reply.status == 412 || reply.status == 409 {
    // 412: the precondition did not hold.
    // 409: a concurrent conditional write won. Both mean "re-read and retry".
    PutOutcome::NotApplied
  } else if is_indeterminate(reply.status) {
    PutOutcome::Unknown
  } else if reply.status == 400 && condition is IfMatch(_) {
    // Some S3-compatible stores answer 400 rather than 501 for an
    // unsupported If-Match. Surface it as a hard error: silently treating it
    // as NotApplied would loop forever.
    raise @bit.GitError::IoError(
      "PUT \{key}: store rejected the conditional write (HTTP 400); " +
      "this backend may not support compare-and-swap",
    )
  } else {
    raise @bit.GitError::IoError("PUT \{key} failed: HTTP \{reply.status}")
  }
}

///|
pub impl ObjectStore for S3Store with fn delete(self, key) {
  let reply = self.request(
    "DELETE",
    self.object_path(key),
    [],
    Map([]),
    Bytes::new(0),
  )
  // 404 is success: the key is gone, which is what was asked for.
  if reply.status == 200 ||
    reply.status == 204 ||
    reply.status == 202 ||
    reply.status == 404 {
    return
  }
  raise @bit.GitError::IoError("DELETE \{key} failed: HTTP \{reply.status}")
}

///|
pub impl ObjectStore for S3Store with fn list(self, prefix, after) {
  let query : Array[(String, String)] = [
    ("list-type", "2"),
    ("max-keys", self.page_size.to_string()),
    ("prefix", prefix),
  ]
  if after != "" {
    query.push(("start-after", after))
  }
  let reply = self.request(
    "GET",
    self.bucket_path(),
    query,
    Map([]),
    Bytes::new(0),
  )
  if reply.status != 200 {
    raise @bit.GitError::IoError("LIST \{prefix} failed: HTTP \{reply.status}")
  }
  parse_list_objects_v2(@utf8.decode_lossy(reply.body[:]))
}

///|
pub impl ObjectStore for S3Store with fn supports_cas(_self) {
  true
}
