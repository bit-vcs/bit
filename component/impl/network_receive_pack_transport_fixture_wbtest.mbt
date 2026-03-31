///|
test "component impl: receive-pack transport fixture helpers capture calls" {
  let (adv, success) = component_impl_fixture_receive_pack_responses()
  let get_calls : Array[String] = []
  let post_calls : Array[String] = []

  let (_adv_response, adv_body) = component_impl_fixture_receive_pack_get(
    get_calls,
    adv,
    "https://example.com/repo/info/refs?service=git-receive-pack",
    {},
  )
  assert_eq(adv_body, adv)

  let (_push_response, success_body) = component_impl_fixture_receive_pack_post(
    post_calls,
    success,
    "https://example.com/repo/git-receive-pack",
    Bytes::from_array([1, 2, 3, 4, 5]),
    {},
  )
  assert_eq(success_body, success)
  component_impl_assert_receive_pack_calls(
    "https://example.com/repo", get_calls, post_calls,
  )
}
