///| Collect reachable objects for pack generation

///|
pub fn collect_reachable_objects(
  db : ObjectDb,
  fs : &@git.RepoFileSystem,
  commit_id : @git.ObjectId,
) -> Array[@git.PackObject] raise @git.GitError {
  let seen : Map[String, Bool] = {}
  let out : Array[@git.PackObject] = []
  collect_commit_objects(db, fs, commit_id, seen, out)
  out
}

///|
/// Collect reachable objects from multiple commits (deduplicated).
pub fn collect_reachable_objects_from_commits(
  db : ObjectDb,
  fs : &@git.RepoFileSystem,
  commits : Array[@git.ObjectId],
) -> Array[@git.PackObject] raise @git.GitError {
  let seen : Map[String, Bool] = {}
  let out : Array[@git.PackObject] = []
  for commit_id in commits {
    collect_commit_objects(db, fs, commit_id, seen, out)
  }
  out
}

///|
fn collect_commit_objects(
  db : ObjectDb,
  fs : &@git.RepoFileSystem,
  commit_id : @git.ObjectId,
  seen : Map[String, Bool],
  out : Array[@git.PackObject],
) -> Unit raise @git.GitError {
  let hex = commit_id.to_hex()
  if seen.contains(hex) {
    return
  }
  seen[hex] = true
  let obj = db.get(fs, commit_id)
  match obj {
    None => raise @git.GitError::InvalidObject("Missing commit object")
    Some(o) => {
      if o.obj_type != @git.ObjectType::Commit {
        raise @git.GitError::InvalidObject("Object is not a commit")
      }
      out.push(o)
      let info = @git.parse_commit(o.data)
      collect_tree_objects(db, fs, info.tree, seen, out)
      for p in info.parents {
        collect_commit_objects(db, fs, p, seen, out)
      }
    }
  }
}

///|
fn collect_tree_objects(
  db : ObjectDb,
  fs : &@git.RepoFileSystem,
  tree_id : @git.ObjectId,
  seen : Map[String, Bool],
  out : Array[@git.PackObject],
) -> Unit raise @git.GitError {
  let hex = tree_id.to_hex()
  if seen.contains(hex) {
    return
  }
  seen[hex] = true
  let obj = db.get(fs, tree_id)
  match obj {
    None => raise @git.GitError::InvalidObject("Missing tree object")
    Some(o) => {
      if o.obj_type != @git.ObjectType::Tree {
        raise @git.GitError::InvalidObject("Object is not a tree")
      }
      out.push(o)
      let entries = @git.parse_tree(o.data)
      for entry in entries {
        if collect_is_tree_mode(entry.mode) {
          collect_tree_objects(db, fs, entry.id, seen, out)
        } else {
          collect_blob_object(db, fs, entry.id, seen, out)
        }
      }
    }
  }
}

///|
fn collect_blob_object(
  db : ObjectDb,
  fs : &@git.RepoFileSystem,
  blob_id : @git.ObjectId,
  seen : Map[String, Bool],
  out : Array[@git.PackObject],
) -> Unit raise @git.GitError {
  let hex = blob_id.to_hex()
  if seen.contains(hex) {
    return
  }
  seen[hex] = true
  let obj = db.get(fs, blob_id)
  match obj {
    None => raise @git.GitError::InvalidObject("Missing blob object")
    Some(o) => {
      if o.obj_type != @git.ObjectType::Blob {
        raise @git.GitError::InvalidObject("Object is not a blob")
      }
      out.push(o)
    }
  }
}

///|
fn collect_is_tree_mode(mode : String) -> Bool {
  mode == "40000" || mode == "040000"
}
