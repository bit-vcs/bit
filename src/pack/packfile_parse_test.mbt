///|
/// Tests for packfile parsing

///|
test "packfile parse: blob roundtrip" {
  let content = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let packfile = create_blob_packfile(content)
  let objects = parse_packfile(packfile)
  assert_true(objects.length() == 1)
  let obj = objects[0]
  assert_true(obj.obj_type == @git.ObjectType::Blob)
  assert_true(obj.data.length() == content.length())
  for i = 0; i < content.length(); i = i + 1 {
    assert_true(obj.data[i] == content[i])
  }
}

///|
test "packfile parse: commit packfile order" {
  let blob_content = Bytes::from_array([b'h', b'e', b'l', b'l', b'o', b'\n'])
  let commit = @git.Commit::new(
    @git.ObjectId::zero(),
    [],
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "Test commit\n",
  )
  let (_, packfile) = create_commit_packfile(blob_content, "hello.txt", commit)
  let objects = parse_packfile(packfile)
  assert_true(objects.length() == 3)
  assert_true(objects[0].obj_type == @git.ObjectType::Blob)
  assert_true(objects[1].obj_type == @git.ObjectType::Tree)
  assert_true(objects[2].obj_type == @git.ObjectType::Commit)
}

///|
test "packfile parse: trailer mismatch" {
  let content = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let packfile = create_blob_packfile(content)
  let bytes : Array[Byte] = []
  for b in packfile {
    bytes.push(b)
  }
  let last = bytes.length() - 1
  bytes[last] = (bytes[last].to_int() ^ 0xff).to_byte()
  let tampered = Bytes::from_array(
    FixedArray::makei(bytes.length(), fn(i) { bytes[i] }),
  )
  let result = try? parse_packfile(tampered)
  match result {
    Err(@git.GitError::HashMismatch(_, _)) => ()
    _ => assert_true(false)
  }
}
