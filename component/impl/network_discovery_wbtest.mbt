///|
test "component impl: discover refs accepts scp-style ssh remote" {
  let (adv, lsrefs, _fetch) = component_impl_fixture_upload_pack_responses()
  let get_calls : Array[String] = []
  let post_calls : Array[String] = []
  let (refs, _caps, version, symrefs) = discover_refs_sync(
    "git@github.com:user/repo.git",
    true,
    fn(
      url : String,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) {
      get_calls.push(url)
      component_impl_fixture_upload_pack_get(adv, url, _headers)
    },
    fn(
      url : String,
      body : Bytes,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
      post_calls.push(url)
      component_impl_fixture_upload_pack_post(
        lsrefs,
        Bytes::from_array([]),
        url,
        body,
        _headers,
      )
    },
  )
  assert_true(version == @protocol.ProtocolVersion::V2)
  component_impl_assert_upload_pack_calls(
    "https://github.com/user/repo", get_calls, post_calls,
  )
  inspect(refs.length() > 0, content="true")
  inspect(symrefs.get("HEAD"), content="Some(\"refs/heads/main\")")
}
