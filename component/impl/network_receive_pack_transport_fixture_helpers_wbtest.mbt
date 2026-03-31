///|
fn component_impl_fixture_receive_pack_responses() -> (Bytes, Bytes) {
  (
    component_impl_fixture_receive_pack_advertisement(),
    component_impl_fixture_push_success_response(),
  )
}

///|
fn component_impl_fixture_receive_pack_get(
  get_calls : Array[String],
  adv : Bytes,
  url : String,
  _headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) {
  get_calls.push(url)
  (@bit.HttpResponse::new(200), adv)
}

///|
fn component_impl_fixture_receive_pack_post(
  post_calls : Array[String],
  success : Bytes,
  url : String,
  body : Bytes,
  _headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  post_calls.push(url)
  if body.length() <= 4 {
    raise @bit.GitError::InvalidObject("push request body missing packfile")
  }
  (@bit.HttpResponse::new(200), success)
}

///|
fn component_impl_assert_receive_pack_calls(
  base_url : String,
  get_calls : Array[String],
  post_calls : Array[String],
) -> Unit raise {
  assert_eq(get_calls, [base_url + "/info/refs?service=git-receive-pack"])
  assert_eq(post_calls, [base_url + "/git-receive-pack"])
}
