///|
fn rm_wbtest_entry(path : String) -> @gitlib.IndexEntry {
  let zero = @git.ObjectId::new(FixedArray::make(20, b'\x00'))
  @gitlib.IndexEntry::new(path, zero, 0o100644, 0)
}

///|
test "rm pathspec: dot matches repository root entries" {
  let entries = [rm_wbtest_entry("a.txt"), rm_wbtest_entry("dir/b.txt")]
  assert_true(rm_pathspec_matches_any(".", entries, true))
  assert_true(rm_pathspec_matches_any("./", entries, true))
}

///|
test "rm collect target paths: dot expands to all index entries" {
  let entries = [rm_wbtest_entry("a.txt"), rm_wbtest_entry("dir/b.txt")]
  let removed = rm_collect_target_paths(["."], entries, true)
  assert_eq(removed.length(), 2)
  assert_true(removed.contains("a.txt"))
  assert_true(removed.contains("dir/b.txt"))
}
