///| WASM Component repository initialization operations

///|
fn git_init_with_fs(
  fs : &@bit.FileSystem,
  root : String,
  default_branch : String,
) -> Unit raise @bit.GitError {
  @bitlib.init_repo(fs, root, default_branch~)
}

///|
pub fn git_init(root : String, default_branch : String) -> Result[Unit, String] {
  with_wasm_fs(fn(fs) raise @bit.GitError {
    git_init_with_fs(fs, root, default_branch)
  })
}
