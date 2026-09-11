///| Native HTTP client implementation using @http package

///| This file is only compiled for native target

///|
pub struct NativeHttpClient {
  // No state needed, uses @http directly
  dummy : Int
}

///|
pub fn NativeHttpClient::new() -> NativeHttpClient {
  { dummy: 0 }
}

///|
async fn apply_auth_header(
  url : String,
  headers : Map[String, String],
) -> Map[String, String] raise @bit.GitError {
  if headers.contains("Authorization") {
    return headers
  }
  let auth = resolve_auth_header(url)
  match auth {
    None => headers
    Some(value) => {
      let out : Map[String, String] = Map([])
      for k, v in headers {
        out[k] = v
      }
      out["Authorization"] = value
      out
    }
  }
}

///|
async fn resolve_auth_header(url : String) -> String? raise @bit.GitError {
  match parse_http_url(url) {
    None => None
    Some((protocol, host, path, username, password)) =>
      match password {
        Some(pass) => {
          let user = username.unwrap_or("")
          Some(build_basic_auth(user, pass))
        }
        None => {
          let cred_path = normalize_credential_path(path)
          match bit_credential_fill(protocol, host, cred_path, username) {
            None => None
            Some((user, pass)) => Some(build_basic_auth(user, pass))
          }
        }
      }
  }
}

///|
fn build_basic_auth(username : String, password : String) -> String {
  let raw = username + ":" + password
  let encoded = @base64.encode(@utf8.encode(raw), url_safe=false)
  "Basic " + encoded
}

///|
fn parse_http_url(url : String) -> (String, String, String, String?, String?)? {
  let (protocol, rest) = if url.has_prefix("https://") {
    ("https", String::unsafe_substring(url, start=8, end=url.length()))
  } else if url.has_prefix("http://") {
    ("http", String::unsafe_substring(url, start=7, end=url.length()))
  } else {
    return None
  }
  let slash = rest.find("/")
  let authority = match slash {
    Some(idx) => String::unsafe_substring(rest, start=0, end=idx)
    None => rest
  }
  let path = match slash {
    Some(idx) =>
      String::unsafe_substring(rest, start=idx + 1, end=rest.length())
    None => ""
  }
  let mut host = authority
  let mut username : String? = None
  let mut password : String? = None
  match authority.rev_find("@") {
    Some(at) => {
      let userinfo = String::unsafe_substring(authority, start=0, end=at)
      host = String::unsafe_substring(
        authority,
        start=at + 1,
        end=authority.length(),
      )
      match userinfo.find(":") {
        Some(colon) => {
          username = Some(
            String::unsafe_substring(userinfo, start=0, end=colon),
          )
          password = Some(
            String::unsafe_substring(
              userinfo,
              start=colon + 1,
              end=userinfo.length(),
            ),
          )
        }
        None => username = Some(userinfo)
      }
    }
    None => ()
  }
  Some((protocol, host, path, username, password))
}

///|
fn normalize_credential_path(path : String) -> String {
  let mut out = path
  if out.find("?") is Some(q) {
    out = String::unsafe_substring(out, start=0, end=q)
  }
  let suffix_info = "/info/refs"
  if out.has_suffix(suffix_info) {
    out = String::unsafe_substring(
      out,
      start=0,
      end=out.length() - suffix_info.length(),
    )
  }
  let suffix_recv = "/git-receive-pack"
  if out.has_suffix(suffix_recv) {
    out = String::unsafe_substring(
      out,
      start=0,
      end=out.length() - suffix_recv.length(),
    )
  }
  out
}

///|
async fn bit_credential_fill(
  protocol : String,
  host : String,
  path : String,
  username : String?,
) -> (String, String)? raise @bit.GitError {
  let input = build_credential_input(protocol, host, path, username)
  let (stdin, writer) = @process.write_to_process() catch {
    err => raise @bit.GitError::IoError("git credential pipe failed: \{err}")
  }
  writer.write(input) catch {
    err => raise @bit.GitError::IoError("git credential write failed: \{err}")
  }
  writer.close()
  let (code, stdout, stderr) = @process.collect_output(
    "git",
    ["credential", "fill"],
    inherit_env=true,
    stdin~,
    extra_env={ "GIT_TERMINAL_PROMPT": "0" },
  ) catch {
    err => raise @bit.GitError::IoError("git credential fill failed: \{err}")
  }
  if code != 0 {
    ignore(stderr)
    return None
  }
  let text = stdout.text() catch {
    err if @async.is_cancellation_error(err) =>
      raise @bit.GitError::IoError(err.to_string())
    _ => ""
  }
  let mut user : String? = None
  let mut pass : String? = None
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    match line.find("=") {
      Some(eq) => {
        let key = String::unsafe_substring(line, start=0, end=eq)
        let value = String::unsafe_substring(
          line,
          start=eq + 1,
          end=line.length(),
        )
        if key == "username" {
          user = Some(value)
        } else if key == "password" || key == "token" || key == "oauth_token" {
          pass = Some(value)
        }
      }
      None => ()
    }
  }
  match pass {
    Some(p) => Some((user.unwrap_or(""), p))
    None => None
  }
}

///|
fn build_credential_input(
  protocol : String,
  host : String,
  path : String,
  username : String?,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("protocol=" + protocol + "\n")
  sb.write_string("host=" + host + "\n")
  if path.length() > 0 {
    sb.write_string("path=" + path + "\n")
  }
  if username is Some(u) {
    sb.write_string("username=" + u + "\n")
  }
  sb.write_string("\n")
  sb.to_string()
}

///|
/// Read a response body to completion and close the client.
///
/// A read error is treated as end of body rather than raised, because some
/// servers close abruptly once the body is complete. `drain_response_strict`
/// is the variant for callers that cannot tolerate a silent truncation.
async fn drain_response(client : @http.Client) -> Bytes raise @bit.GitError {
  let data = collect_response(client, false)
  client.close()
  data
}

///|
/// Read a response body to completion, raising if the transfer breaks.
///
/// Object storage reads must not truncate silently: a short pack that reports
/// success is worse than a failed request.
async fn drain_response_strict(
  client : @http.Client,
) -> Bytes raise @bit.GitError {
  let data = try {
    collect_response(client, true)
  } catch {
    e => {
      client.close()
      raise e
    }
  }
  client.close()
  data
}

///|
async fn collect_response(
  client : @http.Client,
  strict : Bool,
) -> Bytes raise @bit.GitError {
  let chunks : Array[Byte] = []
  while true {
    let chunk = client.read_some() catch {
      err if @async.is_cancellation_error(err) =>
        raise @bit.GitError::IoError(err.to_string())
      err =>
        if strict {
          raise @bit.GitError::IoError("HTTP response body truncated: \{err}")
        } else {
          break
        }
    }
    match chunk {
      Some(b) =>
        for byte in b {
          chunks.push(byte)
        }
      None => break
    }
  }
  Bytes::from_array(FixedArray::makei(chunks.length(), i => chunks[i]))
}

///|
/// Carry the response headers through.
///
/// They were previously dropped, which made ETags invisible and so made
/// compare-and-swap against an object store impossible.
fn http_response_of(response : @http.Response) -> @bit.HttpResponse {
  let headers : Map[String, String] = Map([])
  for name, value in response.headers {
    headers[name] = value
  }
  @bit.HttpResponse::with_headers(response.code, headers)
}

///|
/// Split an absolute URL into the origin a `Client` connects to and the path
/// a request line carries.
fn split_url_origin(url : String) -> (String, String) raise @bit.GitError {
  let scheme_end = match url.find("://") {
    Some(i) => i + 3
    None =>
      raise @bit.GitError::IoError("URL has no scheme: \{url}")
  }
  let rest = String::unsafe_substring(url, start=scheme_end, end=url.length())
  match rest.find("/") {
    Some(i) => (
      String::unsafe_substring(url, start=0, end=scheme_end + i),
      String::unsafe_substring(url, start=scheme_end + i, end=url.length()),
    )
    None => (url, "/")
  }
}

///|
pub async fn native_http_get(
  url : String,
  headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  let auth_headers = apply_auth_header(url, headers)
  let (response, client) = @http.get_stream(url, headers=auth_headers) catch {
    e => raise @bit.GitError::IoError("HTTP GET failed: \{e}")
  }
  let data = drain_response(client)
  (http_response_of(response), data)
}

///|
pub async fn native_http_post(
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  let auth_headers = apply_auth_header(url, headers)
  let client = @http.post_stream(url, headers=auth_headers) catch {
    e => raise @bit.GitError::IoError("HTTP POST failed: \{e}")
  }
  client.write(body) catch {
    e => raise @bit.GitError::IoError("HTTP POST write failed: \{e}")
  }
  let response = client.end_request() catch {
    e => raise @bit.GitError::IoError("HTTP POST end_request failed: \{e}")
  }
  let data = drain_response(client)
  (http_response_of(response), data)
}

///|
pub impl @types.AsyncHttpClient for NativeHttpClient with fn get(
  _self,
  url,
  headers,
) {
  native_http_get(url, headers)
}

///|
pub impl @types.AsyncHttpClient for NativeHttpClient with fn post(
  _self,
  url,
  body,
  headers,
) {
  native_http_post(url, body, headers)
}

///|
pub async fn native_http_put(
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  let auth_headers = apply_auth_header(url, headers)
  let client = @http.put_stream(url, headers=auth_headers) catch {
    e => raise @bit.GitError::IoError("HTTP PUT failed: \{e}")
  }
  client.write(body) catch {
    e => raise @bit.GitError::IoError("HTTP PUT write failed: \{e}")
  }
  let response = client.end_request() catch {
    e => raise @bit.GitError::IoError("HTTP PUT end_request failed: \{e}")
  }
  let data = drain_response(client)
  (http_response_of(response), data)
}

///|
/// DELETE, needed by object-store garbage collection.
///
/// `@http` exposes no `delete_stream`, so the request is issued through a
/// `Client` directly: the constructor takes an origin, the request line takes
/// the path.
pub async fn native_http_delete(
  url : String,
  headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  let auth_headers = apply_auth_header(url, headers)
  let (origin, path) = split_url_origin(url)
  let client = @http.Client::Client(origin) catch {
    e => raise @bit.GitError::IoError("HTTP DELETE connect failed: \{e}")
  }
  let response = try {
    client.request(@http.RequestMethod::Delete, path, extra_headers=auth_headers)
    client.end_request()
  } catch {
    e => {
      client.close()
      raise @bit.GitError::IoError("HTTP DELETE failed: \{e}")
    }
  }
  let data = drain_response_strict(client)
  (http_response_of(response), data)
}

///|
/// Native transport for `bit_objstore`.
///
/// This is the only place the object store touches the network: the store
/// itself takes this as an injected function, which is what lets its
/// status-code handling be tested without a bucket and lets the same store
/// run under a different transport elsewhere.
///
/// Bodies are read strictly — a truncated pack that reported success would
/// corrupt the repository it was read for.
pub async fn native_objstore_send(
  verb : String,
  url : String,
  headers : Map[String, String],
  body : Bytes,
) -> @objstore.HttpReply raise @bit.GitError {
  let (origin, path) = split_url_origin(url)
  let request_method = match verb {
    "GET" => @http.RequestMethod::Get
    "PUT" => @http.RequestMethod::Put
    "POST" => @http.RequestMethod::Post
    "DELETE" => @http.RequestMethod::Delete
    "HEAD" => @http.RequestMethod::Head
    other => raise @bit.GitError::IoError("unsupported HTTP verb: \{other}")
  }
  // The request is already SigV4-signed, so no credential helper may add to
  // it: an extra header would invalidate the signature.
  let client = @http.Client::Client(origin) catch {
    e => raise @bit.GitError::IoError("connect to \{origin} failed: \{e}")
  }
  let response = try {
    client.request(request_method, path, extra_headers=headers)
    if body.length() > 0 {
      client.write(body)
    }
    client.end_request()
  } catch {
    e => {
      client.close()
      raise @bit.GitError::IoError("\{verb} \{url} failed: \{e}")
    }
  }
  let data = drain_response_strict(client)
  let out_headers : Map[String, String] = Map([])
  for name, value in response.headers {
    out_headers[name] = value
  }
  { status: response.code, headers: out_headers, body: data }
}

///|
/// Build an S3-backed store wired to the native transport and clock.
pub fn native_s3_store(
  config : @objstore.S3Config,
  page_size? : Int = 1000,
) -> @objstore.S3Store {
  @objstore.S3Store::new(
    config,
    (verb, url, headers, body) => native_objstore_send(verb, url, headers, body),
    amz_date_now,
    page_size~,
  )
}
