///| WasmHttpClient response conversion helpers.

///|
fn wasmhttp_pairs_to_headers(
  pairs : Array[(String, String)],
) -> Map[String, String] {
  let headers : Map[String, String] = {}
  for pair in pairs {
    let (k, v) = pair
    headers[k] = v
  }
  headers
}

///|
fn wasmhttp_wrap_response(
  response : @wit_http.HttpResponse,
  body : Array[Byte],
) -> (@bit.HttpResponse, Bytes) {
  (
    @bit.HttpResponse::with_headers(
      response.code,
      wasmhttp_pairs_to_headers(response.headers),
    ),
    Bytes::from_array(body),
  )
}

///|
fn wasmhttp_unwrap_result(
  result : Result[(@wit_http.HttpResponse, Array[Byte]), String],
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  match result {
    Ok((response, body)) => wasmhttp_wrap_response(response, body)
    Err(e) => raise @bit.GitError::IoError(e)
  }
}
