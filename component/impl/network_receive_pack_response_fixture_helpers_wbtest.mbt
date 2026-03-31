///|
fn component_impl_assert_receive_pack_request(
  info_url : String,
  info_headers : Map[String, String],
  push_url : String,
  push_body : Bytes,
  push_headers : Map[String, String],
  pack : Bytes,
  base_url : String,
) -> Unit raise {
  assert_eq(info_url, base_url + "/info/refs?service=git-receive-pack")
  assert_eq(
    info_headers.get("Accept"),
    Some("application/x-git-receive-pack-advertisement"),
  )
  assert_eq(push_url, base_url + "/git-receive-pack")
  assert_true(push_body.length() > pack.length())
  assert_eq(
    push_headers.get("Content-Type"),
    Some("application/x-git-receive-pack-request"),
  )
}

///|
fn component_impl_assert_receive_pack_response(
  old_id : @bit.ObjectId,
  result : String,
) -> Unit raise {
  assert_eq(old_id.to_hex(), @bit.ObjectId::zero().to_hex())
  component_impl_assert_push_success(result)
}
