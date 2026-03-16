///|
async fn handle_merge_base(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut all = false
  let mut is_ancestor = false
  let mut octopus = false
  let mut fork_point = false
  let mut independent = false
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-h" | "--help" => {
        print_line("usage: git merge-base [-a | --all] <commit> <commit>...")
        print_line("   or: git merge-base [-a | --all] --octopus <commit>...")
        print_line("   or: git merge-base --is-ancestor <commit> <commit>")
        print_line("   or: git merge-base --fork-point <ref> [<commit>]")
        print_line("   or: git merge-base --independent <commit>...")
        return
      }
      "-a" | "--all" => all = true
      "--is-ancestor" => is_ancestor = true
      "--octopus" => octopus = true
      "--fork-point" => fork_point = true
      "--independent" => independent = true
      _ if arg.has_prefix("-") => warn_unimplemented_arg("merge-base", arg)
      _ => positional.push(arg)
    }
    i += 1
  }
  if is_ancestor {
    if positional.length() != 2 {
      eprint_line("usage: git merge-base --is-ancestor <commit> <commit>")
      @sys.exit(1)
      return
    }
    let a = merge_base_resolve_ref(fs, git_dir, positional[0])
    let b = merge_base_resolve_ref(fs, git_dir, positional[1])
    if merge_base_is_ancestor(fs, git_dir, a, b) {
      @sys.exit(0)
    } else {
      @sys.exit(1)
    }
    return
  }
  if independent {
    if positional.length() < 2 {
      eprint_line("usage: git merge-base --independent <commit>...")
      @sys.exit(1)
      return
    }
    let ids : Array[@bitcore.ObjectId] = []
    for p in positional {
      ids.push(merge_base_resolve_ref(fs, git_dir, p))
    }
    let result = merge_base_independent(fs, git_dir, ids)
    for oid in result {
      print_line(oid.to_hex())
    }
    return
  }
  if fork_point {
    if positional.length() < 1 {
      eprint_line("usage: git merge-base --fork-point <ref> [<commit>]")
      @sys.exit(1)
      return
    }
    let ref_arg = positional[0]
    let commit_arg = if positional.length() > 1 {
      positional[1]
    } else {
      "HEAD"
    }
    let a = merge_base_resolve_ref(fs, git_dir, ref_arg)
    let b = merge_base_resolve_ref(fs, git_dir, commit_arg)
    // Use reflog-based fork-point detection
    let result = merge_base_fork_point(fs, git_dir, ref_arg, b)
    match result {
      Some(mb) => print_line(mb.to_hex())
      None =>
        // Fall back to regular merge-base
        match rev_parse_find_merge_base(fs, git_dir, a, b) {
          Some(mb2) => print_line(mb2.to_hex())
          None => {
            @sys.exit(1)
            return
          }
        }
    }
    return
  }
  if octopus {
    if positional.length() < 2 {
      eprint_line("usage: git merge-base --octopus <commit>...")
      @sys.exit(1)
      return
    }
    let ids : Array[@bitcore.ObjectId] = []
    for p in positional {
      ids.push(merge_base_resolve_ref(fs, git_dir, p))
    }
    let result = merge_base_octopus(fs, git_dir, ids)
    match result {
      Some(mb) => print_line(mb.to_hex())
      None => @sys.exit(1)
    }
    return
  }
  // Default: merge-base A B (or multiple commits with --all)
  if positional.length() < 2 {
    eprint_line("usage: git merge-base [-a | --all] <commit> <commit>...")
    @sys.exit(129)
    return
  }
  // Resolve all commit refs
  let ids : Array[@bitcore.ObjectId] = []
  for p in positional {
    ids.push(merge_base_resolve_ref(fs, git_dir, p))
  }
  if ids.length() == 2 {
    if all {
      let results = merge_base_all(fs, git_dir, ids[0], ids[1])
      if results.length() == 0 {
        @sys.exit(1)
        return
      }
      for mb in results {
        print_line(mb.to_hex())
      }
    } else {
      match rev_parse_find_merge_base(fs, git_dir, ids[0], ids[1]) {
        Some(mb) => print_line(mb.to_hex())
        None => @sys.exit(1)
      }
    }
  } else {
    // Multiple commits: reduce pairwise
    let mut current = ids[0]
    for j in 1..<ids.length() {
      match rev_parse_find_merge_base(fs, git_dir, current, ids[j]) {
        Some(mb) => current = mb
        None => {
          @sys.exit(1)
          return
        }
      }
    }
    print_line(current.to_hex())
  }
}

///|
/// Resolve a ref string to an ObjectId, exiting on failure.
async fn merge_base_resolve_ref(
  fs : OsFs,
  git_dir : String,
  name : String,
) -> @bitcore.ObjectId raise Error {
  match @bitrepo.rev_parse(fs, git_dir, name) {
    Some(id) => id
    None => {
      eprint_line("fatal: Not a valid object name \{name}")
      @sys.exit(128)
      return @bitcore.ObjectId::from_hex(
        "0000000000000000000000000000000000000000",
      )
    }
  }
}

///|
/// Check if ancestor is an ancestor of descendant using BFS.
async fn merge_base_is_ancestor(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  ancestor : @bitcore.ObjectId,
  descendant : @bitcore.ObjectId,
) -> Bool raise Error {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  @bitlib.merge_base_is_ancestor(db, fs, ancestor, descendant)
}

///|
/// Find all merge bases between two commits.
/// A merge base is a common ancestor that is not an ancestor of any other common ancestor.
async fn merge_base_all(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  a : @bitcore.ObjectId,
  b : @bitcore.ObjectId,
) -> Array[@bitcore.ObjectId] raise Error {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  @bitlib.merge_base_all(db, fs, a, b)
}

///|
/// Octopus merge-base: find the best common ancestor of all commits.
/// Reduces pairwise using merge-base.
async fn merge_base_octopus(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  commits : Array[@bitcore.ObjectId],
) -> @bitcore.ObjectId? raise Error {
  if commits.length() == 0 {
    return None
  }
  let mut current = commits[0]
  for idx in 1..<commits.length() {
    match rev_parse_find_merge_base(fs, git_dir, current, commits[idx]) {
      Some(mb) => current = mb
      None => return None
    }
  }
  Some(current)
}

///|
/// Find independent commits: those not reachable from any other in the set.
async fn merge_base_independent(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  commits : Array[@bitcore.ObjectId],
) -> Array[@bitcore.ObjectId] raise Error {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  @bitlib.merge_base_independent(db, fs, commits)
}

///|
/// Fork-point: find the best merge-base between a ref's reflog entries and a commit.
/// This walks the reflog of the given ref and finds the best fork point.
async fn merge_base_fork_point(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  ref_name : String,
  commit : @bitcore.ObjectId,
) -> @bitcore.ObjectId? raise Error {
  // Read reflog entries for the ref
  let reflog_path = if ref_name.has_prefix("refs/") {
    git_dir + "/logs/" + ref_name
  } else {
    git_dir + "/logs/refs/heads/" + ref_name
  }
  let data = decode_bytes(fs.read_file(reflog_path)) catch { _ => return None }
  // Parse reflog entries to get new OIDs
  let reflog_oids : Array[@bitcore.ObjectId] = []
  for line_view in data.split("\n") {
    let line = line_view.to_string()
    if line.length() < 82 {
      continue
    }
    // Reflog format: <old-oid(40)> <new-oid(40)> <rest>
    let new_hex = String::unsafe_substring(line, start=41, end=81)
    let oid = @bitcore.ObjectId::from_hex(new_hex) catch { _ => continue }
    reflog_oids.push(oid)
  }
  // Find the best merge-base between commit and any reflog entry
  let mut best : @bitcore.ObjectId? = None
  let mut best_is_reflog_entry = false
  for oid in reflog_oids {
    let mb = rev_parse_find_merge_base(fs, git_dir, oid, commit)
    match mb {
      Some(m) => {
        let m_hex = m.to_hex()
        let oid_hex = oid.to_hex()
        // Prefer merge-base that equals a reflog entry (true fork point)
        if m_hex == oid_hex {
          if not(best_is_reflog_entry) {
            best = Some(m)
            best_is_reflog_entry = true
          } else {
            // Both are reflog entries, check if new one is descendant of current best
            match best {
              Some(prev) =>
                if merge_base_is_ancestor(fs, git_dir, prev, m) {
                  best = Some(m)
                }
              None => best = Some(m)
            }
          }
        } else if not(best_is_reflog_entry) {
          match best {
            Some(prev) =>
              if merge_base_is_ancestor(fs, git_dir, prev, m) {
                best = Some(m)
              }
            None => best = Some(m)
          }
        }
      }
      None => ()
    }
  }
  best
}
