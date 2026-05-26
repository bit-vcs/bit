///| JS HTTP wrappers for serve using Node.js fetch

///|
extern "js" fn js_fetch_get(
  url : String,
  headers_json : String,
) -> @js_async.Promise[String] =
  #| async (url, headersJson) => {
  #|   const headers = JSON.parse(headersJson);
  #|   const resp = await fetch(url, { method: 'GET', headers });
  #|   const buf = Buffer.from(await resp.arrayBuffer());
  #|   return JSON.stringify({ status: resp.status, body: buf.toString('base64') });
  #| }

///|
extern "js" fn js_fetch_post(
  url : String,
  body_b64 : String,
  headers_json : String,
) -> @js_async.Promise[String] =
  #| async (url, bodyB64, headersJson) => {
  #|   const headers = JSON.parse(headersJson);
  #|   const body = bodyB64.length > 0 ? Buffer.from(bodyB64, 'base64') : undefined;
  #|   const resp = await fetch(url, { method: 'POST', headers, body });
  #|   const buf = Buffer.from(await resp.arrayBuffer());
  #|   return JSON.stringify({ status: resp.status, body: buf.toString('base64') });
  #| }

///|
fn parse_fetch_response(result_json : String) -> (Int, Bytes) raise Error {
  let parsed = @json.parse(result_json) catch {
    _ =>
      raise @bitcore.GitError::ProtocolError("Failed to parse fetch response")
  }
  guard parsed is Json::Object(obj) else {
    raise @bitcore.GitError::ProtocolError("Invalid fetch response format")
  }
  let status = match obj.get("status") {
    Some(Json::Number(n, ..)) => n.to_int()
    _ =>
      raise @bitcore.GitError::ProtocolError("Missing status in fetch response")
  }
  let body_b64 = match obj.get("body") {
    Some(Json::String(s)) => s
    _ => ""
  }
  let body = serve_base64_decode(body_b64)
  (status, body)
}

///|
fn headers_to_json(headers : Map[String, String]) -> String {
  let obj : Map[String, Json] = {}
  for entry in headers.to_array() {
    let (key, value) = entry
    obj[key] = Json::string(value)
  }
  Json::object(obj).stringify()
}

///|
async fn serve_http_get(
  url : String,
  headers : Map[String, String],
) -> (Int, Bytes) raise Error {
  let headers_json = headers_to_json(headers)
  let result = js_fetch_get(url, headers_json).wait()
  parse_fetch_response(result)
}

///|
async fn serve_http_post(
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> (Int, Bytes) raise Error {
  let headers_json = headers_to_json(headers)
  let body_b64 = serve_base64_encode(body)
  let result = js_fetch_post(url, body_b64, headers_json).wait()
  parse_fetch_response(result)
}
