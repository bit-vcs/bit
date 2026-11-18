///|
/// Perform an SSE streaming fetch request (synchronous via curl).
/// headers_json and body are JSON strings.
/// timeout_sec: 0 means no timeout.
/// on_line is called for each SSE data line (without "data: " prefix).
/// on_error is called on error.
/// on_done is called when the stream is complete.
pub fn fetch_sse(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
  timeout_sec : Int,
  on_line : (String) -> Unit,
  on_error : (String) -> Unit,
  on_done : () -> Unit,
) -> Unit {
  let args = build_curl_args(url, http_method, headers_json, body, timeout_sec)
  let args_json = serialize_string_array(args)
  let result = run_command("curl", args_json)
  if result.has_prefix("ERROR:") {
    on_error(result)
    return
  }
  let lines = split_lines(result)
  for line in lines {
    let trimmed = line.trim(chars=" \t\r\n").to_owned()
    if trimmed.has_prefix("data: ") {
      let data = trimmed.unsafe_substring(start=6, end=trimmed.length())
      if data != "[DONE]" {
        on_line(data)
      }
    }
  }
  on_done()
}

///|
/// Perform a non-streaming fetch request (synchronous via curl).
/// Returns the response body as a string.
/// timeout_sec: 0 means no timeout.
pub fn fetch(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
  timeout_sec : Int,
  on_result : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  let args = build_curl_args(url, http_method, headers_json, body, timeout_sec)
  let args_json = serialize_string_array(args)
  let result = run_command("curl", args_json)
  if result.has_prefix("ERROR:") {
    on_error(result)
    return
  }
  on_result(result)
}

///|
/// Get an environment variable value. Returns empty string if not found.
pub fn get_env(name : String) -> String {
  @x_sys.get_env_var(name).unwrap_or("")
}

///|
/// Build curl command-line arguments.
fn build_curl_args(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
  timeout_sec : Int,
) -> Array[String] {
  let args : Array[String] = ["-sS", "-X", http_method, url]
  if timeout_sec > 0 {
    args.push("--max-time")
    args.push(timeout_sec.to_string())
  }
  // Parse headers JSON and add -H flags
  let headers = @json.parse(headers_json) catch { _ => Json::null() }
  match headers {
    Json::Object(entries) =>
      for entry in entries {
        let (key, value) = entry
        let val_str = match value {
          Json::String(s) => s
          _ => value.stringify()
        }
        args.push("-H")
        args.push(key + ": " + val_str)
      }
    _ => ()
  }
  if !body.is_empty() {
    args.push("-d")
    args.push(body)
  }
  args
}

///|
/// Split a string by newlines.
fn split_lines(s : String) -> Array[String] {
  let result : Array[String] = []
  let buf = StringBuilder::StringBuilder()
  for ch in s {
    if ch == '\n' {
      result.push(buf.to_string())
      buf.reset()
    } else {
      buf.write_char(ch)
    }
  }
  let last = buf.to_string()
  if !last.is_empty() {
    result.push(last)
  }
  result
}

///|
/// Serialize an array of strings to a JSON array string.
fn serialize_string_array(arr : Array[String]) -> String {
  Json::array(arr.map(fn(s) { ToJson::to_json(s) })).stringify()
}
