///|
test "component impl: repo clone state fixture helpers assert clone final state" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/refs/heads")
  fs.mkdir_p("/repo/.git/refs/remotes/origin")
  fs.write_string("/repo/hello.txt", "hello\n")
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main",
    component_impl_fixture_commit + "\n",
  )
  fs.write_string(
    "/repo/.git/refs/remotes/origin/main",
    component_impl_fixture_commit + "\n",
  )
  component_impl_assert_clone_main_state(fs, "/repo")
}
