///| Native HTTP wrappers for serve

///|
async fn serve_http_get(
  url : String,
  headers : Map[String, String],
) -> (Int, Bytes) raise Error {
  let (response, body) = @bitnative.native_http_get(url, headers)
  (response.code, body)
}

///|
async fn serve_http_post(
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> (Int, Bytes) raise Error {
  let (response, resp_body) = @bitnative.native_http_post(url, body, headers)
  (response.code, resp_body)
}
