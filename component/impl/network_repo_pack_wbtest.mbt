///|
test "component impl: repo pack helpers install pack and index" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  let pack = upload_pack_extract_fetch_pack(
    @protocol.ProtocolVersion::V2,
    component_impl_fixture_hex_to_bytes(component_impl_fetch_hex),
  )

  net_install_pack(fs, "/repo/.git", pack)

  assert_true(fs.is_dir("/repo/.git/objects/pack"))
  let files = fs.readdir("/repo/.git/objects/pack")
  assert_eq(files.length(), 2)
  assert_true(files[0].has_suffix(".idx") || files[1].has_suffix(".idx"))
  assert_true(files[0].has_suffix(".pack") || files[1].has_suffix(".pack"))
}
