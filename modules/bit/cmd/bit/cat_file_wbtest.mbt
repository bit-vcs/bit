///|
fn cat_file_wbtest_setup_sha256_compat_repo(root : String) -> OsFs raise Error {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  cleanup_tree(fs, root)
  fs.mkdir_p(root + "/.git/objects")
  fs.write_string(
    root + "/.git/config",
    "[extensions]\n\tobjectformat = sha256\n\tcompatobjectformat = sha1\n",
  )
  fs
}

///|
fn cat_file_wbtest_assert_bytes_equal(
  actual : Bytes,
  expected : Bytes,
) -> Unit raise Error {
  if !Bytes::equal(actual, expected) {
    fail("expected converted bytes to match compat object bytes")
  }
}

///|
test "cat-file: compat sha1 tree raw bytes rewrite entry ids" {
  let root = "/tmp/bit-cat-file-tree-compat-" +
    get_current_timestamp().to_string()
  let fs = cat_file_wbtest_setup_sha256_compat_repo(root)
  let git_dir = root + "/.git"
  let blob = @utf8.encode("hello\n")
  let storage_blob = @bitcore.hash_object_content_with_algo(
    @bitcore.HashAlgorithm::Sha256,
    @bitcore.ObjectType::Blob,
    blob,
  )
  let compat_blob = @bitcore.hash_object_content_with_algo(
    @bitcore.HashAlgorithm::Sha1,
    @bitcore.ObjectType::Blob,
    blob,
  )
  @bitlib.compat_append_loose_object_idx(
    fs, fs, git_dir, storage_blob, compat_blob,
  )
  let storage_tree = @bitcore.serialize_tree([
    @bitcore.TreeEntry::new("100644", "hello", storage_blob),
  ])
  let compat_tree = @bitcore.serialize_tree([
    @bitcore.TreeEntry::new("100644", "hello", compat_blob),
  ])

  let converted = cat_file_convert_object_data_for_display(
    fs,
    git_dir,
    @bitcore.PackObject::new(@bitcore.ObjectType::Tree, storage_tree),
    40,
  )

  cat_file_wbtest_assert_bytes_equal(converted, compat_tree)
  cleanup_tree(fs, root)
}

///|
test "cat-file: compat sha1 commit raw bytes rewrite tree and parent ids" {
  let root = "/tmp/bit-cat-file-commit-compat-" +
    get_current_timestamp().to_string()
  let fs = cat_file_wbtest_setup_sha256_compat_repo(root)
  let git_dir = root + "/.git"
  let blob = @utf8.encode("hello\n")
  let storage_blob = @bitcore.hash_object_content_with_algo(
    @bitcore.HashAlgorithm::Sha256,
    @bitcore.ObjectType::Blob,
    blob,
  )
  let compat_blob = @bitcore.hash_object_content_with_algo(
    @bitcore.HashAlgorithm::Sha1,
    @bitcore.ObjectType::Blob,
    blob,
  )
  let (storage_tree_id, _) = @bitobject.create_tree_with_algo(
    @bitobject.HashAlgorithm::Sha256,
    [@bitcore.TreeEntry::new("100644", "hello", storage_blob)],
  )
  let (compat_tree_id, _) = @bitobject.create_tree_with_algo(
    @bitobject.HashAlgorithm::Sha1,
    [@bitcore.TreeEntry::new("100644", "hello", compat_blob)],
  )
  let storage_parent = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let compat_parent = @bitcore.ObjectId::from_hex(
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  )
  @bitlib.compat_append_loose_object_idx(
    fs, fs, git_dir, storage_blob, compat_blob,
  )
  @bitlib.compat_append_loose_object_idx(
    fs, fs, git_dir, storage_tree_id, compat_tree_id,
  )
  @bitlib.compat_append_loose_object_idx(
    fs, fs, git_dir, storage_parent, compat_parent,
  )
  let storage_commit = @bitcore.Commit::new(
    storage_tree_id,
    [storage_parent],
    "A U Thor <author@example.com>",
    1112354055L,
    "+0200",
    "C O Mitter <committer@example.com>",
    1112354055L,
    "+0200",
    "Initial commit\n",
  )
  let compat_commit = @bitcore.Commit::new(
    compat_tree_id,
    [compat_parent],
    "A U Thor <author@example.com>",
    1112354055L,
    "+0200",
    "C O Mitter <committer@example.com>",
    1112354055L,
    "+0200",
    "Initial commit\n",
  )

  let converted = cat_file_convert_object_data_for_display(
    fs,
    git_dir,
    @bitcore.PackObject::new(
      @bitcore.ObjectType::Commit,
      @bitobject.serialize_commit_content(storage_commit),
    ),
    40,
  )

  cat_file_wbtest_assert_bytes_equal(
    converted,
    @bitobject.serialize_commit_content(compat_commit),
  )
  cleanup_tree(fs, root)
}

///|
test "cat-file: compat sha1 tag raw bytes rewrite object ids" {
  let root = "/tmp/bit-cat-file-tag-compat-" +
    get_current_timestamp().to_string()
  let fs = cat_file_wbtest_setup_sha256_compat_repo(root)
  let git_dir = root + "/.git"
  let storage_target = @bitcore.ObjectId::from_hex(
    "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  )
  let compat_target = @bitcore.ObjectId::from_hex(
    "dddddddddddddddddddddddddddddddddddddddd",
  )
  @bitlib.compat_append_loose_object_idx(
    fs, fs, git_dir, storage_target, compat_target,
  )
  let storage_tag = @utf8.encode(
    "object \{storage_target.to_hex()}\ntype commit\ntag v1\n" +
    "tagger A U Thor <author@example.com> 1112354055 +0200\n\nmessage\n",
  )
  let compat_tag = @utf8.encode(
    "object \{compat_target.to_hex()}\ntype commit\ntag v1\n" +
    "tagger A U Thor <author@example.com> 1112354055 +0200\n\nmessage\n",
  )

  let converted = cat_file_convert_object_data_for_display(
    fs,
    git_dir,
    @bitcore.PackObject::new(@bitcore.ObjectType::Tag, storage_tag),
    40,
  )

  cat_file_wbtest_assert_bytes_equal(converted, compat_tag)
  cleanup_tree(fs, root)
}
