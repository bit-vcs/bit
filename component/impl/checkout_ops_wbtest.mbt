///|
test "component impl: checkout_b_with_fs marks current branch" {
  let fs = @bit.TestFs::new()
  git_init_with_fs(fs, "/repo", "main")
  fs.write_string("/repo/hello.txt", "hello\n")
  add_with_fs(fs, fs, "/repo", ["hello.txt"])
  let head = commit_with_fs(
    fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L,
  )

  checkout_b_with_fs(fs, fs, "/repo", "feature")

  assert_eq(branch_list_with_fs(fs, "/repo"), [
    BranchInfo::{ name: "feature", commit_id: head, is_current: true },
    BranchInfo::{ name: "main", commit_id: head, is_current: false },
  ])
}
