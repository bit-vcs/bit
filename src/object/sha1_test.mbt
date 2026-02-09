///|
/// Tests for SHA-1 implementation
test "sha1 empty" {
  let data = Bytes::from_array([])
  let hash = sha1(data)
  // SHA-1("") = da39a3ee5e6b4b0d3255bfef95601890afd80709
  inspect(hash.to_hex(), content="da39a3ee5e6b4b0d3255bfef95601890afd80709")
}

///|
test "sha1 abc" {
  let data = Bytes::from_array([b'a', b'b', b'c'])
  let hash = sha1(data)
  // SHA-1("abc") = a9993e364706816aba3e25717850c26c9cd0d89d
  inspect(hash.to_hex(), content="a9993e364706816aba3e25717850c26c9cd0d89d")
}

///|
test "sha1 message" {
  // "The quick brown fox jumps over the lazy dog"
  let msg = "The quick brown fox jumps over the lazy dog"
  let data : Array[Byte] = []
  for c in msg {
    data.push(c.to_int().to_byte())
  }
  let hash = sha1(
    Bytes::from_array(FixedArray::makei(data.length(), fn(i) { data[i] })),
  )
  // SHA-1 = 2fd4e1c67a2d28fced849ee1bb76e7391b93eb12
  inspect(hash.to_hex(), content="2fd4e1c67a2d28fced849ee1bb76e7391b93eb12")
}

///|
test "sha1 git blob hello" {
  // Git blob format: "blob {size}\0{content}"
  // For "hello\n", the SHA should be ce013625030ba8dba906f756967f9e9ca394464a
  let content = "hello\n"
  let header = "blob 6\u0000"
  let data : Array[Byte] = []
  for c in header {
    data.push(c.to_int().to_byte())
  }
  for c in content {
    data.push(c.to_int().to_byte())
  }
  let hash = sha1(
    Bytes::from_array(FixedArray::makei(data.length(), fn(i) { data[i] })),
  )
  inspect(hash.to_hex(), content="ce013625030ba8dba906f756967f9e9ca394464a")
}

///|
test "ObjectId from_hex to_hex roundtrip" {
  let hex = "ce013625030ba8dba906f756967f9e9ca394464a"
  let id = ObjectId::from_hex(hex)
  inspect(id.to_hex(), content="ce013625030ba8dba906f756967f9e9ca394464a")
}

///|
test "ObjectId zero" {
  let id = ObjectId::zero()
  inspect(id.to_hex(), content="0000000000000000000000000000000000000000")
}

///|
test "ObjectId equality" {
  let id1 = ObjectId::from_hex("ce013625030ba8dba906f756967f9e9ca394464a")
  let id2 = ObjectId::from_hex("ce013625030ba8dba906f756967f9e9ca394464a")
  let id3 = ObjectId::from_hex("da39a3ee5e6b4b0d3255bfef95601890afd80709")
  assert_true(id1 == id2)
  assert_true(id1 != id3)
}
