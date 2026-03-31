///|
test "component impl: receive-pack request helpers normalize ssh remote" {
  let (info_url, info_headers) = receive_pack_info_refs_request(
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
    info_url, info_headers, push_url, push_body, push_headers, pack, "https://github.com/user/repo",
  )
}
