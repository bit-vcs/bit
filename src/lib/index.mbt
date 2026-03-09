///| Git index (v2/v3) reader/writer

///|
pub struct IndexEntry {
  path : String
  id : @bit.ObjectId
  mode : Int
  size : Int
  mtime_sec : Int
  mtime_nsec : Int
  intent_to_add : Bool
  dev : Int
  ino : Int
  uid : Int
  gid : Int
}

///|
pub fn IndexEntry::new(
  path : String,
  id : @bit.ObjectId,
  mode : Int,
  size : Int,
  mtime_sec? : Int = 0,
  mtime_nsec? : Int = 0,
  intent_to_add? : Bool = false,
  dev? : Int = 0,
  ino? : Int = 0,
  uid? : Int = 0,
  gid? : Int = 0,
) -> IndexEntry {
  {
    path,
    id,
    mode,
    size,
    mtime_sec,
    mtime_nsec,
    intent_to_add,
    dev,
    ino,
    uid,
    gid,
  }
}

///|
pub fn read_index_entries(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
) -> Array[IndexEntry] raise @bit.GitError {
  let path = join_path(git_dir, "index")
  if not(fs.is_file(path)) {
    return []
  }
  let data = fs.read_file(path)
  if data.length() < 12 + 20 {
    raise @bit.GitError::InvalidObject("Index file too short")
  }
  if not(
      data[0] == b'D' && data[1] == b'I' && data[2] == b'R' && data[3] == b'C',
    ) {
    raise @bit.GitError::InvalidObject("Invalid index header")
  }
  let version = index_read_u32_be(data, 4)
  if version != 2 && version != 3 {
    raise @bit.GitError::InvalidObject("Unsupported index version: \{version}")
  }
  let count = index_read_u32_be(data, 8)
  let mut offset = 12
  // Fast path: parse directly into sorted array when no conflict stages.
  // Index file entries are already sorted, so no re-sort needed.
  let entries : Array[IndexEntry] = Array::new(capacity=count)
  let stages : Array[Int] = Array::new(capacity=count)
  let mut has_conflicts = false
  for _ in 0..<count {
    let entry_start = offset
    if offset + 62 > data.length() {
      raise @bit.GitError::InvalidObject("Index entry truncated")
    }
    // Index entry format (40 bytes stat data):
    // ctime_seconds, ctime_nanoseconds, mtime_seconds, mtime_nanoseconds,
    // dev, ino, mode, uid, gid, file_size
    offset += 8 // skip ctime_sec, ctime_nsec
    let mtime_sec = index_read_u32_be(data, offset)
    offset += 4
    let mtime_nsec = index_read_u32_be(data, offset)
    offset += 4
    let dev = index_read_u32_be(data, offset)
    offset += 4
    let ino = index_read_u32_be(data, offset)
    offset += 4
    let mode = index_read_u32_be(data, offset)
    offset += 4
    let uid = index_read_u32_be(data, offset)
    offset += 4
    let gid = index_read_u32_be(data, offset)
    offset += 4
    let size = index_read_u32_be(data, offset)
    offset += 4
    let id = index_read_object_id(data, offset)
    offset += 20
    // flags (u16)
    let flags = index_read_u16_be(data, offset)
    offset += 2
    let stage = (flags >> 12) & 0x3
    let has_extended = (flags & 0x4000) != 0
    let ext_flags = if has_extended {
      index_read_u16_be(data, offset)
    } else {
      0
    }
    if has_extended {
      offset += 2
    }
    // Read path directly from bytes (avoid intermediate Array[Byte] + StringBuilder)
    let fixed_size = if has_extended { 64 } else { 62 }
    let path_start = entry_start + fixed_size
    let mut path_end = path_start
    while path_end < data.length() && data[path_end] != b'\x00' {
      path_end += 1
    }
    let path_str = @utf8.decode_lossy(data[path_start:path_end])
    let path_len = path_end - path_start
    let entry_size = (fixed_size + path_len + 1 + 7) / 8 * 8
    offset = entry_start + entry_size
    if stage != 0 {
      has_conflicts = true
    }
    entries.push({
      path: path_str,
      id,
      mode,
      size,
      mtime_sec,
      mtime_nsec,
      intent_to_add: index_ext_flags_has_intent_to_add(ext_flags),
      dev,
      ino,
      uid,
      gid,
    })
    stages.push(stage)
  }
  if has_conflicts {
    // Slow path: deduplicate by stage priority
    let selected : Map[String, (Int, IndexEntry)] = {}
    for i in 0..<entries.length() {
      let prio = index_stage_priority(stages[i])
      let entry = entries[i]
      match selected.get(entry.path) {
        Some((prev_prio, _)) =>
          if prio > prev_prio {
            selected[entry.path] = (prio, entry)
          }
        None => selected[entry.path] = (prio, entry)
      }
    }
    let deduped : Array[IndexEntry] = []
    for item in selected.to_array() {
      let (_, value) = item
      let (_, entry) = value
      deduped.push(entry)
    }
    deduped.sort_by((a, b) => index_path_compare_git_order(a.path, b.path))
    deduped
  } else {
    entries
  }
}

///|
/// Read skip-worktree paths from both bit sidecar and index extended flags.
pub fn read_skip_worktree_paths(
  fs : &@bit.RepoFileSystem,
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
      out[@utf8.decode_lossy(data[path_start:i])] = true
    }
    let path_len = i - path_start
    let entry_size = (fixed_size + path_len + 1 + 7) / 8 * 8
    offset += entry_size
  }
  out
}

///|
pub fn read_unmerged_paths(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
) -> Map[String, Bool] {
  let out : Map[String, Bool] = {}
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
  let version = index_read_u32_be(data, 4) catch { _ => return out }
  if version != 2 && version != 3 {
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
    let fixed_size = if has_extended { 64 } else { 62 }
    let path_start = offset + fixed_size
    let mut i = path_start
    while i < data.length() && data[i] != b'\x00' {
      i += 1
    }
    if i >= data.length() {
      return out
    }
    if stage != 0 {
      out[@utf8.decode_lossy(data[path_start:i])] = true
    }
    let path_len = i - path_start
    let entry_size = (fixed_size + path_len + 1 + 7) / 8 * 8
    offset += entry_size
  }
  out
}

///|
pub fn write_skip_worktree_paths(
  fs : &@bit.FileSystem,
  git_dir : String,
  paths : Array[String],
) -> Unit raise @bit.GitError {
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
fn index_entry_buf_size(path_len : Int, has_extended : Bool) -> Int {
  let fixed_size = if has_extended { 64 } else { 62 }
  (fixed_size + path_len + 1 + 7) / 8 * 8
}

///|
fn write_index_entry_to_buf(
  buf : FixedArray[Byte],
  pos : Int,
  e : IndexEntry,
  skip_worktree : Bool,
) -> Int {
  let entry_start = pos
  let mut pos = pos
  fa_set_u32_be(buf, pos, e.mtime_sec) // ctime_sec
  fa_set_u32_be(buf, pos + 4, e.mtime_nsec) // ctime_nsec
  fa_set_u32_be(buf, pos + 8, e.mtime_sec) // mtime_sec
  fa_set_u32_be(buf, pos + 12, e.mtime_nsec) // mtime_nsec
  fa_set_u32_be(buf, pos + 16, e.dev)
  fa_set_u32_be(buf, pos + 20, e.ino)
  fa_set_u32_be(buf, pos + 24, e.mode) // mode
  fa_set_u32_be(buf, pos + 28, e.uid)
  fa_set_u32_be(buf, pos + 32, e.gid)
  fa_set_u32_be(buf, pos + 36, e.size) // file_size
  pos += 40
  // object id (20 bytes)
  for i in 0..<20 {
    buf[pos + i] = e.id.bytes[i]
  }
  pos += 20
  // flags
  let name_len = if e.path.length() < 0x0fff { e.path.length() } else { 0x0fff }
  let mut flags = name_len
  let ext_flags = index_extended_flags(e.intent_to_add, skip_worktree)
  let has_extended = ext_flags != 0
  if has_extended {
    flags = flags | 0x4000
  }
  fa_set_u16_be(buf, pos, flags)
  pos += 2
  if has_extended {
    fa_set_u16_be(buf, pos, ext_flags)
    pos += 2
  }
  // path bytes
  for c in e.path {
    buf[pos] = c.to_int().to_byte()
    pos += 1
  }
  // NUL + padding to 8-byte alignment (already zeroed)
  entry_start + index_entry_buf_size(e.path.length(), has_extended)
}

///|
fn write_index_buf(
  sorted : Array[IndexEntry],
  skip_worktree_paths : Map[String, Bool]?,
) -> FixedArray[Byte] {
  // Pre-calculate total buffer size
  let mut total_size = 12 // header: "DIRC" + version + count
  for e in sorted {
    let is_skip = match skip_worktree_paths {
      Some(m) => m.contains(e.path)
      None => false
    }
    total_size += index_entry_buf_size(
      e.path.length(),
      index_extended_flags(e.intent_to_add, is_skip) != 0,
    )
  }
  total_size += 20 // SHA1 checksum
  let buf : FixedArray[Byte] = FixedArray::make(total_size, b'\x00')
  // Header
  buf[0] = b'D'
  buf[1] = b'I'
  buf[2] = b'R'
  buf[3] = b'C'
  fa_set_u32_be(buf, 4, 2) // version
  fa_set_u32_be(buf, 8, sorted.length()) // count
  let mut pos = 12
  for e in sorted {
    let is_skip = match skip_worktree_paths {
      Some(m) => m.contains(e.path)
      None => false
    }
    pos = write_index_entry_to_buf(buf, pos, e, is_skip)
  }
  // SHA1 checksum over header + entries
  let content_bytes = Bytes::from_array(buf[:pos])
  let checksum = @bit.sha1(content_bytes)
  for i in 0..<20 {
    buf[pos + i] = checksum.bytes[i]
  }
  buf
}

///|
pub fn write_index_entries(
  fs : &@bit.FileSystem,
  git_dir : String,
  entries : Array[IndexEntry],
) -> Unit raise @bit.GitError {
  let sorted = entries.copy()
  sorted.sort_by((a, b) => index_path_compare_git_order(a.path, b.path))
  let buf = write_index_buf(sorted, None)
  let index_path = join_path(git_dir, "index")
  fs.write_file(index_path, Bytes::from_array(buf[:]))
}

///|
fn index_read_u32_be(data : Bytes, start : Int) -> Int raise @bit.GitError {
  if start < 0 || start + 4 > data.length() {
    raise @bit.GitError::InvalidObject("Unexpected end of index data")
  }
  (data[start].to_int() << 24) |
  (data[start + 1].to_int() << 16) |
  (data[start + 2].to_int() << 8) |
  data[start + 3].to_int()
}

///|
fn index_read_u16_be(data : Bytes, start : Int) -> Int raise @bit.GitError {
  if start < 0 || start + 2 > data.length() {
    raise @bit.GitError::InvalidObject("Unexpected end of index data")
  }
  (data[start].to_int() << 8) | data[start + 1].to_int()
}

///|
pub fn write_index_entries_with_skip_worktree(
  fs : &@bit.FileSystem,
  git_dir : String,
  entries : Array[IndexEntry],
  skip_worktree_paths : Map[String, Bool],
) -> Unit raise @bit.GitError {
  let sorted = entries.copy()
  sorted.sort_by((a, b) => index_path_compare_git_order(a.path, b.path))
  let buf = write_index_buf(sorted, Some(skip_worktree_paths))
  let index_path = join_path(git_dir, "index")
  fs.write_file(index_path, Bytes::from_array(buf[:]))
}

///|
fn index_read_object_id(
  data : Bytes,
  start : Int,
) -> @bit.ObjectId raise @bit.GitError {
  if start + 20 > data.length() {
    raise @bit.GitError::InvalidObject("Unexpected end of index data")
  }
  let bytes : FixedArray[Byte] = FixedArray::make(20, b'\x00')
  for i in 0..<20 {
    bytes[i] = data[start + i]
  }
  @bit.ObjectId::new(bytes)
}

///|
fn index_extended_flags(intent_to_add : Bool, skip_worktree : Bool) -> Int {
  let mut flags = 0
  if intent_to_add {
    flags = flags | 0x2000
  }
  if skip_worktree {
    flags = flags | 0x4000
  }
  flags
}

///|
fn index_ext_flags_has_intent_to_add(ext_flags : Int) -> Bool {
  (ext_flags & 0x2000) != 0
}

///|
fn fa_set_u32_be(buf : FixedArray[Byte], offset : Int, v : Int) -> Unit {
  buf[offset] = ((v >> 24) & 0xff).to_byte()
  buf[offset + 1] = ((v >> 16) & 0xff).to_byte()
  buf[offset + 2] = ((v >> 8) & 0xff).to_byte()
  buf[offset + 3] = (v & 0xff).to_byte()
}

///|
fn fa_set_u16_be(buf : FixedArray[Byte], offset : Int, v : Int) -> Unit {
  buf[offset] = ((v >> 8) & 0xff).to_byte()
  buf[offset + 1] = (v & 0xff).to_byte()
}

///|
fn index_path_compare_git_order(a : String, b : String) -> Int {
  let a_len = a.length()
  let b_len = b.length()
  let min_len = if a_len < b_len { a_len } else { b_len }
  for i in 0..<min_len {
    let av = a.unsafe_get(i)
    let bv = b.unsafe_get(i)
    if av < bv {
      return -1
    }
    if av > bv {
      return 1
    }
  }
  if a_len < b_len {
    -1
  } else if a_len > b_len {
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
