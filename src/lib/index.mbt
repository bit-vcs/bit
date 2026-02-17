///| Git index (v2/v3) reader/writer

///|
pub struct IndexEntry {
  path : String
  id : @git.ObjectId
  mode : Int
  size : Int
  mtime_sec : Int
  mtime_nsec : Int
}

///|
pub fn IndexEntry::new(
  path : String,
  id : @git.ObjectId,
  mode : Int,
  size : Int,
  mtime_sec? : Int = 0,
  mtime_nsec? : Int = 0,
) -> IndexEntry {
  { path, id, mode, size, mtime_sec, mtime_nsec }
}

///|
pub fn read_index_entries(
  fs : &@git.RepoFileSystem,
  git_dir : String,
) -> Array[IndexEntry] raise @git.GitError {
  let path = join_path(git_dir, "index")
  if not(fs.is_file(path)) {
    return []
  }
  let data = fs.read_file(path)
  if data.length() < 12 + 20 {
    raise @git.GitError::InvalidObject("Index file too short")
  }
  if not(
      data[0] == b'D' && data[1] == b'I' && data[2] == b'R' && data[3] == b'C',
    ) {
    raise @git.GitError::InvalidObject("Invalid index header")
  }
  let version = index_read_u32_be(data, 4)
  if version != 2 && version != 3 {
    raise @git.GitError::InvalidObject("Unsupported index version: \{version}")
  }
  let count = index_read_u32_be(data, 8)
  let mut offset = 12
  let selected : Map[String, (Int, IndexEntry)] = {}
  for _ in 0..<count {
    let entry_start = offset
    if offset + 62 > data.length() {
      raise @git.GitError::InvalidObject("Index entry truncated")
    }
    // Index entry format (40 bytes stat data):
    // ctime_seconds, ctime_nanoseconds, mtime_seconds, mtime_nanoseconds,
    // dev, ino, mode, uid, gid, file_size
    let _ctime_sec = index_read_u32_be(data, offset)
    offset += 4
    let _ctime_nsec = index_read_u32_be(data, offset)
    offset += 4
    let mtime_sec = index_read_u32_be(data, offset)
    offset += 4
    let mtime_nsec = index_read_u32_be(data, offset)
    offset += 4
    offset += 8 // skip dev, ino (2 u32)
    let mode = index_read_u32_be(data, offset)
    offset += 4
    offset += 8 // skip uid, gid (2 u32)
    let size = index_read_u32_be(data, offset)
    offset += 4
    let id = index_read_object_id(data, offset)
    offset += 20
    // flags (u16)
    let flags = index_read_u16_be(data, offset)
    offset += 2
    let stage = (flags >> 12) & 0x3
    // Check extended flag (bit 14) - if set, skip 2 more bytes
    let has_extended = (flags & 0x4000) != 0
    if has_extended {
      offset += 2
    }
    let (path_str, next) = index_read_cstring(data, offset)
    let path_len = path_str.length()
    // Calculate next entry position: entry size must be a multiple of 8
    // Fixed part: 62 bytes (or 64 with extended flags)
    // Variable part: path_len + NUL + padding
    let fixed_size = if has_extended { 64 } else { 62 }
    let entry_size_without_padding = fixed_size + path_len + 1
    let entry_size = (entry_size_without_padding + 7) / 8 * 8
    offset = entry_start + entry_size
    ignore(next)
    let entry = { path: path_str, id, mode, size, mtime_sec, mtime_nsec }
    let prio = index_stage_priority(stage)
    match selected.get(path_str) {
      Some((prev_prio, _)) =>
        if prio > prev_prio {
          selected[path_str] = (prio, entry)
        }
      None => selected[path_str] = (prio, entry)
    }
  }
  let entries : Array[IndexEntry] = []
  for item in selected.to_array() {
    let (_, value) = item
    let (_, entry) = value
    entries.push(entry)
  }
  entries.sort_by((a, b) => index_path_compare_git_order(a.path, b.path))
  entries
}

///|
/// Read skip-worktree paths from both bit sidecar and index extended flags.
pub fn read_skip_worktree_paths(
  fs : &@git.RepoFileSystem,
  git_dir : String,
) -> Map[String, Bool] {
  let out : Map[String, Bool] = {}
  let sidecar_path = join_path(git_dir, "bit-skip-worktree")
  if fs.is_file(sidecar_path) {
    let text = @utf8.decode_lossy(
      (fs.read_file(sidecar_path) catch { _ => Bytes::default() })[:],
    )
    for line_view in text.split("\n") {
      let line = line_view.to_string()
      if line.length() > 0 {
        out[line] = true
      }
    }
  }
  let index_path = join_path(git_dir, "index")
  if not(fs.is_file(index_path)) {
    return out
  }
  let data = fs.read_file(index_path) catch { _ => return out }
  if data.length() < 12 + 20 {
    return out
  }
  if not(
      data[0] == b'D' && data[1] == b'I' && data[2] == b'R' && data[3] == b'C',
    ) {
    return out
  }
  let count = index_read_u32_be(data, 8) catch { _ => return out }
  let mut offset = 12
  for _ in 0..<count {
    if offset + 62 > data.length() {
      return out
    }
    let flags = index_read_u16_be(data, offset + 60) catch { _ => return out }
    let stage = (flags >> 12) & 0x3
    let has_extended = (flags & 0x4000) != 0
    let ext_flags = if has_extended {
      index_read_u16_be(data, offset + 62) catch {
        _ => return out
      }
    } else {
      0
    }
    let fixed_size = if has_extended { 64 } else { 62 }
    let path_start = offset + fixed_size
    let mut i = path_start
    while i < data.length() && data[i] != b'\x00' {
      i += 1
    }
    if i >= data.length() {
      return out
    }
    if stage == 0 && has_extended && (ext_flags & 0x4000) != 0 {
      let path_bytes : Array[Byte] = []
      for j in path_start..<i {
        path_bytes.push(data[j])
      }
      out[index_bytes_to_string(path_bytes)] = true
    }
    let path_len = i - path_start
    let entry_size = (fixed_size + path_len + 1 + 7) / 8 * 8
    offset += entry_size
  }
  out
}

///|
pub fn write_skip_worktree_paths(
  fs : &@git.FileSystem,
  git_dir : String,
  paths : Array[String],
) -> Unit raise @git.GitError {
  let state_path = join_path(git_dir, "bit-skip-worktree")
  let by_path : Map[String, Bool] = {}
  for path in paths {
    if path.length() > 0 {
      by_path[path] = true
    }
  }
  let sorted : Array[String] = []
  for item in by_path.to_array() {
    let (path, _) = item
    sorted.push(path)
  }
  sorted.sort_by((a, b) => String::compare(a, b))
  if sorted.length() == 0 {
    fs.remove_file(state_path) catch {
      _ => ()
    }
    return
  }
  fs.write_string(state_path, sorted.join("\n") + "\n")
}

///|
pub fn write_index_entries(
  fs : &@git.FileSystem,
  git_dir : String,
  entries : Array[IndexEntry],
) -> Unit raise @git.GitError {
  let sorted = entries.copy()
  sorted.sort_by((a, b) => index_path_compare_git_order(a.path, b.path))
  let out : Array[Byte] = []
  // Header: "DIRC" + version(2) + count
  out.push(b'D')
  out.push(b'I')
  out.push(b'R')
  out.push(b'C')
  index_push_u32_be(out, 2)
  index_push_u32_be(out, sorted.length())
  for e in sorted {
    let entry_start = out.length()
    // Index entry format (40 bytes stat data):
    // ctime_seconds, ctime_nanoseconds, mtime_seconds, mtime_nanoseconds,
    // dev, ino, mode, uid, gid, file_size
    index_push_u32_be(out, e.mtime_sec) // ctime_seconds
    index_push_u32_be(out, e.mtime_nsec) // ctime_nanoseconds
    index_push_u32_be(out, e.mtime_sec) // mtime_seconds
    index_push_u32_be(out, e.mtime_nsec) // mtime_nanoseconds
    index_push_u32_be(out, 0) // dev
    index_push_u32_be(out, 0) // ino
    index_push_u32_be(out, e.mode) // mode
    index_push_u32_be(out, 0) // uid
    index_push_u32_be(out, 0) // gid
    index_push_u32_be(out, e.size) // file_size
    // object id
    for b in e.id.bytes {
      out.push(b)
    }
    let name_len = if e.path.length() < 0x0fff {
      e.path.length()
    } else {
      0x0fff
    }
    index_push_u16_be(out, name_len)
    for c in e.path {
      out.push(c.to_int().to_byte())
    }
    out.push(b'\x00')
    // Pad to 8-byte alignment from entry start
    while (out.length() - entry_start) % 8 != 0 {
      out.push(b'\x00')
    }
  }
  let content = index_bytes_from_array(out)
  let checksum = @git.sha1(content)
  for b in checksum.bytes {
    out.push(b)
  }
  let index_bytes = index_bytes_from_array(out)
  let index_path = join_path(git_dir, "index")
  fs.write_file(index_path, index_bytes)
}

///|
fn index_read_u32_be(data : Bytes, start : Int) -> Int raise @git.GitError {
  if start < 0 || start + 4 > data.length() {
    raise @git.GitError::InvalidObject("Unexpected end of index data")
  }
  (data[start].to_int() << 24) |
  (data[start + 1].to_int() << 16) |
  (data[start + 2].to_int() << 8) |
  data[start + 3].to_int()
}

///|
fn index_read_u16_be(data : Bytes, start : Int) -> Int raise @git.GitError {
  if start < 0 || start + 2 > data.length() {
    raise @git.GitError::InvalidObject("Unexpected end of index data")
  }
  (data[start].to_int() << 8) | data[start + 1].to_int()
}

///|
pub fn write_index_entries_with_skip_worktree(
  fs : &@git.FileSystem,
  git_dir : String,
  entries : Array[IndexEntry],
  skip_worktree_paths : Map[String, Bool],
) -> Unit raise @git.GitError {
  let sorted = entries.copy()
  sorted.sort_by((a, b) => index_path_compare_git_order(a.path, b.path))
  let out : Array[Byte] = []
  // Header: "DIRC" + version(2) + count
  out.push(b'D')
  out.push(b'I')
  out.push(b'R')
  out.push(b'C')
  index_push_u32_be(out, 2)
  index_push_u32_be(out, sorted.length())
  for e in sorted {
    let entry_start = out.length()
    // Index entry format (40 bytes stat data):
    // ctime_seconds, ctime_nanoseconds, mtime_seconds, mtime_nanoseconds,
    // dev, ino, mode, uid, gid, file_size
    index_push_u32_be(out, e.mtime_sec) // ctime_seconds
    index_push_u32_be(out, e.mtime_nsec) // ctime_nanoseconds
    index_push_u32_be(out, e.mtime_sec) // mtime_seconds
    index_push_u32_be(out, e.mtime_nsec) // mtime_nanoseconds
    index_push_u32_be(out, 0) // dev
    index_push_u32_be(out, 0) // ino
    index_push_u32_be(out, e.mode) // mode
    index_push_u32_be(out, 0) // uid
    index_push_u32_be(out, 0) // gid
    index_push_u32_be(out, e.size) // file_size
    // object id
    for b in e.id.bytes {
      out.push(b)
    }
    let name_len = if e.path.length() < 0x0fff {
      e.path.length()
    } else {
      0x0fff
    }
    let is_skip = skip_worktree_paths.contains(e.path)
    let mut flags = name_len
    if is_skip {
      flags = flags | 0x4000
    }
    index_push_u16_be(out, flags)
    if is_skip {
      index_push_u16_be(out, 0x4000)
    }
    for c in e.path {
      out.push(c.to_int().to_byte())
    }
    out.push(b'\x00')
    while (out.length() - entry_start) % 8 != 0 {
      out.push(b'\x00')
    }
  }
  let content = index_bytes_from_array(out)
  let checksum = @git.sha1(content)
  for b in checksum.bytes {
    out.push(b)
  }
  let index_bytes = index_bytes_from_array(out)
  let index_path = join_path(git_dir, "index")
  fs.write_file(index_path, index_bytes)
}

///|
fn index_read_object_id(
  data : Bytes,
  start : Int,
) -> @git.ObjectId raise @git.GitError {
  if start + 20 > data.length() {
    raise @git.GitError::InvalidObject("Unexpected end of index data")
  }
  let bytes : FixedArray[Byte] = FixedArray::make(20, b'\x00')
  for i in 0..<20 {
    bytes[i] = data[start + i]
  }
  @git.ObjectId::new(bytes)
}

///|
fn index_read_cstring(
  data : Bytes,
  start : Int,
) -> (String, Int) raise @git.GitError {
  let mut i = start
  while i < data.length() && data[i] != b'\x00' {
    i += 1
  }
  if i >= data.length() {
    raise @git.GitError::InvalidObject("Missing NUL in index entry")
  }
  let bytes : Array[Byte] = []
  for j in start..<i {
    bytes.push(data[j])
  }
  let s = index_bytes_to_string(bytes)
  (s, i + 1)
}

///|
fn index_bytes_to_string(bytes : Array[Byte]) -> String {
  let sb = StringBuilder::new()
  for b in bytes {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
fn index_bytes_from_array(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), i => arr[i]))
}

///|
fn index_push_u32_be(out : Array[Byte], v : Int) -> Unit {
  out.push(((v >> 24) & 0xff).to_byte())
  out.push(((v >> 16) & 0xff).to_byte())
  out.push(((v >> 8) & 0xff).to_byte())
  out.push((v & 0xff).to_byte())
}

///|
fn index_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  out.push(((v >> 8) & 0xff).to_byte())
  out.push((v & 0xff).to_byte())
}

///|
fn index_path_compare_git_order(a : String, b : String) -> Int {
  let a_chars = a.to_array()
  let b_chars = b.to_array()
  let mut i = 0
  while i < a_chars.length() && i < b_chars.length() {
    let av = a_chars[i].to_int()
    let bv = b_chars[i].to_int()
    if av < bv {
      return -1
    }
    if av > bv {
      return 1
    }
    i += 1
  }
  if a_chars.length() < b_chars.length() {
    -1
  } else if a_chars.length() > b_chars.length() {
    1
  } else {
    0
  }
}

///|
fn index_stage_priority(stage : Int) -> Int {
  if stage == 0 {
    4
  } else if stage == 2 {
    3
  } else if stage == 1 {
    2
  } else {
    1
  }
}
