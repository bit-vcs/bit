///|
async fn handle_fsck(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let git_dir = resolve_git_dir(fs, root)
  // Parse flags
  let mut verbose = false
  let mut show_unreachable = false
  let mut show_dangling = true
  let mut show_root = false
  let mut show_tags = false
  let mut connectivity_only = false
  let mut full = false
  let mut strict = false
  let mut no_reflogs = false
  let mut lost_found = false
  let mut name_objects = false
  let mut no_progress = false
  let specific_objects : Array[String] = []
  for arg in args {
    match arg {
      "-v" | "--verbose" => verbose = true
      "--unreachable" => show_unreachable = true
      "--dangling" => show_dangling = true
      "--no-dangling" => show_dangling = false
      "--root" => show_root = true
      "--tags" => show_tags = true
      "--connectivity-only" => connectivity_only = true
      "--full" => full = true
      "--strict" => strict = true
      "--no-reflogs" => no_reflogs = true
      "--lost-found" => {
        lost_found = true
        show_unreachable = true
      }
      "--name-objects" => name_objects = true
      "--no-progress" => no_progress = true
      "--progress" => no_progress = false
      _ if arg.has_prefix("-") => warn_unimplemented_arg("fsck", arg)
      _ => specific_objects.push(arg)
    }
  }
  ignore(name_objects)
  ignore(no_progress)
  ignore(strict)
  ignore(full)
  ignore(specific_objects)
  let mut errors = 0
  let objects_dir = git_dir + "/objects"
  // Load object database
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  // Phase 1: Check HEAD
  errors += fsck_check_head(fs, git_dir)
  // Phase 2: Verify loose objects (hash check)
  if not(connectivity_only) {
    errors += fsck_verify_loose_objects(fs, objects_dir)
  }
  // Phase 3: Verify pack files
  if not(connectivity_only) {
    errors += fsck_verify_packs(fs, objects_dir)
  }
  // Phase 4: Connectivity check - walk from all refs
  let reachable : Map[String, Bool] = {}
  let missing : Map[String, Bool] = {}
  // Collect all ref tips
  let refs = @bitrepo.show_ref(fs, git_dir)
  let ref_tips : Array[@bitcore.ObjectId] = []
  for item in refs {
    let (_, id) = item
    ref_tips.push(id)
  }
  // Also add HEAD
  let head_content = fsck_read_head(fs, git_dir)
  match head_content {
    Some(hex) => {
      let id = @bitcore.ObjectId::from_hex(hex) catch {
        _ => @bitcore.ObjectId::zero()
      }
      if id.to_hex() != "0000000000000000000000000000000000000000" {
        ref_tips.push(id)
      }
    }
    None => ()
  }
  // Add reflog entries if not --no-reflogs
  if not(no_reflogs) {
    fsck_collect_reflog_tips(fs, git_dir, ref_tips)
  }
  // Walk from all tips — use cursor instead of queue.remove(0) for O(1) dequeue
  for tip in ref_tips {
    errors += fsck_walk_object(db, fs, tip, reachable, missing)
  }
  // Phase 5: Enumerate all objects and find dangling/unreachable
  // Reuse db.loose_paths and db.packs for enumeration instead of re-scanning filesystem
  let all_objects = fsck_enumerate_all_objects_fast(db, objects_dir, fs)
  if show_dangling || show_unreachable {
    for hex in all_objects {
      if not(reachable.contains(hex)) {
        let obj_type = fsck_get_object_type(db, fs, hex)
        if show_unreachable {
          eprint_line("unreachable \{obj_type} \{hex}")
        } else if show_dangling {
          eprint_line("dangling \{obj_type} \{hex}")
        }
      }
    }
  }
  // Report root commits
  if show_root {
    for hex in all_objects {
      if reachable.contains(hex) {
        let obj = db.get(fs, @bitcore.ObjectId::from_hex(hex)) catch {
          _ => None
        }
        match obj {
          Some(o) =>
            if o.obj_type == @bitcore.ObjectType::Commit {
              let info = @bitcore.parse_commit(o.data) catch { _ => continue }
              if info.parents.length() == 0 {
                eprint_line("root \{hex}")
              }
            }
          None => ()
        }
      }
    }
  }
  // Report tagged objects
  if show_tags {
    for hex in all_objects {
      if reachable.contains(hex) {
        let obj = db.get(fs, @bitcore.ObjectId::from_hex(hex)) catch {
          _ => None
        }
        match obj {
          Some(o) =>
            if o.obj_type == @bitcore.ObjectType::Tag {
              eprint_line("tagged \{hex}")
            }
          None => ()
        }
      }
    }
  }
  // Create lost-found directory if needed
  if lost_found {
    fsck_write_lost_found(fs, git_dir, db, all_objects, reachable)
  }
  if verbose {
    eprint_line("Checking object directory")
  }
  if errors > 0 {
    @sys.exit(1)
  }
}

///|
async fn fsck_check_head(fs : OsFs, git_dir : String) -> Int {
  let head_path = git_dir + "/HEAD"
  if not(fs.is_file(head_path)) {
    eprint_line("error: HEAD is missing")
    return 1
  }
  let content = @utf8.decode_lossy(fs.read_file(head_path)[:]) catch {
    _ => {
      eprint_line("error: could not read HEAD")
      return 1
    }
  }
  let trimmed = fsck_trim(content)
  if trimmed.length() == 0 {
    eprint_line("error: HEAD is empty")
    return 1
  }
  if trimmed.has_prefix("ref: ") {
    let refname = String::unsafe_substring(
      trimmed,
      start=5,
      end=trimmed.length(),
    )
    // HEAD should point to refs/heads/
    if not(refname.has_prefix("refs/heads/")) {
      eprint_line("warning: HEAD points to non-branch '\{refname}'")
    }
    return 0
  }
  if trimmed.length() == 40 {
    // Detached HEAD - verify it's a valid hex
    for i in 0..<40 {
      let c = trimmed.unsafe_get(i).to_int().unsafe_to_char()
      if not(fsck_is_hex_char(c)) {
        eprint_line(
          "error: HEAD: badRefOid: points to invalid object ID '\{trimmed}'",
        )
        return 1
      }
    }
    return 0
  }
  eprint_line(
    "error: HEAD: badRefOid: points to invalid object ID '\{trimmed}'",
  )
  1
}

///|
fn fsck_read_head(fs : OsFs, git_dir : String) -> String? {
  let head_path = git_dir + "/HEAD"
  if not(fs.is_file(head_path)) {
    return None
  }
  let content = @utf8.decode_lossy(fs.read_file(head_path)[:]) catch {
    _ => return None
  }
  let trimmed = fsck_trim(content)
  if trimmed.has_prefix("ref: ") {
    let refname = String::unsafe_substring(
      trimmed,
      start=5,
      end=trimmed.length(),
    )
    // Resolve the ref
    let ref_path = git_dir + "/" + refname
    if fs.is_file(ref_path) {
      let ref_content = @utf8.decode_lossy(fs.read_file(ref_path)[:]) catch {
        _ => return None
      }
      return Some(fsck_trim(ref_content))
    }
    // Try packed-refs
    let packed_path = git_dir + "/packed-refs"
    if fs.is_file(packed_path) {
      let packed = @utf8.decode_lossy(fs.read_file(packed_path)[:]) catch {
        _ => return None
      }
      for line_view in packed.split("\n") {
        let line = line_view.to_string()
        if line.has_prefix("#") || line.has_prefix("^") {
          continue
        }
        let space = line.find(" ")
        match space {
          Some(idx) => {
            let hex = String::unsafe_substring(line, start=0, end=idx)
            let name = String::unsafe_substring(
              line,
              start=idx + 1,
              end=line.length(),
            )
            if fsck_trim(name) == refname {
              return Some(hex)
            }
          }
          None => ()
        }
      }
    }
    None
  } else if trimmed.length() == 40 {
    Some(trimmed)
  } else {
    None
  }
}

///|
async fn fsck_verify_loose_objects(fs : OsFs, objects_dir : String) -> Int {
  let mut errors = 0
  if not(fs.is_dir(objects_dir)) {
    return 0
  }
  let entries = fs.readdir(objects_dir) catch { _ => return 0 }
  for entry in entries {
    if entry == "info" || entry == "pack" {
      continue
    }
    if entry.length() != 2 {
      continue
    }
    let subdir = objects_dir + "/" + entry
    if not(fs.is_dir(subdir)) {
      continue
    }
    let files = fs.readdir(subdir) catch { _ => continue }
    for name in files {
      if name.length() != 38 {
        continue
      }
      let hex = entry + name
      let path = subdir + "/" + name
      // Try to decompress and verify the object
      let data = fs.read_file(path) catch {
        _ => {
          eprint_line("error: \{hex}: object corrupt or missing: \{path}")
          errors += 1
          continue
        }
      }
      let raw = @zlib.zlib_decompress(data) catch {
        _ => {
          eprint_line("error: \{hex}: object corrupt or missing: \{path}")
          errors += 1
          continue
        }
      }
      // Verify hash directly on raw (header+content) — avoids content copy
      // Git loose objects are stored as "<type> <size>\0<content>",
      // and SHA-1 is computed on exactly that byte sequence.
      let computed = @bitcore.sha1(raw)
      if computed.to_hex() != hex {
        eprint_line(
          "error: hash mismatch for \{hex} (expected \{computed.to_hex()})",
        )
        errors += 1
      }
    }
  }
  errors
}

///|
async fn fsck_verify_packs(fs : OsFs, objects_dir : String) -> Int {
  let mut errors = 0
  let pack_dir = objects_dir + "/pack"
  if not(fs.is_dir(pack_dir)) {
    return 0
  }
  let entries = fs.readdir(pack_dir) catch { _ => return 0 }
  for entry in entries {
    if not(entry.has_suffix(".idx")) {
      continue
    }
    // Verify corresponding pack file exists
    let stem = String::unsafe_substring(entry, start=0, end=entry.length() - 4)
    let pack_file = pack_dir + "/" + stem + ".pack"
    if not(fs.is_file(pack_file)) {
      eprint_line("error: pack index \{entry} has no corresponding pack file")
      errors += 1
    }
  }
  errors
}

///|
async fn fsck_walk_object(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  id : @bitcore.ObjectId,
  reachable : Map[String, Bool],
  missing : Map[String, Bool],
) -> Int {
  let mut errors = 0
  // BFS walk with cursor (avoids O(n) queue.remove(0))
  let queue : Array[@bitcore.ObjectId] = [id]
  let mut cursor = 0
  while cursor < queue.length() {
    let current = queue[cursor]
    cursor += 1
    let hex = current.to_hex()
    if reachable.contains(hex) {
      continue
    }
    reachable[hex] = true
    let obj = db.get(fs, current) catch {
      _ => {
        if not(missing.contains(hex)) {
          missing[hex] = true
          eprint_line("error: \{hex}: missing object")
          errors += 1
        }
        continue
      }
    }
    match obj {
      None =>
        if not(missing.contains(hex)) {
          missing[hex] = true
          eprint_line("error: \{hex}: missing object")
          errors += 1
        }
      Some(o) =>
        match o.obj_type {
          @bitcore.ObjectType::Commit => {
            let info = @bitcore.parse_commit(o.data) catch {
              _ => {
                eprint_line("error: \{hex}: bad commit object")
                errors += 1
                continue
              }
            }
            if not(reachable.contains(info.tree.to_hex())) {
              queue.push(info.tree)
            }
            for parent in info.parents {
              if not(reachable.contains(parent.to_hex())) {
                queue.push(parent)
              }
            }
          }
          @bitcore.ObjectType::Tree => {
            let entries = @bitcore.parse_tree(o.data) catch {
              _ => {
                eprint_line("error: \{hex}: bad tree object")
                errors += 1
                continue
              }
            }
            for entry in entries {
              if not(reachable.contains(entry.id.to_hex())) {
                queue.push(entry.id)
              }
            }
          }
          @bitcore.ObjectType::Tag => {
            let text = @utf8.decode_lossy(o.data[:])
            for line_view in text.split("\n") {
              let line = line_view.to_string()
              if line.length() == 0 {
                break
              }
              if line.has_prefix("object ") {
                let target_hex = String::unsafe_substring(
                  line,
                  start=7,
                  end=line.length(),
                )
                let target = @bitcore.ObjectId::from_hex(target_hex) catch {
                  _ => continue
                }
                if not(reachable.contains(target.to_hex())) {
                  queue.push(target)
                }
                break
              }
            }
          }
          @bitcore.ObjectType::Blob => ()
        }
    }
  }
  errors
}

///|
/// Enumerate all objects using db's already-loaded loose_paths and pack indexes.
/// Avoids re-scanning the filesystem when ObjectDb::load already did it.
fn fsck_enumerate_all_objects_fast(
  db : @bitlib.ObjectDb,
  _objects_dir : String,
  _fs : OsFs,
) -> Array[String] {
  let all : Array[String] = []
  let seen : Map[String, Bool] = {}
  // Loose objects from db.loose_paths (already collected during ObjectDb::load)
  for item in db.loose_paths.to_array() {
    let hex = item.0
    if not(seen.contains(hex)) {
      seen[hex] = true
      all.push(hex)
    }
  }
  // Packed objects from loaded indexes
  for pack in db.packs {
    for id in pack.ids {
      if not(seen.contains(id)) {
        seen[id] = true
        all.push(id)
      }
    }
  }
  all
}

///|
fn fsck_get_object_type(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  hex : String,
) -> String {
  let id = @bitcore.ObjectId::from_hex(hex) catch { _ => return "blob" }
  let obj = db.get(fs, id) catch { _ => return "blob" }
  match obj {
    None => "blob"
    Some(o) => fsck_type_name(o.obj_type)
  }
}

///|
fn fsck_type_name(obj_type : @bitcore.ObjectType) -> String {
  match obj_type {
    @bitcore.ObjectType::Commit => "commit"
    @bitcore.ObjectType::Tree => "tree"
    @bitcore.ObjectType::Blob => "blob"
    @bitcore.ObjectType::Tag => "tag"
  }
}

///|
fn fsck_collect_reflog_tips(
  fs : OsFs,
  git_dir : String,
  tips : Array[@bitcore.ObjectId],
) -> Unit {
  let logs_dir = git_dir + "/logs"
  if not(fs.is_dir(logs_dir)) {
    return
  }
  fsck_collect_reflog_tips_dir(fs, git_dir, logs_dir, tips)
}

///|
fn fsck_collect_reflog_tips_dir(
  fs : OsFs,
  git_dir : String,
  dir : String,
  tips : Array[@bitcore.ObjectId],
) -> Unit {
  let entries = fs.readdir(dir) catch { _ => return }
  for entry in entries {
    let path = dir + "/" + entry
    if fs.is_dir(path) {
      fsck_collect_reflog_tips_dir(fs, git_dir, path, tips)
    } else if fs.is_file(path) {
      let prefix = git_dir + "/logs/"
      let refname = if path.has_prefix(prefix) {
        String::unsafe_substring(path, start=prefix.length(), end=path.length())
      } else {
        entry
      }
      let log_entries = @bitlib.read_reflog(fs, git_dir, refname) catch {
        _ => continue
      }
      for log_entry in log_entries {
        let new_hex = log_entry.new_id.to_hex()
        if new_hex != "0000000000000000000000000000000000000000" {
          tips.push(log_entry.new_id)
        }
        let old_hex = log_entry.old_id.to_hex()
        if old_hex != "0000000000000000000000000000000000000000" {
          tips.push(log_entry.old_id)
        }
      }
    }
  }
}

///|
fn fsck_write_lost_found(
  fs : OsFs,
  git_dir : String,
  db : @bitlib.ObjectDb,
  all_objects : Array[String],
  reachable : Map[String, Bool],
) -> Unit {
  let lf_dir = git_dir + "/lost-found"
  let commit_dir = lf_dir + "/commit"
  let other_dir = lf_dir + "/other"
  ensure_dir(lf_dir) catch {
    _ => return
  }
  ensure_dir(commit_dir) catch {
    _ => return
  }
  ensure_dir(other_dir) catch {
    _ => return
  }
  for hex in all_objects {
    if reachable.contains(hex) {
      continue
    }
    let id = @bitcore.ObjectId::from_hex(hex) catch { _ => continue }
    let obj = db.get(fs, id) catch { _ => continue }
    match obj {
      None => ()
      Some(o) => {
        let dir = if o.obj_type == @bitcore.ObjectType::Commit {
          commit_dir
        } else {
          other_dir
        }
        let path = dir + "/" + hex
        @fs.write_bytes_to_file(path, o.data) catch {
          _ => ()
        }
      }
    }
  }
}

///|
fn fsck_trim(s : String) -> String {
  let mut end = s.length()
  while end > 0 {
    let c = s.unsafe_get(end - 1)
    if c == '\n' || c == '\r' || c == ' ' || c == '\t' {
      end -= 1
    } else {
      break
    }
  }
  let mut start = 0
  while start < end {
    let c = s.unsafe_get(start)
    if c == ' ' || c == '\t' {
      start += 1
    } else {
      break
    }
  }
  if start == 0 && end == s.length() {
    s
  } else {
    String::unsafe_substring(s, start~, end~)
  }
}

///|
fn fsck_is_hex_char(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
