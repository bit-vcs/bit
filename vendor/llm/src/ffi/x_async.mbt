///|
fn parse_http_headers(headers_json : String) -> Map[String, String] {
  let headers : Map[String, String] = Map([])
  let parsed = @json.parse(headers_json) catch { _ => Json::null() }
  match parsed {
    Json::Object(entries) =>
      for key, value in entries {
        match value {
          Json::String(text) => headers[key] = text
          _ => ()
        }
      }
    _ => ()
  }
  headers
}

///|
pub async fn fetch_async(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
  _timeout_sec : Int,
) -> (Int, String) {
  let headers = parse_http_headers(headers_json)
  let (response, response_body) = match http_method.to_upper() {
    "GET" => @x_http.get(url, headers~)
    "POST" => @x_http.post(url, body, headers~)
    "PUT" => @x_http.put(url, body, headers~)
    other_method =>
      raise Failure::Failure("unsupported HTTP method: " + other_method)
  }
  (response.code, response_body.text())
}

///|
pub async fn exec_async(
  program : String,
  args : Array[String],
) -> (Int, String, String) {
  let (code, stdout, stderr) = @x_process.collect_output(program, args)
  (code, stdout.text(), stderr.text())
}
