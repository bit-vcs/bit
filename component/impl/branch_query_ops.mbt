///| WASM Component branch query operations

///|
fn branch_list_with_fs(
  fs : &@bit.RepoFileSystem,
  root : String,
) -> Array[BranchInfo] raise @bit.GitError {
  let git_dir = resolve_git_dir(fs, root)
  let (_, branches) = @bitlib.list_branches(fs, git_dir)
  let result : Array[BranchInfo] = []
  for b in branches {
    result.push(BranchInfo::{
      name: b.name,
      commit_id: b.id.to_hex(),
      is_current: b.current,
    })
  }
  result.sort_by((a, b) => String::lexical_compare(a.name, b.name))
  result
}

///|
pub fn branch_list(root : String) -> Result[Array[BranchInfo], String] {
  with_wasm_repo_fs(fn(rfs) raise @bit.GitError {
    branch_list_with_fs(rfs, root)
  })
}
