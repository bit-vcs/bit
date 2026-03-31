///|
test "component impl: repo fetch state fixture helpers assert fetch final state" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/refs/heads")
  fs.mkdir_p("/repo/.git/refs/remotes/origin")
  fs.write_string("/repo/hello.txt", "hello\n")
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/remotes/origin/feature",
    component_impl_fixture_commit + "\n",
  )
  component_impl_assert_fetch_only_state(fs, "/repo", "main", "feature")
}
