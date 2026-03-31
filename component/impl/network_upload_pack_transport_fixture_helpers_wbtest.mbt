///|
fn component_impl_fixture_upload_pack_responses() -> (Bytes, Bytes, Bytes) {
  (
    component_impl_fixture_hex_to_bytes(component_impl_adv_v2_hex),
    component_impl_fixture_hex_to_bytes(component_impl_lsrefs_hex),
    component_impl_fixture_hex_to_bytes(component_impl_fetch_hex),
  )
}

///|
fn component_impl_fixture_upload_pack_get(
  adv : Bytes,
  _url : String,
  _headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) {
  (@bit.HttpResponse::new(200), adv)
}

///|
fn component_impl_fixture_upload_pack_post(
  lsrefs : Bytes,
  fetch : Bytes,
  _url : String,
  body : Bytes,
  _headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  let text = component_impl_fixture_bytes_to_string(body)
  if text.contains("command=ls-refs") {
    return (@bit.HttpResponse::new(200), lsrefs)
  }
  if text.contains("command=fetch") || text.contains("want ") {
    return (@bit.HttpResponse::new(200), fetch)
  }
  raise @bit.GitError::ProtocolError("unexpected request body")
}

///|
fn component_impl_assert_upload_pack_calls(
  base_url : String,
  get_calls : Array[String],
  post_calls : Array[String],
) -> Unit raise {
  assert_eq(get_calls, [base_url + "/info/refs?service=git-upload-pack"])
  assert_eq(post_calls, [base_url + "/git-upload-pack"])
}

///|
fn component_impl_assert_upload_pack_request(
  info_url : String,
  info_headers : Map[String, String],
  post_url : String,
  post_headers : Map[String, String],
  base_url : String,
) -> Unit raise {
  assert_eq(info_url, base_url + "/info/refs?service=git-upload-pack")
  assert_eq(info_headers.get("Git-Protocol"), Some("version=2"))
  assert_eq(
    info_headers.get("Accept"),
    Some("application/x-git-upload-pack-advertisement"),
  )
  assert_eq(post_url, base_url + "/git-upload-pack")
  assert_eq(post_headers.get("Git-Protocol"), Some("version=2"))
  assert_eq(
    post_headers.get("Content-Type"),
    Some("application/x-git-upload-pack-request"),
  )
}
