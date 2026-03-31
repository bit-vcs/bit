///|
test "component impl: branch mutation helpers create checkout and delete branches" {
  let fs = @bit.TestFs::new()
  git_init_with_fs(fs, "/repo", "main")
  fs.write_string("/repo/hello.txt", "hello\n")
  add_with_fs(fs, fs, "/repo", ["hello.txt"])
  let head = commit_with_fs(
    fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L,
  )

  branch_create_with_fs(fs, fs, "/repo", "feature")
  checkout_with_fs(fs, fs, "/repo", "feature")

  assert_eq(branch_list_with_fs(fs, "/repo"), [
    BranchInfo::{ name: "feature", commit_id: head, is_current: true },
    BranchInfo::{ name: "main", commit_id: head, is_current: false },
  ])

  checkout_with_fs(fs, fs, "/repo", "main")
  branch_delete_with_fs(fs, fs, "/repo", "feature")

  assert_eq(branch_list_with_fs(fs, "/repo"), [
    BranchInfo::{ name: "main", commit_id: head, is_current: true },
  ])
}
