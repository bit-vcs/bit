///|
test "component impl: network fixture codec helpers decode and encode bytes" {
  let bytes = component_impl_fixture_hex_to_bytes("6869")
  assert_eq(bytes.length(), 2)
  assert_eq(bytes[0], 'h'.to_int().to_byte())
  assert_eq(bytes[1], 'i'.to_int().to_byte())
  assert_eq(component_impl_fixture_bytes_to_string(bytes), "hi")
  assert_eq(component_impl_fixture_hex_to_bytes("abc").length(), 0)
}

///|
test "component impl: network fixture pktline helpers build protocol payloads" {
  let old_id = receive_pack_parse_advertisement(
    component_impl_fixture_receive_pack_advertisement(),
    "refs/heads/main",
  )
  assert_eq(old_id.to_hex(), @bit.ObjectId::zero().to_hex())

  assert_eq(
    receive_pack_parse_result(component_impl_fixture_push_success_response()),
    "Push successful",
  )

  let (refs_v0, _caps_v0, version_v0, symrefs_v0) = upload_pack_parse_discovery_advertisement(
    component_impl_fixture_upload_pack_v0_advertisement(),
  )
  assert_true(version_v0 == @protocol.ProtocolVersion::V0)
  assert_eq(refs_v0.length(), 2)
  assert_eq(symrefs_v0.get("HEAD"), Some("refs/heads/main"))
}
