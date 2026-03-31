///| WASM Component status operations implementation

///|
fn status_with_fs(
  fs : &@bit.RepoFileSystem,
  root : String,
) -> StatusResult raise @bit.GitError {
  let git_dir = resolve_git_dir(fs, root)
  let entries = @bitlib.read_index_entries(fs, git_dir)
  let worktree = status_collect_worktree_changes(fs, root, entries)
  let staged = status_collect_staged_changes(fs, git_dir, entries)
  status_build_result(worktree, staged)
}

///|
pub fn status(root : String) -> Result[StatusResult, String] {
  with_wasm_repo_fs(fn(rfs) raise @bit.GitError { status_with_fs(rfs, root) })
}

///|
pub fn status_porcelain(root : String) -> Result[Array[String], String] {
  match status(root) {
    Ok(s) => Ok(porcelain_lines_from_status(s))
    Err(e) => Err(e)
  }
}
