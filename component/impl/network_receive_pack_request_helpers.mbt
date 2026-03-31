///| WASM Component receive-pack request helpers

///|
fn receive_pack_info_refs_request(
  remote : String,
) -> (String, Map[String, String]) raise @bit.GitError {
  let remote = net_http_remote(remote)
  let headers : Map[String, String] = {
    "User-Agent": "git/moonbit",
    "Accept": "application/x-git-receive-pack-advertisement",
  }
  (remote.info_refs_url(), headers)
}

///|
fn receive_pack_service_request(
  remote : String,
  new_id : @bit.ObjectId,
  old_id : @bit.ObjectId,
  refname : String,
  pack : Bytes,
) -> (String, Bytes, Map[String, String]) raise @bit.GitError {
  let remote = net_http_remote(remote)
  let request = @protocol.PushRequest::new(old_id, new_id, refname, pack)
  let headers : Map[String, String] = {
    "User-Agent": "git/moonbit",
    "Content-Type": "application/x-git-receive-pack-request",
    "Accept": "application/x-git-receive-pack-result",
  }
  (
    remote.receive_pack_url(),
    @protocol.build_receive_pack_body(request),
    headers,
  )
}
