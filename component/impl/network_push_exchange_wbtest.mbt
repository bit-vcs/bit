///|
test "component impl: push exchange helpers execute receive-pack flow" {
  let (adv, success) = component_impl_fixture_receive_pack_responses()
  let get_calls : Array[String] = []
  let post_calls : Array[String] = []
  let result = net_execute_push_request(
    "git@github.com:user/repo.git",
    "refs/heads/main",
    @bit.ObjectId::from_hex(component_impl_fixture_commit),
    Bytes::from_array([1, 2, 3, 4]),
    fn(
      url : String,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) {
      component_impl_fixture_receive_pack_get(get_calls, adv, url, _headers)
    },
    fn(
      url : String,
      body : Bytes,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
      component_impl_fixture_receive_pack_post(
        post_calls, success, url, body, _headers,
      )
    },
  )
  component_impl_assert_push_success(result)
  component_impl_assert_receive_pack_calls(
    "https://github.com/user/repo", get_calls, post_calls,
  )
}
