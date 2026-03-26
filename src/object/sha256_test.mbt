///|
test "sha256 empty" {
  let data = Bytes::from_array([])
  let hash = sha256(data)
  inspect(
    hash.to_hex(),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256 abc" {
  let data = Bytes::from_array([b'a', b'b', b'c'])
  let hash = sha256(data)
  inspect(
    hash.to_hex(),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 git blob hello" {
  // git hash-object --object-format=sha256 with "hello\n"
  // = "blob 6\0hello\n" hashed with SHA-256
  let hash = hash_object_content_with_algo(
    Sha256,
    Blob,
    Bytes::from_array([b'h', b'e', b'l', b'l', b'o', b'\n']),
  )
  // Verified: printf "blob 6\0hello\n" | sha256sum
  inspect(
    hash.to_hex(),
    content="2cf8d83d9ee29543b34a87727421fdecb7e3f3a183d337639025de576db9ebb4",
  )
}

///|
test "ObjectId from_hex sha256 roundtrip" {
  let hex = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  let id = ObjectId::from_hex(hex)
  assert_eq(id.hash_size(), 32)
  inspect(
    id.to_hex(),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "ObjectId zero sha256" {
  let id = ObjectId::zero(algo=Sha256)
  assert_eq(id.hash_size(), 32)
  inspect(
    id.to_hex(),
    content="0000000000000000000000000000000000000000000000000000000000000000",
  )
  assert_true(id.is_zero())
}

///|
test "ObjectId is_zero_hex both formats" {
  assert_true(ObjectId::is_zero_hex("0000000000000000000000000000000000000000"))
  assert_true(
    ObjectId::is_zero_hex(
      "0000000000000000000000000000000000000000000000000000000000000000",
    ),
  )
  assert_false(
    ObjectId::is_zero_hex(
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    ),
  )
}

///|
test "HashState sha1 matches direct" {
  let direct = hash_object_content(
    Blob,
    Bytes::from_array([b'h', b'e', b'l', b'l', b'o', b'\n']),
  )
  let via_algo = hash_object_content_with_algo(
    Sha1,
    Blob,
    Bytes::from_array([b'h', b'e', b'l', b'l', b'o', b'\n']),
  )
  assert_eq(direct, via_algo)
}

///|
test "HashAlgorithm properties" {
  assert_eq(HashAlgorithm::Sha1.hash_size(), 20)
  assert_eq(HashAlgorithm::Sha1.hex_size(), 40)
  assert_eq(HashAlgorithm::Sha256.hash_size(), 32)
  assert_eq(HashAlgorithm::Sha256.hex_size(), 64)
}

///|
test "HashAlgorithm from_string" {
  assert_eq(HashAlgorithm::from_string("sha1"), Sha1)
  assert_eq(HashAlgorithm::from_string("sha256"), Sha256)
  assert_eq(HashAlgorithm::from_string("SHA-256"), Sha256)
}
