///|
test "component impl: staged head helpers compare head tree and index" {
  let fs = @bit.TestFs::new()
  git_init_with_fs(fs, "/repo", "main")
  fs.write_string("/repo/tracked.txt", "base\n")
  fs.write_string("/repo/delete.txt", "delete me\n")
  add_with_fs(fs, fs, "/repo", ["tracked.txt", "delete.txt"])
  ignore(
    commit_with_fs(
      fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L,
    ),
  )

  fs.write_string("/repo/tracked.txt", "staged\n")
  add_with_fs(fs, fs, "/repo", ["tracked.txt"])
  fs.write_string("/repo/added.txt", "added\n")
  add_with_fs(fs, fs, "/repo", ["added.txt"])
  rm_with_fs(fs, fs, "/repo", ["delete.txt"], false)

  let index_map : Map[String, @bitlib.IndexEntry] = {}
  let entries = @bitlib.read_index_entries(fs, "/repo/.git")
  for entry in entries {
    index_map[entry.path] = entry
  }
  let staged_modified : Array[String] = []
  let staged_deleted : Array[String] = []

  status_collect_staged_head_changes(
    fs, "/repo/.git", index_map, staged_modified, staged_deleted,
  )

  let staged_added : Array[String] = []
  for item in index_map.to_array() {
    let (path, _) = item
    staged_added.push(path)
  }
  staged_added.sort()
  staged_modified.sort()
  staged_deleted.sort()

  assert_eq(staged_added, ["added.txt"])
  assert_eq(staged_modified, ["tracked.txt"])
  assert_eq(staged_deleted, ["delete.txt"])
}
