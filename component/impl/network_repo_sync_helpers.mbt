///| WASM Component remote repository sync helpers

///|
fn net_sync_remote_target(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  remote_url : String,
  depth : Int,
  missing_target_message : String,
  select_target : (Array[(@bit.ObjectId, String)], Map[String, String]) -> (
    String,
    @bit.ObjectId,
  )?,
  checkout_branch : Bool,
  http_get : (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> Unit raise @bit.GitError {
  let (refname, commit_id, pack) = net_fetch_remote_target(
    remote_url, depth, missing_target_message, select_target, http_get, http_post,
  )
  net_apply_fetched_tip(
    fs, rfs, root, pack, refname, commit_id, checkout_branch,
  )
}
