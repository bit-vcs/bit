///|
test "component impl: status_collect_worktree_changes separates modified deleted and untracked paths" {
  let fs = @bit.TestFs::new()
  git_init_with_fs(fs, "/repo", "main")
  fs.write_string("/repo/tracked.txt", "base\n")
  fs.write_string("/repo/delete.txt", "delete me\n")
  add_with_fs(fs, fs, "/repo", ["tracked.txt", "delete.txt"])
  ignore(
    commit_with_fs(
      fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L,
    ),
  )

  fs.write_string("/repo/tracked.txt", "worktree\n")
  fs.remove_file("/repo/delete.txt")
  fs.write_string("/repo/untracked.txt", "untracked\n")

  let entries = @bitlib.read_index_entries(fs, "/repo/.git")
  assert_eq(status_collect_worktree_changes(fs, "/repo", entries), StatusWorktreeChanges::{
    untracked: ["untracked.txt"],
    unstaged_modified: ["tracked.txt"],
    unstaged_deleted: ["delete.txt"],
  })
}
