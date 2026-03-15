///| Tests for pure fsck logic

///|
test "fsck_connectivity_check on empty repo" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  fs.mkdir_p(git_dir + "/objects")
  fs.mkdir_p(git_dir + "/objects/pack")
  let db = @lib.ObjectDb::load(fs, git_dir)
  let result = @lib.fsck_connectivity_check(db, fs, [])
  assert_eq(result.errors, 0)
  assert_eq(result.reachable.to_array().length(), 0)
  assert_eq(result.missing.to_array().length(), 0)
}

///|
test "fsck_connectivity_check finds reachable objects" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  fs.mkdir_p(git_dir)
  fs.mkdir_p(git_dir + "/objects")
  fs.mkdir_p(git_dir + "/refs")
  // Create a blob
  let (blob_id, blob_bytes) = @bit.create_blob_string("hello\n")
  @lib.write_object_bytes(fs, git_dir, blob_id, blob_bytes)
  // Create a tree with the blob
  let (tree_id, tree_bytes) = @bit.create_tree(
    [@bit.TreeEntry::new("100644", "hello.txt", blob_id)],
  )
  @lib.write_object_bytes(fs, git_dir, tree_id, tree_bytes)
  // Create a root commit
  let commit = @bit.Commit::new(
    tree_id, [], "A <a@b.c>", 1000000000L, "+0000", "A <a@b.c>",
    1000000000L, "+0000", "test\n",
  )
  let (commit_id, commit_bytes) = @bit.create_commit(commit)
  @lib.write_object_bytes(fs, git_dir, commit_id, commit_bytes)
  let db = @lib.ObjectDb::load(fs, git_dir)
  let result = @lib.fsck_connectivity_check(
    db,
    fs,
    [commit_id],
    collect_extra=true,
  )
  assert_eq(result.errors, 0)
  assert_eq(result.reachable.to_array().length(), 3)
  assert_true(result.reachable.contains(commit_id.to_hex()))
  assert_true(result.reachable.contains(tree_id.to_hex()))
  assert_true(result.reachable.contains(blob_id.to_hex()))
  assert_eq(result.root_commits.length(), 1)
}

///|
test "fsck_connectivity_check detects missing objects" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  fs.mkdir_p(git_dir)
  fs.mkdir_p(git_dir + "/objects")
  fs.mkdir_p(git_dir + "/refs")
  let fake_tree_hex = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let fake_tree_id = @bit.ObjectId::from_hex(fake_tree_hex)
  let commit = @bit.Commit::new(
    fake_tree_id,
    [],
    "A <a@b.c>",
    1000000000L,
    "+0000",
    "A <a@b.c>",
    1000000000L,
    "+0000",
    "test\n",
  )
  let (commit_id, commit_bytes) = @bit.create_commit(commit)
  @lib.write_object_bytes(fs, git_dir, commit_id, commit_bytes)
  let db = @lib.ObjectDb::load(fs, git_dir)
  let result = @lib.fsck_connectivity_check(db, fs, [commit_id])
  assert_true(result.errors > 0)
  assert_true(result.missing.contains(fake_tree_hex))
}

///|
test "fsck_enumerate_objects lists all" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  fs.mkdir_p(git_dir)
  fs.mkdir_p(git_dir + "/objects")
  for i in 0..<3 {
    let (id, data) = @bit.create_blob_string("content \{i}\n")
    @lib.write_object_bytes(fs, git_dir, id, data)
  }
  let db = @lib.ObjectDb::load(fs, git_dir)
  let all = @lib.fsck_enumerate_objects(db)
  assert_eq(all.length(), 3)
}

///|
test "fsck_verify_loose_hash valid" {
  let content = b"hello\n"
  // Build raw loose object: "blob 6\0hello\n"
  let header_str = "blob 6"
  let header_parts : Array[Byte] = []
  for i in 0..<header_str.length() {
    header_parts.push(header_str.unsafe_get(i).to_int().to_byte())
  }
  header_parts.push(b'\x00') // NUL separator
  let raw = Bytes::from_array(
    FixedArray::makei(header_parts.length() + content.length(), fn(i) {
      if i < header_parts.length() {
        header_parts[i]
      } else {
        content[i - header_parts.length()]
      }
    }),
  )
  let expected = @bit.sha1(raw)
  assert_true(@lib.fsck_verify_loose_hash(raw, expected.to_hex()))
  assert_true(
    not(
      @lib.fsck_verify_loose_hash(
        raw,
        "0000000000000000000000000000000000000000",
      ),
    ),
  )
}
