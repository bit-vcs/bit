///|
test "roundtrip compress/decompress" {
  let data = Bytes::from_array(
    FixedArray::makei(10000, i => (i % 251 * 7 % 256).to_byte()),
  )
  for c in [zlib_compress(data), zlib_compress_fast(data), zlib_compress_stored(data)] {
    assert_eq(zlib_decompress(c), data)
  }
  assert_true(zlib_compress_stored(data).length() >= data.length() + 6)
}

///|
test "decompress_at stops after trailer" {
  let a = b"hello hello hello"
  let b = b"world"
  let ca = zlib_compress(a)
  let cb = zlib_compress_stored(b)
  let joined = Bytes::from_array(
    FixedArray::from_array([..b"xy", ..ca, ..cb, ..b"!"]),
  )
  let (out_a, next) = zlib_decompress_at(joined, 2)
  assert_eq(out_a, a)
  assert_eq(next, 2 + ca.length())
  let (out_b, next2) = zlib_decompress_at(joined, next)
  assert_eq(out_b, b)
  assert_eq(next2, joined.length() - 1)
}

///|
test "decompress_at rejects bad input" {
  let c = zlib_compress(b"abcdef")
  let truncated = c[:c.length() - 1].to_owned()
  assert_true(fails(() => ignore(zlib_decompress_at(truncated, 0))))
  let corrupt = Bytes::from_array(
    FixedArray::from_array([..c[:c.length() - 1], c[c.length() - 1] ^ 1]),
  )
  assert_true(fails(() => ignore(zlib_decompress_at(corrupt, 0))))
  assert_true(fails(() => ignore(zlib_decompress(zlib_compress(b"x"), max_size=0))))
  assert_true(fails(() => ignore(zlib_decompress_at(b"\x00\x00", 0))))
}

///|
test "adler32 known values" {
  assert_eq(adler32(b""), 1U)
  assert_eq(adler32(b"Wikipedia"), 0x11E60398U)
}

///|
fn fails(f : () -> Unit raise) -> Bool {
  try f() catch {
    _ => true
  } noraise {
    _ => false
  }
}
