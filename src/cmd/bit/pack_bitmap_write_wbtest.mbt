///| Tests for single-pack bitmap file writing

///|
test "bitmap: build_ewah empty" {
  let ewah = midx_build_ewah_bitmap(0, [])
  // bit_size=0, word_count=1, RLW(0,0,0), trailing=0
  assert_true(ewah.length() > 0)
  // First 4 bytes: bit_size = 0
  assert_eq(ewah[0].to_int(), 0)
  assert_eq(ewah[1].to_int(), 0)
  assert_eq(ewah[2].to_int(), 0)
  assert_eq(ewah[3].to_int(), 0)
}

///|
test "bitmap: build_ewah single bit" {
  let ewah = midx_build_ewah_bitmap(64, [0])
  // bit_size=64 (4 bytes) + word_count=2 (4 bytes) + RLW (8 bytes) + 1 word (8 bytes) + trailing (4 bytes)
  // = 4 + 4 + 8 + 8 + 4 = 28 bytes
  assert_eq(ewah.length(), 28)
  // bit_size = 64
  assert_eq(ewah[0].to_int(), 0)
  assert_eq(ewah[1].to_int(), 0)
  assert_eq(ewah[2].to_int(), 0)
  assert_eq(ewah[3].to_int(), 64)
  // word_count = 2 (1 RLW + 1 literal)
  assert_eq(ewah[4].to_int(), 0)
  assert_eq(ewah[5].to_int(), 0)
  assert_eq(ewah[6].to_int(), 0)
  assert_eq(ewah[7].to_int(), 2)
}

///|
test "bitmap: build_ewah multiple positions" {
  // Set bits 0, 1, 63 in a 64-bit bitmap
  let ewah = midx_build_ewah_bitmap(64, [0, 1, 63])
  assert_eq(ewah.length(), 28)
  // bit_size = 64
  assert_eq(ewah[3].to_int(), 64)
}

///|
test "bitmap: build_ewah multi-word" {
  // 128 bits = 2 words
  let ewah = midx_build_ewah_bitmap(128, [0, 64, 127])
  // 4 + 4 + 8 + 8 + 8 + 4 = 36 bytes
  assert_eq(ewah.length(), 36)
  assert_eq(ewah[3].to_int(), 128)
  // word_count = 3 (1 RLW + 2 literals)
  assert_eq(ewah[7].to_int(), 3)
}

///|
test "bitmap: object_type_code" {
  assert_eq(midx_object_type_code(@bitcore.ObjectType::Commit), 1)
  assert_eq(midx_object_type_code(@bitcore.ObjectType::Tree), 2)
  assert_eq(midx_object_type_code(@bitcore.ObjectType::Blob), 3)
  assert_eq(midx_object_type_code(@bitcore.ObjectType::Tag), 4)
}

///|
test "bitmap: push_u16" {
  let out : Array[Byte] = []
  midx_push_u16(out, 0x0102)
  assert_eq(out[0].to_int(), 1)
  assert_eq(out[1].to_int(), 2)
}

///|
test "bitmap: push_u32" {
  let out : Array[Byte] = []
  midx_push_u32(out, 0x01020304)
  assert_eq(out[0].to_int(), 1)
  assert_eq(out[1].to_int(), 2)
  assert_eq(out[2].to_int(), 3)
  assert_eq(out[3].to_int(), 4)
}

///|
fn bitmap_test_append(out : Array[Byte], data : Array[Byte]) -> Unit {
  for b in data {
    out.push(b)
  }
}

///|
fn bitmap_test_bytes(out : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] }))
}

///|
fn bitmap_test_file(
  object_count : Int,
  commit_positions : Array[Int],
  tree_positions : Array[Int],
  blob_positions : Array[Int],
  tag_positions : Array[Int],
  tip_positions : Array[Int],
) -> Bytes {
  let out : Array[Byte] = []
  out.push(b'B')
  out.push(b'I')
  out.push(b'T')
  out.push(b'M')
  midx_push_u16(out, 1)
  midx_push_u16(out, 1)
  midx_push_u32(out, 1)
  for _ in 0..<20 {
    out.push(b'\x00')
  }
  bitmap_test_append(
    out,
    midx_build_ewah_bitmap(object_count, commit_positions),
  )
  bitmap_test_append(out, midx_build_ewah_bitmap(object_count, tree_positions))
  bitmap_test_append(out, midx_build_ewah_bitmap(object_count, blob_positions))
  bitmap_test_append(out, midx_build_ewah_bitmap(object_count, tag_positions))
  midx_push_u32(out, tip_positions[tip_positions.length() - 1])
  midx_push_u16(out, 1)
  bitmap_test_append(out, midx_build_ewah_bitmap(object_count, tip_positions))
  let body = bitmap_test_bytes(out)
  let trailer = @bitcore.sha1(body)
  for b in trailer.bytes {
    out.push(b)
  }
  bitmap_test_bytes(out)
}

///|
test "bitmap: read_ewah expands literal positions" {
  let ewah = midx_build_ewah_bitmap(130, [0, 40, 65, 129])
  guard pack_bitmap_read_ewah(
      Bytes::from_array(FixedArray::makei(ewah.length(), fn(i) { ewah[i] })),
      0,
      ewah.length(),
    )
    is Some((bits, next_pos)) else {
    fail("expected ewah parse")
  }
  assert_eq(next_pos, ewah.length())
  assert_eq(bits.bit_size, 130)
  assert_eq(bits.positions, [0, 40, 65, 129])
}

///|
test "bitmap: parse pack bitmap type and tip entries" {
  let data = bitmap_test_file(4, [0, 3], [1], [2], [], [0, 1, 2, 3])
  guard pack_bitmap_parse(data) is Some(bitmap) else {
    fail("expected bitmap parse")
  }
  assert_eq(bitmap.version, 1)
  assert_eq(bitmap.options, 1)
  assert_eq(bitmap.object_count, 4)
  assert_eq(bitmap.commit_positions, [0, 3])
  assert_eq(bitmap.tree_positions, [1])
  assert_eq(bitmap.blob_positions, [2])
  assert_eq(bitmap.tag_positions, [])
  assert_eq(bitmap.entries.length(), 1)
  assert_eq(bitmap.entries[0].object_pos, 3)
  assert_eq(bitmap.entries[0].flags, 1)
  assert_eq(bitmap.entries[0].positions, [0, 1, 2, 3])
}

///|
test "bitmap: parse rejects checksum mismatch" {
  let data = bitmap_test_file(2, [0], [1], [], [], [0, 1])
  let bytes = FixedArray::makei(data.length(), fn(i) { data[i] })
  bytes[data.length() - 1] = (bytes[data.length() - 1].to_int() ^ 1).to_byte()
  match pack_bitmap_parse(Bytes::from_array(bytes)) {
    None => ()
    Some(_) => fail("expected checksum mismatch rejection")
  }
}
