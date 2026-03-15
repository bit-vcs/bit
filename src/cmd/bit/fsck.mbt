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
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  // Phase 1: Check HEAD and get resolved OID
  let (head_errors, head_oid) = fsck_check_and_resolve_head(fs, git_dir)
  errors += head_errors
  // Phase 2: Verify loose objects (hash check)
  if not(connectivity_only) {
    errors += fsck_verify_loose_objects(fs, objects_dir)
  }
  // Phase 3: Verify pack files
  if not(connectivity_only) {
    errors += fsck_verify_packs(fs, objects_dir)
  }
  // Phase 4: Connectivity check via pure lib function
  let ref_tips : Array[@bitcore.ObjectId] = []
  let refs = @bitrepo.show_ref(fs, git_dir)
  for item in refs {
    ref_tips.push(item.1)
  }
  match head_oid {
    Some(id) => ref_tips.push(id)
    None => ()
  }
  if not(no_reflogs) {
    fsck_collect_reflog_tips(fs, git_dir, ref_tips)
  }
  let need_extra = show_root || show_tags
  let result = @bitlib.fsck_connectivity_check(
    db,
    fs,
    ref_tips,
    collect_extra=need_extra,
  )
  errors += result.errors
  // Report missing objects
  for hex, _ in result.missing {
    eprint_line("error: \{hex}: missing object")
  }
  // Phase 5: Enumerate and report dangling/unreachable
  let need_all = show_dangling || show_unreachable || lost_found
  if need_all {
    let all_objects = @bitlib.fsck_enumerate_objects(db)
    for hex in all_objects {
      if not(result.reachable.contains(hex)) {
        let obj_type = @bitlib.fsck_object_type(db, fs, hex)
        if show_unreachable {
          eprint_line("unreachable \{obj_type} \{hex}")
        } else if show_dangling {
          eprint_line("dangling \{obj_type} \{hex}")
        }
      }
    }
    if lost_found {
      fsck_write_lost_found(fs, git_dir, db, all_objects, result.reachable)
    }
  }
  if show_root {
    for hex in result.root_commits {
      eprint_line("root \{hex}")
    }
  }
  if show_tags {
    for hex in result.tag_objects {
      eprint_line("tagged \{hex}")
    }
  }
  if verbose {
    eprint_line("Checking object directory")
  }
  if errors > 0 {
    @sys.exit(1)
  }
}

///|
/// Check HEAD validity and return (error_count, resolved_oid).
async fn fsck_check_and_resolve_head(
  fs : OsFs,
  git_dir : String,
) -> (Int, @bitcore.ObjectId?) {
  let head_path = git_dir + "/HEAD"
  if not(fs.is_file(head_path)) {
    eprint_line("error: HEAD is missing")
    return (1, None)
  }
  let content = @utf8.decode_lossy(fs.read_file(head_path)[:]) catch {
    _ => {
      eprint_line("error: could not read HEAD")
      return (1, None)
    }
  }
  let trimmed = trim_string(content)
  if trimmed.length() == 0 {
    eprint_line("error: HEAD is empty")
    return (1, None)
  }
  if trimmed.has_prefix("ref: ") {
    let refname = String::unsafe_substring(
      trimmed,
      start=5,
      end=trimmed.length(),
    )
    if not(refname.has_prefix("refs/heads/")) {
      eprint_line("warning: HEAD points to non-branch '\{refname}'")
    }
    let resolved = fsck_resolve_ref(fs, git_dir, refname)
    return (0, resolved)
  }
  if trimmed.length() == 40 {
    let id = @bitcore.ObjectId::from_hex(trimmed) catch {
      _ => {
        eprint_line(
          "error: HEAD: badRefOid: points to invalid object ID '\{trimmed}'",
        )
        return (1, None)
      }
    }
    return (0, Some(id))
  }
  eprint_line(
    "error: HEAD: badRefOid: points to invalid object ID '\{trimmed}'",
  )
  (1, None)
}

///|
fn fsck_resolve_ref(
  fs : OsFs,
  git_dir : String,
  refname : String,
) -> @bitcore.ObjectId? {
  let ref_path = git_dir + "/" + refname
  if fs.is_file(ref_path) {
    let ref_content = @utf8.decode_lossy(fs.read_file(ref_path)[:]) catch {
      _ => return None
    }
    let hex = trim_string(ref_content)
    let id = @bitcore.ObjectId::from_hex(hex) catch { _ => return None }
    return Some(id)
  }
  let packed_path = git_dir + "/packed-refs"
  if not(fs.is_file(packed_path)) {
    return None
  }
  let packed = @utf8.decode_lossy(fs.read_file(packed_path)[:]) catch {
    _ => return None
  }
  for line_view in packed.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("#") || line.has_prefix("^") || line.length() == 0 {
      continue
    }
    let space = line.find(" ")
    match space {
      Some(idx) => {
        let hex = String::unsafe_substring(line, start=0, end=idx)
        let name = trim_string(
          String::unsafe_substring(line, start=idx + 1, end=line.length()),
        )
        if name == refname {
          let id = @bitcore.ObjectId::from_hex(hex) catch { _ => return None }
          return Some(id)
        }
      }
      None => ()
    }
  }
  None
}

///|
async fn fsck_verify_loose_objects(fs : OsFs, objects_dir : String) -> Int {
  let mut errors = 0
  if not(fs.is_dir(objects_dir)) {
    return 0
  }
  let entries = fs.readdir(objects_dir) catch { _ => return 0 }
  for entry in entries {
    if entry == "info" || entry == "pack" || entry.length() != 2 {
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
      if not(@bitlib.fsck_verify_loose_hash(raw, hex)) {
        eprint_line("error: hash mismatch for \{hex}")
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
  let zero_hex = @bitcore.ObjectId::zero().to_hex()
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
        if log_entry.new_id.to_hex() != zero_hex {
          tips.push(log_entry.new_id)
        }
        if log_entry.old_id.to_hex() != zero_hex {
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
  ensure_dir(lf_dir) catch { _ => return }
  ensure_dir(commit_dir) catch { _ => return }
  ensure_dir(other_dir) catch { _ => return }
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
        @fs.write_bytes_to_file(dir + "/" + hex, o.data) catch { _ => () }
      }
    }
  }
}

///|
