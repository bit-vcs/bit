///|
test "component impl: net_apply_fetched_tip writes clone refs and checkout" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  let pack = upload_pack_extract_fetch_pack(
    @protocol.ProtocolVersion::V2,
    component_impl_fixture_hex_to_bytes(component_impl_fetch_hex),
  )
  let commit_id = @bit.ObjectId::from_hex(component_impl_fixture_commit)

  net_apply_fetched_tip(
    fs, fs, "/repo", pack, "refs/heads/main", commit_id, true,
  )
  component_impl_assert_clone_main_state(fs, "/repo")
}

///|
test "component impl: net_apply_fetched_tip keeps head on fetch path" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  let pack = upload_pack_extract_fetch_pack(
    @protocol.ProtocolVersion::V2,
    component_impl_fixture_hex_to_bytes(component_impl_fetch_hex),
  )
  let commit_id = @bit.ObjectId::from_hex(component_impl_fixture_commit)

  net_apply_fetched_tip(
    fs, fs, "/repo", pack, "refs/heads/feature", commit_id, false,
  )
  component_impl_assert_fetch_only_state(fs, "/repo", "main", "feature")
}
