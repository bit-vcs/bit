///| WASM Component clone remote config helpers

///|
fn net_write_clone_remote_config(
  fs : &@bit.FileSystem,
  git_dir : String,
  remote_url : String,
) -> Unit raise @bit.GitError {
  let config_path = join_path(git_dir, "config")
  let config_content = "[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n\tbare = false\n[remote \"origin\"]\n\turl = \{remote_url}\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n"
  fs.write_string(config_path, config_content)
}
