///|
test "component impl: upload-pack response helpers parse advertisements" {
  let adv_v2 = component_impl_fixture_hex_to_bytes(component_impl_adv_v2_hex)
  let (refs_v2, caps_v2, version_v2, symrefs_v2) = upload_pack_parse_discovery_advertisement(
    adv_v2,
  )
  component_impl_assert_upload_pack_v2_response(
    refs_v2, caps_v2, version_v2, symrefs_v2,
  )

  let adv_v0 = component_impl_fixture_upload_pack_v0_advertisement()
  let (refs_v0, caps_v0, version_v0, symrefs_v0) = upload_pack_parse_discovery_advertisement(
    adv_v0,
  )
  component_impl_assert_upload_pack_v0_response(
    refs_v0, caps_v0, version_v0, symrefs_v0,
  )
}

///|
test "component impl: upload-pack response helpers extract pack payload" {
  let pack = upload_pack_extract_fetch_pack(
    @protocol.ProtocolVersion::V2,
    component_impl_fixture_hex_to_bytes(component_impl_fetch_hex),
  )
  component_impl_assert_pack_magic(pack)
}
