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
