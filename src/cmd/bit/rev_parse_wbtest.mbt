///|
test "rev-parse: output-object-format uses loose-object-idx mapping" {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/repo/.git/objects")
  fs.write_string(
    "/repo/.git/config",
    "[extensions]\n\tobjectformat = sha1\n\tcompatobjectformat = sha256\n",
  )
  fs.write_string(
    "/repo/.git/objects/loose-object-idx",
    "# loose-object-idx\n1111111111111111111111111111111111111111 2222222222222222222222222222222222222222222222222222222222222222\n",
  )
  let oid = @git.ObjectId::from_hex("1111111111111111111111111111111111111111")
  assert_eq(
    rev_parse_resolve_output_oid_hex(
      fs,
      "/repo/.git",
      oid,
      Some("sha256"),
    ),
    "2222222222222222222222222222222222222222222222222222222222222222",
  )
}

///|
test "rev-parse: output-object-format falls back to storage oid when mapping is absent" {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string(
    "/repo/.git/config",
    "[extensions]\n\tobjectformat = sha1\n\tcompatobjectformat = sha256\n",
  )
  let oid = @git.ObjectId::from_hex("3333333333333333333333333333333333333333")
  assert_eq(
    rev_parse_resolve_output_oid_hex(
      fs,
      "/repo/.git",
      oid,
      Some("sha256"),
    ),
    "3333333333333333333333333333333333333333",
  )
}

