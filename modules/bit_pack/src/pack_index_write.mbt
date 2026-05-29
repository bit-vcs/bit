///| Pack index writer (v2)

///|
priv struct PackIndexEntry {
  id : @bit.ObjectId
  offset : Int
  crc : UInt
}

///|
/// Build a pack index (v2) from packfile bytes.
pub fn build_pack_index(
  pack : Bytes,
  hash_size? : Int = 20,
) -> Bytes raise @bit.GitError {
  let objects = parse_packfile(pack, hash_size~)
  build_pack_index_from_objects(pack, objects, hash_size~)
}

///|
/// Build a pack index (v2) from packfile bytes and parsed objects.
/// Uses cached metadata (id, offset, crc32) from PackObject when available.
/// Falls back to re-parsing the pack if metadata is missing.
pub fn build_pack_index_from_objects(
  pack : Bytes,
  objects : Array[@bit.PackObject],
  hash_size? : Int = 20,
) -> Bytes raise @bit.GitError {
  // Validate that object offsets are plausible for this pack.
  // Objects may carry stale offsets from a different (source) pack,
  // so we check: offset >= 12 (after header) and < pack_data_end.
  let pack_data_end = if pack.length() >= hash_size {
    pack.length() - hash_size
  } else {
    0
  }
  let mut needs_parse = false
  for obj in objects {
    if obj.offset < 12 || obj.offset >= pack_data_end {
      needs_parse = true
      break
    }
  }

  // If objects have stale/invalid offsets, re-parse the pack to get correct values
  if needs_parse {
    return build_pack_index(pack, hash_size~)
  }
  if pack.length() < hash_size {
    raise @bit.GitError::PackfileError("Packfile too short")
  }

  // Sort objects by id in place (callers don't depend on order after this)
  objects.sort_by(fn(a, b) { compare_object_id(a.id, b.id) })

  let n = objects.length()
  // idx v2: header(8) + fanout(1024) + names(N*hash_size) + crc(N*4) + offsets(N*4)
  //       + pack_checksum(hash_size) + idx_checksum(hash_size)
  let total_size = 8 + 1024 + n * (hash_size + 8) + hash_size * 2
  let content_size = total_size - hash_size
  let out : FixedArray[Byte] = FixedArray::make(total_size, b'\x00')
  let mut pos = 0

  // Header: magic + version
  out[0] = b'\xff'
  out[1] = b't'
  out[2] = b'O'
  out[3] = b'c'
  pos = 4
  set_u32_be(out, pos, 2)
  pos += 4

  // Fanout table
  let counts : FixedArray[Int] = FixedArray::make(256, 0)
  for obj in objects {
    let first = obj.id.bytes[0].to_int()
    counts[first] = counts[first] + 1
  }
  let mut sum = 0
  for i in 0..<256 {
    sum = sum + counts[i]
    set_u32_be(out, pos, sum)
    pos += 4
  }

  // Object name table
  for obj in objects {
    for i in 0..<hash_size {
      out[pos] = obj.id.bytes[i]
      pos += 1
    }
  }

  // CRC32 table
  for obj in objects {
    set_u32_be_uint(out, pos, obj.crc32)
    pos += 4
  }

  // Offsets table
  for obj in objects {
    if obj.offset < 0 {
      raise @bit.GitError::PackfileError("Negative pack offset")
    }
    set_u32_be(out, pos, obj.offset)
    pos += 4
  }

  // Pack checksum (trailer)
  let trailer_offset = pack.length() - hash_size
  for i in 0..<hash_size {
    out[pos] = pack[trailer_offset + i]
    pos += 1
  }

  // Index checksum: hash of everything before this point
  let tmp_bytes = Bytes::from_array(out)
  let index_checksum = @bit.hash_prefix(tmp_bytes, content_size, hash_size~)
  for i in 0..<hash_size {
    out[pos] = index_checksum.bytes[i]
    pos += 1
  }
  Bytes::from_array(out)
}

///|
/// Build a v2 pack index with optional 64-bit offset threshold.
/// When threshold is Some(n), offsets >= n are stored as 64-bit entries.
fn build_pack_index_from_objects_with_threshold(
  pack : Bytes,
  objects : Array[@bit.PackObject],
  threshold : Int64?,
  hash_size? : Int = 20,
) -> Bytes raise @bit.GitError {
  // Default: no 64-bit offsets
  let off64_threshold = match threshold {
    None => 0x80000000L // 2^31, only truly large offsets
    Some(t) => t
  }
  // Validate that object offsets are plausible for this pack.
  let pack_data_end = if pack.length() >= hash_size {
    pack.length() - hash_size
  } else {
    0
  }
  let mut needs_parse = false
  for obj in objects {
    if obj.offset < 12 || obj.offset >= pack_data_end {
      needs_parse = true
      break
    }
  }
  let parsed_objects = if needs_parse {
    parse_packfile(pack, hash_size~)
  } else {
    objects
  }
  let entries : Array[PackIndexEntry] = []
  for obj in parsed_objects {
    entries.push({ id: obj.id, offset: obj.offset, crc: obj.crc32 })
  }
  entries.sort_by(fn(a, b) { compare_object_id(a.id, b.id) })
  let counts : Array[Int] = Array::make(256, 0)
  for entry in entries {
    let first = entry.id.bytes[0].to_int()
    counts[first] = counts[first] + 1
  }
  // Collect large offset entries
  let large_offsets : Array[(Int, Int64)] = [] // (entry_index, offset_value)
  for i, entry in entries {
    if entry.offset.to_int64() >= off64_threshold {
      large_offsets.push((i, entry.offset.to_int64()))
    }
  }
  let out : Array[Byte] = []
  // Index header: magic + version
  out.push(b'\xff')
  out.push(b't')
  out.push(b'O')
  out.push(b'c')
  push_u32_be_from_int(out, 2)
  // Fanout table
  let mut sum = 0
  for i in 0..<256 {
    sum = sum + counts[i]
    push_u32_be_from_int(out, sum)
  }
  // Object name table
  for entry in entries {
    for b in entry.id.bytes {
      out.push(b)
    }
  }
  // CRC32 table
  for entry in entries {
    push_u32_be_from_uint(out, entry.crc)
  }
  // Offsets table - mark large offsets with MSB set
  let mut large_idx = 0
  for i, entry in entries {
    let mut is_large = false
    if large_idx < large_offsets.length() && large_offsets[large_idx].0 == i {
      is_large = true
    }
    if is_large {
      // MSB set + index into 64-bit table
      let marker = 0x80000000 | large_idx
      push_u32_be_from_int(out, marker)
      large_idx += 1
    } else {
      if entry.offset < 0 {
        raise @bit.GitError::PackfileError("Negative pack offset")
      }
      push_u32_be_from_int(out, entry.offset)
    }
  }
  // 64-bit offset table
  for pair in large_offsets {
    let offset = pair.1
    // Write as 8-byte big-endian
    push_u32_be_from_int(out, (offset >> 32).to_int())
    push_u32_be_from_int(out, (offset & 0xFFFFFFFFL).to_int())
  }
  // Packfile checksum (trailer)
  if pack.length() < hash_size {
    raise @bit.GitError::PackfileError("Packfile too short")
  }
  let trailer_offset = pack.length() - hash_size
  let pack_checksum = read_trailer_id(pack, trailer_offset, hash_size~)
  for b in pack_checksum.bytes {
    out.push(b)
  }
  // Index checksum
  let before_checksum = bytes_from_array(out)
  let index_checksum = @bit.hash_prefix(
    before_checksum,
    before_checksum.length(),
    hash_size~,
  )
  for b in index_checksum.bytes {
    out.push(b)
  }
  bytes_from_array(out)
}

///|
/// Write a pack index to the filesystem.
pub fn write_pack_index(
  fs : &@bit.FileSystem,
  idx_path : String,
  pack : Bytes,
) -> Unit raise @bit.GitError {
  let idx = build_pack_index(pack)
  fs.write_file(idx_path, idx)
}

///|
/// Write a pack index using pre-parsed objects.
pub fn write_pack_index_from_objects(
  fs : &@bit.FileSystem,
  idx_path : String,
  pack : Bytes,
  objects : Array[@bit.PackObject],
) -> Unit raise @bit.GitError {
  let idx = build_pack_index_from_objects(pack, objects)
  fs.write_file(idx_path, idx)
}

///|
/// Write a pack index using pre-parsed objects with specific version.
pub fn write_pack_index_from_objects_versioned(
  fs : &@bit.FileSystem,
  idx_path : String,
  pack : Bytes,
  objects : Array[@bit.PackObject],
  version : Int,
  off64_threshold : Int64?,
) -> Unit raise @bit.GitError {
  let idx = if version == 1 {
    build_pack_index_v1_from_objects(pack, objects)
  } else {
    build_pack_index_from_objects_with_threshold(pack, objects, off64_threshold)
  }
  fs.write_file(idx_path, idx)
}

///|
/// Build a pack index (v1) from packfile bytes and parsed objects.
/// Falls back to re-parsing the pack if metadata is missing.
fn build_pack_index_v1_from_objects(
  pack : Bytes,
  objects : Array[@bit.PackObject],
  hash_size? : Int = 20,
) -> Bytes raise @bit.GitError {
  // Validate that object offsets are plausible for this pack.
  let pack_data_end = if pack.length() >= hash_size {
    pack.length() - hash_size
  } else {
    0
  }
  let mut needs_parse = false
  for obj in objects {
    if obj.offset < 12 || obj.offset >= pack_data_end {
      needs_parse = true
      break
    }
  }

  // If objects have stale/invalid offsets, re-parse the pack to get correct values
  if needs_parse {
    let parsed = parse_packfile(pack, hash_size~)
    return build_pack_index_v1_from_objects(pack, parsed, hash_size~)
  }
  let entries : Array[PackIndexEntry] = []
  for obj in objects {
    entries.push({ id: obj.id, offset: obj.offset, crc: obj.crc32 })
  }
  entries.sort_by((a, b) => compare_object_id(a.id, b.id))

  // Build fanout table (counts per first byte)
  let counts : Array[Int] = Array::make(256, 0)
  for entry in entries {
    let first = entry.id.bytes[0].to_int()
    counts[first] = counts[first] + 1
  }
  let out : Array[Byte] = []

  // v1 format: no header, starts directly with fanout
  // Fanout table (cumulative counts)
  let mut sum = 0
  for i in 0..<256 {
    sum = sum + counts[i]
    push_u32_be_from_int(out, sum)
  }

  // v1 entries: each entry is offset(4) + sha1(20) = 24 bytes
  for entry in entries {
    if entry.offset < 0 {
      raise @bit.GitError::PackfileError("Negative pack offset")
    }
    push_u32_be_from_int(out, entry.offset)
    for b in entry.id.bytes {
      out.push(b)
    }
  }

  // Packfile checksum (trailer)
  if pack.length() < hash_size {
    raise @bit.GitError::PackfileError("Packfile too short")
  }
  let trailer_offset = pack.length() - hash_size
  let pack_checksum = read_trailer_id(pack, trailer_offset, hash_size~)
  for b in pack_checksum.bytes {
    out.push(b)
  }

  // Index checksum (hash of all preceding bytes)
  let before_checksum = bytes_from_array(out)
  let index_checksum = @bit.hash_prefix(
    before_checksum,
    before_checksum.length(),
    hash_size~,
  )
  for b in index_checksum.bytes {
    out.push(b)
  }
  bytes_from_array(out)
}

///|
fn compare_object_id(a : @bit.ObjectId, b : @bit.ObjectId) -> Int {
  let len = a.bytes.length()
  for i in 0..<len {
    let av = a.bytes[i].to_int()
    let bv = b.bytes[i].to_int()
    if av != bv {
      return av - bv
    }
  }
  0
}

///|
let pack_crc32_poly : UInt = (Int::reinterpret_as_uint(237) << 24) |
  (Int::reinterpret_as_uint(184) << 16) |
  (Int::reinterpret_as_uint(131) << 8) |
  Int::reinterpret_as_uint(32)

///|
fn build_pack_crc32_table() -> FixedArray[UInt] {
  FixedArray::makei(256, fn(i) {
    let mut c = i.reinterpret_as_uint()
    for _ in 0..<8 {
      if (c & Int::reinterpret_as_uint(1)) == Int::reinterpret_as_uint(1) {
        c = (c >> 1) ^ pack_crc32_poly
      } else {
        c = c >> 1
      }
    }
    c
  })
}

///|
let pack_crc32_table : FixedArray[UInt] = build_pack_crc32_table()

///|
fn crc32_bytes_range(data : Bytes, start : Int, end : Int) -> UInt {
  let mut crc : UInt = Int::reinterpret_as_uint(-1)
  for i = start; i < end; i = i + 1 {
    let idx = UInt::reinterpret_as_int(
      (crc ^ Int::reinterpret_as_uint(data[i].to_int())) &
      Int::reinterpret_as_uint(255),
    )
    crc = (crc >> 8) ^ pack_crc32_table[idx]
  }
  crc ^ Int::reinterpret_as_uint(-1)
}

///|
pub fn crc32_range(
  data : Bytes,
  start : Int,
  end : Int,
) -> UInt raise @bit.GitError {
  if start < 0 || end < start || end > data.length() {
    raise @bit.GitError::PackfileError("Invalid CRC range")
  }
  crc32_bytes_range(data, start, end)
}

///|
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(arr)
}

///|
fn push_u32_be_from_int(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 24) & 0xff).to_byte())
  out.push(((value >> 16) & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
fn set_u32_be(out : FixedArray[Byte], pos : Int, value : Int) -> Unit {
  out[pos] = ((value >> 24) & 0xff).to_byte()
  out[pos + 1] = ((value >> 16) & 0xff).to_byte()
  out[pos + 2] = ((value >> 8) & 0xff).to_byte()
  out[pos + 3] = (value & 0xff).to_byte()
}

///|
fn set_u32_be_uint(out : FixedArray[Byte], pos : Int, value : UInt) -> Unit {
  let mask = Int::reinterpret_as_uint(0xff)
  out[pos] = UInt::reinterpret_as_int((value >> 24) & mask).to_byte()
  out[pos + 1] = UInt::reinterpret_as_int((value >> 16) & mask).to_byte()
  out[pos + 2] = UInt::reinterpret_as_int((value >> 8) & mask).to_byte()
  out[pos + 3] = UInt::reinterpret_as_int(value & mask).to_byte()
}

///|
fn push_u32_be_from_uint(out : Array[Byte], value : UInt) -> Unit {
  let mask = Int::reinterpret_as_uint(0xff)
  let b0 = (value >> 24) & mask
  let b1 = (value >> 16) & mask
  let b2 = (value >> 8) & mask
  let b3 = value & mask
  out.push(UInt::reinterpret_as_int(b0).to_byte())
  out.push(UInt::reinterpret_as_int(b1).to_byte())
  out.push(UInt::reinterpret_as_int(b2).to_byte())
  out.push(UInt::reinterpret_as_int(b3).to_byte())
}

///|
/// Write a packfile and build its index in one step.
/// Avoids the need for callers to parse + write separately.
pub fn write_pack_and_index(
  fs : &@bit.FileSystem,
  git_dir : String,
  pack : Bytes,
  verify_checksum? : Bool = true,
) -> Unit raise @bit.GitError {
  if pack.length() < 20 {
    raise @bit.GitError::PackfileError("Packfile too short")
  }
  let pack_dir = @bit.join_path(git_dir, "objects/pack")
  fs.mkdir_p(pack_dir)
  let trailer_offset = pack.length() - 20
  let pack_id = read_trailer_id(pack, trailer_offset)
  let base = "pack-\{pack_id.to_hex()}"
  let pack_path = @bit.join_path(pack_dir, base + ".pack")
  let idx_path = @bit.join_path(pack_dir, base + ".idx")
  fs.write_file(pack_path, pack)
  let objects = parse_packfile(pack, verify_checksum~)
  let idx = build_pack_index_from_objects(pack, objects)
  fs.write_file(idx_path, idx)
}

///|
/// Write a packfile and its index under .git/objects/pack.
pub fn write_packfile_with_index(
  fs : &@bit.FileSystem,
  git_dir : String,
  pack : Bytes,
  objects : Array[@bit.PackObject],
) -> Unit raise @bit.GitError {
  if pack.length() < 20 {
    raise @bit.GitError::PackfileError("Packfile too short")
  }
  let pack_dir = @bit.join_path(git_dir, "objects/pack")
  fs.mkdir_p(pack_dir)
  let trailer_offset = pack.length() - 20
  let pack_id = read_trailer_id(pack, trailer_offset)
  let base = "pack-\{pack_id.to_hex()}"
  let pack_path = @bit.join_path(pack_dir, base + ".pack")
  let idx_path = @bit.join_path(pack_dir, base + ".idx")
  fs.write_file(pack_path, pack)
  write_pack_index_from_objects(fs, idx_path, pack, objects)
}

///|
/// Build a reverse index (RIDX version 1) from packfile bytes and parsed objects.
/// Format: magic("RIDX") + version(1) + hash_id(1) + position_table + pack_checksum + file_checksum
/// The position_table maps from pack offset order to index position.
pub fn build_reverse_index(
  pack : Bytes,
  objects : Array[@bit.PackObject],
) -> Bytes raise @bit.GitError {
  if pack.length() < 20 {
    raise @bit.GitError::PackfileError("Packfile too short")
  }
  // Validate offsets; re-parse if stale
  let pack_data_end = if pack.length() >= 20 { pack.length() - 20 } else { 0 }
  let mut needs_parse = false
  for obj in objects {
    if obj.offset < 12 || obj.offset >= pack_data_end {
      needs_parse = true
      break
    }
  }
  let objs = if needs_parse { parse_packfile(pack) } else { objects }

  // Build index entries sorted by object id (same as pack index order)
  let entries : Array[PackIndexEntry] = []
  for obj in objs {
    entries.push({ id: obj.id, offset: obj.offset, crc: obj.crc32 })
  }
  entries.sort_by((a, b) => compare_object_id(a.id, b.id))

  // Build offset-sorted indices: for each position in offset order,
  // store the index into the id-sorted entries array
  let count = entries.length()
  let indexed : Array[(Int, Int)] = [] // (offset, index_position)
  for i in 0..<count {
    indexed.push((entries[i].offset, i))
  }
  indexed.sort_by(fn(a, b) {
    let (oa, _) = a
    let (ob, _) = b
    if oa < ob {
      -1
    } else if oa > ob {
      1
    } else {
      0
    }
  })

  let out : Array[Byte] = []
  // Magic: "RIDX"
  out.push(b'R')
  out.push(b'I')
  out.push(b'D')
  out.push(b'X')
  // Version: 1
  push_u32_be_from_int(out, 1)
  // Hash algorithm identifier: 1 = SHA-1
  push_u32_be_from_int(out, 1)

  // Position table: for each object in pack-offset order,
  // the index position (in the .idx id-sorted table)
  for i in 0..<count {
    let (_, idx_pos) = indexed[i]
    push_u32_be_from_int(out, idx_pos)
  }

  // Pack checksum (copy from pack trailer)
  let trailer_offset = pack.length() - 20
  let pack_checksum = read_trailer_id(pack, trailer_offset)
  for b in pack_checksum.bytes {
    out.push(b)
  }

  // RIDX file checksum
  let before_checksum = bytes_from_array(out)
  let file_checksum = @bit.sha1(before_checksum)
  for b in file_checksum.bytes {
    out.push(b)
  }
  bytes_from_array(out)
}

///|
/// Write a reverse index (.rev) file to the filesystem.
pub fn write_reverse_index(
  fs : &@bit.FileSystem,
  rev_path : String,
  pack : Bytes,
  objects : Array[@bit.PackObject],
) -> Unit raise @bit.GitError {
  let rev = build_reverse_index(pack, objects)
  fs.write_file(rev_path, rev)
}
