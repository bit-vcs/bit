///|
async test "worktree package: status sees untracked file" {
  let fs = @bit.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  fs.write_string("/repo/a.txt", "hello\n")
  let st = status(fs, "/repo")
  assert_true(st.untracked.contains("a.txt"))
}
