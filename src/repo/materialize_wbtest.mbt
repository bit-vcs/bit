///| Reproduction test for hq clone index ordering bug.

///|
test "write_index_v2 writes Git lexical path order" {
  let (store, commit_id) = build_commit_for_index_order_wbtest()
  let fs = @io.TestFs::new()
  write_index_v2(store, fs, "/repo/.git", commit_id) catch {
    err => fail("write_index_v2 failed: \{err}")
  }
  let index_bytes = fs.read_file("/repo/.git/index") catch {
    err => fail("failed to read index: \{err}")
  }
  let paths = parse_index_paths_wbtest(index_bytes)
  let expected = paths.copy()
  expected.sort_by((a, b) => String::lexical_compare(a, b))
  assert_eq(paths, expected)
}

///|
test "write_index_v2 keeps lexical order for prefix-like paths" {
  let (store, commit_id) = build_commit_for_prefix_like_paths_wbtest()
  let fs = @io.TestFs::new()
  write_index_v2(store, fs, "/repo/.git", commit_id) catch {
    err => fail("write_index_v2 failed: \{err}")
  }
  let index_bytes = fs.read_file("/repo/.git/index") catch {
    err => fail("failed to read index: \{err}")
  }
  let paths = parse_index_paths_wbtest(index_bytes)
  assert_eq(paths, ["a-y", "a.b", "a.y", "a/z", "a0"])
}

///|
fn build_commit_for_index_order_wbtest() -> (ObjectStore, @object.ObjectId) {
  let store = ObjectStore::new()

  let dot_gitignore_blob = @utf8.encode("# ignore\n")
  let dot_gitignore_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    dot_gitignore_blob,
  )
  let dot_gitignore_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    dot_gitignore_blob,
  )

  let settings_blob = @utf8.encode("{\"v\":1}\n")
  let settings_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    settings_blob,
  )
  let settings_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    settings_blob,
  )

  let nvmrc_blob = @utf8.encode("20\n")
  let nvmrc_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    nvmrc_blob,
  )
  let nvmrc_obj = @object.PackObject::new(@object.ObjectType::Blob, nvmrc_blob)

  let license_blob = @utf8.encode("MIT\n")
  let license_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    license_blob,
  )
  let license_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    license_blob,
  )

  let readme_blob = @utf8.encode("docs\n")
  let readme_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    readme_blob,
  )
  let readme_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    readme_blob,
  )

  let entire_entries = [
    @object.TreeEntry::new("100644", ".gitignore", dot_gitignore_id),
    @object.TreeEntry::new("100644", "settings.json", settings_id),
  ]
  let entire_tree_raw = @object.serialize_tree(entire_entries)
  let entire_tree_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    entire_tree_raw,
  )
  let entire_tree_obj = @object.PackObject::new(
    @object.ObjectType::Tree,
    entire_tree_raw,
  )

  let data_entries = [@object.TreeEntry::new("100644", "README.md", readme_id)]
  let data_tree_raw = @object.serialize_tree(data_entries)
  let data_tree_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    data_tree_raw,
  )
  let data_tree_obj = @object.PackObject::new(
    @object.ObjectType::Tree,
    data_tree_raw,
  )

  let root_entries = [
    @object.TreeEntry::new("40000", ".entire", entire_tree_id),
    @object.TreeEntry::new("100644", ".gitignore", dot_gitignore_id),
    @object.TreeEntry::new("100644", ".nvmrc", nvmrc_id),
    @object.TreeEntry::new("100644", "LICENSE", license_id),
    @object.TreeEntry::new("40000", "data", data_tree_id),
  ]
  let root_tree_raw = @object.serialize_tree(root_entries)
  let root_tree_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    root_tree_raw,
  )
  let root_tree_obj = @object.PackObject::new(
    @object.ObjectType::Tree,
    root_tree_raw,
  )

  let commit = @object.Commit::new(
    root_tree_id,
    [],
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "index order repro\n",
  )
  let commit_raw = @object.serialize_commit_content(commit)
  let commit_id = @object.hash_object_content(
    @object.ObjectType::Commit,
    commit_raw,
  )
  let commit_obj = @object.PackObject::new(
    @object.ObjectType::Commit,
    commit_raw,
  )

  store.add_objects([
    dot_gitignore_obj, settings_obj, nvmrc_obj, license_obj, readme_obj, entire_tree_obj,
    data_tree_obj, root_tree_obj, commit_obj,
  ])

  (store, commit_id)
}

///|
fn build_commit_for_prefix_like_paths_wbtest() -> (
  ObjectStore,
  @object.ObjectId,
) {
  let store = ObjectStore::new()

  let a_dash_blob = @utf8.encode("a-y\n")
  let a_dash_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    a_dash_blob,
  )
  let a_dash_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    a_dash_blob,
  )

  let a_dot_b_blob = @utf8.encode("a.b\n")
  let a_dot_b_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    a_dot_b_blob,
  )
  let a_dot_b_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    a_dot_b_blob,
  )

  let a_dot_y_blob = @utf8.encode("a.y\n")
  let a_dot_y_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    a_dot_y_blob,
  )
  let a_dot_y_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    a_dot_y_blob,
  )

  let a0_blob = @utf8.encode("a0\n")
  let a0_id = @object.hash_object_content(@object.ObjectType::Blob, a0_blob)
  let a0_obj = @object.PackObject::new(@object.ObjectType::Blob, a0_blob)

  let a_slash_z_blob = @utf8.encode("a/z\n")
  let a_slash_z_id = @object.hash_object_content(
    @object.ObjectType::Blob,
    a_slash_z_blob,
  )
  let a_slash_z_obj = @object.PackObject::new(
    @object.ObjectType::Blob,
    a_slash_z_blob,
  )

  let a_tree_entries = [@object.TreeEntry::new("100644", "z", a_slash_z_id)]
  let a_tree_raw = @object.serialize_tree(a_tree_entries)
  let a_tree_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    a_tree_raw,
  )
  let a_tree_obj = @object.PackObject::new(@object.ObjectType::Tree, a_tree_raw)

  let root_entries = [
    @object.TreeEntry::new("40000", "a", a_tree_id),
    @object.TreeEntry::new("100644", "a-y", a_dash_id),
    @object.TreeEntry::new("100644", "a.b", a_dot_b_id),
    @object.TreeEntry::new("100644", "a.y", a_dot_y_id),
    @object.TreeEntry::new("100644", "a0", a0_id),
  ]
  let root_tree_raw = @object.serialize_tree(root_entries)
  let root_tree_id = @object.hash_object_content(
    @object.ObjectType::Tree,
    root_tree_raw,
  )
  let root_tree_obj = @object.PackObject::new(
    @object.ObjectType::Tree,
    root_tree_raw,
  )

  let commit = @object.Commit::new(
    root_tree_id,
    [],
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "prefix-like index order repro\n",
  )
  let commit_raw = @object.serialize_commit_content(commit)
  let commit_id = @object.hash_object_content(
    @object.ObjectType::Commit,
    commit_raw,
  )
  let commit_obj = @object.PackObject::new(
    @object.ObjectType::Commit,
    commit_raw,
  )

  store.add_objects([
    a_dash_obj, a_dot_b_obj, a_dot_y_obj, a0_obj, a_slash_z_obj, a_tree_obj, root_tree_obj,
    commit_obj,
  ])
  (store, commit_id)
}

///|
fn parse_index_paths_wbtest(index : Bytes) -> Array[String] {
  let count = read_u32_be_wbtest(index, 8)
  let mut pos = 12
  let paths : Array[String] = []
  for _ in 0..<count {
    let entry_start = pos
    let name_start = pos + 62
    pos = name_start
    while pos < index.length() && index[pos] != b'\x00' {
      pos += 1
    }
    paths.push(bytes_to_string_wbtest(index, name_start, pos))
    pos += 1
    while (pos - entry_start) % 8 != 0 {
      pos += 1
    }
  }
  paths
}

///|
fn read_u32_be_wbtest(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn bytes_to_string_wbtest(data : Bytes, start : Int, end : Int) -> String {
  let bytes = FixedArray::makei(end - start, i => data[start + i])
  @utf8.decode_lossy(Bytes::from_array(bytes)[:])
}
