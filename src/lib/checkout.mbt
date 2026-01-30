///| Checkout implementation

///|
/// Restore files from index to working tree (like `git checkout -- <paths>` or `git restore <paths>`).
pub fn restore_paths(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  paths : Array[String],
) -> Unit raise @git.GitError {
  let git_dir = join_path(root, ".git")
  let index_entries = read_index_entries(rfs, git_dir)
  let index_map : Map[String, IndexEntry] = {}
  for e in index_entries {
    index_map[e.path] = e
  }
  let db = ObjectDb::load(rfs, git_dir)
  for path in paths {
    match index_map.get(path) {
      None =>
        raise @git.GitError::InvalidObject(
          "error: pathspec '\{path}' did not match any file(s) known to git",
        )
      Some(entry) => {
        let obj = db.get(rfs, entry.id)
        match obj {
          None =>
            raise @git.GitError::InvalidObject(
              "Object not found: \{entry.id.to_hex()}",
            )
          Some(o) => {
            let abs_path = join_path(root, path)
            let dir = parent_dir(abs_path)
            if dir.length() > 0 && dir != root {
              fs.mkdir_p(dir)
            }
            fs.write_file(abs_path, o.data)
          }
        }
      }
    }
  }
}

///|
pub fn checkout(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  spec : String,
  detach? : Bool = false,
  update_worktree? : Bool = true,
  update_index? : Bool = true,
) -> @git.ObjectId raise @git.GitError {
  let git_dir = join_path(root, ".git")
  let head_path = join_path(git_dir, "HEAD")
  let mut target : @git.ObjectId? = None
  let mut refname : String? = None
  if not(detach) {
    let name = if spec.has_prefix("refs/") {
      spec
    } else {
      "refs/heads/" + spec
    }
    match resolve_ref(rfs, git_dir, name) {
      Some(id) => {
        target = Some(id)
        refname = Some(name)
      }
      None => ()
    }
  }
  match target {
    None => {
      let resolved = rev_parse(rfs, git_dir, spec)
      match resolved {
        None => raise @git.GitError::InvalidObject("Invalid ref: \{spec}")
        Some(id) => target = Some(id)
      }
    }
    Some(_) => ()
  }
  let commit_id = match target {
    None => raise @git.GitError::InvalidObject("Invalid ref: \{spec}")
    Some(id) => id
  }
  match refname {
    Some(name) => fs.write_string(head_path, "ref: \{name}\n")
    None => fs.write_string(head_path, commit_id.to_hex() + "\n")
  }
  if update_worktree || update_index {
    let db = ObjectDb::load(rfs, git_dir)
    let files = collect_tree_files_from_commit(db, rfs, commit_id)
    if update_worktree {
      write_worktree_from_files(
        db,
        fs,
        rfs,
        root,
        git_dir,
        files,
        remove_missing=true,
      )
    }
    if update_index {
      let entries = tree_files_to_index(db, rfs, files)
      write_index_entries(fs, git_dir, entries)
    }
  }
  commit_id
}
