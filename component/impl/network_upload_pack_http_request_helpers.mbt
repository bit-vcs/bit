///| WASM Component upload-pack HTTP request helpers

///|
fn upload_pack_http_base_url(remote : String) -> String raise @bit.GitError {
  let normalized_url = net_normalize_remote_for_http_transport(remote)
  let spec = @protocol.parse_remote(normalized_url)
  if spec.kind != @protocol.RemoteKind::Http {
    raise @bit.GitError::ProtocolError("HTTP transport required")
  }
  match spec.base_url {
    Some(base) => base
    None => normalized_url
  }
}

///|
fn upload_pack_info_refs_request(
  remote : String,
  prefer_v2 : Bool,
) -> (String, Map[String, String]) raise @bit.GitError {
  let base = upload_pack_http_base_url(remote)
  let headers : Map[String, String] = {
    "User-Agent": "git/moonbit",
    "Accept": "application/x-git-upload-pack-advertisement",
  }
  if prefer_v2 {
    headers["Git-Protocol"] = "version=2"
  }
  ("\{base}/info/refs?service=git-upload-pack", headers)
}

///|
fn upload_pack_service_request(
  remote : String,
  prefer_v2 : Bool,
) -> (String, Map[String, String]) raise @bit.GitError {
  let base = upload_pack_http_base_url(remote)
  let headers : Map[String, String] = {
    "User-Agent": "git/moonbit",
    "Content-Type": "application/x-git-upload-pack-request",
    "Accept": "application/x-git-upload-pack-result",
  }
  if prefer_v2 {
    headers["Git-Protocol"] = "version=2"
  }
  ("\{base}/git-upload-pack", headers)
}
