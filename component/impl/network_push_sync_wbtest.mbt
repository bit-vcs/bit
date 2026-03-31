///|
test "component impl: push sync helpers prepare state and execute request" {
  let fs = @bit.TestFs::new()
  ignore(component_impl_prepare_push_repo(fs, "/repo"))

  let (adv, success) = component_impl_fixture_receive_pack_responses()
  let get_calls : Array[String] = []
  let post_calls : Array[String] = []

  let result = net_sync_push_target(
    fs,
    "/repo",
    "git@github.com:user/repo.git",
    "",
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
