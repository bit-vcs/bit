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

///|
test "Sha1State: abc" {
  let state = Sha1State::new()
  state.update(Bytes::from_array([b'a', b'b', b'c']))
  let got = state.finish_raw() |> raw_to_hex
  inspect(got, content="a9993e364706816aba3e25717850c26c9cd0d89d")
}

///|
test "Sha1State: large input matches sha1_raw" {
  // Test with a 200-byte input simulating a hub record blob
  let long_str = "version 1\nkey hub/proposal/pr/abc12345/meta\nkind pr-proposal\nclock local=1\ntimestamp 1706745600\nnode dave@example.com\ndeleted 0\n\nsome payload content here that makes this longer than 64 bytes total"
  let bytes = Bytes::from_array(long_str.to_array().map(fn(c) { c.to_int().to_byte() }))
  let expected = sha1_raw(bytes) |> raw_to_hex
  let state = Sha1State::new()
  state.update(bytes)
  let got = state.finish_raw() |> raw_to_hex
  inspect(got == expected, content="true")
}

///|
test "sha1_raw: 35-byte input" {
  // printf "blob 29 hub/proposal/pr/abc12345/meta" | sha1sum
  let key = "hub/proposal/pr/abc12345/meta"
  let header = "blob " + key.length().to_string() + " "
  let data : Array[Byte] = []
  for c in header {
    data.push(c.to_int().to_byte())
  }
  for c in key {
    data.push(c.to_int().to_byte())
  }
  let got = sha1_raw(Bytes::from_array(data)) |> raw_to_hex
  inspect(got, content="11db444b9672b9977348f8f051eb3288d6dbea0c")
}
