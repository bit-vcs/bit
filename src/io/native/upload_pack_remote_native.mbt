///| Upload-pack dispatcher (native targets)

///|
fn ensure_process_remote(remote : String) -> Unit raise @bit.GitError {
  let spec = @protocol.parse_remote(remote)
  if spec.kind == @protocol.RemoteKind::Http {
    raise @bit.GitError::ProtocolError("HTTP transport requires wasm targets")
  }
}

///|
pub async fn upload_pack_info_refs(
  remote : String,
  prefer_v2 : Bool,
) -> Bytes raise @bit.GitError {
  ensure_process_remote(remote)
  upload_pack_info_refs_process(remote, prefer_v2)
}

///|
pub async fn upload_pack_request(
  remote : String,
  body : Bytes,
  prefer_v2 : Bool,
) -> Bytes raise @bit.GitError {
  ensure_process_remote(remote)
  upload_pack_request_process(remote, body, prefer_v2)
}

///|
pub async fn discover_upload_refs(
  remote : String,
  prefer_v2 : Bool,
) -> (
  Array[(@bit.ObjectId, String)],
  Array[String],
  @protocol.ProtocolVersion,
  Map[String, String],
) raise @bit.GitError {
  ensure_process_remote(remote)
  discover_upload_refs_process(remote, prefer_v2)
}

///|
pub async fn fetch_pack(
  remote : String,
  wants : Array[@bit.ObjectId],
  prefer_v2 : Bool,
) -> Bytes raise @bit.GitError {
  ensure_process_remote(remote)
  fetch_pack_process(remote, wants, prefer_v2)
}

///|
pub async fn fetch_objects(
  remote : String,
  wants : Array[@bit.ObjectId],
  prefer_v2 : Bool,
) -> Array[@bit.PackObject] raise @bit.GitError {
  ensure_process_remote(remote)
  fetch_objects_process(remote, wants, prefer_v2)
}

///|
pub async fn clone_remote(
  remote : String,
  prefer_v2 : Bool,
) -> (Array[(@bit.ObjectId, String)], Array[@bit.PackObject]) raise @bit.GitError {
  ensure_process_remote(remote)
  clone_process(remote, prefer_v2)
}

///|
pub async fn clone_remote_to_fs(
  remote : String,
  prefer_v2 : Bool,
  fs : &@bit.FileSystem,
  root : String,
) -> Array[(@bit.ObjectId, String)] raise @bit.GitError {
  ensure_process_remote(remote)
  clone_process_to_fs(remote, prefer_v2, fs, root)
}
