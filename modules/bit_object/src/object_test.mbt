///|
/// Tests for Git object creation
test "create blob hello" {
  // "hello\n" should produce ce013625030ba8dba906f756967f9e9ca394464a
  let (id, _) = @bit_object.create_blob_string("hello\n")
  inspect(id.to_hex(), content="ce013625030ba8dba906f756967f9e9ca394464a")
}

///|
test "hash blob hello" {
  let id = @bit_object.hash_blob_string("hello\n")
  inspect(id.to_hex(), content="ce013625030ba8dba906f756967f9e9ca394464a")
}

///|
test "create blob empty" {
  // Empty blob: e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
  let (id, _) = @bit_object.create_blob_string("")
  inspect(id.to_hex(), content="e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
}

///|
test "create blob world" {
  // "world\n" = cc628ccd10742baea8241c5924df992b5c019f71
  let (id, _) = @bit_object.create_blob_string("world\n")
  inspect(id.to_hex(), content="cc628ccd10742baea8241c5924df992b5c019f71")
}

///|
test "create tree single entry" {
  // Tree with single blob entry
  let blob_id = @bit_object.ObjectId::from_hex("ce013625030ba8dba906f756967f9e9ca394464a")
  let entry = @bit_object.TreeEntry::new("100644", "hello.txt", blob_id)
  let (tree_id, _) = @bit_object.create_tree([entry])

  // Verify the tree ID is computed correctly
  // This can be verified with: git mktree
  assert_true(tree_id.to_hex().length() == 40)
}

///|
test "create tree multiple entries" {
  // Tree with multiple entries (must be sorted by name)
  let hello_id = @bit_object.ObjectId::from_hex("ce013625030ba8dba906f756967f9e9ca394464a")
  let world_id = @bit_object.ObjectId::from_hex("cc628ccd10742baea8241c5924df992b5c019f71")
  let entries = [
    @bit_object.TreeEntry::new("100644", "hello.txt", hello_id),
    @bit_object.TreeEntry::new("100644", "world.txt", world_id),
  ]
  let (tree_id, compressed) = @bit_object.create_tree(entries)

  // Verify tree ID is 40 hex chars
  assert_true(tree_id.to_hex().length() == 40)

  // Verify compressed data is not empty
  assert_true(compressed.length() > 0)
}

///|
test "create commit" {
  let tree_id = @bit_object.ObjectId::from_hex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
  let commit = @bit_object.Commit::new(
    tree_id,
    [], // no parents
    "Test Author <test@example.com>",
    1700000000L,
    "+0000",
    "Test Author <test@example.com>",
    1700000000L,
    "+0000",
    "Initial commit\n",
  )
  let (commit_id, compressed) = @bit_object.create_commit(commit)

  // Verify commit ID is 40 hex chars
  assert_true(commit_id.to_hex().length() == 40)

  // Verify compressed data is not empty
  assert_true(compressed.length() > 0)
}

///|
test "create commit with parent" {
  let tree_id = @bit_object.ObjectId::from_hex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
  let parent_id = @bit_object.ObjectId::from_hex("0000000000000000000000000000000000000001")
  let commit = @bit_object.Commit::new(
    tree_id,
    [parent_id],
    "Test Author <test@example.com>",
    1700000000L,
    "+0000",
    "Test Author <test@example.com>",
    1700000000L,
    "+0000",
    "Second commit\n",
  )
  let (commit_id, _) = @bit_object.create_commit(commit)
  assert_true(commit_id.to_hex().length() == 40)
}

///|
fn object_test_ascii_bytes(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for c in s {
    out.push(c.to_int().to_byte())
  }
  out
}

///|
test "serialize commit preserves non-utf8 encoding header and bytes" {
  let tree_id = @bit_object.ObjectId::from_hex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
  let commit = @bit_object.Commit::new(
    tree_id,
    [],
    "Test Author <test@example.com>",
    1700000000L,
    "+0000",
    "Test Author <test@example.com>",
    1700000000L,
    "+0000",
    "changed (geändert) foo\n",
    encoding="ISO-8859-1",
  )
  let actual = @bit_object.serialize_commit_content(commit).to_array()
  let expected = object_test_ascii_bytes(
    "tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904\n" +
    "author Test Author <test@example.com> 1700000000 +0000\n" +
    "committer Test Author <test@example.com> 1700000000 +0000\n" +
    "encoding ISO-8859-1\n\n" +
    "changed (ge",
  )
  expected.push(b'\xe4')
  expected.append(object_test_ascii_bytes("ndert) foo\n"))
  assert_true(actual == expected)
}

///|
test "ObjectType to_string" {
  inspect(@bit_object.ObjectType::Blob.to_string(), content="blob")
  inspect(@bit_object.ObjectType::Tree.to_string(), content="tree")
  inspect(@bit_object.ObjectType::Commit.to_string(), content="commit")
  inspect(@bit_object.ObjectType::Tag.to_string(), content="tag")
}

///|
test "ObjectType to_packfile_type" {
  inspect(@bit_object.ObjectType::Commit.to_packfile_type(), content="1")
  inspect(@bit_object.ObjectType::Tree.to_packfile_type(), content="2")
  inspect(@bit_object.ObjectType::Blob.to_packfile_type(), content="3")
  inspect(@bit_object.ObjectType::Tag.to_packfile_type(), content="4")
}
