///|
fn component_impl_assert_fetch_only_state(
  fs : @bit.TestFs,
  root : String,
  current_branch : String,
  remote_branch : String,
) -> Unit raise {
  assert_eq(
    fs.read_string(root + "/.git/HEAD"),
    "ref: refs/heads/" + current_branch + "\n",
  )
  assert_true(not(fs.is_file(root + "/.git/refs/heads/" + remote_branch)))
  assert_eq(
    fs.read_string(root + "/.git/refs/remotes/origin/" + remote_branch),
    component_impl_fixture_commit + "\n",
  )
  assert_eq(fs.read_string(root + "/hello.txt"), "hello\n")
}
