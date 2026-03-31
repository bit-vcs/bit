///| WASM Component push sync helpers

///|
fn net_sync_push_target(
  rfs : &@bit.RepoFileSystem,
  root : String,
  remote_url : String,
  refspec : String,
  http_get : (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> String raise @bit.GitError {
  let (refname, head_id, pack) = net_prepare_push_state(rfs, root, refspec)
  net_execute_push_request(
    remote_url, refname, head_id, pack, http_get, http_post,
  )
}
