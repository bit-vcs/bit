///|
test "component impl: status_with_fs reports staged and unstaged changes" {
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

  fs.write_string("/repo/tracked.txt", "staged\n")
  add_with_fs(fs, fs, "/repo", ["tracked.txt"])
  fs.write_string("/repo/tracked.txt", "worktree\n")
  fs.remove_file("/repo/delete.txt")
  fs.write_string("/repo/added.txt", "added\n")
  add_with_fs(fs, fs, "/repo", ["added.txt"])
  fs.write_string("/repo/untracked.txt", "untracked\n")

  let status = status_with_fs(fs, "/repo")
  assert_eq(status, StatusResult::{
    staged_added: ["added.txt"],
    staged_modified: ["tracked.txt"],
    staged_deleted: [],
    unstaged_modified: ["tracked.txt"],
    unstaged_deleted: ["delete.txt"],
    untracked: ["untracked.txt"],
  })
}
