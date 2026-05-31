///|
test "component impl: remote fetch helpers choose default target and fetch pack" {
  let (adv, lsrefs, fetch) = component_impl_fixture_upload_pack_responses()

  let (refname, commit_id, pack) = net_fetch_remote_target(
    component_impl_fixture_remote_url,
    0,
    "No default branch found",
    fn(
      refs : Array[(@bit.ObjectId, String)],
      symrefs : Map[String, String],
    ) -> (String, @bit.ObjectId)? {
      net_select_clone_target(refs, symrefs, "")
    },
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

  component_impl_assert_remote_fetch_target(refname, commit_id, pack)
}
