///| WASM Component network transport bootstrap helpers

///|
fn[T] net_with_wasm_http_transport(
  action : (
    WasmFs,
    WasmFs,
    (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
    (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  ) -> T raise @bit.GitError,
) -> Result[T, String] {
  let http = WasmHttpClient::new()
  with_wasm_rw_fs(fn(fs, rfs) raise @bit.GitError {
    action(
      fs,
      rfs,
      fn(
        req_url : String,
        headers : Map[String, String],
      ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
        http.get(req_url, headers)
      },
      fn(
        req_url : String,
        body : Bytes,
        headers : Map[String, String],
      ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
        http.post(req_url, body, headers)
      },
    )
  })
}
