///| Checkout implementation

///|
/// Restore files from index to working tree (like `git checkout -- <paths>` or `git restore <paths>`).
pub fn restore_paths(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  paths : Array[String],
  restored? : Map[String, TreeFileEntry] = Map([]),
) -> Unit raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let actual_git_dir = if rfs.is_file(git_dir) {
    resolve_gitdir(rfs, git_dir)
  } else {
    git_dir
  }
  let object_git_dir = resolve_checkout_common_git_dir(rfs, actual_git_dir)
  let index_entries = read_index_entries(rfs, actual_git_dir)
  let skip = read_skip_worktree_paths(rfs, actual_git_dir)
  // git (2.37+) clears the skip-worktree bit of entries whose file is
  // present on disk when it reads the index of a sparse checkout, so such
  // a path matches a pathspec and is restored like any tracked file.
  let cleared : Array[String] = []
  if is_sparse_checkout_enabled(rfs, actual_git_dir) {
    for path, _ in skip {
      if @bitio.worktree_entry_meta_sync(rfs, join_path(root, path)) is Some(_) {
        cleared.push(path)
      }
    }
    for path in cleared {
      skip.remove(path)
    }
  }
  if cleared.length() > 0 && read_unmerged_paths(rfs, actual_git_dir).length() == 0 {
    write_index_entries_with_skip_worktree(fs, actual_git_dir, index_entries, skip)
  }
  let autocrlf = read_autocrlf_setting(rfs, actual_git_dir)
  let core_eol = read_core_eol_setting(rfs, actual_git_dir)
  let db = ObjectDb::load(rfs, object_git_dir)
  // Resolve every pathspec (a file, or a directory prefix) first, so a
  // bad one fails before anything is written, as in git.
  let selected : Array[IndexEntry] = []
  let seen : Map[String, Bool] = Map([])
  for path in paths {
    let safe_path = normalize_checkout_path(path)
    let mut matched = false
    for e in index_entries {
      // Skip-worktree (sparse) entries do not match a pathspec, as in git.
      if !skip.contains(e.path) &&
        (safe_path == "" ||
        e.path == safe_path ||
        e.path.has_prefix(safe_path + "/")) {
        matched = true
        if !seen.contains(e.path) {
          seen[e.path] = true
          selected.push(e)
        }
      }
    }
    if !matched {
      raise @bit.GitError::InvalidObject(
        "error: pathspec '\{path}' did not match any file(s) known to git",
      )
    }
  }
  for entry in selected {
    if is_gitlink_mode_int(entry.mode) {
      continue
    }
    let o = match db.get(rfs, entry.id) {
      Some(o) => o
      None =>
        raise @bit.GitError::InvalidObject(
          "Object not found: \{entry.id.to_hex()}",
        )
    }
    let abs_path = join_path(root, entry.path)
    let dir = parent_dir(abs_path)
    if dir.length() > 0 && dir != root {
      fs.mkdir_p(dir)
    }
    // Never write through a worktree symlink: replace the link itself.
    if @bitio.worktree_entry_meta_sync(rfs, abs_path) is Some(info) &&
      info.kind is @bitio.WorktreeKindMeta::Symlink {
      fs.remove_file(abs_path)
    }
    let attrs = resolve_eol_attrs(rfs, root, entry.path)
    let data = if attrs.filter == Some("lfs") && is_lfs_pointer(o.data) {
      match parse_lfs_pointer(o.data) {
        Some(ptr) =>
          match lfs_get_cached_content(rfs, actual_git_dir, ptr.oid) {
            Some(cached) => cached
            None => o.data
          }
        None => o.data
      }
    } else {
      o.data
    }
    let output = if entry.mode == 0o120000 {
      o.data
    } else {
      smudge_for_checkout(data, attrs, autocrlf, core_eol~)
    }
    fs.write_file(abs_path, output)
    restored[entry.path] = { id: entry.id, mode: entry.mode }
  }
}

///|
fn normalize_checkout_path(path : String) -> String raise @bit.GitError {
  if path.has_prefix("/") {
    raise @bit.GitError::InvalidObject("path must not be absolute")
  }
  normalize_repo_path(path)
}

///|
pub fn checkout(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  spec : String,
  detach? : Bool = false,
  update_worktree? : Bool = true,
  update_index? : Bool = true,
  keep_local_changes? : Bool = false,
  updated_paths? : Array[String],
) -> @bit.ObjectId raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let actual_git_dir = if rfs.is_file(git_dir) {
    resolve_gitdir(rfs, git_dir)
  } else {
    git_dir
  }
  let object_git_dir = resolve_checkout_common_git_dir(rfs, actual_git_dir)
  let head_path = join_path(actual_git_dir, "HEAD")
  let mut target : @bit.ObjectId? = None
  let mut refname : String? = None
  if !detach {
    let name = if spec.has_prefix("refs/") {
      spec
    } else {
      "refs/heads/" + spec
    }
    match resolve_ref(rfs, actual_git_dir, name) {
      Some(id) => {
        target = Some(id)
        refname = Some(name)
      }
      None =>
        if !spec.has_prefix("refs/") {
          let remote_ref = "refs/remotes/origin/" + spec
          match resolve_ref(rfs, actual_git_dir, remote_ref) {
            Some(id) => {
              let local_ref = "refs/heads/" + spec
              let ref_path = join_path(actual_git_dir, local_ref)
              let dir = parent_dir(ref_path)
              if dir.length() > 0 {
                fs.mkdir_p(dir)
              }
              fs.write_string(ref_path, id.to_hex() + "\n")
              set_config_key(
                fs, rfs, actual_git_dir, "branch", spec, "remote", "origin",
              )
              set_config_key(
                fs,
                rfs,
                actual_git_dir,
                "branch",
                spec,
                "merge",
                "refs/heads/" + spec,
              )
              target = Some(id)
              refname = Some(local_ref)
            }
            None => ()
          }
        }
    }
  }
  match target {
    None => {
      let resolved = rev_parse(rfs, actual_git_dir, spec)
      match resolved {
        None => raise @bit.GitError::InvalidObject("Invalid ref: \{spec}")
        Some(id) => {
          let peeled_commit = rev_parse(rfs, actual_git_dir, spec + "^{commit}")
          target = Some(peeled_commit.unwrap_or(id))
        }
      }
    }
    Some(_) => ()
  }
  let commit_id = match target {
    None => raise @bit.GitError::InvalidObject("Invalid ref: \{spec}")
    Some(id) => id
  }
  if keep_local_changes && update_worktree && update_index {
    // git's two-tree checkout: only paths that differ between the old and
    // new commits are touched; local changes elsewhere carry over, and a
    // change that would be lost aborts the checkout before anything
    // (HEAD included) is written.
    checkout_two_way(
      fs,
      rfs,
      root,
      actual_git_dir,
      object_git_dir,
      commit_id,
      updated_paths?,
    )
    if refname is Some(name) {
      fs.write_string(head_path, "ref: \{name}\n")
    } else {
      fs.write_string(head_path, commit_id.to_hex() + "\n")
    }
    return commit_id
  }
  if refname is Some(name) {
    fs.write_string(head_path, "ref: \{name}\n")
  } else {
    fs.write_string(head_path, commit_id.to_hex() + "\n")
  }
  if update_worktree || update_index {
    let db = ObjectDb::load_lazy(rfs, object_git_dir)
    db.set_skip_verify(true)
    let files = collect_tree_files_from_commit(db, rfs, commit_id)
    if update_worktree && update_index {
      // Combined path: read each blob only once
      let entries = write_worktree_and_build_index(
        db,
        fs,
        rfs,
        root,
        actual_git_dir,
        files,
        remove_missing=true,
      )
      write_index_entries(fs, actual_git_dir, entries)
    } else if update_worktree {
      write_worktree_from_files(
        db,
        fs,
        rfs,
        root,
        actual_git_dir,
        files,
        remove_missing=true,
      )
    } else {
      let entries = tree_files_to_index(db, rfs, files)
      write_index_entries(fs, actual_git_dir, entries)
    }
  }
  commit_id
}

///|
pub fn resolve_checkout_common_git_dir(
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
fn checkout_entry_eq(a : TreeFileEntry?, b : TreeFileEntry?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) => x.id == y.id && x.mode == y.mode
    _ => false
  }
}

///|
/// The worktree file at `path` as a (blob id, mode) pair, read without
/// following a symlink; None when absent (or a directory).
fn checkout_worktree_entry(
  rfs : &@bit.RepoFileSystem,
  root : String,
  path : String,
) -> TreeFileEntry? {
  let abs = join_path(root, path)
  match @bitio.worktree_entry_meta_sync(rfs, abs) {
    Some(info) =>
      match info.kind {
        @bitio.WorktreeKindMeta::Symlink =>
          @bitio.read_symlink_target_path(abs).map(fn(t) {
            { id: @bit.hash_blob(@utf8.encode(t)), mode: 0o120000 }
          })
        @bitio.WorktreeKindMeta::Regular => {
          let data = rfs.read_file(abs) catch { _ => return None }
          Some({ id: @bit.hash_blob(data), mode: info.mode })
        }
      }
    None =>
      if rfs.is_file(abs) {
        let data = rfs.read_file(abs) catch { _ => return None }
        Some({ id: @bit.hash_blob(data), mode: 0o100644 })
      } else {
        None
      }
  }
}

///|
fn checkout_two_way(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
  object_git_dir : String,
  target : @bit.ObjectId,
  updated_paths? : Array[String],
) -> Unit raise @bit.GitError {
  if read_unmerged_paths(rfs, git_dir).length() > 0 {
    raise @bit.GitError::InvalidObject(
      "you need to resolve your current index first",
    )
  }
  let db = ObjectDb::load_lazy(rfs, object_git_dir)
  db.set_skip_verify(true)
  let old_files : Map[String, TreeFileEntry] = match
    resolve_head_commit(rfs, git_dir) {
    Some(h) => collect_tree_files_from_commit(db, rfs, h)
    None => Map([])
  }
  let new_files = collect_tree_files_from_commit(db, rfs, target)
  let entries = read_index_entries(rfs, git_dir)
  let index : Map[String, IndexEntry] = Map([])
  for e in entries {
    index[e.path] = e
  }
  let skip = effective_skip_worktree_paths(rfs, root, git_dir)
  let sparse_patterns = if is_sparse_checkout_enabled(rfs, git_dir) {
    Some(read_sparse_patterns(rfs, git_dir))
  } else {
    None
  }
  let paths : Map[String, Bool] = Map([])
  for p, _ in old_files {
    paths[p] = true
  }
  for p, _ in new_files {
    paths[p] = true
  }
  for p, _ in index {
    paths[p] = true
  }
  let to_write : Map[String, TreeFileEntry] = Map([])
  let to_delete : Array[String] = []
  let index_only : Array[String] = []
  let dirty : Array[String] = []
  let untracked : Array[String] = []
  let sparse_present : Array[String] = []
  let removed_untracked : Array[String] = []
  for path, _ in paths {
    let o = old_files.get(path)
    let n = new_files.get(path)
    let i : TreeFileEntry? = index.get(path).map(fn(e) { { id: e.id, mode: e.mode } })
    // git refuses to delete an untracked file the old tree had (the
    // index no longer tracks it, so the switch would lose it).
    if i is None &&
      o is Some(_) &&
      n is None &&
      !skip.contains(path) &&
      checkout_worktree_entry(rfs, root, path) is Some(_) {
      removed_untracked.push(path)
      continue
    }
    if checkout_entry_eq(o, n) || checkout_entry_eq(i, n) {
      continue
    }
    if !checkout_entry_eq(i, o) {
      // A staged change that the switch would discard.
      dirty.push(path)
      continue
    }
    if skip.contains(path) || (n is Some(e) && is_gitlink_mode_int(e.mode)) ||
      (o is Some(e) && is_gitlink_mode_int(e.mode)) {
      index_only.push(path)
      continue
    }
    let w = checkout_worktree_entry(rfs, root, path)
    match i {
      // A tracked file missing from the worktree loses nothing (git).
      Some(_) =>
        if w is Some(_) && !checkout_entry_eq(w, i) {
          dirty.push(path)
          continue
        }
      // git refuses to overwrite any untracked file, even an identical one
      // -- except in a sparse checkout, where a new entry's check is only a
      // warning ("already present and thus not updated despite sparse
      // patterns"). Despite its wording, git still writes an entry inside
      // the cone over the file (unpack-trees keeps CE_UPDATE); one outside
      // the cone becomes skip-worktree and the file is left as it is.
      None =>
        if w is Some(_) {
          match (sparse_patterns, n) {
            (Some(patterns), Some(_)) if matches_sparse_pattern(path, patterns) =>
              sparse_present.push(path)
            (Some(_), _) => {
              index_only.push(path)
              continue
            }
            (None, _) => {
              untracked.push(path)
              continue
            }
          }
        }
    }
    match n {
      Some(e) => to_write[path] = e
      None => to_delete.push(path)
    }
  }
  if dirty.length() > 0 {
    dirty.sort()
    raise @bit.GitError::InvalidObject(
      "Your local changes to the following files would be overwritten by checkout:\n\t" +
      dirty.join("\n\t") +
      "\nPlease commit your changes or stash them before you switch branches.\nAborting",
    )
  }
  if untracked.length() > 0 {
    untracked.sort()
    raise @bit.GitError::InvalidObject(
      "The following untracked working tree files would be overwritten by checkout:\n\t" +
      untracked.join("\n\t") +
      "\nPlease move or remove them before you switch branches.\nAborting",
    )
  }
  if removed_untracked.length() > 0 {
    removed_untracked.sort()
    raise @bit.GitError::InvalidObject(
      "The following untracked working tree files would be removed by checkout:\n\t" +
      removed_untracked.join("\n\t") +
      "\nPlease move or remove them before you switch branches.\nAborting",
    )
  }
  note_sparse_not_updated(rfs, git_dir, sparse_present)
  // Apply: deletions first (a file may become a directory), then writes.
  to_delete.sort()
  for path in to_delete {
    let abs = join_path(root, path)
    if worktree_path_is_symlink(abs) || rfs.is_file(abs) {
      fs.remove_file(abs) catch {
        _ => ()
      }
    }
    // Remove directories the deletion left empty, like git.
    let mut dir = parent_dir(abs)
    while dir.length() > root.length() && dir.has_prefix(root) {
      let children = rfs.readdir(dir) catch { _ => break }
      if children.length() > 0 {
        break
      }
      fs.remove_dir(dir) catch {
        _ => break
      }
      dir = parent_dir(dir)
    }
    index.remove(path)
  }
  if to_write.length() > 0 {
    write_worktree_from_files(
      db,
      fs,
      rfs,
      root,
      git_dir,
      to_write,
      remove_missing=false,
    )
    for e in tree_files_to_index(db, rfs, to_write) {
      index[e.path] = e
    }
  }
  for path in index_only {
    match new_files.get(path) {
      Some(e) => {
        let entry = IndexEntry::new(path, e.id, e.mode, 0)
        index[path] = entry
      }
      None => index.remove(path)
    }
  }
  write_index_entries_preserving_cache_tree(
    fs,
    rfs,
    git_dir,
    index.values().to_array(),
  )
  if updated_paths is Some(out) {
    for p, _ in to_write {
      out.push(p)
    }
    for p in to_delete {
      out.push(p)
    }
  }
}
