///| WASM Component discovery helpers

///|
fn discover_refs_sync(
  url : String,
  prefer_v2 : Bool,
  http_get : (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> (
  Array[(@bit.ObjectId, String)],
  Array[String],
  @protocol.ProtocolVersion,
  Map[String, String],
) raise @bit.GitError {
  let (info_url, headers) = upload_pack_info_refs_request(url, prefer_v2)
  let (response, adv) = http_get(info_url, headers)
  if response.code != 200 {
    raise @bit.GitError::ProtocolError(
      "Failed to fetch info/refs: HTTP \{response.code}",
    )
  }
  let (refs, caps, version, symrefs) = upload_pack_parse_discovery_advertisement(
    adv,
  )
  if version == @protocol.ProtocolVersion::V2 {
    let req = @protocol.build_ls_refs_request("git/moonbit", [
      "refs/heads/", "refs/tags/", "HEAD",
    ])
    let resp = upload_pack_request_sync(url, req, true, http_post)
    let parsed = @protocol.parse_ls_refs_response(resp)
    return (parsed.refs, caps, version, parsed.symrefs)
  }
  (refs, caps, version, symrefs)
}

///|
fn upload_pack_request_sync(
  url : String,
  body : Bytes,
  prefer_v2 : Bool,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> Bytes raise @bit.GitError {
  let (post_url, headers) = upload_pack_service_request(url, prefer_v2)
  let (response, data) = http_post(post_url, body, headers)
  if response.code != 200 {
    raise @bit.GitError::ProtocolError(
      "Failed to upload-pack: HTTP \{response.code}",
    )
  }
  data
}
