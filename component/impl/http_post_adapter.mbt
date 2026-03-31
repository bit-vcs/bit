///| WasmHttpClient POST adapter for @bit.HttpClient.

///|
pub impl @bit.HttpClient for WasmHttpClient with post(_self, url, body, headers) {
  let header_pairs = wasmhttp_headers_to_pairs(headers)
  let body_arr = wasmhttp_bytes_to_array(body)
  wasmhttp_unwrap_result(@wit_http.http_post(url, body_arr, header_pairs))
}
