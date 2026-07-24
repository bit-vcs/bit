///| Reproduction test for issue #155: checkout_commit_to_fs left stale files

///| when reusing a checkout root for a second commit.

///|
test "checkout_commit_to_fs removes paths absent from the new tree" {
  let store = ObjectStore::new()
  let kept_blob = @utf8.encode("kept\n")
  let kept_id = @object.hash_object_content(@object.ObjectType::Blob, kept_blob)
  let kept_obj = @object.PackObject::new(@object.ObjectType::Blob, kept_blob)
  let removed_blob = @utf8.encode("removed\n")
  let removed_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    removed_blob,
  )
  let removed_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    removed_blob,
  )
  let tree_v1_entries = [
    @object.TreeEntry::new("100644", "kept.txt", kept_id),
    @object.TreeEntry::new("100644", "removed.txt", removed_id),
  ]
  let tree_v1_raw = @object.serialize_tree(tree_v1_entries)
  let tree_v1_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    tree_v1_raw,
  )
  let tree_v1_obj = @object.PackObject::new(
    @object.ObjectType::Tree,
    tree_v1_raw,
  )
  let commit_v1 = @object.Commit::new(
    tree_v1_id,
    [],
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "v1\n",
  )
  let commit_v1_raw = @object.serialize_commit_content(commit_v1)
  let commit_v1_id = @object.hash_object_content(
    @object.ObjectType::Commit,
    commit_v1_raw,
  )
  let commit_v1_obj = @object.PackObject::new(
    @object.ObjectType::Commit,
    commit_v1_raw,
  )
  let tree_v2_entries = [@object.TreeEntry::new("100644", "kept.txt", kept_id)]
  let tree_v2_raw = @object.serialize_tree(tree_v2_entries)
  let tree_v2_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    tree_v2_raw,
  )
  let tree_v2_obj = @object.PackObject::new(
    @object.ObjectType::Tree,
    tree_v2_raw,
  )
  let commit_v2 = @object.Commit::new(
    tree_v2_id,
    [commit_v1_id],
    "Test <test@example.com>",
    1700000100L,
    "+0000",
    "Test <test@example.com>",
    1700000100L,
    "+0000",
    "v2\n",
  )
  let commit_v2_raw = @object.serialize_commit_content(commit_v2)
  let commit_v2_id = @object.hash_object_content(
    @object.ObjectType::Commit,
    commit_v2_raw,
  )
  let commit_v2_obj = @object.PackObject::new(
    @object.ObjectType::Commit,
    commit_v2_raw,
  )
  store.add_objects([
    kept_obj, removed_obj, tree_v1_obj, commit_v1_obj, tree_v2_obj, commit_v2_obj,
  ])
  let fs = @io.TestFs::new()
  checkout_commit_to_fs(store, commit_v1_id, fs, "/repo", fs) catch {
    err => fail("checkout v1 failed: \{err}")
  }
  assert_true(fs.exists("/repo/kept.txt"))
  assert_true(fs.exists("/repo/removed.txt"))
  checkout_commit_to_fs(store, commit_v2_id, fs, "/repo", fs) catch {
    err => fail("checkout v2 failed: \{err}")
  }
  assert_true(fs.exists("/repo/kept.txt"))
  assert_false(fs.exists("/repo/removed.txt"))
}

///|
test "checkout_commit_to_fs removes stale nested directories" {
  let store = ObjectStore::new()
  let kept_blob = @utf8.encode("kept\n")
  let kept_id = @object.hash_object_content(@object.ObjectType::Blob, kept_blob)
  let kept_obj = @object.PackObject::new(@object.ObjectType::Blob, kept_blob)
  let nested_blob = @utf8.encode("nested\n")
  let nested_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    nested_blob,
  )
  let nested_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    nested_blob,
  )
  let sub_tree_entries = [
    @object.TreeEntry::new("100644", "nested.txt", nested_id),
  ]
  let sub_tree_raw = @object.serialize_tree(sub_tree_entries)
  let sub_tree_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    sub_tree_raw,
  )
  let sub_tree_obj = @object.PackObject::new(
    @object.ObjectType::Tree,
    sub_tree_raw,
  )
  let tree_v1_entries = [
    @object.TreeEntry::new("100644", "kept.txt", kept_id),
    @object.TreeEntry::new("40000", "dir", sub_tree_id),
  ]
  let tree_v1_raw = @object.serialize_tree(tree_v1_entries)
  let tree_v1_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    tree_v1_raw,
  )
  let tree_v1_obj = @object.PackObject::new(
    @object.ObjectType::Tree,
    tree_v1_raw,
  )
  let commit_v1 = @object.Commit::new(
    tree_v1_id,
    [],
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "v1\n",
  )
  let commit_v1_raw = @object.serialize_commit_content(commit_v1)
  let commit_v1_id = @object.hash_object_content(
    @object.ObjectType::Commit,
    commit_v1_raw,
  )
  let commit_v1_obj = @object.PackObject::new(
    @object.ObjectType::Commit,
    commit_v1_raw,
  )
  let tree_v2_entries = [@object.TreeEntry::new("100644", "kept.txt", kept_id)]
  let tree_v2_raw = @object.serialize_tree(tree_v2_entries)
  let tree_v2_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    tree_v2_raw,
  )
  let tree_v2_obj = @object.PackObject::new(
    @object.ObjectType::Tree,
    tree_v2_raw,
  )
  let commit_v2 = @object.Commit::new(
    tree_v2_id,
    [commit_v1_id],
    "Test <test@example.com>",
    1700000100L,
    "+0000",
    "Test <test@example.com>",
    1700000100L,
    "+0000",
    "v2\n",
  )
  let commit_v2_raw = @object.serialize_commit_content(commit_v2)
  let commit_v2_id = @object.hash_object_content(
    @object.ObjectType::Commit,
    commit_v2_raw,
  )
  let commit_v2_obj = @object.PackObject::new(
    @object.ObjectType::Commit,
    commit_v2_raw,
  )
  store.add_objects([
    kept_obj, nested_obj, sub_tree_obj, tree_v1_obj, commit_v1_obj, tree_v2_obj,
    commit_v2_obj,
  ])
  let fs = @io.TestFs::new()
  checkout_commit_to_fs(store, commit_v1_id, fs, "/repo", fs) catch {
    err => fail("checkout v1 failed: \{err}")
  }
  assert_true(fs.exists("/repo/dir/nested.txt"))
  checkout_commit_to_fs(store, commit_v2_id, fs, "/repo", fs) catch {
    err => fail("checkout v2 failed: \{err}")
  }
  assert_true(fs.exists("/repo/kept.txt"))
  assert_false(fs.exists("/repo/dir/nested.txt"))
  assert_false(fs.is_dir("/repo/dir"))
}
