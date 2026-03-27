///| Single-pack bitmap file writer (pack-objects --write-bitmap-index)
///
/// Format: .bitmap file alongside .pack/.idx
///   - 4 bytes: "BITM" magic
///   - 2 bytes: version (1)
///   - 2 bytes: option flags (bit 0 = full DAG, bit 2 = name hash cache)
///   - 4 bytes: tip count
///   - 20 bytes: pack checksum
///   - 4 type bitmaps (commit/tree/blob/tag), each EWAH-encoded
///   - per-tip entries: 4-byte position + 2-byte flags + EWAH bitmap
///   - optional name hash cache: 4 bytes per object
///   - 20 bytes: SHA-1 trailer

///|
priv struct BitmapTip {
  id : @bitcore.ObjectId
  pack_pos : Int
}

///|
fn bitmap_push_u16(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
fn bitmap_push_u32(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 24) & 0xff).to_byte())
  out.push(((value >> 16) & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
fn bitmap_push_u64_parts(out : Array[Byte], hi : Int, lo : Int) -> Unit {
  bitmap_push_u32(out, hi)
  bitmap_push_u32(out, lo)
}

///|
fn bitmap_build_ewah(bit_size : Int, positions : Array[Int]) -> Array[Byte] {
  let word_count = if bit_size <= 0 { 0 } else { (bit_size + 63) / 64 }
  let word_hi : Array[Int] = Array::make(word_count, 0)
  let word_lo : Array[Int] = Array::make(word_count, 0)
  for pos in positions {
    if pos < 0 || pos >= bit_size {
      continue
    }
    let word_idx = pos / 64
    let bit = pos % 64
    if bit < 32 {
      word_lo[word_idx] = word_lo[word_idx] | (1 << bit)
    } else {
      word_hi[word_idx] = word_hi[word_idx] | (1 << (bit - 32))
    }
  }
  let out : Array[Byte] = []
  bitmap_push_u32(out, bit_size)
  bitmap_push_u32(out, word_count + 1)
  // RLW: bit 0 = run bit, bits [1..32] = running length, bits [33..63] = literal count
  // Literal-only: run bit=0, running_length=0, literal_count=word_count
  let rlw_hi = word_count << 1
  let rlw_lo = 0
  bitmap_push_u64_parts(out, rlw_hi, rlw_lo)
  for i in 0..<word_count {
    bitmap_push_u64_parts(out, word_hi[i], word_lo[i])
  }
  bitmap_push_u32(out, 0) // trailing RLW position
  out
}

///|
fn bitmap_object_type_code(obj_type : @bitcore.ObjectType) -> Int {
  match obj_type {
    @bitcore.ObjectType::Commit => 1
    @bitcore.ObjectType::Tree => 2
    @bitcore.ObjectType::Blob => 3
    @bitcore.ObjectType::Tag => 4
  }
}

///|
fn bitmap_collect_tips(
  fs : OsFs,
  git_dir : String,
  pos_by_oid : Map[String, Int],
) -> Array[BitmapTip] {
  let tips : Array[BitmapTip] = []
  let seen : Map[String, Bool] = {}
  let refs = @bitlib.list_refs_with_ids(fs, git_dir, Some("refs/"))
  let refnames : Array[String] = []
  for refname, _ in refs {
    if refname.has_prefix("refs/heads/") || refname.has_prefix("refs/tags/") {
      refnames.push(refname)
    }
  }
  refnames.sort_by(fn(a, b) { a.compare(b) })
  for refname in refnames {
    let rev = refname + "^{commit}"
    let parsed = @bitrepo.rev_parse(fs, git_dir, rev) catch { _ => None }
    match parsed {
      Some(id) => {
        let hex = id.to_hex()
        if not(seen.contains(hex)) {
          match pos_by_oid.get(hex) {
            Some(pack_pos) => {
              seen[hex] = true
              tips.push({ id, pack_pos })
            }
            None => ()
          }
        }
      }
      None => ()
    }
  }
  // Also try HEAD
  let head = @bitrepo.rev_parse(fs, git_dir, "HEAD") catch { _ => None }
  match head {
    Some(id) => {
      let hex = id.to_hex()
      if not(seen.contains(hex)) {
        match pos_by_oid.get(hex) {
          Some(pack_pos) => {
            seen[hex] = true
            tips.push({ id, pack_pos })
          }
          None => ()
        }
      }
    }
    None => ()
  }
  tips
}

///|
async fn write_pack_bitmap(
  fs : OsFs,
  git_dir : String,
  bitmap_path : String,
  pack : Bytes,
  idx_objects : Array[@bitcore.PackObject],
  objects : Array[@bitcore.PackObject],
) -> Unit raise Error {
  let object_count = idx_objects.length()
  if object_count == 0 {
    return
  }
  // Build OID → pack position map (position = sorted order in index)
  let pos_by_oid : Map[String, Int] = {}
  for pack_pos, obj in idx_objects {
    pos_by_oid[obj.id.to_hex()] = pack_pos
  }
  // Determine object types
  let type_by_pos : Array[Int] = Array::make(object_count, -1)
  for pack_pos, obj in idx_objects {
    type_by_pos[pack_pos] = bitmap_object_type_code(obj.obj_type)
  }
  // Build type bitmaps
  let commit_positions : Array[Int] = []
  let tree_positions : Array[Int] = []
  let blob_positions : Array[Int] = []
  let tag_positions : Array[Int] = []
  for pack_pos in 0..<object_count {
    match type_by_pos[pack_pos] {
      1 => commit_positions.push(pack_pos)
      2 => tree_positions.push(pack_pos)
      3 => blob_positions.push(pack_pos)
      4 => tag_positions.push(pack_pos)
      _ => ()
    }
  }
  // Collect bitmap tips from refs
  let bitmap_tips = bitmap_collect_tips(fs, git_dir, pos_by_oid)
  if bitmap_tips.length() == 0 {
    // Find any commit as fallback tip
    for pack_pos in 0..<object_count {
      if type_by_pos[pack_pos] == 1 {
        bitmap_tips.push({ id: idx_objects[pack_pos].id, pack_pos })
        break
      }
    }
  }
  if bitmap_tips.length() == 0 {
    return
  }
  bitmap_tips.sort_by(fn(a, b) { a.pack_pos - b.pack_pos })
  // Collect reachable objects for each tip
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let reachable_positions_by_tip : Array[Array[Int]] = []
  for tip in bitmap_tips {
    let reachable = @bitlib.collect_reachable_objects(db, fs, tip.id) catch {
      _ => {
        // If we can't walk the graph, skip bitmap writing
        return
      }
    }
    let positions : Array[Int] = []
    for obj in reachable {
      match pos_by_oid.get(obj.id.to_hex()) {
        Some(pack_pos) => positions.push(pack_pos)
        None => () // Object not in this pack — skip
      }
    }
    reachable_positions_by_tip.push(positions)
  }
  // Build name hash cache from original objects
  let name_hash_by_pos : Array[Int] = Array::make(object_count, 0)
  // We don't have per-object path info from the pack itself,
  // so name hash cache is left as zeros (valid per spec).
  ignore(objects)
  ignore(name_hash_by_pos)
  let has_name_hash = false
  // Extract pack checksum (last 20 bytes of pack)
  let checksum_offset = pack.length() - 20
  let checksum = FixedArray::makei(20, fn(i) { pack[checksum_offset + i] })
  // Build bitmap file
  let out : Array[Byte] = []
  // Magic: BITM
  out.push(b'B')
  out.push(b'I')
  out.push(b'T')
  out.push(b'M')
  // Version: 1
  bitmap_push_u16(out, 1)
  // Options: bit 0 = full DAG closure
  let mut bitmap_options = 1
  if has_name_hash {
    bitmap_options = bitmap_options | 4
  }
  bitmap_push_u16(out, bitmap_options)
  // Tip count
  bitmap_push_u32(out, bitmap_tips.length())
  // Pack checksum
  for b in checksum {
    out.push(b)
  }
  // Type bitmaps (commit, tree, blob, tag)
  let commits_bitmap = bitmap_build_ewah(object_count, commit_positions)
  for b in commits_bitmap {
    out.push(b)
  }
  let trees_bitmap = bitmap_build_ewah(object_count, tree_positions)
  for b in trees_bitmap {
    out.push(b)
  }
  let blobs_bitmap = bitmap_build_ewah(object_count, blob_positions)
  for b in blobs_bitmap {
    out.push(b)
  }
  let tags_bitmap = bitmap_build_ewah(object_count, tag_positions)
  for b in tags_bitmap {
    out.push(b)
  }
  // Per-tip entries
  for i in 0..<bitmap_tips.length() {
    bitmap_push_u32(out, bitmap_tips[i].pack_pos)
    // Flags: 0x01 = bitmap is valid
    out.push(b'\x00')
    out.push(b'\x01')
    let reachable_bitmap = bitmap_build_ewah(
      object_count,
      reachable_positions_by_tip[i],
    )
    for b in reachable_bitmap {
      out.push(b)
    }
  }
  // Name hash cache (if enabled)
  if has_name_hash {
    for hash in name_hash_by_pos {
      bitmap_push_u32(out, hash)
    }
  }
  // SHA-1 trailer over the body
  let body = Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] }))
  let trailer = @bitcore.sha1(body)
  for b in trailer.bytes {
    out.push(b)
  }
  // Write the bitmap file
  fs.write_file(
    bitmap_path,
    Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] })),
  )
}
