///|
test "component impl: receive-pack response fixture helpers assert request and response expectations" {
  let (receive_info_url, receive_info_headers) = receive_pack_info_refs_request(
    "git@github.com:user/repo.git",
  )
  let pack = Bytes::from_array([1, 2, 3, 4])
  let (push_url, push_body, push_headers) = receive_pack_service_request(
    "git@github.com:user/repo.git",
    @bit.ObjectId::from_hex(component_impl_fixture_commit),
    @bit.ObjectId::zero(),
    "refs/heads/main",
    pack,
  )
  component_impl_assert_receive_pack_request(
    receive_info_url, receive_info_headers, push_url, push_body, push_headers, pack,
    "https://github.com/user/repo",
  )

  let old_id = receive_pack_parse_advertisement(
    component_impl_fixture_receive_pack_advertisement(),
    "refs/heads/main",
  )
  let result = receive_pack_parse_result(
    component_impl_fixture_push_success_response(),
  )
  component_impl_assert_receive_pack_response(old_id, result)
}
