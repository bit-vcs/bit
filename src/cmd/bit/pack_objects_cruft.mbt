///| Cruft pack support for pack-objects
/// Cruft packs store unreachable objects with .mtimes files tracking
/// when each object was last seen.

///|
/// Parse cruft-mode stdin: lines without '-' prefix are keep packs,
/// lines with '-' prefix are discard packs.
fn parse_cruft_stdin_lines(input : Bytes) -> (Array[String], Array[String]) {
  let lines = split_lines_bytes(input)
  let keep_names : Array[String] = []
  let discard_names : Array[String] = []
  for line in lines {
    let trimmed = trim_line_bytes(line)
    if trimmed.length() == 0 {
      continue
    }
    let text = line_to_string(trimmed)
    if text.has_prefix("-") {
      discard_names.push(string_slice_from(text, 1))
    } else {
      keep_names.push(text)
    }
  }
  (keep_names, discard_names)
}

///|
/// Parse a git approxidate string for --cruft-expiration.
/// Supports: "never", "now", "N.seconds.ago", "N.minutes.ago",
/// "N.hours.ago", "N.days.ago", "N.weeks.ago"
fn parse_approxidate(s : String) -> Int64 {
  let trimmed = s.trim().to_string().to_lower()
  if trimmed == "never" {
    return 0L
  }
  let now = get_current_timestamp()
  if trimmed == "now" {
    return now
  }
  // Pattern: N.unit.ago
  if trimmed.has_suffix(".ago") {
    let without_ago = String::unsafe_substring(
      trimmed,
      start=0,
      end=trimmed.length() - 4,
    )
    // Find the last dot to split "N.unit"
    match without_ago.rev_find(".") {
      Some(dot_pos) => {
        let num_str = String::unsafe_substring(
          without_ago,
          start=0,
          end=dot_pos,
        )
        let unit = string_slice_from(without_ago, dot_pos + 1)
        let n = @string.parse_int64(num_str) catch { _ => return now }
        let multiplier : Int64 = match unit {
          "second" | "seconds" => 1L
          "minute" | "minutes" => 60L
          "hour" | "hours" => 3600L
          "day" | "days" => 86400L
          "week" | "weeks" => 604800L
          _ => 1L
        }
        return now - n * multiplier
      }
      None => return now
    }
  }
  // Try as a plain timestamp
  let parsed = @string.parse_int64(trimmed) catch { _ => return now }
  parsed
}

///|
/// Read a .mtimes file and return a map of object hex -> mtime (uint32)
fn read_mtimes_file(
  fs : OsFs,
  mtimes_path : String,
  idx_path : String,
) -> Map[String, Int] {
  let result : Map[String, Int] = {}
  let mtimes_data = fs.read_file(mtimes_path) catch { _ => return result }
  // Parse header: magic (4) + version (4) + hash_id (4) = 12 bytes
  if mtimes_data.length() < 12 {
    return result
  }
  let magic = read_u32_be_i64(mtimes_data, 0)
  if magic != 0x4d544d45L {
    return result
  }
  // Get object IDs from the corresponding index file
  let ids = collect_pack_index_ids(fs, idx_path)
  if ids.length() == 0 {
    return result
  }
  let data_offset = 12
  for i, id in ids {
    let mtime_offset = data_offset + i * 4
    if mtime_offset + 4 > mtimes_data.length() {
      break
    }
    let mtime = read_u32_be_i64(mtimes_data, mtime_offset).to_int()
    result[id] = mtime
  }
  result
}

///|
/// Write a .mtimes file for a cruft pack.
/// Objects must be in the same order as the pack index (lexicographic OID order).
fn write_mtimes_file(
  fs : OsFs,
  mtimes_path : String,
  idx_ids : Array[String],
  mtime_map : Map[String, Int],
  pack_checksum : Bytes,
) -> Unit raise Error {
  // Header: magic + version + hash_id = 12 bytes
  // Data: 4 bytes per object
  // Trailer: pack_checksum (20) + file_checksum (20)
  let data_size = 12 + idx_ids.length() * 4 + 20 + 20
  let buf : Array[Byte] = Array::make(data_size, b'\x00')
  // Magic: MTME = 0x4d544d45
  buf[0] = b'\x4d'
  buf[1] = b'\x54'
  buf[2] = b'\x4d'
  buf[3] = b'\x45'
  // Version: 1
  buf[4] = b'\x00'
  buf[5] = b'\x00'
  buf[6] = b'\x00'
  buf[7] = b'\x01'
  // Hash ID: 1 (SHA1)
  buf[8] = b'\x00'
  buf[9] = b'\x00'
  buf[10] = b'\x00'
  buf[11] = b'\x01'
  // Write mtimes in index order (same as idx_ids order, which is lex sorted)
  for i, id in idx_ids {
    let mtime = mtime_map.get(id).unwrap_or(0)
    let offset = 12 + i * 4
    buf[offset] = ((mtime >> 24) & 0xff).to_byte()
    buf[offset + 1] = ((mtime >> 16) & 0xff).to_byte()
    buf[offset + 2] = ((mtime >> 8) & 0xff).to_byte()
    buf[offset + 3] = (mtime & 0xff).to_byte()
  }
  // Pack checksum (20 bytes)
  let trailer_start = 12 + idx_ids.length() * 4
  for i in 0..<20 {
    if i < pack_checksum.length() {
      buf[trailer_start + i] = pack_checksum[i]
    }
  }
  // File checksum: SHA1 of everything before the file checksum
  let content_len = trailer_start + 20
  let sha = @bitcore.Sha1State::new()
  sha.update(
    Bytes::from_array(FixedArray::makei(content_len, fn(i) { buf[i] })),
  )
  let file_hash = sha.finish()
  let hash_bytes = file_hash.to_bytes()
  for i in 0..<20 {
    buf[content_len + i] = hash_bytes[i]
  }
  let bytes = Bytes::from_array(FixedArray::makei(data_size, fn(i) { buf[i] }))
  fs.write_file(mtimes_path, bytes)
}

///|
/// Get mtime of a file as unix timestamp (seconds).
async fn get_file_mtime_seconds(path : String) -> Int {
  let (sec, _nsec) = @asyncfs.mtime(path[:], follow_symlink=true) catch {
    _ => (0L, 0)
  }
  sec.to_int()
}

///|
/// Collect cruft objects from discard packs and loose objects.
/// Returns (objects, mtime_map) where mtime_map maps hex -> mtime.
async fn collect_cruft_objects(
  fs : OsFs,
  git_dir : String,
  db : @bitlib.ObjectDb,
  keep_names : Array[String],
  discard_names : Array[String],
  expiration : Int64,
  missing_mode : MissingMode,
) -> (Array[@bitcore.PackObject], Map[String, Int]) raise Error {
  let pack_dir = git_dir + "/objects/pack"
  let objects_dir = git_dir + "/objects"
  let alt_dirs = read_alternate_object_dirs(fs, git_dir)
  // Collect all object IDs from keep packs
  let kept_ids : Map[String, Bool] = {}
  for name in keep_names {
    match resolve_pack_path(fs, pack_dir, alt_dirs, name) {
      Some(path) => {
        let idx_path = pack_idx_path(path)
        let ids = collect_pack_index_ids(fs, idx_path)
        for id in ids {
          kept_ids[id] = true
        }
      }
      None => {
        @stdio.stderr.write("fatal: could not find pack '" + name + "'\n")
        @sys.exit(1)
      }
    }
  }
  // Collect cruft objects from discard packs with mtimes
  let mtime_map : Map[String, Int] = {}
  let cruft_ids : Map[String, Bool] = {}
  for name in discard_names {
    match resolve_pack_path(fs, pack_dir, alt_dirs, name) {
      Some(path) => {
        let idx_path = pack_idx_path(path)
        let ids = collect_pack_index_ids(fs, idx_path)
        // Check if this is a cruft pack (has .mtimes file)
        let mtimes_path = if path.has_suffix(".pack") {
          String::unsafe_substring(path, start=0, end=path.length() - 5) +
          ".mtimes"
        } else {
          path + ".mtimes"
        }
        if fs.is_file(mtimes_path) {
          // Read mtimes from the .mtimes file
          let pack_mtimes = read_mtimes_file(fs, mtimes_path, idx_path)
          for id in ids {
            if kept_ids.contains(id) {
              continue
            }
            cruft_ids[id] = true
            let existing = mtime_map.get(id).unwrap_or(0)
            let new_mtime = pack_mtimes.get(id).unwrap_or(0)
            if new_mtime > existing {
              mtime_map[id] = new_mtime
            }
          }
        } else {
          // No .mtimes: use the pack file's mtime for all objects
          let pack_mtime = get_file_mtime_seconds(path)
          for id in ids {
            if kept_ids.contains(id) {
              continue
            }
            cruft_ids[id] = true
            let existing = mtime_map.get(id).unwrap_or(0)
            if pack_mtime > existing {
              mtime_map[id] = pack_mtime
            }
          }
        }
      }
      None => ()
    }
  }
  // Collect loose objects with their file mtimes
  if fs.is_dir(objects_dir) {
    let entries = fs.readdir(objects_dir) catch { _ => [] }
    for entry in entries {
      let name = normalize_dir_entry(entry)
      if name == "info" || name == "pack" {
        continue
      }
      if name.length() != 2 || !(is_hex_string(name)) {
        continue
      }
      let subdir = objects_dir + "/" + name
      if !(fs.is_dir(subdir)) {
        continue
      }
      let files = fs.readdir(subdir) catch { _ => [] }
      for file in files {
        let filename = normalize_dir_entry(file)
        if filename.length() != 38 || !(is_hex_string(filename)) {
          continue
        }
        let hex = name + filename
        if kept_ids.contains(hex) {
          continue
        }
        let path = subdir + "/" + filename
        let mtime = get_file_mtime_seconds(path)
        cruft_ids[hex] = true
        let existing = mtime_map.get(hex).unwrap_or(0)
        if mtime > existing {
          mtime_map[hex] = mtime
        }
      }
    }
  }
  // Apply expiration filter and rescue traversal
  let is_never = expiration == 0L
  let effective_ids : Map[String, Bool] = if is_never {
    // No expiration: include everything
    cruft_ids
  } else {
    // Find recent tips (mtime >= expiration threshold)
    let expiration_int = expiration.to_int()
    let recent_tips : Array[String] = []
    for item in cruft_ids {
      let (id, _) = item
      let mtime = mtime_map.get(id).unwrap_or(0)
      if mtime >= expiration_int {
        recent_tips.push(id)
      }
    }
    // Rescue traversal: objects reachable from recent tips are also kept
    let rescued : Map[String, Bool] = {}
    for tip in recent_tips {
      rescued[tip] = true
      cruft_rescue_walk(
        db,
        fs,
        tip,
        rescued,
        cruft_ids,
        missing_mode is MissingMode::AllowAny,
      )
    }
    rescued
  }
  // Collect actual PackObjects for the cruft pack
  let objects : Array[@bitcore.PackObject] = []
  for item in effective_ids {
    let (hex, _) = item
    let id = @bitcore.ObjectId::from_hex(hex) catch { _ => continue }
    let obj : @bitcore.PackObject? = db.get(fs, id) catch { _ => None }
    match obj {
      Some(o) => objects.push(o)
      None => ()
    }
  }
  (objects, mtime_map)
}

///|
/// Walk from a cruft object to discover all reachable objects for rescue.
fn cruft_rescue_walk(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  hex : String,
  rescued : Map[String, Bool],
  candidate_ids : Map[String, Bool],
  tolerate_missing : Bool,
) -> Unit {
  let id = @bitcore.ObjectId::from_hex(hex) catch { _ => return }
  let obj : @bitcore.PackObject? = db.get(fs, id) catch { _ => None }
  let obj = match obj {
    Some(o) => o
    None => return
  }
  match obj.obj_type {
    @bitcore.ObjectType::Commit => {
      // Rescue parents and tree
      let data_str = bytes_to_string_lossy(obj.data)
      let parts = data_str.split("\n")
      for line_iter in parts {
        let line = line_iter.to_string()
        if line.has_prefix("tree ") {
          let tree_hex = String::unsafe_substring(
              line,
              start=5,
              end=line.length(),
            )
            .trim()
            .to_string()
          if tree_hex.length() == 40 && candidate_ids.contains(tree_hex) {
            if !(rescued.contains(tree_hex)) {
              rescued[tree_hex] = true
              cruft_rescue_walk(
                db, fs, tree_hex, rescued, candidate_ids, tolerate_missing,
              )
            }
          }
        } else if line.has_prefix("parent ") {
          let parent_hex = String::unsafe_substring(
              line,
              start=7,
              end=line.length(),
            )
            .trim()
            .to_string()
          if parent_hex.length() == 40 && candidate_ids.contains(parent_hex) {
            if !(rescued.contains(parent_hex)) {
              rescued[parent_hex] = true
              cruft_rescue_walk(
                db, fs, parent_hex, rescued, candidate_ids, tolerate_missing,
              )
            }
          }
        } else if line.length() == 0 {
          break // End of headers
        }
      }
    }
    @bitcore.ObjectType::Tree => {
      // Rescue sub-trees and blobs
      let entries = @bitcore.parse_tree(obj.data) catch { _ => return }
      for entry in entries {
        let entry_hex = entry.id.to_hex()
        if candidate_ids.contains(entry_hex) {
          if !(rescued.contains(entry_hex)) {
            rescued[entry_hex] = true
            cruft_rescue_walk(
              db, fs, entry_hex, rescued, candidate_ids, tolerate_missing,
            )
          }
        }
      }
    }
    @bitcore.ObjectType::Tag => {
      // Rescue tagged object
      let data_str = bytes_to_string_lossy(obj.data)
      let parts = data_str.split("\n")
      for line_iter in parts {
        let line = line_iter.to_string()
        if line.has_prefix("object ") {
          let target_hex = String::unsafe_substring(
              line,
              start=7,
              end=line.length(),
            )
            .trim()
            .to_string()
          if target_hex.length() == 40 && candidate_ids.contains(target_hex) {
            if !(rescued.contains(target_hex)) {
              rescued[target_hex] = true
              cruft_rescue_walk(
                db, fs, target_hex, rescued, candidate_ids, tolerate_missing,
              )
            }
          }
          break
        }
      }
    }
    @bitcore.ObjectType::Blob => () // Blobs don't reference other objects
  }
}

///|
fn bytes_to_string_lossy(data : Bytes) -> String {
  @encoding.decoder(@encoding.Encoding::UTF8).decode_lossy(data[:])
}

///|
/// Get the pack checksum (last 20 bytes of a pack file).
fn get_pack_checksum_bytes(pack : Bytes) -> Bytes {
  if pack.length() < 20 {
    return Bytes::make(20, b'\x00')
  }
  let start = pack.length() - 20
  Bytes::from_array(FixedArray::makei(20, fn(i) { pack[start + i] }))
}

///|
/// Get sorted object IDs from a pack by parsing it and computing hashes.
fn get_sorted_pack_ids(objects : Array[@bitcore.PackObject]) -> Array[String] {
  let ids : Array[String] = []
  for obj in objects {
    ids.push(@bitcore.hash_object_content(obj.obj_type, obj.data).to_hex())
  }
  ids.sort_by(fn(a, b) { a.compare(b) })
  ids
}
