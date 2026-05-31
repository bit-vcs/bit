///|
test "component impl: upload-pack http request helpers normalize ssh remote" {
  let (info_url, info_headers) = upload_pack_info_refs_request(
    component_impl_fixture_remote_url, true,
  )
  let (post_url, post_headers) = upload_pack_service_request(
    component_impl_fixture_remote_url, true,
  )
  component_impl_assert_upload_pack_request(
    info_url, info_headers, post_url, post_headers, "https://github.com/user/repo",
  )
}
