///|
fn hex(bytes : FixedArray[Byte]) -> String {
  @crypto.bytes_to_hex_string(bytes)
}

///|
test "md5" {
  inspect(hex(@crypto.md5(b"abc")), content="900150983cd24fb0d6963f7d28e17f72")
}

///|
test "sha1" {
  inspect(
    hex(@crypto.sha1(b"abc")),
    content="a9993e364706816aba3e25717850c26c9cd0d89d",
  )
}

///|
test "sha224" {
  inspect(
    hex(@crypto.sha224(b"abc")),
    content="23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7",
  )
}

///|
test "sha256" {
  inspect(
    hex(@crypto.sha256(b"abc")),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sm3" {
  inspect(
    hex(@crypto.sm3(b"abc")),
    content="66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0",
  )
}

///|
test "sha256_from_iter matches one-shot" {
  inspect(
    hex(@crypto.sha256_from_iter(b"abc".iter())),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "incremental SHA256 context" {
  let ctx = @crypto.SHA256::new()
  ctx.update(b"ab")
  ctx.update(b"c")
  inspect(
    hex(ctx.finalize()),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "hmac sha256" {
  let mac = @crypto.hmac(
    @crypto.SHA256::new(),
    b"key"[:],
    b"The quick brown fox jumps over the lazy dog"[:],
  )
  inspect(
    hex(mac),
    content="f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8",
  )
}

///|
test "uints_to_hex_string" {
  inspect(
    @crypto.uints_to_hex_string([(0xdeadbeef : UInt32)].iter()),
    content="deadbeef",
  )
}
