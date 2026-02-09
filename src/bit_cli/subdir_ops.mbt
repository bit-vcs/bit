///|
async fn handle_subdir_diff(
  fs : OsFs,
  _root : String,
  git_dir : String,
  refspec : String,
  subdir_path : String,
  stat_mode : Bool,
  name_only : Bool,
  name_status : Bool,
) -> Unit raise Error {
  let rfs : &@git.RepoFileSystem = fs
  print_line("# Comparing with \{refspec} (subdir: \{subdir_path})")
  print_line("")
  // Resolve upstream ref
  let upstream_id = resolve_ref_for_subdir(fs, git_dir, refspec)
  guard upstream_id is Some(uid) else {
    raise @git.GitError::InvalidObject("Cannot resolve ref: \{refspec}")
  }
  // Get local HEAD
  let head_id = @gitrepo.rev_parse(rfs, git_dir, "HEAD")
  guard head_id is Some(hid) else {
    raise @git.GitError::InvalidObject("Cannot resolve HEAD")
  }
  // Load object database
  let db = @gitlib.ObjectDb::load_lazy(fs, git_dir)
  // Get upstream subdir tree
  let upstream_tree = get_subdir_tree_from_commit(db, fs, uid, subdir_path) catch {
    err => raise err
  }
  guard upstream_tree is Some(utree) else {
    raise @git.GitError::InvalidObject(
      "Subdirectory not found in upstream: \{subdir_path}",
    )
  }
  // Get local tree (root is the subdir)
  let local_obj = db.get(rfs, hid)
  guard local_obj is Some(lo) else {
    raise @git.GitError::InvalidObject("Cannot read local HEAD")
  }
  let local_info = @git.parse_commit(lo.data) catch { err => raise err }
  let local_tree = local_info.tree
  // Compare trees
  let diffs = compare_trees(db, rfs, utree, local_tree, "")
  if diffs.length() == 0 {
    print_line("No differences with \{refspec}")
    return
  }
  // Output
  if name_only {
    for d in diffs {
      print_line(d.path)
    }
  } else if name_status {
    for d in diffs {
      let status = match d.kind {
        SubdirDiffKind::Added => "A"
        SubdirDiffKind::Modified => "M"
        SubdirDiffKind::Deleted => "D"
      }
      print_line("\{status}\t\{d.path}")
    }
  } else if stat_mode {
    for d in diffs {
      let status = match d.kind {
        SubdirDiffKind::Added => " (new)"
        SubdirDiffKind::Modified => ""
        SubdirDiffKind::Deleted => " (deleted)"
      }
      print_line(" \{d.path}\{status}")
    }
    print_line("")
    print_line(" \{diffs.length()} files changed")
  } else {
    for d in diffs {
      let header = match d.kind {
        SubdirDiffKind::Added => "new file: \{d.path}"
        SubdirDiffKind::Modified => "modified: \{d.path}"
        SubdirDiffKind::Deleted => "deleted: \{d.path}"
      }
      print_line("diff --git a/\{d.path} b/\{d.path}")
      print_line(header)
    }
  }
}

///|
pub(all) enum SubdirDiffKind {
  Added
  Modified
  Deleted
}

///|
struct SubdirDiffEntry {
  path : String
  kind : SubdirDiffKind
}

///|
fn compare_trees(
  db : @gitlib.ObjectDb,
  rfs : &@git.RepoFileSystem,
  tree_a : @git.ObjectId,
  tree_b : @git.ObjectId,
  prefix : String,
) -> Array[SubdirDiffEntry] raise Error {
  let result : Array[SubdirDiffEntry] = []
  // Get entries from both trees
  let entries_a = get_tree_entries(db, rfs, tree_a)
  let entries_b = get_tree_entries(db, rfs, tree_b)
  // Build maps
  let map_a : Map[String, @git.TreeEntry] = {}
  let map_b : Map[String, @git.TreeEntry] = {}
  for e in entries_a {
    map_a[e.name] = e
  }
  for e in entries_b {
    map_b[e.name] = e
  }
  // Find deleted (in A but not in B)
  for e in entries_a {
    let path = if prefix.length() > 0 { prefix + "/" + e.name } else { e.name }
    if not(map_b.contains(e.name)) {
      if e.mode == "40000" || e.mode == "040000" {
        // Recurse into deleted directory
        let sub = compare_trees_deleted(db, rfs, e.id, path)
        for s in sub {
          result.push(s)
        }
      } else {
        result.push({ path, kind: SubdirDiffKind::Deleted })
      }
    }
  }
  // Find added (in B but not in A) and modified
  for e in entries_b {
    let path = if prefix.length() > 0 { prefix + "/" + e.name } else { e.name }
    match map_a.get(e.name) {
      None =>
        if e.mode == "40000" || e.mode == "040000" {
          // Recurse into added directory
          let sub = compare_trees_added(db, rfs, e.id, path)
          for s in sub {
            result.push(s)
          }
        } else {
          result.push({ path, kind: SubdirDiffKind::Added })
        }
      Some(ea) =>
        if e.id.to_hex() != ea.id.to_hex() {
          if (e.mode == "40000" || e.mode == "040000") &&
            (ea.mode == "40000" || ea.mode == "040000") {
            // Both are directories, recurse
            let sub = compare_trees(db, rfs, ea.id, e.id, path)
            for s in sub {
              result.push(s)
            }
          } else {
            result.push({ path, kind: SubdirDiffKind::Modified })
          }
        }
    }
  }
  result
}

///|
fn compare_trees_deleted(
  db : @gitlib.ObjectDb,
  rfs : &@git.RepoFileSystem,
  tree_id : @git.ObjectId,
  prefix : String,
) -> Array[SubdirDiffEntry] raise Error {
  let result : Array[SubdirDiffEntry] = []
  let entries = get_tree_entries(db, rfs, tree_id)
  for e in entries {
    let path = prefix + "/" + e.name
    if e.mode == "40000" || e.mode == "040000" {
      let sub = compare_trees_deleted(db, rfs, e.id, path)
      for s in sub {
        result.push(s)
      }
    } else {
      result.push({ path, kind: SubdirDiffKind::Deleted })
    }
  }
  result
}

///|
fn compare_trees_added(
  db : @gitlib.ObjectDb,
  rfs : &@git.RepoFileSystem,
  tree_id : @git.ObjectId,
  prefix : String,
) -> Array[SubdirDiffEntry] raise Error {
  let result : Array[SubdirDiffEntry] = []
  let entries = get_tree_entries(db, rfs, tree_id)
  for e in entries {
    let path = prefix + "/" + e.name
    if e.mode == "40000" || e.mode == "040000" {
      let sub = compare_trees_added(db, rfs, e.id, path)
      for s in sub {
        result.push(s)
      }
    } else {
      result.push({ path, kind: SubdirDiffKind::Added })
    }
  }
  result
}

///|
/// Handle merge for subdir-clone
async fn handle_subdir_merge(
  fs : OsFs,
  root : String,
  git_dir : String,
  refspec : String,
  subdir_path : String,
  message : String?,
) -> Unit raise Error {
  print_line("Merging from upstream (subdir: \{subdir_path})...")
  // Resolve upstream ref
  let upstream_id = resolve_ref_for_subdir(fs, git_dir, refspec) catch {
    err => raise err
  }
  guard upstream_id is Some(uid) else {
    raise @git.GitError::InvalidObject("unknown revision: \{refspec}")
  }
  // Load object database
  let db = @gitlib.ObjectDb::load_lazy(fs, git_dir)
  // Get upstream subdir tree
  let upstream_tree = get_subdir_tree_from_commit(db, fs, uid, subdir_path) catch {
    err => raise err
  }
  guard upstream_tree is Some(utree) else {
    raise @git.GitError::InvalidObject(
      "Subdirectory not found in upstream: \{subdir_path}",
    )
  }
  // Get local HEAD tree
  let rfs : &@git.RepoFileSystem = fs
  let head_id = @gitrepo.rev_parse(rfs, git_dir, "HEAD")
  guard head_id is Some(hid) else {
    raise @git.GitError::InvalidObject("Cannot resolve HEAD")
  }
  let local_obj = db.get(rfs, hid)
  guard local_obj is Some(lo) else {
    raise @git.GitError::InvalidObject("Cannot read local HEAD")
  }
  let local_info = @git.parse_commit(lo.data) catch { err => raise err }
  let local_tree = local_info.tree
  // Check if already up to date
  if local_tree.to_hex() == utree.to_hex() {
    print_line("Already up to date.")
    return
  }
  // For simplicity, we replace local tree with upstream subdir tree
  // This is a "theirs" strategy - in a real impl we'd do proper 3-way merge
  print_line("  Applying upstream changes...")
  // Write upstream tree to worktree
  write_subdir_tree_to_worktree(db, fs, utree, root)
  // Create merge commit
  let author = get_author_string()
  let timestamp = get_commit_timestamp()
  let msg = message.unwrap_or("Merge \{refspec} (subdir: \{subdir_path})")
  // Stage all changes
  let status = @gitlib.status(fs, root)
  let paths_to_add : Array[String] = []
  for p in status.untracked {
    paths_to_add.push(p)
  }
  for p in status.unstaged_modified {
    paths_to_add.push(p)
  }
  for p in status.unstaged_deleted {
    paths_to_add.push(p)
  }
  if paths_to_add.length() > 0 {
    @gitlib.add_paths_async(fs, fs, root, paths_to_add)
  }
  // Commit
  let commit_id = @gitlib.commit(fs, fs, root, msg, author, timestamp)
  let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
  print_line("[\{short}] \{msg}")
}

///|
fn write_subdir_tree_to_worktree(
  db : @gitlib.ObjectDb,
  fs : OsFs,
  tree_id : @git.ObjectId,
  dir : String,
) -> Unit raise Error {
  let rfs : &@git.RepoFileSystem = fs
  let obj = db.get(rfs, tree_id)
  guard obj is Some(tree_obj) else { return }
  let entries = @git.parse_tree(tree_obj.data) catch { _ => return }
  for entry in entries {
    let path = dir + "/" + entry.name
    if entry.mode == "40000" || entry.mode == "040000" {
      fs.mkdir_p(path) catch {
        _ => ()
      }
      write_subdir_tree_to_worktree(db, fs, entry.id, path) catch {
        _ => ()
      }
    } else {
      let blob_obj = db.get(rfs, entry.id)
      guard blob_obj is Some(blob) else { continue }
      fs.write_file(path, blob.data) catch {
        _ => ()
      }
    }
  }
}
