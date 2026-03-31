///|
test "component impl: push fixture helpers prepare repo and assert push state" {
  let fs = @bit.TestFs::new()
  let head = component_impl_prepare_push_repo(fs, "/repo")
  assert_eq(
    head,
    fs.read_string("/repo/.git/refs/heads/main").trim().to_string(),
  )
  assert_eq(fs.read_string("/repo/hello.txt"), "hello\n")

  component_impl_assert_push_success("Push successful")

  let (refname, head_id, pack) = net_prepare_push_state(fs, "/repo", "")
  component_impl_assert_push_state(
    refname, head_id, pack, "refs/heads/main", head,
  )
}
