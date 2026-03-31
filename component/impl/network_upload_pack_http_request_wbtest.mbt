///|
test "component impl: upload-pack http request helpers normalize ssh remote" {
  let (info_url, info_headers) = upload_pack_info_refs_request(
    "git@github.com:user/repo.git", true,
  )
  let (post_url, post_headers) = upload_pack_service_request(
    "git@github.com:user/repo.git", true,
  )
  component_impl_assert_upload_pack_request(
    info_url, info_headers, post_url, post_headers, "https://github.com/user/repo",
  )
}
