///|
test "component impl: fetch_with_transport materializes fetched state" {
  let (adv, lsrefs, fetch) = component_impl_fixture_upload_pack_responses()
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")

  fetch_with_transport(
    fs,
    fs,
    "/repo",
    "git@github.com:user/repo.git",
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
