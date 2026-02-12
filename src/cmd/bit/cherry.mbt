///|
async fn handle_cherry(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut verbose = false
  let mut upstream : String? = None
  let mut head : String? = None
  let mut limit : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-v" => verbose = true
      _ if not(arg.has_prefix("-")) =>
        if upstream is None {
          upstream = Some(arg)
        } else if head is None {
          head = Some(arg)
        } else if limit is None {
          limit = Some(arg)
        }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("cherry", arg)
      _ => ()
    }
    i += 1
  }
  // Default upstream to tracking branch or origin/HEAD
  let effective_upstream = match upstream {
    Some(u) => u
    None => {
      // Try to get upstream from current branch
      let head_content = decode_bytes(fs.read_file(git_dir + "/HEAD"))
      if head_content.has_prefix("ref: refs/heads/") {
        let branch = trim_string(head_content[16:].to_string())
        // Check for remote tracking
        let remote_ref = "origin/" + branch
        if @gitrepo.rev_parse(fs, git_dir, remote_ref) is Some(_) {
          remote_ref
        } else {
          "origin/HEAD"
        }
      } else {
        "origin/HEAD"
      }
    }
  }
  // Default head to HEAD
  let effective_head = head.unwrap_or("HEAD")
  // Resolve revisions
  let upstream_id = match @gitrepo.rev_parse(fs, git_dir, effective_upstream) {
    Some(id) => id
    None => {
      eprint_line("fatal: bad revision '" + effective_upstream + "'")
      @sys.exit(128)
      return
    }
  }
  let head_id = match @gitrepo.rev_parse(fs, git_dir, effective_head) {
    Some(id) => id
    None => {
      eprint_line("fatal: bad revision '" + effective_head + "'")
      @sys.exit(128)
      return
    }
  }
  let limit_id : @git.ObjectId? = match limit {
    Some(l) => @gitrepo.rev_parse(fs, git_dir, l)
    None => None
  }
  // Collect commits from upstream (to find merge base)
  let db = @gitlib.ObjectDb::load(fs, git_dir)
  let upstream_commits = cherry_collect_commits(db, fs, upstream_id, limit_id)
  let head_commits = cherry_collect_commits(db, fs, head_id, limit_id)
  // Compute patch-ids for upstream commits
  let upstream_patch_ids : Map[String, @git.ObjectId] = {}
  for commit_id in upstream_commits {
    let patch_id = cherry_compute_patch_id(db, fs, commit_id)
    upstream_patch_ids[patch_id] = commit_id
  }
  // Check each head commit
  for commit_id in head_commits {
    // Skip if also in upstream (by commit id)
    let mut in_upstream_by_id = false
    for u_id in upstream_commits {
      if u_id == commit_id {
        in_upstream_by_id = true
        break
      }
    }
    if in_upstream_by_id {
      continue
    }
    let patch_id = cherry_compute_patch_id(db, fs, commit_id)
    let prefix = if upstream_patch_ids.contains(patch_id) { "-" } else { "+" }
    if verbose {
      let subject = plumb_get_commit_subject(db, fs, commit_id)
      print_line(prefix + " " + commit_id.to_hex() + " " + subject)
    } else {
      print_line(prefix + " " + commit_id.to_hex())
    }
  }
  ignore(limit_id)
}

///|
fn cherry_collect_commits(
  db : @gitlib.ObjectDb,
  fs : OsFs,
  start : @git.ObjectId,
  limit : @git.ObjectId?,
) -> Array[@git.ObjectId] {
  let result : Array[@git.ObjectId] = []
  let limit_hex = match limit {
    Some(l) => l.to_hex()
    None => ""
  }
  let mut current : @git.ObjectId? = Some(start)
  let mut count = 0
  let max_commits = 1000 // Safety limit
  while current is Some(id) && count < max_commits {
    if limit_hex.length() > 0 && id.to_hex() == limit_hex {
      break
    }
    result.push(id)
    count += 1
    let obj = db.get(fs, id) catch { _ => break }
    match obj {
      Some(o) if o.obj_type == @git.ObjectType::Commit => {
        let info = @git.parse_commit(o.data) catch { _ => break }
        current = if info.parents.length() > 0 {
          Some(info.parents[0])
        } else {
          None
        }
      }
      _ => current = None
    }
  }
  result
}

///|
fn cherry_compute_patch_id(
  db : @gitlib.ObjectDb,
  fs : OsFs,
  commit_id : @git.ObjectId,
) -> String {
  // Get commit and its parent
  let obj = db.get(fs, commit_id) catch { _ => return commit_id.to_hex() }
  match obj {
    Some(o) if o.obj_type == @git.ObjectType::Commit => {
      let info = @git.parse_commit(o.data) catch {
        _ => return commit_id.to_hex()
      }
      // Get tree entries of this commit
      let tree_entries = cherry_get_tree_entries(db, fs, info.tree)
      // Get parent tree entries (or empty if no parent)
      let parent_entries : Array[(String, String)] = if info.parents.length() >
        0 {
        let parent_obj = db.get(fs, info.parents[0]) catch {
          _ => return commit_id.to_hex()
        }
        match parent_obj {
          Some(po) if po.obj_type == @git.ObjectType::Commit => {
            let parent_info = @git.parse_commit(po.data) catch {
              _ => return commit_id.to_hex()
            }
            cherry_get_tree_entries(db, fs, parent_info.tree)
          }
          _ => []
        }
      } else {
        []
      }
      // Compute diff: files that changed between parent and commit
      let diff = cherry_compute_tree_diff(parent_entries, tree_entries)
      // Sort diff for consistent ordering
      diff.sort_by((a, b) => a.0.compare(b.0))
      // Hash the diff content (path + blob id pairs)
      let content_parts : Array[String] = []
      for item in diff {
        let (path, change) = item
        content_parts.push(path + ":" + change)
      }
      let patch_content = content_parts.join("\n")
      let patch_bytes = Bytes::from_array(
        FixedArray::makei(patch_content.length(), fn(i) {
          patch_content[i].to_int().to_byte()
        }),
      )
      @git.sha1(patch_bytes).to_hex()
    }
    _ => commit_id.to_hex()
  }
}

///|
fn cherry_get_tree_entries(
  db : @gitlib.ObjectDb,
  fs : OsFs,
  tree_id : @git.ObjectId,
) -> Array[(String, String)] {
  let result : Array[(String, String)] = []
  let obj = db.get(fs, tree_id) catch { _ => return result }
  match obj {
    Some(o) if o.obj_type == @git.ObjectType::Tree => {
      let entries = @git.parse_tree(o.data) catch { _ => return result }
      for entry in entries {
        // For files, add path -> blob id
        // For directories, recursively get entries
        if entry.mode.has_prefix("04") {
          // Directory - recurse
          let sub_entries = cherry_get_tree_entries(db, fs, entry.id)
          for sub in sub_entries {
            let (sub_path, sub_id) = sub
            result.push((entry.name + "/" + sub_path, sub_id))
          }
        } else {
          // File
          result.push((entry.name, entry.id.to_hex()))
        }
      }
    }
    _ => ()
  }
  result
}

///|
fn cherry_compute_tree_diff(
  parent : Array[(String, String)],
  current : Array[(String, String)],
) -> Array[(String, String)] {
  // Build map of parent entries
  let parent_map : Map[String, String] = {}
  for item in parent {
    let (path, id) = item
    parent_map[path] = id
  }
  // Find changes
  let diff : Array[(String, String)] = []
  for item in current {
    let (path, id) = item
    match parent_map.get(path) {
      Some(parent_id) =>
        if parent_id != id {
          // Modified
          diff.push((path, "M:" + id))
        }
      None =>
        // Added
        diff.push((path, "A:" + id))
    }
  }
  // Find deleted files
  let current_map : Map[String, String] = {}
  for item in current {
    let (path, id) = item
    current_map[path] = id
  }
  for item in parent {
    let (path, _) = item
    if not(current_map.contains(path)) {
      diff.push((path, "D"))
    }
  }
  diff
}
