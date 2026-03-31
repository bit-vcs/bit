///| WASM Component branch mutation operations

///|
fn branch_create_with_fs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  name : String,
) -> Unit raise @bit.GitError {
  @bitlib.create_branch(fs, rfs, root, name)
}

///|
pub fn branch_create(root : String, name : String) -> Result[Unit, String] {
  with_wasm_rw_fs(fn(fs, rfs) raise @bit.GitError {
    branch_create_with_fs(fs, rfs, root, name)
  })
}

///|
fn branch_delete_with_fs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  name : String,
) -> Unit raise @bit.GitError {
  @bitlib.delete_branch(fs, rfs, root, name)
}

///|
pub fn branch_delete(root : String, name : String) -> Result[Unit, String] {
  with_wasm_rw_fs(fn(fs, rfs) raise @bit.GitError {
    branch_delete_with_fs(fs, rfs, root, name)
  })
}
