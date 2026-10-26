///|
async test "worktree package: status sees untracked file" {
  let fs = @bit.TestFs::new()
  ignore(@bitlib.init_repo(fs, "/repo")) catch {
    _ => ()
  }
  fs.write_string("/repo/a.txt", "hello\n")
  let st = @bit_worktree.status(fs, "/repo")
  assert_true(st.untracked.contains("a.txt"))
}
