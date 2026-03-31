///|
test "component impl: upload-pack transport fixture helpers load and choose responses" {
  let (adv, lsrefs, fetch) = component_impl_fixture_upload_pack_responses()
  assert_true(adv.length() > 0)
  assert_true(lsrefs.length() > 0)
  assert_true(fetch.length() > 0)

  let (_lsrefs_response, lsrefs_body) = component_impl_fixture_upload_pack_post(
    lsrefs,
    fetch,
    "https://example.com/repo/git-upload-pack",
    component_impl_fixture_string_to_bytes("0014command=ls-refs\n"),
    {},
  )
  assert_eq(lsrefs_body, lsrefs)

  let (_fetch_response, fetch_body) = component_impl_fixture_upload_pack_post(
    lsrefs,
    fetch,
    "https://example.com/repo/git-upload-pack",
    component_impl_fixture_string_to_bytes("000ewant deadbeef\n"),
    {},
  )
  assert_eq(fetch_body, fetch)
}

///|
test "component impl: upload-pack transport fixture helpers assert request expectations" {
  component_impl_assert_upload_pack_calls(
    "https://example.com/repo",
    ["https://example.com/repo/info/refs?service=git-upload-pack"],
    ["https://example.com/repo/git-upload-pack"],
  )

  let (upload_info_url, upload_info_headers) = upload_pack_info_refs_request(
    "git@github.com:user/repo.git", true,
  )
  let (upload_post_url, upload_post_headers) = upload_pack_service_request(
    "git@github.com:user/repo.git", true,
  )
  component_impl_assert_upload_pack_request(
    upload_info_url, upload_info_headers, upload_post_url, upload_post_headers, "https://github.com/user/repo",
  )
}
