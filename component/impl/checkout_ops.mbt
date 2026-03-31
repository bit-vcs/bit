///| WASM Component checkout operations

///|
fn checkout_with_fs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  target : String,
) -> Unit raise @bit.GitError {
  let _ = @bitlib.checkout(fs, rfs, root, target)
}

///|
pub fn checkout(root : String, target : String) -> Result[Unit, String] {
  with_wasm_rw_fs(fn(fs, rfs) raise @bit.GitError {
    checkout_with_fs(fs, rfs, root, target)
  })
}

///|
fn checkout_b_with_fs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  branch_name : String,
) -> Unit raise @bit.GitError {
  @bitlib.create_branch(fs, rfs, root, branch_name)
  let _ = @bitlib.checkout(fs, rfs, root, branch_name)
}

///|
pub fn checkout_b(root : String, branch_name : String) -> Result[Unit, String] {
  with_wasm_rw_fs(fn(fs, rfs) raise @bit.GitError {
    checkout_b_with_fs(fs, rfs, root, branch_name)
  })
}
