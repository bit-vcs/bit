///| JS stubs for auto-fetch in serve (not yet supported)

///|
async fn serve_discover_upload_refs_http(
  _remote : String,
  _prefer_v2 : Bool,
) -> (
  Array[(@bitcore.ObjectId, String)],
  Array[String],
  @protocol.ProtocolVersion,
  Map[String, String],
) raise Error {
  raise @bitcore.GitError::ProtocolError(
    "auto-fetch is not supported in JS target",
  )
}

///|
async fn serve_fetch_pack_http(
  _remote : String,
  _wants : Array[@bitcore.ObjectId],
  _prefer_v2 : Bool,
) -> Bytes raise Error {
  raise @bitcore.GitError::ProtocolError(
    "auto-fetch is not supported in JS target",
  )
}
