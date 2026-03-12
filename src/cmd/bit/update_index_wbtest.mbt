///|
test "update-index: normalize_update_index_path rejects traversal paths" {
  let bad_paths : Array[String] = ["..", "../a.txt", "/a.txt", "a/../../b.txt"]
  for p in bad_paths {
    assert_true(update_index_path_is_rejected(p))
  }
}

///|
fn update_index_path_is_rejected(path : String) -> Bool {
  let _ = normalize_update_index_path(path) catch { _ => return true }
  false
}

///|
test "update-index: parse_update_index_cacheinfo rejects bad paths" {
  let (blob_id, _) = @bitcore.create_blob_string("cacheinfo")
  assert_true(
    parse_update_index_cacheinfo("100644", blob_id.to_hex(), "../a.txt") is None,
  )
}

///|
test "update-index: parse_update_index_info_line rejects bad paths" {
  let (blob_id, _) = @bitcore.create_blob_string("info line")
  let line = "100644 " + blob_id.to_hex() + "\t../a.txt"
  assert_true(parse_update_index_info_line(line) is None)
}

///|
test "update-index: parse_update_index_version accepts supported values" {
  assert_eq(parse_update_index_version("2"), Some(2))
  assert_eq(parse_update_index_version("3"), Some(3))
  assert_eq(parse_update_index_version("4"), Some(4))
  assert_eq(parse_update_index_version("1"), None)
}

///|
test "update-index: update_index_entry_is_racy matches index mtime" {
  let (blob_id, _) = @bitcore.create_blob_string("racy")
  let entry = @bitlib.IndexEntry::new(
    "file",
    blob_id,
    0o100644,
    4,
    mtime_sec=123,
    mtime_nsec=456,
  )
  assert_true(update_index_entry_is_racy(entry, Some((123, 456))))
  assert_false(update_index_entry_is_racy(entry, Some((123, 457))))
  assert_false(update_index_entry_is_racy(entry, None))
}

///|
test "update-index: preserve symlink mode when restaging existing entry" {
  let (blob_id, _) = @bitcore.create_blob_string("target")
  let before = [@bitlib.IndexEntry::new("symlink", blob_id, 0o120000, 6)]
  let after = [@bitlib.IndexEntry::new("symlink", blob_id, 0o100644, 6)]
  let preserved = update_index_preserve_existing_symlink_modes(before, after)
  assert_eq(preserved.length(), 1)
  assert_eq(preserved[0].mode, 0o120000)
}
