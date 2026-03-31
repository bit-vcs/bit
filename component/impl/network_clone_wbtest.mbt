///|
test "component impl: clone_with_transport materializes repo with injected transport" {
  let (adv, lsrefs, fetch) = component_impl_fixture_upload_pack_responses()
  let fs = @bit.TestFs::new()
  clone_with_transport(
    fs,
    fs,
    "git@github.com:user/repo.git",
    "/repo",
    "",
    0,
    fn(
      _url : String,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) {
      component_impl_fixture_upload_pack_get(adv, _url, _headers)
    },
    fn(
      _url : String,
      body : Bytes,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
      component_impl_fixture_upload_pack_post(
        lsrefs, fetch, _url, body, _headers,
      )
    },
  )
  component_impl_assert_clone_main_state(fs, "/repo")
}
