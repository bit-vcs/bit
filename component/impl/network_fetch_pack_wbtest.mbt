///|
test "component impl: fetch_pack_sync returns pack payload through injected transport" {
  let (adv, lsrefs, fetch) = component_impl_fixture_upload_pack_responses()

  let pack = fetch_pack_sync(
    "git@github.com:user/repo.git",
    [@bit.ObjectId::from_hex(component_impl_fixture_commit)],
    true,
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

  assert_eq(pack[0], 'P'.to_int().to_byte())
  assert_eq(pack[1], 'A'.to_int().to_byte())
  assert_eq(pack[2], 'C'.to_int().to_byte())
  assert_eq(pack[3], 'K'.to_int().to_byte())
}
