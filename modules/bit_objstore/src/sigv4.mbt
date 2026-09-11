///|
/// AWS Signature Version 4 request signing.
///
/// Pure: it takes a clock reading rather than reading one, so the whole
/// signer is testable against the published AWS vectors.

///|
/// Connection details for an S3-compatible endpoint.
pub(all) struct S3Config {
  /// Scheme and host, no trailing slash, e.g. `https://s3.us-east-1.amazonaws.com`
  /// or `https://<account>.r2.cloudflarestorage.com`.
  endpoint : String
  region : String
  bucket : String
  access_key_id : String
  secret_access_key : String
  /// Set for temporary credentials (STS).
  session_token : String?
  /// Address objects as `<endpoint>/<bucket>/<key>` rather than as a
  /// virtual host. R2 and MinIO require this.
  path_style : Bool
}

///|
/// A request ready to hand to an HTTP client.
pub(all) struct SignedRequest {
  verb : String
  url : String
  headers : Map[String, String]
  body : Bytes
}

///|
/// The service name in the SigV4 credential scope. R2 and MinIO both present
/// themselves as `s3`.
const S3_SERVICE : String = "s3"

///|
/// RFC 3986 percent-encoding, as SigV4 requires it.
///
/// Only `A-Z a-z 0-9 - . _ ~` survive unencoded. `/` survives too when
/// `encode_slash` is false, which is how the canonical URI keeps its path
/// separators while a query value does not.
pub fn uri_encode(value : String, encode_slash : Bool) -> String {
  let digits = "0123456789ABCDEF"
  let out = StringBuilder::new()
  for byte in @utf8.encode(value) {
    let b = byte.to_int()
    let is_unreserved = (b >= 0x41 && b <= 0x5a) ||
      (b >= 0x61 && b <= 0x7a) ||
      (b >= 0x30 && b <= 0x39) ||
      b == 0x2d ||
      b == 0x2e ||
      b == 0x5f ||
      b == 0x7e
    if is_unreserved {
      out.write_char(b.unsafe_to_char())
    } else if b == 0x2f && !encode_slash {
      out.write_char('/')
    } else {
      out.write_char('%')
      out.write_char(digits[(b >> 4) & 0xf].to_int().unsafe_to_char())
      out.write_char(digits[b & 0xf].to_int().unsafe_to_char())
    }
  }
  out.to_string()
}

///|
/// Lowercase hex SHA-256 of a payload.
pub fn hex_sha256(data : Bytes) -> String {
  @hash.hex_encode(@hash.sha256_raw(data))
}

///|
/// Host (with port, when present) of an endpoint URL.
pub fn endpoint_host(endpoint : String) -> String raise @bit.GitError {
  let rest = if endpoint.has_prefix("https://") {
    String::unsafe_substring(endpoint, start=8, end=endpoint.length())
  } else if endpoint.has_prefix("http://") {
    String::unsafe_substring(endpoint, start=7, end=endpoint.length())
  } else {
    raise @bit.GitError::IoError(
      "endpoint must start with http:// or https://: \{endpoint}",
    )
  }
  let host = match rest.find("/") {
    Some(i) => String::unsafe_substring(rest, start=0, end=i)
    None => rest
  }
  if host.length() == 0 {
    raise @bit.GitError::IoError("endpoint has no host: \{endpoint}")
  }
  host
}

///|
fn lowercase(s : String) -> String {
  let out = StringBuilder::new()
  for c in s {
    let code = c.to_int()
    if code >= 0x41 && code <= 0x5a {
      out.write_char((code + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// Strip the leading and trailing whitespace SigV4 requires trimmed from
/// header values before they are signed.
fn trim_header_value(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end && (s[start] == ' ' || s[start] == '\t') {
    start += 1
  }
  while end > start && (s[end - 1] == ' ' || s[end - 1] == '\t') {
    end -= 1
  }
  String::unsafe_substring(s, start~, end~)
}

///|
/// Canonical query string: percent-encoded pairs sorted by name.
fn canonical_query(query : Array[(String, String)]) -> String {
  let pairs : Array[(String, String)] = []
  for pair in query {
    pairs.push((uri_encode(pair.0, true), uri_encode(pair.1, true)))
  }
  pairs.sort_by((a, b) => {
    if a.0 == b.0 {
      lex_compare(a.1, b.1)
    } else {
      lex_compare(a.0, b.0)
    }
  })
  let out = StringBuilder::new()
  for i in 0..<pairs.length() {
    if i > 0 {
      out.write_char('&')
    }
    out.write_string(pairs[i].0)
    out.write_char('=')
    out.write_string(pairs[i].1)
  }
  out.to_string()
}

///|
/// The header set that will be signed: the caller's headers lowercased and
/// trimmed, plus the three (or four) SigV4 always adds.
fn signed_header_set(
  config : S3Config,
  headers : Map[String, String],
  payload_hash : String,
  host : String,
  amz_date : String,
) -> Map[String, String] {
  let signed : Map[String, String] = Map([])
  for name, value in headers {
    signed[lowercase(name)] = trim_header_value(value)
  }
  signed["host"] = host
  signed["x-amz-date"] = amz_date
  signed["x-amz-content-sha256"] = payload_hash
  match config.session_token {
    Some(token) => signed["x-amz-security-token"] = token
    None => ()
  }
  signed
}

///|
/// Canonical request plus the `SignedHeaders` list that goes with it. Both
/// fall out of the same sorted header walk, so they are produced together.
fn canonical_request_of(
  signed : Map[String, String],
  verb : String,
  path : String,
  query : Array[(String, String)],
  payload_hash : String,
) -> (String, String) {
  let names : Array[String] = []
  for name, _ in signed {
    names.push(name)
  }
  names.sort_by((a, b) => lex_compare(a, b))
  let canonical_headers = StringBuilder::new()
  let signed_headers = StringBuilder::new()
  for i in 0..<names.length() {
    if i > 0 {
      signed_headers.write_char(';')
    }
    signed_headers.write_string(names[i])
    canonical_headers.write_string(names[i])
    canonical_headers.write_char(':')
    canonical_headers.write_string(signed[names[i]])
    canonical_headers.write_char('\n')
  }
  let signed_headers_str = signed_headers.to_string()
  let canonical = "\{verb}\n" +
    "\{uri_encode(path, false)}\n" +
    "\{canonical_query(query)}\n" +
    "\{canonical_headers.to_string()}\n" +
    "\{signed_headers_str}\n" +
    payload_hash
  (canonical, signed_headers_str)
}

///|
/// The canonical request string, exposed for tests and for diagnosing the
/// `SignatureDoesNotMatch` responses that are otherwise opaque.
pub fn s3_canonical_request(
  config : S3Config,
  verb : String,
  path : String,
  query : Array[(String, String)],
  headers : Map[String, String],
  body : Bytes,
  amz_date : String,
) -> String raise @bit.GitError {
  let payload_hash = hex_sha256(body)
  let signed = signed_header_set(
    config,
    headers,
    payload_hash,
    endpoint_host(config.endpoint),
    amz_date,
  )
  let (canonical, _) = canonical_request_of(
    signed, verb, path, query, payload_hash,
  )
  canonical
}

///|
/// Sign a request for an S3-compatible endpoint.
///
/// `amz_date` is `YYYYMMDDTHHMMSSZ`; the credential scope's datestamp is its
/// first eight characters. Taking it as an argument rather than reading a
/// clock is what makes this function testable.
pub fn sign_s3_request(
  config : S3Config,
  verb : String,
  path : String,
  query : Array[(String, String)],
  headers : Map[String, String],
  body : Bytes,
  amz_date : String,
) -> SignedRequest raise @bit.GitError {
  if amz_date.length() < 8 {
    raise @bit.GitError::IoError("malformed x-amz-date: \{amz_date}")
  }
  let datestamp = String::unsafe_substring(amz_date, start=0, end=8)
  let payload_hash = hex_sha256(body)
  let signed = signed_header_set(
    config,
    headers,
    payload_hash,
    endpoint_host(config.endpoint),
    amz_date,
  )
  let (canonical_request, signed_headers_str) = canonical_request_of(
    signed, verb, path, query, payload_hash,
  )
  let scope = "\{datestamp}/\{config.region}/\{S3_SERVICE}/aws4_request"
  let string_to_sign = "AWS4-HMAC-SHA256\n" +
    "\{amz_date}\n" +
    "\{scope}\n" +
    hex_sha256(@utf8.encode(canonical_request))

  // kSigning = HMAC(HMAC(HMAC(HMAC("AWS4"+secret, date), region), service), "aws4_request")
  let k_date = @hash.hmac_sha256_bytes(
    @utf8.encode("AWS4" + config.secret_access_key),
    @utf8.encode(datestamp),
  )
  let k_region = @hash.hmac_sha256_bytes(k_date, @utf8.encode(config.region))
  let k_service = @hash.hmac_sha256_bytes(k_region, @utf8.encode(S3_SERVICE))
  let k_signing = @hash.hmac_sha256_bytes(
    k_service,
    @utf8.encode("aws4_request"),
  )
  let signature = @hash.hex_encode(
    @hash.hmac_sha256_raw(k_signing, @utf8.encode(string_to_sign)),
  )
  let out_headers : Map[String, String] = Map([])
  for name, value in signed {
    out_headers[name] = value
  }
  out_headers["Authorization"] = "AWS4-HMAC-SHA256 " +
    "Credential=\{config.access_key_id}/\{scope}, " +
    "SignedHeaders=\{signed_headers_str}, " +
    "Signature=\{signature}"
  let query_str = canonical_query(query)
  // The wire URL must carry the same encoding that was signed, or the
  // server recomputes a different canonical request and rejects it.
  let encoded_path = uri_encode(path, false)
  let url = if query_str.length() > 0 {
    "\{config.endpoint}\{encoded_path}?\{query_str}"
  } else {
    "\{config.endpoint}\{encoded_path}"
  }
  { verb, url, headers: out_headers, body }
}
