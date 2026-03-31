///| WASM Component clone bootstrap helpers

///|
fn net_prepare_clone_repo(
  fs : &@bit.FileSystem,
  dest : String,
  remote_url : String,
) -> Unit raise @bit.GitError {
  fs.mkdir_p(dest)
  @bitlib.init_repo(fs, dest)
  let git_dir = join_path(dest, ".git")
  net_write_clone_remote_config(fs, git_dir, remote_url)
}
