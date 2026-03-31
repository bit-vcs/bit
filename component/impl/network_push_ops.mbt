///| WASM Component push transport operations

///|
fn push_with_transport(
  rfs : &@bit.RepoFileSystem,
  root : String,
  remote_url : String,
  refspec : String,
  http_get : (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> String raise @bit.GitError {
  net_sync_push_target(rfs, root, remote_url, refspec, http_get, http_post)
}

///|
pub fn push(
  root : String,
  remote_url : String,
  refspec : String,
) -> Result[String, String] {
  net_with_wasm_http_transport(fn(
    _fs,
    rfs,
    http_get,
    http_post,
  ) raise @bit.GitError {
    push_with_transport(rfs, root, remote_url, refspec, http_get, http_post)
  })
}
