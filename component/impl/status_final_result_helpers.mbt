///| WASM Component status final result assembly helpers

///|
fn status_build_result(
  worktree : StatusWorktreeChanges,
  staged : StatusStagedChanges,
) -> StatusResult {
  let staged_added = staged.staged_added
  let staged_modified = staged.staged_modified
  let staged_deleted = staged.staged_deleted
  let unstaged_modified = worktree.unstaged_modified
  let unstaged_deleted = worktree.unstaged_deleted
  let untracked = worktree.untracked
  sort_status_paths(staged_added)
  sort_status_paths(staged_modified)
  sort_status_paths(staged_deleted)
  sort_status_paths(unstaged_modified)
  sort_status_paths(unstaged_deleted)
  sort_status_paths(untracked)
  StatusResult::{
    staged_added,
    staged_modified,
    staged_deleted,
    unstaged_modified,
    unstaged_deleted,
    untracked,
  }
}
