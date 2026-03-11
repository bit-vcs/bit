///|
test "index: read_index_entries accepts version 3 headers" {
  let fs = @bit.TestFs::new()
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
  let fs = @bit.TestFs::new()
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
  let fs = @bit.TestFs::new()
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
test "index: read_index_entries preserves intent-to-add entries" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo")
  let empty = @bit.ObjectId::from_hex(
    "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
  )
  let entries = [
    IndexEntry::new("file", empty, 0o100644, 0, intent_to_add=true),
  ]
  write_index_entries(fs, "/repo/.git", entries)

  let actual = read_index_entries(fs, "/repo/.git")
  assert_eq(actual.length(), 1)
  assert_eq(actual[0].path, "file")
  assert_true(actual[0].intent_to_add)
  assert_eq(actual[0].id.to_hex(), empty.to_hex())
}

///|
test "index: read_index_stage_entries preserves unmerged stages" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "hello\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  index_test_replace_single_entry_with_stages(fs, "/repo/.git/index", [1, 2, 3])

  let actual = read_index_stage_entries(fs, "/repo/.git")
  assert_eq(actual.length(), 3)
  assert_eq(actual[0].entry.path, "a.txt")
  assert_eq(actual[0].stage, 1)
  assert_eq(actual[1].stage, 2)
  assert_eq(actual[2].stage, 3)
}

///|
fn index_test_mark_single_entry_skip_worktree(
  fs : @bit.TestFs,
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

///|
fn index_test_replace_single_entry_with_stages(
  fs : @bit.TestFs,
  index_path : String,
  stages : Array[Int],
) -> Unit {
  let data = fs.read_file(index_path) catch { _ => Bytes::default() }
  let arr : Array[Byte] = []
  for b in data {
    arr.push(b)
  }
  let checksum_start = arr.length() - 20
  let entry : Array[Byte] = []
  for i in 12..<checksum_start {
    entry.push(arr[i])
  }
  let body : Array[Byte] = []
  for stage in stages {
    let copied : Array[Byte] = []
    for b in entry {
      copied.push(b)
    }
    let flags_offset = 60
    let flags_hi = copied[flags_offset].to_int()
    let flags_lo = copied[flags_offset + 1].to_int()
    let flags = (((flags_hi << 8) | flags_lo) & 0xCFFF) | (stage << 12)
    copied[flags_offset] = (flags >> 8).to_byte()
    copied[flags_offset + 1] = (flags & 0xFF).to_byte()
    body.append(copied)
  }
  let patched : Array[Byte] = []
  for i in 0..<12 {
    patched.push(arr[i])
  }
  let count = stages.length()
  patched[8] = ((count >> 24) & 0xFF).to_byte()
  patched[9] = ((count >> 16) & 0xFF).to_byte()
  patched[10] = ((count >> 8) & 0xFF).to_byte()
  patched[11] = (count & 0xFF).to_byte()
  patched.append(body)
  for _ in 0..<20 {
    patched.push(b'\x00')
  }
  fs.write_file(
    index_path,
    Bytes::from_array(FixedArray::makei(patched.length(), fn(i) { patched[i] })),
  )
}
