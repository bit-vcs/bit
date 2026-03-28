///| Tests for commit-graph writer

///|
test "cgraph: write_u32 via midx_push_u32" {
  let buf : Array[Byte] = []
  midx_push_u32(buf, 0x43475048)
  assert_eq(buf[0].to_int(), 0x43)
  assert_eq(buf[1].to_int(), 0x47)
  assert_eq(buf[2].to_int(), 0x50)
  assert_eq(buf[3].to_int(), 0x48)
}

///|
test "cgraph: compare_oid_bytes equal" {
  let a = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let b = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  assert_eq(cgraph_compare_oid_bytes(a.bytes, b.bytes, 20), 0)
}

///|
test "cgraph: compare_oid_bytes less" {
  let a = @bitcore.ObjectId::from_hex(
    "1111111111111111111111111111111111111111",
  )
  let b = @bitcore.ObjectId::from_hex(
    "2222222222222222222222222222222222222222",
  )
  assert_true(cgraph_compare_oid_bytes(a.bytes, b.bytes, 20) < 0)
  assert_true(cgraph_compare_oid_bytes(b.bytes, a.bytes, 20) > 0)
}

///|
test "cgraph: extract_committer_timestamp" {
  let commit_text = "tree aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\nauthor Test <test@test.com> 1700000000 +0000\ncommitter Test <test@test.com> 1700000001 +0000\n\ntest commit\n"
  let data = @utf8.encode(commit_text)
  assert_eq(@tar.tar_parse_committer_timestamp(data), 1700000001L)
}

///|
test "cgraph: extract_committer_timestamp missing" {
  let commit_text = "tree aaaa\n\nno committer\n"
  let data = @utf8.encode(commit_text)
  assert_eq(@tar.tar_parse_committer_timestamp(data), 0L)
}
