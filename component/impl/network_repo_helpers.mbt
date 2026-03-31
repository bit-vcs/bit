///| WASM Component network repository update helpers

///|
fn net_apply_fetched_tip(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  pack : Bytes,
  refname : String,
  commit_id : @bit.ObjectId,
  checkout_branch : Bool,
) -> Unit raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  net_install_pack(fs, git_dir, pack)
  if checkout_branch {
    net_write_local_checkout_ref(fs, git_dir, refname, commit_id)
  }
  net_write_remote_tracking_ref(fs, git_dir, refname, commit_id)
  @bitlib.fast_forward_to(fs, rfs, root, commit_id)
}
