///| Native wrappers for auto-fetch in serve

///|
async fn serve_discover_upload_refs_http(
  remote : String,
  prefer_v2 : Bool,
) -> (
  Array[(@bitcore.ObjectId, String)],
  Array[String],
  @protocol.ProtocolVersion,
  Map[String, String],
) raise Error {
  @bitnative.discover_upload_refs_http(remote, prefer_v2)
}

///|
async fn serve_fetch_pack_http(
  remote : String,
  wants : Array[@bitcore.ObjectId],
  prefer_v2 : Bool,
) -> Bytes raise Error {
  @bitnative.fetch_pack_http(remote, wants, prefer_v2)
}
