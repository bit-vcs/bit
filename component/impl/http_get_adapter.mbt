///| WasmHttpClient GET adapter for @bit.HttpClient.

///|
pub impl @bit.HttpClient for WasmHttpClient with get(_self, url, headers) {
  let header_pairs = wasmhttp_headers_to_pairs(headers)
  wasmhttp_unwrap_result(@wit_http.http_get(url, header_pairs))
}
