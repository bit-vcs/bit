///| WASM Component upload-pack response helpers

///|
fn upload_pack_parse_discovery_advertisement(
  adv : Bytes,
) -> (
  Array[(@bit.ObjectId, String)],
  Array[String],
  @protocol.ProtocolVersion,
  Map[String, String],
) raise @bit.GitError {
  let version = @protocol.detect_protocol_version(adv)
  if version == @protocol.ProtocolVersion::V2 {
    return ([], @protocol.parse_v2_advertised_caps(adv), version, {})
  }
  let refs = @protocol.parse_refs(adv)
  let caps = @protocol.extract_capabilities(adv)
  let symrefs = net_parse_symrefs_from_capabilities(caps)
  (refs, caps, @protocol.ProtocolVersion::V0, symrefs)
}

///|
fn upload_pack_extract_fetch_pack(
  version : @protocol.ProtocolVersion,
  response : Bytes,
) -> Bytes raise @bit.GitError {
  if version == @protocol.ProtocolVersion::V2 {
    return @protocol.extract_pack_from_v2_response(response)
  }
  @protocol.extract_pack_from_v0_response(response)
}
