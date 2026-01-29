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
  let target = match rev_parse(rfs, git_dir, spec) {
    None => raise @git.GitError::InvalidObject("Invalid ref: \{spec}")
    Some(id) => id
  }
  update_head_ref(fs, rfs, git_dir, target)
  match mode {
    Soft => target
    Mixed => {
      let db = ObjectDb::load(rfs, git_dir)
      let files = collect_tree_files_from_commit(db, rfs, target)
      let entries = tree_files_to_index(db, rfs, files)
      write_index_entries(fs, git_dir, entries)
      target
    }
    Hard => {
      let db = ObjectDb::load(rfs, git_dir)
      let files = collect_tree_files_from_commit(db, rfs, target)
      write_worktree_from_files(
        db,
        fs,
        rfs,
        root,
        git_dir,
        files,
        remove_missing=true,
      )
      let entries = tree_files_to_index(db, rfs, files)
      write_index_entries(fs, git_dir, entries)
      target
    }
  }
}
