///|
test "is_lfs_pointer: valid pointer" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 12345\n"
  assert_eq(is_lfs_pointer(content), true)
}

///|
test "is_lfs_pointer: empty content" {
  assert_eq(is_lfs_pointer(b""), false)
}

///|
test "is_lfs_pointer: regular file content" {
  assert_eq(is_lfs_pointer(b"hello world\n"), false)
}

///|
test "is_lfs_pointer: wrong version" {
  let content = b"version https://example.com/v1\noid sha256:abcd\nsize 100\n"
  assert_eq(is_lfs_pointer(content), false)
}

///|
test "parse_lfs_pointer: valid pointer" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 12345\n"
  let ptr = parse_lfs_pointer(content)
  assert_eq(ptr is None, false)
  let p = ptr.unwrap()
  assert_eq(p.oid, "4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393")
  assert_eq(p.size, 12345L)
}

///|
test "parse_lfs_pointer: missing oid" {
  let content = b"version https://git-lfs.github.com/spec/v1\nsize 100\n"
  assert_eq(parse_lfs_pointer(content) is None, true)
}

///|
test "parse_lfs_pointer: missing size" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\n"
  assert_eq(parse_lfs_pointer(content) is None, true)
}

///|
test "lfs_object_path: correct sharding" {
  let path = lfs_object_path("/repo/.git", "4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393")
  assert_eq(path, "/repo/.git/lfs/objects/4d/7a/4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393")
}
