///|
/// RFC 4231 test vectors for HMAC-SHA256.
fn repeat_byte(b : Byte, n : Int) -> Bytes {
  Bytes::from_array(FixedArray::make(n, b))
}

///|
fn ascii_bytes(s : String) -> Bytes {
  let out : Array[Byte] = []
  for c in s {
    out.push(c.to_int().to_byte())
  }
  Bytes::from_array(out)
}

///|
test "hmac_sha256 RFC 4231 case 1" {
  let key = repeat_byte(b'\x0b', 20)
  let got = hmac_sha256_raw(key, ascii_bytes("Hi There")) |> raw_to_hex
  inspect(
    got,
    content="b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7",
  )
}

///|
test "hmac_sha256 RFC 4231 case 2" {
  let got = hmac_sha256_raw(
      ascii_bytes("Jefe"),
      ascii_bytes("what do ya want for nothing?"),
    )
    |> raw_to_hex
  inspect(
    got,
    content="5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
  )
}

///|
test "hmac_sha256 RFC 4231 case 3" {
  let got = hmac_sha256_raw(repeat_byte(b'\xaa', 20), repeat_byte(b'\xdd', 50))
    |> raw_to_hex
  inspect(
    got,
    content="773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe",
  )
}

///|
test "hmac_sha256 RFC 4231 case 6: key longer than the block" {
  let got = hmac_sha256_raw(
      repeat_byte(b'\xaa', 131),
      ascii_bytes("Test Using Larger Than Block-Size Key - Hash Key First"),
    )
    |> raw_to_hex
  inspect(
    got,
    content="60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54",
  )
}

///|
test "hmac_sha256 key of exactly one block" {
  // The boundary where the key is neither hashed nor padded.
  let got = hmac_sha256_raw(repeat_byte(b'\xaa', 64), ascii_bytes("abc"))
    |> raw_to_hex
  // hmac_sha256_bytes must agree with the raw form.
  let via_bytes = hmac_sha256_bytes(
    repeat_byte(b'\xaa', 64),
    ascii_bytes("abc"),
  )
  inspect(got == raw_to_hex(via_bytes.to_fixedarray()), content="true")
  inspect(got.length(), content="64")
}
