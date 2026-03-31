///| WASM Component status staged tree traversal helpers

///|
fn status_tree_entry_path(prefix : String, name : String) -> String {
  if prefix.length() == 0 {
    name
  } else {
    prefix + "/" + name
  }
}

///|
fn status_collect_staged_tree_changes(
  db : @bitlib.ObjectDb,
  fs : &@bit.RepoFileSystem,
  tree_id : @bit.ObjectId,
  prefix : String,
  index_map : Map[String, @bitlib.IndexEntry],
  staged_modified : Array[String],
  staged_deleted : Array[String],
) -> Unit raise @bit.GitError {
  let tree_obj = db.get(fs, tree_id)
  match tree_obj {
    None => raise @bit.GitError::InvalidObject("Missing tree object")
    Some(obj) => {
      if obj.obj_type != @bit.ObjectType::Tree {
        raise @bit.GitError::InvalidObject("Object is not a tree")
      }
      let entries = @bit.parse_tree(obj.data)
      for entry in entries {
        let path = status_tree_entry_path(prefix, entry.name)
        if status_is_tree_mode(entry.mode) {
          status_collect_staged_tree_changes(
            db,
            fs,
            entry.id,
            path,
            index_map,
            staged_modified,
            staged_deleted,
          )
        } else {
          let mode = status_parse_octal_mode(entry.mode)
          match index_map.get(path) {
            Some(index_entry) => {
              if index_entry.id != entry.id || index_entry.mode != mode {
                staged_modified.push(path)
              }
              index_map.remove(path)
            }
            None => staged_deleted.push(path)
          }
        }
      }
    }
  }
}
