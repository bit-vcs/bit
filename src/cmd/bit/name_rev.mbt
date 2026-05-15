///| git name-rev - find symbolic names for given revs

///|
async fn handle_name_rev(args : Array[String]) -> Unit raise Error {
  let mut tags_only = false
  let mut name_only = false
  let mut read_stdin = false
  let mut refs_pattern : String? = None
  let mut all = false
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git name-rev [--tags] [--refs=<pattern>] [--name-only] [--stdin] <commit-ish>...",
          summary="Find symbolic names for given revs.",
        )
        return
      }
      "--tags" => tags_only = true
      "--name-only" => name_only = true
      "--stdin" => read_stdin = true
      "--all" => all = true
      _ if arg.has_prefix("--refs=") =>
        refs_pattern = Some(
          String::unsafe_substring(arg, start=7, end=arg.length()),
        )
      "--refs" => {
        i += 1
        if i < args.length() {
          refs_pattern = Some(args[i])
        }
      }
      "--no-undefined" | "--always" | "--undefined" => ()
      _ if arg.has_prefix("-") => warn_unimplemented_arg("name-rev", arg)
      _ => positional.push(arg)
    }
    i += 1
  }
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  // Build ref->commit map
  let ref_map = name_rev_build_ref_map(rfs, git_dir, tags_only, refs_pattern)
  // Build reverse map: commit OID -> (name, distance)
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let name_map = name_rev_build_name_map(rfs, git_dir, db, ref_map)
  if all {
    // Print all refs with their name
    for entry in name_map {
      let (oid_hex, name) = entry
      if name_only {
        print_line(name)
      } else {
        print_line("\{oid_hex} \{name}")
      }
    }
    return
  }
  if read_stdin {
    let input = decode_bytes(read_all_stdin())
    for line_view in input.split("\n") {
      let line = line_view.to_string()
      if line.length() == 0 {
        continue
      }
      // Try to find and replace hex OIDs in the line
      let output = name_rev_replace_oids(line, name_map)
      print_line(output)
    }
    return
  }
  // Named commits from positional args
  for commit_ref in positional {
    let oid = @bitrepo.rev_parse(rfs, git_dir, commit_ref)
    match oid {
      Some(id) => {
        let hex = id.to_hex()
        match name_map.get(hex) {
          Some(name) =>
            if name_only {
              print_line(name)
            } else {
              print_line("\{commit_ref} \{name}")
            }
          None =>
            if name_only {
              print_line("undefined")
            } else {
              print_line("\{commit_ref} undefined")
            }
        }
      }
      None => {
        eprint_line("error: unknown revision '\{commit_ref}'")
        @sys.exit(1)
      }
    }
  }
}

///|
fn name_rev_build_ref_map(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  tags_only : Bool,
  refs_pattern : String?,
) -> Array[(String, @bitcore.ObjectId)] {
  let all_refs = @bitrepo.show_ref(rfs, git_dir) catch { _ => [] }
  let result : Array[(String, @bitcore.ObjectId)] = []
  for item in all_refs {
    let (name, id) = item
    // Filter by tags if requested
    if tags_only && !name.has_prefix("refs/tags/") {
      continue
    }
    // Filter by pattern if given
    match refs_pattern {
      Some(pattern) => if !name_rev_match_pattern(name, pattern) { continue }
      None => ()
    }
    // Shorten the ref name for display
    let display_name = if name.has_prefix("refs/tags/") {
      "tags/" + String::unsafe_substring(name, start=10, end=name.length())
    } else if name.has_prefix("refs/heads/") {
      String::unsafe_substring(name, start=11, end=name.length())
    } else if name.has_prefix("refs/remotes/") {
      "remotes/" + String::unsafe_substring(name, start=13, end=name.length())
    } else {
      name
    }
    result.push((display_name, id))
  }
  result
}

///|
fn name_rev_match_pattern(name : String, pattern : String) -> Bool {
  // Simple glob: support trailing * only
  if pattern.has_suffix("*") {
    let prefix = String::unsafe_substring(
      pattern,
      start=0,
      end=pattern.length() - 1,
    )
    name.has_prefix(prefix)
  } else {
    name == pattern || name.has_suffix("/" + pattern)
  }
}

///|
fn name_rev_build_name_map(
  rfs : &@bitcore.RepoFileSystem,
  _git_dir : String,
  db : @bitlib.ObjectDb,
  ref_map : Array[(String, @bitcore.ObjectId)],
) -> Map[String, String] {
  let name_map : Map[String, String] = {}
  // For each ref, BFS backward to assign names
  for item in ref_map {
    let (ref_name, ref_id) = item
    // Dereference tag objects to commits
    let commit_id = name_rev_deref_tag(rfs, db, ref_id)
    let hex = commit_id.to_hex()
    // Direct match: ref points at this commit
    if !name_map.contains(hex) {
      name_map.set(hex, ref_name)
    }
    // Walk parents with BFS up to a depth limit
    let queue : Array[(@bitcore.ObjectId, Int)] = [(commit_id, 0)]
    let visited : Map[String, Unit] = {}
    visited.set(hex, ())
    let max_depth = 256
    while queue.length() > 0 {
      let (oid, depth) = queue.remove(0)
      if depth >= max_depth {
        continue
      }
      let obj = db.get(rfs, oid) catch { _ => continue }
      guard obj is Some(o) else { continue }
      if o.obj_type != @bitcore.ObjectType::Commit {
        continue
      }
      let info = @bitcore.parse_commit(o.data) catch { _ => continue }
      for parent in info.parents {
        let parent_hex = parent.to_hex()
        if visited.contains(parent_hex) {
          continue
        }
        visited.set(parent_hex, ())
        let dist = depth + 1
        let name = "\{ref_name}~\{dist}"
        // Only set if not already named (prefer shorter names)
        if !name_map.contains(parent_hex) {
          name_map.set(parent_hex, name)
        }
        queue.push((parent, dist))
      }
    }
  }
  name_map
}

///|
fn name_rev_deref_tag(
  rfs : &@bitcore.RepoFileSystem,
  db : @bitlib.ObjectDb,
  id : @bitcore.ObjectId,
) -> @bitcore.ObjectId {
  let obj = db.get(rfs, id) catch { _ => return id }
  guard obj is Some(o) else { return id }
  if o.obj_type != @bitcore.ObjectType::Tag {
    return id
  }
  let data = decode_bytes(o.data)
  // Parse "object <hex>" from tag
  for line_view in data.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("object ") {
      let hex = trim_string(
        String::unsafe_substring(line, start=7, end=line.length()),
      )
      let oid = @bitcore.ObjectId::from_hex(hex) catch { _ => return id }
      return oid
    }
  }
  id
}

///|
fn name_rev_replace_oids(
  line : String,
  name_map : Map[String, String],
) -> String {
  // Find 40-char hex strings and replace with names
  let chars = line.to_array()
  let result = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    // Check if we have a 40-char hex starting here
    if i + 40 <= chars.length() && name_rev_is_hex_char(chars[i]) {
      let candidate = String::unsafe_substring(line, start=i, end=i + 40)
      let all_hex = name_rev_all_hex(candidate)
      if all_hex {
        match name_map.get(candidate) {
          Some(name) => {
            result.write_string(candidate)
            result.write_string(" (")
            result.write_string(name)
            result.write_string(")")
            i += 40
            continue
          }
          None => ()
        }
      }
    }
    result.write_char(chars[i])
    i += 1
  }
  result.to_string()
}

///|
fn name_rev_is_hex_char(c : Char) -> Bool {
  @bithash.is_hex_char(c)
}

///|
fn name_rev_all_hex(s : String) -> Bool {
  s.length() == 40 && @bithash.is_hex_string(s)
}
