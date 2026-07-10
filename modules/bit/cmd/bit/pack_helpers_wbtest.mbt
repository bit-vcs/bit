///|
fn make_sha256_ref_delta_pack_for_helpers() -> (Bytes, String) {
  let base = @utf8.encode("Hello, World! This is a test content.\n")
  let target = @utf8.encode("Hello, World! This is a test changed.\n")
  let pack : Array[Byte] = []
  pack.push(b'P')
  pack.push(b'A')
  pack.push(b'C')
  pack.push(b'K')
  pack.push(b'\x00')
  pack.push(b'\x00')
  pack.push(b'\x00')
  pack.push(b'\x02')
  pack.push(b'\x00')
  pack.push(b'\x00')
  pack.push(b'\x00')
  pack.push(b'\x02')

  @pack.encode_type_and_size(
    @bitcore.ObjectType::Blob.to_packfile_type(),
    base.length(),
    pack,
  )
  let compressed_base = @zlib.zlib_compress_stored(base)
  for b in compressed_base {
    pack.push(b)
  }

  let delta = @pack.build_delta_pub(base, target)
  @pack.encode_type_and_size(7, delta.length(), pack)
  let base_id = @bitcore.hash_object_content_with_algo(
    @bitcore.HashAlgorithm::Sha256,
    @bitcore.ObjectType::Blob,
    base,
  )
  for b in base_id.bytes {
    pack.push(b)
  }
  let compressed_delta = @zlib.zlib_compress_stored(delta)
  for b in compressed_delta {
    pack.push(b)
  }
  let trailer = @bitcore.hash_array_prefix(pack, pack.length(), hash_size=32)
  for b in trailer.bytes {
    pack.push(b)
  }
  (
    Bytes::from_array(FixedArray::makei(pack.length(), fn(i) { pack[i] })),
    base_id.to_hex(),
  )
}

///|
test "pack helpers: pack_hash_hex supports sha256 trailer" {
  let (pack, _) = make_sha256_ref_delta_pack_for_helpers()
  let expected = @bitcore.hash_prefix(pack, pack.length() - 32, hash_size=32)
  assert_eq(pack_hash_hex(pack, hash_size=32), expected.to_hex())
}

///|
test "pack helpers: scan_ref_delta_bases supports sha256 ids" {
  let (pack, base_hex) = make_sha256_ref_delta_pack_for_helpers()
  let bases = scan_ref_delta_bases(pack, hash_size=32)
  assert_eq(bases.length(), 1)
  assert_eq(bases[0], base_hex)
}
