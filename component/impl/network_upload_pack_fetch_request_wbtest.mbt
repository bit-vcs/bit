///|
test "component impl: upload-pack fetch request helpers select wants and build request" {
  let refs_v0 = [
    (@bit.ObjectId::from_hex(component_impl_fixture_commit), "refs/heads/main"),
    (
      @bit.ObjectId::from_hex("1111111111111111111111111111111111111111"),
      "refs/heads/topic",
    ),
  ]
  let wants = upload_pack_select_wants(refs_v0, [])
  assert_eq(wants.length(), 2)

  let (fetch_req, use_v2) = upload_pack_build_fetch_request(
    @protocol.ProtocolVersion::V2,
    [@bit.ObjectId::from_hex(component_impl_fixture_commit)],
    [],
    0,
  )
  assert_true(use_v2)
  inspect(
    component_impl_fixture_bytes_to_string(fetch_req).contains("command=fetch"),
    content="true",
  )
}
