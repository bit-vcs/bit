///| WASM Component upload-pack fetch request helpers

///|
fn upload_pack_select_wants(
  refs : Array[(@bit.ObjectId, String)],
  wants : Array[@bit.ObjectId],
) -> Array[@bit.ObjectId] {
  if wants.length() > 0 {
    return wants
  }
  let ids : Array[@bit.ObjectId] = []
  for item in refs {
    let (id, _) = item
    ids.push(id)
  }
  ids
}

///|
fn upload_pack_build_fetch_request(
  version : @protocol.ProtocolVersion,
  wants : Array[@bit.ObjectId],
  caps : Array[String],
  depth : Int,
) -> (Bytes, Bool) {
  if version == @protocol.ProtocolVersion::V2 {
    return (@protocol.build_fetch_request_v2("git/moonbit", wants, depth), true)
  }
  (@protocol.build_fetch_request_v0("git/moonbit", wants, caps), false)
}
