///| Reset implementation

///|
pub(all) enum ResetMode {
  Soft
  Mixed
  Hard
}

///|
pub fn reset(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  spec : String,
  mode : ResetMode,
  committer? : String = "unknown <unknown>",
  timestamp? : Int64 = 0L,
  timezone? : String = "+0000",
) -> @bit.ObjectId raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let actual_git_dir = if rfs.is_file(git_dir) {
    resolve_gitdir(rfs, git_dir)
  } else {
    git_dir
  }
  let object_git_dir = reset_resolve_common_git_dir(rfs, actual_git_dir)
  let target = match rev_parse(rfs, actual_git_dir, spec) {
    None => raise @bit.GitError::InvalidObject("Invalid ref: \{spec}")
    Some(id) => id
  }
  let old_head = resolve_head_commit(rfs, actual_git_dir).unwrap_or(
    @bit.ObjectId::zero(),
  )
  update_head_ref(fs, rfs, actual_git_dir, target)
  append_head_update_reflogs(
    fs,
    rfs,
    actual_git_dir,
    old_head,
    target,
    "reset: moving to " + spec,
    committer~,
    timestamp~,
    timezone~,
  )
  match mode {
    Soft => target
    Mixed => {
      let db = ObjectDb::load(rfs, object_git_dir)
      let tree_id = reset_resolve_target_tree_id(db, rfs, target)
      let files = collect_tree_files_from_commit(db, rfs, target)
      let entries = tree_files_to_index(db, rfs, files)
      let skip = read_skip_worktree_paths(rfs, actual_git_dir)
      let sparse = is_sparse_checkout_enabled(rfs, actual_git_dir)
      if skip.length() > 0 || sparse {
        // Sparse: entries that stay keep their skip-worktree bit, and an
        // out-of-cone entry missing from the worktree gets it (git).
        let patterns = if sparse {
          read_sparse_patterns(rfs, actual_git_dir)
        } else {
          []
        }
        let keep : Map[String, Bool] = Map([])
        for e in entries {
          if skip.contains(e.path) {
            keep[e.path] = true
          } else if sparse &&
            !matches_sparse_pattern(e.path, patterns) &&
            @bitio.worktree_entry_meta_sync(rfs, join_path(root, e.path))
            is None {
            keep[e.path] = true
          }
        }
        write_index_entries_with_skip_worktree(fs, actual_git_dir, entries, keep)
      } else {
        write_index_entries_with_tree(fs, rfs, actual_git_dir, entries, tree_id)
      }
      target
    }
    Hard => {
      let db = ObjectDb::load(rfs, object_git_dir)
      let tree_id = reset_resolve_target_tree_id(db, rfs, target)
      let files = collect_tree_files_from_commit(db, rfs, target)
      // Sparse: skip-worktree paths that stay tracked keep their bit and
      // are not materialized, and git re-applies the patterns: every
      // out-of-cone entry gets the bit (its file is discarded, --hard).
      let skip = read_skip_worktree_paths(rfs, actual_git_dir)
      // Out-of-cone untracked files the reset brings back into the index
      // stay as they are on disk (not written over, no skip bit).
      let leave : Map[String, Bool] = Map([])
      let sparse_on = is_sparse_checkout_enabled(rfs, actual_git_dir)
      if sparse_on {
        let patterns = read_sparse_patterns(rfs, actual_git_dir)
        let emptied : Array[String] = []
        let indexed : Map[String, Bool] = Map([])
        for e in read_index_entries(rfs, actual_git_dir) {
          indexed[e.path] = true
        }
        for path, f in files {
          // Only entries the index already had: an untracked file at a
          // path the reset brings back is left alone (git).
          if !is_gitlink_mode_int(f.mode) &&
            !matches_sparse_pattern(path, patterns) &&
            !skip.contains(path) &&
            !indexed.contains(path) &&
            @bitio.worktree_entry_meta_sync(rfs, join_path(root, path)) is Some(_) {
            leave[path] = true
          } else if !is_gitlink_mode_int(f.mode) &&
            !matches_sparse_pattern(path, patterns) &&
            !skip.contains(path) &&
            indexed.contains(path) {
            skip[path] = true
            let abs = join_path(root, path)
            if @bitio.worktree_entry_meta_sync(rfs, abs) is Some(_) {
              fs.remove_file(abs) catch {
                _ => ()
              }
              emptied.push(parent_dir(abs))
            }
          }
        }
        tree_ops_prune_empty_dirs(fs, rfs, root, emptied)
      }
      let to_write : Map[String, TreeFileEntry] = Map([])
      for path, f in files {
        if !skip.contains(path) && !leave.contains(path) {
          to_write[path] = f
        }
      }
      if skip.length() > 0 || sparse_on {
        // Keep skipped paths from being "removed" by remove_missing.
        let keep_paths : Map[String, TreeFileEntry] = to_write.copy()
        for path, _ in skip {
          match files.get(path) {
            Some(f) => keep_paths[path] = f
            None => ()
          }
        }
        tree_ops_remove_missing_paths(
          fs, rfs, root, actual_git_dir, keep_paths, false,
        )
        write_worktree_from_files(db, fs, rfs, root, actual_git_dir, to_write)
      } else {
        write_worktree_from_files(
          db,
          fs,
          rfs,
          root,
          actual_git_dir,
          files,
          remove_missing=true,
        )
      }
      let entries = tree_files_to_index(db, rfs, files)
      if skip.length() > 0 {
        let keep : Map[String, Bool] = Map([])
        for e in entries {
          if skip.contains(e.path) {
            keep[e.path] = true
          }
        }
        write_index_entries_with_skip_worktree(fs, actual_git_dir, entries, keep)
      } else {
        write_index_entries_with_tree(fs, rfs, actual_git_dir, entries, tree_id)
      }
      target
    }
  }
}

///|
fn reset_resolve_target_tree_id(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  target : @bit.ObjectId,
) -> @bit.ObjectId raise @bit.GitError {
  match db.get(fs, target) {
    Some(obj) if obj.obj_type == @bit.ObjectType::Commit =>
      @bit.parse_commit(obj.data).tree
    Some(_) => raise @bit.GitError::InvalidObject("Object is not a commit")
    None => raise @bit.GitError::InvalidObject("Missing commit object")
  }
}

///|
fn reset_resolve_common_git_dir(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
) -> String {
  let commondir_path = join_path(git_dir, "commondir")
  if !fs.is_file(commondir_path) {
    return git_dir
  }
  let raw = @utf8.decode_lossy(
    (fs.read_file(commondir_path) catch { _ => Default::default() })[:],
  )
  let rel = @string_utils.trim_string(raw)
  if rel.length() == 0 {
    return git_dir
  }
  if rel.has_prefix("/") {
    normalize_path(rel)
  } else {
    normalize_path(join_path(git_dir, rel))
  }
}

///|
/// `git reset --merge <target>` as used by cherry-pick / revert --abort:
/// unmerged paths and paths whose index entry differs from `target` are
/// reset (index and worktree); every other path, and its unstaged edits,
/// is left alone. HEAD moves to `target`.
pub fn reset_merge(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  target : @bit.ObjectId,
) -> Unit raise @bit.GitError {
  let marker = join_path(root, ".git")
  let git_dir = if rfs.is_file(marker) {
    resolve_gitdir(rfs, marker)
  } else {
    marker
  }
  let common = resolve_common_git_dir(rfs, git_dir)
  let db = ObjectDb::load(rfs, common)
  let target_files = collect_tree_files_from_commit(db, rfs, target)
  let skip = read_skip_worktree_paths(rfs, git_dir)
  let stage0 : Map[String, IndexEntry] = Map([])
  let unmerged : Map[String, Bool] = Map([])
  for item in read_index_stage_entries(rfs, git_dir) {
    if item.stage == 0 {
      stage0[item.entry.path] = item.entry
    } else {
      unmerged[item.entry.path] = true
    }
  }
  let reset_paths : Map[String, Bool] = Map([])
  for path, _ in unmerged {
    reset_paths[path] = true
  }
  for path, e in stage0 {
    match target_files.get(path) {
      Some(t) if t.id == e.id && t.mode == e.mode => ()
      _ => reset_paths[path] = true
    }
  }
  for path, _ in target_files {
    if !stage0.contains(path) {
      reset_paths[path] = true
    }
  }
  let to_write : Map[String, TreeFileEntry] = Map([])
  let emptied : Array[String] = []
  for path, _ in reset_paths {
    match target_files.get(path) {
      Some(t) => if !skip.contains(path) { to_write[path] = t }
      None => {
        let abs = join_path(root, path)
        if @bitio.worktree_entry_meta_sync(rfs, abs) is Some(_) {
          fs.remove_file(abs) catch {
            _ => ()
          }
          emptied.push(parent_dir(abs))
        }
      }
    }
  }
  tree_ops_prune_empty_dirs(fs, rfs, root, emptied)
  write_worktree_from_files(db, fs, rfs, root, git_dir, to_write)
  // Index: kept entries plus the target's version of every reset path.
  let out : Array[IndexEntry] = []
  for path, e in stage0 {
    if !reset_paths.contains(path) {
      out.push(e)
    }
  }
  let reset_files : Map[String, TreeFileEntry] = Map([])
  for path, _ in reset_paths {
    match target_files.get(path) {
      Some(t) => reset_files[path] = t
      None => ()
    }
  }
  for e in tree_files_to_index(db, rfs, reset_files) {
    out.push(e)
  }
  write_index_entries_with_skip_worktree(fs, git_dir, out, skip)
  update_head_ref(fs, rfs, git_dir, target)
}
