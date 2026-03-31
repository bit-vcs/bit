///|
test "component impl: receive-pack response helpers parse advertisement and result" {
  let old_id = receive_pack_parse_advertisement(
    component_impl_fixture_receive_pack_advertisement(),
    "refs/heads/main",
  )
  component_impl_assert_receive_pack_response(
    old_id,
    receive_pack_parse_result(component_impl_fixture_push_success_response()),
  )
}
