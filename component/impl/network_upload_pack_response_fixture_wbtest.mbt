///|
test "component impl: upload-pack response fixture helpers assert response expectations" {
  let (refs_v2, caps_v2, version_v2, symrefs_v2) = upload_pack_parse_discovery_advertisement(
    component_impl_fixture_hex_to_bytes(component_impl_adv_v2_hex),
  )
  component_impl_assert_upload_pack_v2_response(
    refs_v2, caps_v2, version_v2, symrefs_v2,
  )

  let extracted = upload_pack_extract_fetch_pack(
    @protocol.ProtocolVersion::V2,
    component_impl_fixture_hex_to_bytes(component_impl_fetch_hex),
  )
  component_impl_assert_pack_magic(extracted)
}
