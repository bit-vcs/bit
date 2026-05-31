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

///|
fn component_impl_assert_remote_fetch_target(
  refname : String,
  commit_id : @bit.ObjectId,
  pack : Bytes,
) -> Unit {
  assert_eq(refname, component_impl_fixture_default_branch)
  inspect(commit_id.to_hex(), content=component_impl_fixture_commit)
  assert_true(pack.length() > 0)
}
