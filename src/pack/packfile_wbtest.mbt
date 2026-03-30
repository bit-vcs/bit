///| Whitebox tests for packfile delta encoding/decoding

///|
test "delta: build and apply roundtrip" {
  let base = @utf8.encode("Hello, World!\n")
  let target = @utf8.encode("Hello, MoonBit!\n")
  let delta = build_delta(base, target)
  let result = apply_delta(base, delta)
  assert_true(result.length() == target.length())
  for i = 0; i < target.length(); i = i + 1 {
    assert_true(result[i] == target[i])
  }
}

///|
test "delta: identical content produces copy-based delta" {
  let data = @utf8.encode("Hello, World!\n")
  let delta = build_delta(data, data)
  let result = apply_delta(data, delta)
  assert_true(result.length() == data.length())
  for i = 0; i < data.length(); i = i + 1 {
    assert_true(result[i] == data[i])
  }
}

///|
test "delta: empty target" {
  let base = @utf8.encode("Hello\n")
  let target = Bytes::from_array([])
  let delta = build_delta(base, target)
  let result = apply_delta(base, delta)
  assert_true(result.length() == 0)
}

///|
test "delta: large similar content uses copy ops" {
  let base_parts : Array[Byte] = []
  let target_parts : Array[Byte] = []
  for i = 0; i < 500; i = i + 1 {
    let line = "line \{i}: some content here\n"
    for c in line {
      base_parts.push(c.to_int().to_byte())
      target_parts.push(c.to_int().to_byte())
    }
  }
  // Modify one line in target
  let mod_line = "line 250: MODIFIED content here\n"
  let mod_start = 250 * 28
  let mut mod_idx = 0
  for c in mod_line {
    if mod_start + mod_idx < target_parts.length() {
      target_parts[mod_start + mod_idx] = c.to_int().to_byte()
    }
    mod_idx += 1
  }
  let base = Bytes::from_array(
    FixedArray::makei(base_parts.length(), fn(i) { base_parts[i] }),
  )
  let target = Bytes::from_array(
    FixedArray::makei(target_parts.length(), fn(i) { target_parts[i] }),
  )
  let delta = build_delta(base, target)
  let result = apply_delta(base, delta)
  // Delta should be smaller than full content
  assert_true(delta.length() < target.length())
  assert_true(result.length() == target.length())
  for i = 0; i < target.length(); i = i + 1 {
    assert_true(result[i] == target[i])
  }
}

///|
test "delta: completely different content uses insert ops" {
  let base = @utf8.encode("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n")
  let target = @utf8.encode("BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB\n")
  let delta = build_delta(base, target)
  let result = apply_delta(base, delta)
  assert_true(result.length() == target.length())
  for i = 0; i < target.length(); i = i + 1 {
    assert_true(result[i] == target[i])
  }
}

///|
test "delta: encode_ofs_delta_offset roundtrip" {
  // Test various offset values
  let test_values = [1, 127, 128, 255, 256, 1000, 0x1234, 0x12345]
  for val in test_values {
    let buf : Array[Byte] = []
    encode_ofs_delta_offset(val, buf)
    // Convert to Bytes for read_ofs_delta_offset
    let bytes = Bytes::from_array(
      FixedArray::makei(buf.length(), fn(i) { buf[i] }),
    )
    let (decoded, _) = read_ofs_delta_offset(bytes, 0)
    assert_true(decoded == val)
  }
}

///|
test "delta: encode_delta_size roundtrip" {
  let test_values = [0, 1, 127, 128, 255, 256, 1000, 0x1234, 0x12345]
  for val in test_values {
    let buf : Array[Byte] = []
    encode_delta_size(val, buf)
    let bytes = Bytes::from_array(
      FixedArray::makei(buf.length(), fn(i) { buf[i] }),
    )
    let (decoded, _) = read_delta_size(bytes, 0)
    assert_true(decoded == val)
  }
}

///|
fn make_sha256_ref_delta_pack() -> (Bytes, @bit.ObjectId, @bit.ObjectId) {
  let base = @utf8.encode("Hello, World! This is the base blob.\n")
  let target = @utf8.encode("Hello, World! This is the updated blob.\n")

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

  encode_type_and_size(
    @bit.ObjectType::Blob.to_packfile_type(),
    base.length(),
    pack,
  )
  let compressed_base = compress_pack_data(base, @bit.PackCompression::Default)
  for b in compressed_base {
    pack.push(b)
  }

  let delta = build_delta(base, target)
  encode_type_and_size(7, delta.length(), pack)
  let base_id = @bit.hash_object_content_with_algo(
    @bit.HashAlgorithm::Sha256,
    @bit.ObjectType::Blob,
    base,
  )
  for b in base_id.bytes {
    pack.push(b)
  }
  let compressed_delta = compress_pack_data(
    delta,
    @bit.PackCompression::Default,
  )
  for b in compressed_delta {
    pack.push(b)
  }

  let trailer = @bit.hash_array_prefix(pack, pack.length(), hash_size=32)
  for b in trailer.bytes {
    pack.push(b)
  }
  let pack_bytes = Bytes::from_array(
    FixedArray::makei(pack.length(), fn(i) { pack[i] }),
  )
  let target_id = @bit.hash_object_content_with_algo(
    @bit.HashAlgorithm::Sha256,
    @bit.ObjectType::Blob,
    target,
  )
  (pack_bytes, base_id, target_id)
}

///|
test "packfile parse: sha256 REF_DELTA roundtrip" {
  let (pack_bytes, base_id, target_id) = make_sha256_ref_delta_pack()
  let objects = parse_packfile(pack_bytes, hash_size=32)
  let ids : Array[String] = []
  for obj in objects {
    ids.push(obj.id.to_hex())
  }
  assert_true(objects.length() == 2)
  assert_true(ids.contains(base_id.to_hex()))
  assert_true(ids.contains(target_id.to_hex()))
}

///|
test "packfile stream: sha256 REF_DELTA roundtrip" {
  let (pack_bytes, base_id, target_id) = make_sha256_ref_delta_pack()
  let streamed_ids : Array[String] = []
  parse_packfile_stream(
    pack_bytes,
    fn(obj) { streamed_ids.push(obj.id.to_hex()) },
    hash_size=32,
  )
  assert_true(streamed_ids.contains(base_id.to_hex()))
  assert_true(streamed_ids.contains(target_id.to_hex()))
}

///|
test "packfile depth: sha256 REF_DELTA roundtrip" {
  let (pack_bytes, _, _) = make_sha256_ref_delta_pack()
  let depth = max_delta_chain_length(pack_bytes, hash_size=32)
  assert_true(depth == 1)
}
