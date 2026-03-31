///| WASM Component network remote tracking ref helpers

///|
fn net_write_remote_tracking_ref(
  fs : &@bit.FileSystem,
  git_dir : String,
  refname : String,
  commit_id : @bit.ObjectId,
) -> Unit raise @bit.GitError {
  let remote_ref = net_remote_refname(refname)
  net_write_ref_oid(fs, join_path(git_dir, remote_ref), commit_id)
}
