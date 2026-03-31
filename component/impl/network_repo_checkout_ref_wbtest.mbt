///|
test "component impl: repo checkout ref helpers write HEAD and local branch ref" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  let commit_id = @bit.ObjectId::from_hex(component_impl_fixture_commit)

  net_write_local_checkout_ref(fs, "/repo/.git", "refs/heads/topic", commit_id)

  assert_eq(fs.read_string("/repo/.git/HEAD"), "ref: refs/heads/topic\n")
  assert_eq(
    fs.read_string("/repo/.git/refs/heads/topic"),
    component_impl_fixture_commit + "\n",
  )
}

///|
test "component impl: repo checkout ref helpers default checkout branch to main" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  let commit_id = @bit.ObjectId::from_hex(component_impl_fixture_commit)

  net_write_local_checkout_ref(fs, "/repo/.git", "HEAD", commit_id)

  assert_eq(fs.read_string("/repo/.git/HEAD"), "ref: refs/heads/main\n")
  assert_eq(
    fs.read_string("/repo/.git/refs/heads/main"),
    component_impl_fixture_commit + "\n",
  )
}
