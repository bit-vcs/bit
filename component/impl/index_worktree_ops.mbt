///| WASM Component index and worktree operations

///|
fn add_with_fs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  paths : Array[String],
) -> Unit raise @bit.GitError {
  @bitlib.add_paths(fs, rfs, root, paths)
}

///|
pub fn add(root : String, paths : Array[String]) -> Result[Unit, String] {
  with_wasm_rw_fs(fn(fs, rfs) raise @bit.GitError {
    add_with_fs(fs, rfs, root, paths)
  })
}

///|
fn rm_with_fs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  paths : Array[String],
  cached : Bool,
) -> Unit raise @bit.GitError {
  @bitlib.rm_paths(fs, rfs, root, paths, cached~)
}

///|
pub fn rm(
  root : String,
  paths : Array[String],
  cached : Bool,
) -> Result[Unit, String] {
  with_wasm_rw_fs(fn(fs, rfs) raise @bit.GitError {
    rm_with_fs(fs, rfs, root, paths, cached)
  })
}

///|
fn mv_with_fs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  source : String,
  dest : String,
) -> Unit raise @bit.GitError {
  @bitlib.mv_path(fs, rfs, root, source, dest)
}

///|
pub fn mv(
  root : String,
  source : String,
  dest : String,
) -> Result[Unit, String] {
  with_wasm_rw_fs(fn(fs, rfs) raise @bit.GitError {
    mv_with_fs(fs, rfs, root, source, dest)
  })
}
