///|
test "component impl: push state helpers prepare head ref and pack" {
  let fs = @bit.TestFs::new()
  let head = component_impl_prepare_push_repo(fs, "/repo")

  let (default_refname, default_head_id, default_pack) = net_prepare_push_state(
    fs, "/repo", "",
  )
  component_impl_assert_push_state(
    default_refname, default_head_id, default_pack, "refs/heads/main", head,
  )

  let (explicit_refname, explicit_head_id, explicit_pack) = net_prepare_push_state(
    fs, "/repo", "refs/heads/topic",
  )
  component_impl_assert_push_state(
    explicit_refname, explicit_head_id, explicit_pack, "refs/heads/topic", head,
  )
}
