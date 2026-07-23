///|
test "shallow metadata: read and apply server updates" {
  let fs = @io.TestFs::new()
  let first = @object.ObjectId::from_hex(
    "cc628ccd10742baea8241c5924df992b5c019f71",
  )
  let second = @object.ObjectId::from_hex(
    "88e38705fdbd3608cddbe904b67c731f3234c45b",
  )
  fs.mkdir_p("/repo/.git")
  fs.write_string("/repo/.git/shallow", first.to_hex() + "\n\ninvalid\n")
  let initial = read_shallow_boundaries(fs, "/repo/.git")
  @test.assert_eq(initial.length(), 1)
  @test.assert_eq(initial[0], first)
  apply_shallow_updates(fs, fs, "/repo/.git", [second], [first])
  @test.assert_eq(
    @utf8.decode_lossy(fs.read_file("/repo/.git/shallow")[:]),
    second.to_hex() + "\n",
  )
  apply_shallow_updates(fs, fs, "/repo/.git", [], [second])
  assert_false(fs.is_file("/repo/.git/shallow"))
}
