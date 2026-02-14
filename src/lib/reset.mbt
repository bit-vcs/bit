///| Reset implementation

///|
pub(all) enum ResetMode {
  Soft
  Mixed
  Hard
}

///|
pub fn reset(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  spec : String,
  mode : ResetMode,
) -> @git.ObjectId raise @git.GitError {
  let git_dir = join_path(root, ".git")
  let actual_git_dir = if rfs.is_file(git_dir) {
    resolve_gitdir(rfs, git_dir)
  } else {
    git_dir
  }
  let object_git_dir = reset_resolve_common_git_dir(rfs, actual_git_dir)
  let target = match rev_parse(rfs, actual_git_dir, spec) {
    None => raise @git.GitError::InvalidObject("Invalid ref: \{spec}")
    Some(id) => id
  }
  update_head_ref(fs, rfs, actual_git_dir, target)
  match mode {
    Soft => target
    Mixed => {
      let db = ObjectDb::load(rfs, object_git_dir)
      let files = collect_tree_files_from_commit(db, rfs, target)
      let entries = tree_files_to_index(db, rfs, files)
      write_index_entries(fs, actual_git_dir, entries)
      target
    }
    Hard => {
      let db = ObjectDb::load(rfs, object_git_dir)
      let files = collect_tree_files_from_commit(db, rfs, target)
      write_worktree_from_files(
        db,
        fs,
        rfs,
        root,
        actual_git_dir,
        files,
        remove_missing=true,
      )
      let entries = tree_files_to_index(db, rfs, files)
      write_index_entries(fs, actual_git_dir, entries)
      target
    }
  }
}

///|
fn reset_resolve_common_git_dir(
  fs : &@git.RepoFileSystem,
  git_dir : String,
) -> String {
  let commondir_path = join_path(git_dir, "commondir")
  if not(fs.is_file(commondir_path)) {
    return git_dir
  }
  let raw = @utf8.decode_lossy(
    (fs.read_file(commondir_path) catch { _ => Bytes::default() })[:],
  )
  let rel = trim_string(raw)
  if rel.length() == 0 {
    return git_dir
  }
  if rel.has_prefix("/") {
    normalize_path(rel)
  } else {
    normalize_path(join_path(git_dir, rel))
  }
}
