///|
fn component_impl_assert_upload_pack_v2_response(
  refs : Array[(@bit.ObjectId, String)],
  caps : Array[String],
  version : @protocol.ProtocolVersion,
  symrefs : Map[String, String],
) -> Unit raise {
  assert_true(version == @protocol.ProtocolVersion::V2)
  assert_eq(refs.length(), 0)
  assert_eq(symrefs.length(), 0)
  assert_true(caps.contains("ls-refs=unborn"))
}

///|
fn component_impl_assert_upload_pack_v0_response(
  refs : Array[(@bit.ObjectId, String)],
  caps : Array[String],
  version : @protocol.ProtocolVersion,
  symrefs : Map[String, String],
) -> Unit raise {
  assert_true(version == @protocol.ProtocolVersion::V0)
  assert_eq(refs.length(), 2)
  assert_eq(symrefs.get("HEAD"), Some("refs/heads/main"))
  assert_true(caps.contains("multi_ack"))
}

///|
fn component_impl_assert_pack_magic(pack : Bytes) -> Unit raise {
  assert_eq(pack[0], 'P'.to_int().to_byte())
  assert_eq(pack[1], 'A'.to_int().to_byte())
  assert_eq(pack[2], 'C'.to_int().to_byte())
  assert_eq(pack[3], 'K'.to_int().to_byte())
}
