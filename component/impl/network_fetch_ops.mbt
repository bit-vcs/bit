///| WASM Component fetch transport operations

///|
fn fetch_with_transport(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  remote_url : String,
  http_get : (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> Unit raise @bit.GitError {
  net_sync_remote_target(
    fs,
    rfs,
    root,
    remote_url,
    0,
    "No refs found on remote",
    fn(
      refs : Array[(@bit.ObjectId, String)],
      symrefs : Map[String, String],
    ) -> (String, @bit.ObjectId)? {
      @protocol.select_default_ref(refs, symrefs)
    },
    false,
    http_get,
    http_post,
  )
}

///|
pub fn fetch(root : String, remote_url : String) -> Result[Unit, String] {
  net_with_wasm_http_transport(fn(
    fs,
    rfs,
    http_get,
    http_post,
  ) raise @bit.GitError {
    fetch_with_transport(fs, rfs, root, remote_url, http_get, http_post)
  })
}
