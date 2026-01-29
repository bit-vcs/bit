///| Tree helpers for checkout/reset/merge

///|
pub struct TreeFileEntry {
  id : ObjectId
  mode : Int
}

///|
pub fn collect_tree_files(
  db : ObjectDb,
  fs : &RepoFileSystem,
  tree_id : ObjectId,
) -> Map[String, TreeFileEntry] raise GitError {
  let out : Map[String, TreeFileEntry] = {}
  collect_tree_files_inner(db, fs, tree_id, "", out)
  out
}

///|
pub fn collect_tree_files_from_commit(
  db : ObjectDb,
  fs : &RepoFileSystem,
  commit_id : ObjectId,
) -> Map[String, TreeFileEntry] raise GitError {
  let commit_obj = db.get(fs, commit_id)
  match commit_obj {
    None => raise GitError::InvalidObject("Missing commit object")
    Some(obj) => {
      if obj.obj_type != ObjectType::Commit {
        raise GitError::InvalidObject("Object is not a commit")
      }
      let info = parse_commit(obj.data)
      collect_tree_files(db, fs, info.tree)
    }
  }
}

///|
pub fn tree_files_to_index(
  db : ObjectDb,
  fs : &RepoFileSystem,
  files : Map[String, TreeFileEntry],
) -> Array[IndexEntry] raise GitError {
  let entries : Array[IndexEntry] = []
  for item in files.to_array() {
    let (path, info) = item
    let obj = db.get(fs, info.id)
    match obj {
      None => raise GitError::InvalidObject("Missing blob object")
      Some(o) => {
        if o.obj_type != ObjectType::Blob {
          raise GitError::InvalidObject("Object is not a blob")
        }
        entries.push({
          path,
          id: info.id,
          mode: info.mode,
          size: o.data.length(),
        })
      }
    }
  }
  entries.sort_by(fn(a, b) { String::compare(a.path, b.path) })
  entries
}

///|
pub fn write_worktree_from_files(
  db : ObjectDb,
  fs : &FileSystem,
  rfs : &RepoFileSystem,
  root : String,
  git_dir : String,
  files : Map[String, TreeFileEntry],
  remove_missing? : Bool = false,
) -> Unit raise GitError {
  if remove_missing {
    let entries = read_index_entries(rfs, git_dir)
    for entry in entries {
      if not(files.contains(entry.path)) {
        let path = join_path(root, entry.path)
        if rfs.is_file(path) {
          fs.remove_file(path)
        }
      }
    }
  }
  for item in files.to_array() {
    let (path, info) = item
    let obj = db.get(rfs, info.id)
    match obj {
      None => raise GitError::InvalidObject("Missing blob object")
      Some(o) => {
        if o.obj_type != ObjectType::Blob {
          raise GitError::InvalidObject("Object is not a blob")
        }
        let full_path = join_path(root, path)
        let dir = parent_dir(full_path)
        fs.mkdir_p(dir)
        fs.write_file(full_path, o.data)
      }
    }
  }
}

///|
fn collect_tree_files_inner(
  db : ObjectDb,
  fs : &RepoFileSystem,
  tree_id : ObjectId,
  prefix : String,
  out : Map[String, TreeFileEntry],
) -> Unit raise GitError {
  let tree_obj = db.get(fs, tree_id)
  match tree_obj {
    None => raise GitError::InvalidObject("Missing tree object")
    Some(obj) => {
      if obj.obj_type != ObjectType::Tree {
        raise GitError::InvalidObject("Object is not a tree")
      }
      let entries = parse_tree(obj.data)
      for entry in entries {
        let path = if prefix.length() == 0 {
          entry.name
        } else {
          prefix + "/" + entry.name
        }
        if is_tree_mode(entry.mode) {
          collect_tree_files_inner(db, fs, entry.id, path, out)
        } else {
          let mode = worktree_parse_octal(entry.mode)
          out[path] = { id: entry.id, mode }
        }
      }
    }
  }
}
