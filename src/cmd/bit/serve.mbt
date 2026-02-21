///|
fn print_hub_serve_usage() -> Unit {
  println("Usage: bit hub serve [<relay-url>] [--repo <name>]")
  println("")
  println("Serve the current repository via relay for remote cloning.")
  println("The relay URL should use relay+https:// or relay+http:// prefix.")
  println("")
  println("Options:")
  println("  --repo <name>    Repository name to advertise")
  println("  -h, --help       Show this help")
}

///|
struct HubServeOptions {
  relay_url : String
  repo : String?
}

///|
fn parse_hub_serve_options(args : Array[String]) -> HubServeOptions? {
  let mut relay_url : String? = None
  let mut repo : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      print_hub_serve_usage()
      return None
    }
    if arg == "--repo" && i + 1 < args.length() {
      repo = Some(args[i + 1])
      i += 2
      continue
    }
    if arg.has_prefix("--repo=") {
      repo = Some(
        String::unsafe_substring(arg, start=7, end=arg.length()),
      )
      i += 1
      continue
    }
    if not(arg.has_prefix("-")) && relay_url is None {
      relay_url = Some(arg)
      i += 1
      continue
    }
    i += 1
  }
  let url = match relay_url {
    Some(u) => u
    None =>
      match @sys.get_env_var("BIT_RELAY_URL") {
        Some(u) => u
        None => {
          println("Error: relay URL required")
          print_hub_serve_usage()
          return None
        }
      }
  }
  Some({ relay_url: url, repo })
}

///|
fn serve_parse_relay_base_url(remote_url : String) -> String? {
  if remote_url.has_prefix("relay+http://") ||
    remote_url.has_prefix("relay+https://") {
    let raw = String::unsafe_substring(
      remote_url,
      start=6,
      end=remote_url.length(),
    )
    Some(serve_trim_trailing_slash(raw))
  } else if remote_url.has_prefix("relay://") {
    let suffix = String::unsafe_substring(
      remote_url,
      start=8,
      end=remote_url.length(),
    )
    Some(serve_trim_trailing_slash("http://" + suffix))
  } else if remote_url.has_prefix("http://") ||
    remote_url.has_prefix("https://") {
    Some(serve_trim_trailing_slash(remote_url))
  } else {
    None
  }
}

///|
fn serve_trim_trailing_slash(s : String) -> String {
  if s.has_suffix("/") {
    String::unsafe_substring(s, start=0, end=s.length() - 1)
  } else {
    s
  }
}

///|
fn serve_decode_bytes(data : Bytes) -> String {
  @encoding.decoder(@encoding.Encoding::UTF8).decode_lossy(data[:])
}

///|
fn serve_json_get_string(
  obj : Map[String, Json],
  key : String,
) -> String? {
  match obj.get(key) {
    Some(Json::String(value)) => Some(value)
    _ => None
  }
}

///|
fn serve_b64_char(idx : Int) -> Char {
  let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let mut pos = 0
  for c in table {
    if pos == idx {
      return c
    }
    pos += 1
  }
  'A'
}

///|
fn serve_base64_encode(data : Bytes) -> String {
  let out = StringBuilder::new()
  let len = data.length()
  let mut i = 0
  while i < len {
    let b0 = data[i].to_int()
    let b1 = if i + 1 < len { data[i + 1].to_int() } else { 0 }
    let b2 = if i + 2 < len { data[i + 2].to_int() } else { 0 }
    let n = (b0 << 16) | (b1 << 8) | b2
    out.write_char(serve_b64_char((n >> 18) & 0x3f))
    out.write_char(serve_b64_char((n >> 12) & 0x3f))
    if i + 1 < len {
      out.write_char(serve_b64_char((n >> 6) & 0x3f))
    } else {
      out.write_char('=')
    }
    if i + 2 < len {
      out.write_char(serve_b64_char(n & 0x3f))
    } else {
      out.write_char('=')
    }
    i += 3
  }
  out.to_string()
}

///|
fn serve_b64_decode_char(c : Char) -> Int {
  if c >= 'A' && c <= 'Z' {
    c.to_int() - 'A'.to_int()
  } else if c >= 'a' && c <= 'z' {
    c.to_int() - 'a'.to_int() + 26
  } else if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int() + 52
  } else if c == '+' {
    62
  } else if c == '/' {
    63
  } else {
    -1
  }
}

///|
fn serve_base64_decode(b64 : String) -> Bytes {
  let out : Array[Byte] = []
  let chars : Array[Int] = []
  for c in b64 {
    if c == '=' {
      break
    }
    let v = serve_b64_decode_char(c)
    if v >= 0 {
      chars.push(v)
    }
  }
  let mut i = 0
  while i + 1 < chars.length() {
    if i + 3 < chars.length() {
      let n = (chars[i] << 18) | (chars[i + 1] << 12) | (chars[i + 2] << 6) |
        chars[i + 3]
      out.push(((n >> 16) & 0xff).to_byte())
      out.push(((n >> 8) & 0xff).to_byte())
      out.push((n & 0xff).to_byte())
      i += 4
    } else if i + 2 < chars.length() {
      let n = (chars[i] << 18) | (chars[i + 1] << 12) | (chars[i + 2] << 6)
      out.push(((n >> 16) & 0xff).to_byte())
      out.push(((n >> 8) & 0xff).to_byte())
      i += 3
    } else {
      let n = (chars[i] << 18) | (chars[i + 1] << 12)
      out.push(((n >> 16) & 0xff).to_byte())
      i += 2
    }
  }
  Bytes::from_array(FixedArray::makei(out.length(), fn(idx) { out[idx] }))
}

///|
async fn serve_register_session(
  base_url : String,
) -> String raise Error {
  let url = base_url + "/api/v1/serve/register"
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
  }
  let (response, body) = @bitnative.native_http_post(
    url,
    Bytes::new(0),
    headers,
  )
  if response.code != 200 {
    raise @bitcore.GitError::ProtocolError(
      "Failed to register session: HTTP \{response.code}",
    )
  }
  let text = serve_decode_bytes(body)
  let parsed = @json.parse(text) catch {
    _ =>
      raise @bitcore.GitError::ProtocolError(
        "Failed to parse register response",
      )
  }
  guard parsed is Json::Object(obj) else {
    raise @bitcore.GitError::ProtocolError(
      "Invalid register response format",
    )
  }
  guard serve_json_get_string(obj, "session_id") is Some(session_id) else {
    raise @bitcore.GitError::ProtocolError(
      "Missing session_id in register response",
    )
  }
  session_id
}

///|
struct ServePollRequest {
  request_id : String
  req_method : String
  path : String
  headers : Map[String, String]
  body_base64 : String?
}

///|
fn serve_parse_poll_response(body : Bytes) -> Array[ServePollRequest]? {
  let text = serve_decode_bytes(body)
  let parsed = @json.parse(text) catch { _ => return None }
  guard parsed is Json::Object(root) else { return None }
  match root.get("ok") {
    Some(Json::True) => ()
    _ => return None
  }
  let requests : Array[ServePollRequest] = []
  guard root.get("requests") is Some(Json::Array(arr)) else {
    return Some(requests)
  }
  for item in arr {
    guard item is Json::Object(obj) else { continue }
    let request_id = match serve_json_get_string(obj, "request_id") {
      Some(s) => s
      None => continue
    }
    let req_method = match serve_json_get_string(obj, "method") {
      Some(s) => s
      None => "GET"
    }
    let path = match serve_json_get_string(obj, "path") {
      Some(s) => s
      None => continue
    }
    let headers : Map[String, String] = {}
    match obj.get("headers") {
      Some(Json::Object(hobj)) =>
        for key, value in hobj {
          match value {
            Json::String(v) => headers[key] = v
            _ => ()
          }
        }
      _ => ()
    }
    let body_base64 : String? = serve_json_get_string(obj, "body_base64")
    requests.push({ request_id, req_method, path, headers, body_base64 })
  }
  Some(requests)
}

///|
async fn serve_poll(
  base_url : String,
  session_id : String,
  timeout : Int,
) -> Array[ServePollRequest] raise Error {
  let url = "\{base_url}/api/v1/serve/poll?session=\{session_id}&timeout=\{timeout}"
  let headers : Map[String, String] = {}
  let (response, body) = @bitnative.native_http_get(url, headers)
  if response.code != 200 {
    raise @bitcore.GitError::ProtocolError(
      "Poll failed: HTTP \{response.code}",
    )
  }
  match serve_parse_poll_response(body) {
    Some(requests) => requests
    None =>
      raise @bitcore.GitError::ProtocolError("Failed to parse poll response")
  }
}

///|
fn serve_concat_bytes(chunks : Array[Bytes]) -> Bytes {
  let result : Array[Byte] = []
  for chunk in chunks {
    for b in chunk {
      result.push(b)
    }
  }
  Bytes::from_array(FixedArray::makei(result.length(), fn(i) { result[i] }))
}

///|
async fn serve_respond(
  base_url : String,
  session_id : String,
  request_id : String,
  status : Int,
  response_headers : Map[String, String],
  body_base64 : String,
) -> Unit raise Error {
  let url = "\{base_url}/api/v1/serve/respond?session=\{session_id}"
  let headers_obj : Map[String, Json] = {}
  for entry in response_headers.to_array() {
    let (key, value) = entry
    headers_obj[key] = Json::string(value)
  }
  let payload_obj : Map[String, Json] = {}
  payload_obj["request_id"] = Json::string(request_id)
  payload_obj["status"] = Json::number(status.to_double())
  payload_obj["headers"] = Json::object(headers_obj)
  payload_obj["body_base64"] = Json::string(body_base64)
  let payload = Json::object(payload_obj)
  let payload_text = payload.stringify()
  let payload_bytes = @encoding.encode(@encoding.Encoding::UTF8, payload_text)
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
  }
  let (response, _body) = @bitnative.native_http_post(
    url,
    payload_bytes,
    headers,
  )
  if response.code != 200 {
    eprint_line(
      "Warning: respond failed for request \{request_id}: HTTP \{response.code}",
    )
  }
}

///|
async fn serve_handle_git_request(
  repo_root : String,
  req : ServePollRequest,
) -> (Int, Map[String, String], Bytes) raise Error {
  let path = req.path
  if path.has_prefix("/info/refs") {
    let fs = OsFs::new()
    let root = normalize_repo_root(repo_root)
    let out = @bitlib.build_upload_pack_advertisement(fs, root)
    let service_line = "# service=git-upload-pack\n"
    let pkt_service = @protocol.pktline_encode(service_line)
    let flush_bytes = @encoding.encode(@encoding.Encoding::UTF8, "0000")
    let full_body = serve_concat_bytes([pkt_service, flush_bytes, out])
    let headers : Map[String, String] = {
      "Content-Type": "application/x-git-upload-pack-advertisement",
    }
    (200, headers, full_body)
  } else if path.has_prefix("/git-upload-pack") {
    let input_bytes = match req.body_base64 {
      Some(b64) => serve_base64_decode(b64)
      None => Bytes::new(0)
    }
    let fs = OsFs::new()
    let root = normalize_repo_root(repo_root)
    let protocol_version = @bitlib.get_protocol_version()
    let cmdline_config = @bitlib.parse_config_overrides()
    let out = if protocol_version == 2 {
      let pack_req = @bitlib.parse_upload_pack_request_v2(input_bytes)
      let config = @bitlib.build_upload_pack_config_with_overrides(
        fs, root, cmdline_config,
      )
      @bitlib.upload_pack_v2(fs, root, pack_req, config)
    } else {
      let pack_req = @bitlib.parse_upload_pack_request(input_bytes)
      @bitlib.upload_pack(fs, root, pack_req)
    }
    let headers : Map[String, String] = {
      "Content-Type": "application/x-git-upload-pack-result",
    }
    (200, headers, out)
  } else {
    let error_body = @encoding.encode(@encoding.Encoding::UTF8, "not found")
    (404, {}, error_body)
  }
}

///|
async fn handle_hub_serve(args : Array[String]) -> Unit raise Error {
  guard parse_hub_serve_options(args) is Some(options) else { return }
  guard serve_parse_relay_base_url(options.relay_url) is Some(base_url) else {
    eprint_line(
      "Error: invalid relay URL '\{options.relay_url}'. Use relay+https://... or relay+http://...",
    )
    @sys.exit(1)
    return
  }
  let repo_root = get_work_root()
  let session_id = serve_register_session(base_url)
  print_line("Session registered: \{session_id}")
  print_line("Clone URL: \{options.relay_url}/\{session_id}")
  print_line("Waiting for clone requests... (Ctrl-C to stop)")
  while true {
    let requests = serve_poll(base_url, session_id, 30) catch {
      err => {
        if @async.is_cancellation_error(err) {
          break
        }
        eprint_line("Poll error: \{err}, retrying...")
        continue
      }
    }
    for req in requests {
      print_line("[\{session_id}] \{req.req_method} \{req.path}")
      let (status, response_headers, body) = serve_handle_git_request(
        repo_root,
        req,
      ) catch {
        err => {
          eprint_line("Error handling request \{req.request_id}: \{err}")
          let error_body = @encoding.encode(
            @encoding.Encoding::UTF8,
            "internal server error",
          )
          (500, {}, error_body)
        }
      }
      let body_b64 = serve_base64_encode(body)
      serve_respond(
        base_url,
        session_id,
        req.request_id,
        status,
        response_headers,
        body_b64,
      ) catch {
        err => {
          if @async.is_cancellation_error(err) {
            break
          }
          eprint_line("Respond error: \{err}")
        }
      }
    }
  }
}
