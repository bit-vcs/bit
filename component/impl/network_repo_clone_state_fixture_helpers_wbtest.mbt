///|
fn component_impl_assert_clone_main_state(
  fs : @bit.TestFs,
  root : String,
) -> Unit raise {
  assert_eq(fs.read_string(root + "/hello.txt"), "hello\n")
  assert_eq(fs.read_string(root + "/.git/HEAD"), "ref: refs/heads/main\n")
  assert_eq(
    fs.read_string(root + "/.git/refs/heads/main"),
    component_impl_fixture_commit + "\n",
  )
  assert_eq(
    fs.read_string(root + "/.git/refs/remotes/origin/main"),
    component_impl_fixture_commit + "\n",
  )
}
