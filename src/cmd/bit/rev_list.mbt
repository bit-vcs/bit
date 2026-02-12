///| Pack handlers: rev-list, verify-pack, unpack-objects, bundle

///|
async fn handle_rev_list(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut max_count : Int? = None
  let mut count_only = false
  let mut objects = false
  let mut quiet = false
  let mut reverse = false
  let mut first_parent = false
  let mut all = false
  let mut stdin = false
  let refs : Array[String] = []
  let excludes : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-n" | "--max-count" if i + 1 < args.length() => {
        max_count = Some(
          @strconv.parse_int(args[i + 1]) catch {
            err if @async.is_cancellation_error(err) => raise err
            _ => 0
          },
        )
        i += 2
        continue
      }
      "--count" => count_only = true
      "--objects" | "--objects-edge" => objects = true
      "--quiet" | "-q" => quiet = true
      "--reverse" => reverse = true
      "--ancestry-path" => () // Ignored for now
      "--first-parent" => first_parent = true
      "--all" => all = true
      "--stdin" => stdin = true
      "--not" => {
        // Next refs are excludes until another --not
        i += 1
        while i < args.length() {
          let next = args[i]
          if next == "--not" {
            break
          }
          if not(next.has_prefix("-")) {
            excludes.push(next)
          }
          i += 1
        }
        continue
      }
      _ if arg.has_prefix("--max-count=") => {
        let val = String::unsafe_substring(arg, start=12, end=arg.length())
        max_count = Some(
          @strconv.parse_int(val) catch {
            err if @async.is_cancellation_error(err) => raise err
            _ => 0
          },
        )
      }
      _ if arg.has_prefix("^") =>
        excludes.push(String::unsafe_substring(arg, start=1, end=arg.length()))
      _ if not(arg.has_prefix("-")) => refs.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("rev-list", arg)
      _ => ()
    }
    i += 1
  }
  // Read from stdin if requested
  if stdin {
    let input = decode_bytes(read_all_stdin())
    for line_view in input.split("\n") {
      let line = trim_string(line_view.to_string())
      if line.length() > 0 && not(line.has_prefix("#")) {
        if line.has_prefix("^") {
          excludes.push(
            String::unsafe_substring(line, start=1, end=line.length()),
          )
        } else {
          refs.push(line)
        }
      }
    }
  }
  // If --all, add all refs
  if all {
    let all_refs = @gitrepo.show_ref(fs, git_dir)
    for item in all_refs {
      let (name, _) = item
      refs.push(name)
    }
  }
  // If no refs specified, default to HEAD
  if refs.length() == 0 {
    refs.push("HEAD")
  }
  // Resolve starting commits
  let start_ids : Array[@git.ObjectId] = []
  for spec in refs {
    match @gitrepo.rev_parse(fs, git_dir, spec) {
      Some(id) => start_ids.push(id)
      None => ()
    }
  }
  // Resolve exclude commits
  let exclude_ids : Map[String, Bool] = {}
  for spec in excludes {
    match @gitrepo.rev_parse(fs, git_dir, spec) {
      Some(id) =>
        // Walk the exclude commit and all its ancestors
        walk_commits_to_map(fs, git_dir, id, exclude_ids)
      None => ()
    }
  }
  let db = @gitlib.ObjectDb::load(fs, git_dir)
  let visited : Map[String, Bool] = {}
  let result : Array[@git.ObjectId] = []
  let object_ids : Array[@git.ObjectId] = []
  let limit = max_count.unwrap_or(2147483647)
  // BFS/DFS traversal
  let queue : Array[@git.ObjectId] = []
  for id in start_ids {
    queue.push(id)
  }
  while queue.length() > 0 && result.length() < limit {
    let id = queue.unsafe_pop()
    let hex = id.to_hex()
    if visited.contains(hex) || exclude_ids.contains(hex) {
      continue
    }
    visited[hex] = true
    result.push(id)
    if objects {
      object_ids.push(id)
    }
    // Get commit and add parents
    match db.get(fs, id) {
      Some(obj) if obj.obj_type == @git.ObjectType::Commit => {
        let info = @git.parse_commit(obj.data)
        if objects {
          // Also collect tree objects
          collect_tree_objects(db, fs, info.tree, object_ids, visited)
        }
        if first_parent && info.parents.length() > 0 {
          if not(visited.contains(info.parents[0].to_hex())) {
            queue.push(info.parents[0])
          }
        } else {
          for parent in info.parents {
            if not(visited.contains(parent.to_hex())) {
              queue.push(parent)
            }
          }
        }
      }
      _ => ()
    }
  }
  // Apply reverse if requested
  if reverse {
    result.rev_in_place()
    if objects {
      object_ids.rev_in_place()
    }
  }
  // Output
  if count_only {
    print_line(result.length().to_string())
    return
  }
  if quiet {
    return
  }
  // Output commits
  for id in result {
    print_line(id.to_hex())
  }
  // Output objects (trees, blobs) if --objects
  if objects {
    for id in object_ids {
      // Skip commits already printed
      let hex = id.to_hex()
      let mut is_commit = false
      for r in result {
        if r.to_hex() == hex {
          is_commit = true
          break
        }
      }
      if not(is_commit) {
        print_line(hex)
      }
    }
  }
}

///|
fn walk_commits_to_map(
  fs : OsFs,
  git_dir : String,
  start : @git.ObjectId,
  out : Map[String, Bool],
) -> Unit {
  let db = @gitlib.ObjectDb::load(fs, git_dir) catch { _ => return () }
  let queue : Array[@git.ObjectId] = [start]
  while queue.length() > 0 {
    let id = queue.unsafe_pop()
    let hex = id.to_hex()
    if out.contains(hex) {
      continue
    }
    out[hex] = true
    let obj = db.get(fs, id) catch { _ => continue }
    match obj {
      Some(o) if o.obj_type == @git.ObjectType::Commit => {
        let info = @git.parse_commit(o.data) catch { _ => continue }
        for parent in info.parents {
          if not(out.contains(parent.to_hex())) {
            queue.push(parent)
          }
        }
      }
      _ => ()
    }
  }
}

///|
fn collect_tree_objects(
  db : @gitlib.ObjectDb,
  fs : OsFs,
  tree_id : @git.ObjectId,
  out : Array[@git.ObjectId],
  visited : Map[String, Bool],
) -> Unit {
  let hex = tree_id.to_hex()
  if visited.contains(hex) {
    return ()
  }
  visited[hex] = true
  out.push(tree_id)
  let obj = db.get(fs, tree_id) catch { _ => return () }
  match obj {
    Some(o) if o.obj_type == @git.ObjectType::Tree => {
      let entries = @git.parse_tree(o.data) catch { _ => return () }
      for entry in entries {
        let entry_hex = entry.id.to_hex()
        if not(visited.contains(entry_hex)) {
          if entry.mode.has_prefix("40") {
            // Directory - recurse
            collect_tree_objects(db, fs, entry.id, out, visited)
          } else {
            // File or other
            visited[entry_hex] = true
            out.push(entry.id)
          }
        }
      }
    }
    _ => ()
  }
}

///|
