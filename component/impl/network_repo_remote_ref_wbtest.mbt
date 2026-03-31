///|
test "component impl: repo remote ref helpers write tracking ref" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  let commit_id = @bit.ObjectId::from_hex(component_impl_fixture_commit)

  net_write_remote_tracking_ref(fs, "/repo/.git", "refs/heads/topic", commit_id)

  assert_eq(
    fs.read_string("/repo/.git/refs/remotes/origin/topic"),
    component_impl_fixture_commit + "\n",
  )
}
