///|
test "component impl: mv_with_fs and rm_with_fs update worktree and index" {
  let fs = @bit.TestFs::new()
  git_init_with_fs(fs, "/repo", "main")
  fs.write_string("/repo/src.txt", "src\n")
  fs.write_string("/repo/remove.txt", "remove\n")
  add_with_fs(fs, fs, "/repo", ["src.txt", "remove.txt"])
  ignore(
    commit_with_fs(
      fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L,
    ),
  )

  mv_with_fs(fs, fs, "/repo", "src.txt", "dir/dst.txt")
  rm_with_fs(fs, fs, "/repo", ["remove.txt"], false)

  assert_true(not(fs.is_file("/repo/src.txt")))
  assert_eq(fs.read_string("/repo/dir/dst.txt"), "src\n")
  assert_true(not(fs.is_file("/repo/remove.txt")))
  assert_eq(status_with_fs(fs, "/repo"), StatusResult::{
    staged_added: ["dir/dst.txt"],
    staged_modified: [],
    staged_deleted: ["remove.txt", "src.txt"],
    unstaged_modified: [],
    unstaged_deleted: [],
    untracked: [],
  })
}
