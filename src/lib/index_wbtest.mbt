///|
test "index: read_index_entries accepts version 3 headers" {
  let fs = @git.TestFs::new()
  init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "hello\n")
  add_paths(fs, fs, "/repo", ["a.txt"])

  let index_path = "/repo/.git/index"
  let data = fs.read_file(index_path)
  let patched = Bytes::from_array(
    FixedArray::makei(data.length(), fn(i) {
      if i == 7 {
        b'\x03'
      } else {
        data[i]
      }
    }),
  )
  fs.write_file(index_path, patched)

  let entries = read_index_entries(fs, "/repo/.git")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].path, "a.txt")
}

///|
test "index: read_skip_worktree_paths reads extended skip-worktree flag" {
  let fs = @git.TestFs::new()
  init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "hello\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  index_test_mark_single_entry_skip_worktree(fs, "/repo/.git/index")

  let skip = read_skip_worktree_paths(fs, "/repo/.git")
  assert_true(skip.contains("a.txt"))

  let entries = read_index_entries(fs, "/repo/.git")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].path, "a.txt")
}

///|
test "index: write_skip_worktree_paths marks extended flag entries" {
  let fs = @git.TestFs::new()
  init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "hello\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  let entries = read_index_entries(fs, "/repo/.git")
  let skip_set : Map[String, Bool] = { "a.txt": true }
  write_skip_worktree_paths(fs, "/repo/.git", ["a.txt"])
  write_index_entries_with_skip_worktree(fs, "/repo/.git", entries, skip_set)
  let skip = read_skip_worktree_paths(fs, "/repo/.git")
  assert_true(skip.contains("a.txt"))
}

///|
fn index_test_mark_single_entry_skip_worktree(
  fs : @git.TestFs,
  index_path : String,
) -> Unit {
  let data = fs.read_file(index_path) catch { _ => Bytes::default() }
  let arr : Array[Byte] = []
  for b in data {
    arr.push(b)
  }
  // entry_start = 12, flags offset = entry_start + 60
  let flags_offset = 72
  arr[flags_offset] = (arr[flags_offset].to_int() | 0x40).to_byte()

  // Rewrite [ext_flags][path...NUL][padding] in-place.
  // For a.txt (len=5), old/new entry sizes are both 72 bytes.
  let path_start = 74
  let path_with_nul : Array[Byte] = []
  let mut i = path_start
  while i < arr.length() && arr[i] != b'\x00' {
    path_with_nul.push(arr[i])
    i += 1
  }
  path_with_nul.push(b'\x00')

  arr[path_start] = b'\x40'
  arr[path_start + 1] = b'\x00'
  for j in 0..<path_with_nul.length() {
    arr[path_start + 2 + j] = path_with_nul[j]
  }
  let entry_end = 84
  let mut k = path_start + 2 + path_with_nul.length()
  while k < entry_end {
    arr[k] = b'\x00'
    k += 1
  }

  let patched = Bytes::from_array(
    FixedArray::makei(arr.length(), fn(i) { arr[i] }),
  )
  fs.write_file(index_path, patched)
}
