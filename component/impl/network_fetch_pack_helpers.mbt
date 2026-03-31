///| WASM Component fetch-pack helpers

///|
fn fetch_pack_sync(
  url : String,
  wants : Array[@bit.ObjectId],
  prefer_v2 : Bool,
  depth : Int,
  http_get : (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> Bytes raise @bit.GitError {
  let (refs, caps, version, _symrefs) = discover_refs_sync(
    url, prefer_v2, http_get, http_post,
  )
  let actual_wants = upload_pack_select_wants(refs, wants)
  let (request, use_v2) = upload_pack_build_fetch_request(
    version, actual_wants, caps, depth,
  )
  let response = upload_pack_request_sync(url, request, use_v2, http_post)
  upload_pack_extract_fetch_pack(version, response)
}
