///|
/// git replace: Create, list, or delete refs to replace objects

///|
async fn handle_replace(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let wfs : &@bitcore.FileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  // Parse arguments
  let mut list_mode = false
  let mut delete_mode = false
  let mut graft_mode = false
  let mut edit_mode = false
  let mut convert_graft_file = false
  let mut force = false
  let mut format : String = "short"
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-h" => {
        print_line(
          "usage: git replace [-f] [-d] [-l [<pattern>]] [--graft <commit> [<parent>...]]",
        )
        @sys.exit(129)
        return
      }
      "-l" | "--list" => {
        list_mode = true
        i += 1
        continue
      }
      "-d" | "--delete" => {
        delete_mode = true
        i += 1
        continue
      }
      "-f" | "--force" => {
        force = true
        i += 1
        continue
      }
      "--graft" => {
        graft_mode = true
        i += 1
        continue
      }
      "--edit" => {
        edit_mode = true
        i += 1
        continue
      }
      "--convert-graft-file" => {
        convert_graft_file = true
        i += 1
        continue
      }
      "--format" if i + 1 < args.length() => {
        format = args[i + 1]
        i += 2
        continue
      }
      _ if arg.has_prefix("--format=") => {
        format = string_slice_from(arg, 9)
        i += 1
        continue
      }
      "--raw" => {
        // --raw is an alias for listing with special handling; ignore for now
        i += 1
        continue
      }
      "--" => {
        i += 1
        while i < args.length() {
          positional.push(args[i])
          i += 1
        }
        continue
      }
      _ if arg.has_prefix("-") && not(delete_mode) => {
        eprint_line("error: unknown option '\{arg}'")
        @sys.exit(129)
        return
      }
      _ => {
        positional.push(arg)
        i += 1
        continue
      }
    }
  }
  if edit_mode {
    eprint_line("error: --edit requires an editor, which is not supported")
    @sys.exit(1)
    return
  }
  if convert_graft_file {
    replace_convert_graft_file(rfs, wfs, git_dir, force)
    return
  }
  if graft_mode {
    if positional.length() < 1 {
      eprint_line("error: --graft requires at least a commit argument")
      @sys.exit(1)
      return
    }
    let commit_ref = positional[0]
    let parent_refs : Array[String] = []
    for j in 1..<positional.length() {
      parent_refs.push(positional[j])
    }
    replace_graft(rfs, wfs, git_dir, commit_ref, parent_refs, force)
    return
  }
  if delete_mode {
    if positional.length() == 0 {
      eprint_line("error: -d requires at least one argument")
      @sys.exit(1)
      return
    }
    for ref_arg in positional {
      replace_delete(rfs, wfs, git_dir, ref_arg)
    }
    return
  }
  // List mode (default) or explicit create
  if positional.length() == 0 || list_mode {
    // List mode
    let pattern : String? = if positional.length() > 0 {
      Some(positional[0])
    } else {
      None
    }
    replace_list(rfs, git_dir, pattern, format)
    return
  }
  if positional.length() == 2 && not(list_mode) {
    // Create mode: <object> <replacement>
    let object_ref = positional[0]
    let replacement_ref = positional[1]
    replace_create(rfs, wfs, git_dir, object_ref, replacement_ref, force)
    return
  }
  if positional.length() == 1 && not(list_mode) {
    // With one argument and no subcommand flags, it's list with a pattern
    replace_list(rfs, git_dir, Some(positional[0]), format)
    return
  }
  eprint_line("error: bad number of arguments")
  @sys.exit(1)
}

///|
fn replace_resolve_to_oid(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  rev : String,
) -> @bitcore.ObjectId raise Error {
  if rev.length() == 40 {
    let valid = rev
      .iter()
      .all(fn(c) {
        (c >= '0' && c <= '9') ||
        (c >= 'a' && c <= 'f') ||
        (c >= 'A' && c <= 'F')
      })
    if valid {
      return @bitcore.ObjectId::from_hex(rev)
    }
  }
  match @bitrepo.rev_parse(fs, git_dir, rev) {
    Some(id) => id
    None =>
      raise @bitcore.GitError::InvalidObject("not a valid object name '\{rev}'")
  }
}

///|
async fn replace_list(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  pattern : String?,
  format : String,
) -> Unit {
  let replace_dir = git_dir + "/refs/replace"
  if not(fs.is_dir(replace_dir)) {
    return
  }
  let entries = fs.readdir(replace_dir) catch { _ => return }
  let oids : Array[String] = []
  for name in entries {
    if name.length() != 40 {
      continue
    }
    let valid = name
      .iter()
      .all(fn(c) {
        (c >= '0' && c <= '9') ||
        (c >= 'a' && c <= 'f') ||
        (c >= 'A' && c <= 'F')
      })
    if not(valid) {
      continue
    }
    match pattern {
      Some(pat) => if not(replace_glob_match(pat, name)) { continue }
      None => ()
    }
    oids.push(name)
  }
  oids.sort()
  for oid in oids {
    match format {
      "short" => print_line(oid)
      "medium" => {
        let ref_path = replace_dir + "/" + oid
        let replacement = replace_read_ref(fs, ref_path)
        match replacement {
          Some(rep) => print_line("\{oid} -> \{rep}")
          None => print_line(oid)
        }
      }
      "long" => {
        let ref_path = replace_dir + "/" + oid
        let replacement = replace_read_ref(fs, ref_path)
        let db = @bitlib.ObjectDb::load(fs, git_dir) catch {
          _ => {
            print_line(oid)
            continue
          }
        }
        let orig_type = replace_get_object_type_str(db, fs, oid)
        match replacement {
          Some(rep) => {
            let rep_type = replace_get_object_type_str(db, fs, rep)
            print_line("\{oid} (\{orig_type}) -> \{rep} (\{rep_type})")
          }
          None => print_line(oid)
        }
      }
      _ => print_line(oid)
    }
  }
}

///|
fn replace_get_object_type_str(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  hex : String,
) -> String raise Error {
  let id = @bitcore.ObjectId::from_hex(hex)
  let obj = db.get(fs, id) catch { _ => return "unknown" }
  match obj {
    Some(o) =>
      match o.obj_type {
        @bitcore.ObjectType::Commit => "commit"
        @bitcore.ObjectType::Tree => "tree"
        @bitcore.ObjectType::Blob => "blob"
        @bitcore.ObjectType::Tag => "tag"
      }
    None => "unknown"
  }
}

///|
fn replace_read_ref(fs : &@bitcore.RepoFileSystem, path : String) -> String? {
  let content = fs.read_file(path) catch { _ => return None }
  let text = decode_bytes(content)
  let trimmed = trim_chars(text, " \t\r\n")
  if trimmed.length() >= 40 {
    Some(trimmed)
  } else {
    None
  }
}

///|
async fn replace_create(
  fs : &@bitcore.RepoFileSystem,
  wfs : &@bitcore.FileSystem,
  git_dir : String,
  object_ref : String,
  replacement_ref : String,
  force : Bool,
) -> Unit raise Error {
  let object_id = replace_resolve_to_oid(fs, git_dir, object_ref)
  let replacement_id = replace_resolve_to_oid(fs, git_dir, replacement_ref)
  // Validate both objects exist
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let obj = db.get(fs, object_id)
  if obj is None {
    eprint_line("error: object '\{object_ref}' does not exist")
    @sys.exit(1)
    return
  }
  let rep = db.get(fs, replacement_id)
  if rep is None {
    eprint_line("error: replacement object '\{replacement_ref}' does not exist")
    @sys.exit(1)
    return
  }
  let replace_dir = git_dir + "/refs/replace"
  let ref_path = replace_dir + "/" + object_id.to_hex()
  if not(force) && fs.is_file(ref_path) {
    eprint_line(
      "error: replace ref 'refs/replace/\{object_id.to_hex()}' already exists",
    )
    @sys.exit(1)
    return
  }
  wfs.mkdir_p(replace_dir)
  wfs.write_string(ref_path, replacement_id.to_hex() + "\n")
}

///|
async fn replace_delete(
  fs : &@bitcore.RepoFileSystem,
  wfs : &@bitcore.FileSystem,
  git_dir : String,
  ref_arg : String,
) -> Unit raise Error {
  let oid = replace_resolve_to_oid(fs, git_dir, ref_arg)
  let hex = oid.to_hex()
  let ref_path = git_dir + "/refs/replace/" + hex
  if not(fs.is_file(ref_path)) {
    eprint_line("error: replace ref 'refs/replace/\{hex}' not found")
    @sys.exit(1)
    return
  }
  wfs.remove_file(ref_path)
  print_line("Deleted replace ref '\{hex}'")
}

///|
async fn replace_graft(
  fs : &@bitcore.RepoFileSystem,
  wfs : &@bitcore.FileSystem,
  git_dir : String,
  commit_ref : String,
  parent_refs : Array[String],
  force : Bool,
) -> Unit raise Error {
  let commit_id = replace_resolve_to_oid(fs, git_dir, commit_ref)
  // Read the original commit object
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let commit_obj = db.get(fs, commit_id)
  guard commit_obj is Some(obj) else {
    eprint_line("error: object '\{commit_ref}' does not exist")
    @sys.exit(1)
    return
  }
  if obj.obj_type != @bitcore.ObjectType::Commit {
    eprint_line("error: '\{commit_ref}' is not a commit")
    @sys.exit(1)
    return
  }
  // Parse the commit content to extract headers and message
  let content_text = decode_bytes(obj.data)
  // Rebuild the commit with new parents
  let new_parents : Array[@bitcore.ObjectId] = []
  for pref in parent_refs {
    let pid = replace_resolve_to_oid(fs, git_dir, pref)
    new_parents.push(pid)
  }
  let new_commit_content = replace_rebuild_commit(content_text, new_parents)
  // Create the new commit object
  let new_bytes = @bitcore.create_object(
    @bitcore.ObjectType::Commit,
    new_commit_content,
  )
  let new_commit_id = new_bytes.0
  let compressed = new_bytes.1
  @bitlib.write_object_bytes(wfs, git_dir, new_commit_id, compressed)
  // Check if the new commit is the same as old (same parents already)
  if new_commit_id == commit_id {
    eprint_line(
      "error: new commit is the same as the old one: '\{commit_id.to_hex()}'",
    )
    @sys.exit(1)
    return
  }
  // Create replace ref
  let replace_dir = git_dir + "/refs/replace"
  let ref_path = replace_dir + "/" + commit_id.to_hex()
  if not(force) && fs.is_file(ref_path) {
    eprint_line(
      "error: replace ref 'refs/replace/\{commit_id.to_hex()}' already exists",
    )
    @sys.exit(1)
    return
  }
  wfs.mkdir_p(replace_dir)
  wfs.write_string(ref_path, new_commit_id.to_hex() + "\n")
}

///|
/// Rebuild a commit object content with new parents.
/// Parses the original commit text, replaces parent lines, preserves everything else.
fn replace_rebuild_commit(
  original : String,
  new_parents : Array[@bitcore.ObjectId],
) -> Bytes {
  let result : Array[Byte] = []
  let lines = replace_split_lines_keep_newlines(original)
  let mut in_header = true
  let mut wrote_parents = false
  let mut past_tree = false
  for line in lines {
    if in_header {
      if line == "\n" || line == "" {
        // End of header: if we haven't written parents yet, do so now
        if not(wrote_parents) {
          for parent_id in new_parents {
            let pline = "parent " + parent_id.to_hex() + "\n"
            for c in pline {
              result.push(c.to_int().to_byte())
            }
          }
          wrote_parents = true
        }
        in_header = false
        // Write the blank line separator
        for c in line {
          result.push(c.to_int().to_byte())
        }
        continue
      }
      if line.has_prefix("tree ") {
        // Keep the tree line
        for c in line {
          result.push(c.to_int().to_byte())
        }
        past_tree = true
        continue
      }
      if line.has_prefix("parent ") {
        // Skip original parent lines; we'll write new ones
        if not(wrote_parents) && past_tree {
          for parent_id in new_parents {
            let pline = "parent " + parent_id.to_hex() + "\n"
            for c in pline {
              result.push(c.to_int().to_byte())
            }
          }
          wrote_parents = true
        }
        continue
      }
      // Other header lines (author, committer, etc.)
      // If we haven't written parents yet and we're past tree, do it now
      if not(wrote_parents) && past_tree {
        for parent_id in new_parents {
          let pline = "parent " + parent_id.to_hex() + "\n"
          for c in pline {
            result.push(c.to_int().to_byte())
          }
        }
        wrote_parents = true
      }
      for c in line {
        result.push(c.to_int().to_byte())
      }
    } else {
      // Message body: keep as-is
      for c in line {
        result.push(c.to_int().to_byte())
      }
    }
  }
  let fa = FixedArray::makei(result.length(), fn(i) { result[i] })
  Bytes::from_array(fa)
}

///|
/// Split a string into lines, keeping the newline character at the end of each line.
fn replace_split_lines_keep_newlines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let buf = StringBuilder::new()
  for c in text {
    buf.write_char(c)
    if c == '\n' {
      lines.push(buf.to_string())
      buf.reset()
    }
  }
  let remaining = buf.to_string()
  if remaining.length() > 0 {
    lines.push(remaining)
  }
  lines
}

///|
async fn replace_convert_graft_file(
  fs : &@bitcore.RepoFileSystem,
  wfs : &@bitcore.FileSystem,
  git_dir : String,
  force : Bool,
) -> Unit raise Error {
  let graft_path = git_dir + "/info/grafts"
  if not(fs.is_file(graft_path)) {
    eprint_line("error: could not read graft file '\{graft_path}'")
    @sys.exit(1)
    return
  }
  let content = fs.read_file(graft_path) catch {
    _ => {
      eprint_line("error: could not read graft file '\{graft_path}'")
      @sys.exit(1)
      return
    }
  }
  let text = decode_bytes(content)
  let mut count = 0
  for line_view in text.split("\n") {
    let line = trim_chars(line_view.to_string(), " \t\r")
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    // Parse: <commit> [<parent1> <parent2> ...]
    let parts : Array[String] = []
    for part_view in line.split(" ") {
      let part = trim_chars(part_view.to_string(), " \t")
      if part.length() > 0 {
        parts.push(part)
      }
    }
    if parts.length() < 1 {
      continue
    }
    let commit_ref = parts[0]
    let parent_refs : Array[String] = []
    for j in 1..<parts.length() {
      parent_refs.push(parts[j])
    }
    replace_graft(fs, wfs, git_dir, commit_ref, parent_refs, force)
    count += 1
  }
  if count > 0 {
    print_line(
      "Converted \{count} graft(s) to replace refs. You can now delete '\{graft_path}'.",
    )
  }
}

///|
fn replace_glob_match(pattern : String, text : String) -> Bool {
  let p = pattern.to_array()
  let t = text.to_array()
  let plen = p.length()
  let tlen = t.length()
  let mut pi = 0
  let mut ti = 0
  let mut star_pi = -1
  let mut star_ti = -1
  while ti < tlen {
    if pi < plen && (p[pi] == t[ti] || p[pi] == '?') {
      pi += 1
      ti += 1
    } else if pi < plen && p[pi] == '*' {
      star_pi = pi
      star_ti = ti
      pi += 1
    } else if star_pi >= 0 {
      pi = star_pi + 1
      star_ti += 1
      ti = star_ti
    } else {
      return false
    }
  }
  while pi < plen && p[pi] == '*' {
    pi += 1
  }
  pi == plen
}
