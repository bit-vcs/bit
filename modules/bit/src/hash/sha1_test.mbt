///|
fn raw_to_hex(raw : FixedArray[Byte]) -> String {
  let digits = "0123456789abcdef"
  let out = StringBuilder::new()
  for b in raw {
    let v = b.to_int()
    out.write_char(digits[v / 16].to_int().unsafe_to_char())
    out.write_char(digits[v % 16].to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
test "sha1_raw empty" {
  let got = sha1_raw(Bytes::from_array([])) |> raw_to_hex
  inspect(got, content="da39a3ee5e6b4b0d3255bfef95601890afd80709")
}

///|
test "sha1_raw abc" {
  let got = sha1_raw(Bytes::from_array([b'a', b'b', b'c'])) |> raw_to_hex
  inspect(got, content="a9993e364706816aba3e25717850c26c9cd0d89d")
}
