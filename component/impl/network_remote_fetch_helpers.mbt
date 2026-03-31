///| WASM Component remote tip fetch helpers

///|
fn net_fetch_remote_target(
  remote_url : String,
  depth : Int,
  missing_target_message : String,
  select_target : (Array[(@bit.ObjectId, String)], Map[String, String]) -> (
    String,
    @bit.ObjectId,
  )?,
  http_get : (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> (String, @bit.ObjectId, Bytes) raise @bit.GitError {
  let prefer_v2 = true
  let (refs, _caps, _version, symrefs) = discover_refs_sync(
    remote_url, prefer_v2, http_get, http_post,
  )
  let target = select_target(refs, symrefs)
  match target {
    None => raise @bit.GitError::ProtocolError(missing_target_message)
    Some((refname, commit_id)) => {
      let pack = fetch_pack_sync(
        remote_url,
        [commit_id],
        prefer_v2,
        depth,
        http_get,
        http_post,
      )
      (refname, commit_id, pack)
    }
  }
}
