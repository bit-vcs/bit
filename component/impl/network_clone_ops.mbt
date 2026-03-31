///| WASM Component clone transport operations

///|
fn clone_with_transport(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  url : String,
  dest : String,
  branch : String,
  depth : Int,
  http_get : (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> Unit raise @bit.GitError {
  net_prepare_clone_repo(fs, dest, url)
  net_sync_remote_target(
    fs,
    rfs,
    dest,
    url,
    depth,
    "No default branch found",
    fn(
      refs : Array[(@bit.ObjectId, String)],
      symrefs : Map[String, String],
    ) -> (String, @bit.ObjectId)? {
      net_select_clone_target(refs, symrefs, branch)
    },
    true,
    http_get,
    http_post,
  )
}

///|
pub fn clone(
  url : String,
  dest : String,
  branch : String,
  depth : Int,
) -> Result[Unit, String] {
  net_with_wasm_http_transport(fn(
    fs,
    rfs,
    http_get,
    http_post,
  ) raise @bit.GitError {
    clone_with_transport(fs, rfs, url, dest, branch, depth, http_get, http_post)
  })
}
