///| Asynchronous worktree materialization.

///|
/// Asynchronous counterpart to `checkout_commit_to_fs`.
pub async fn[FS : @types.AsyncFileSystem + @types.AsyncRepoFileSystem] checkout_commit_to_fs_async(
  store : ObjectStore,
  commit_id : @object.ObjectId,
  fs : FS,
  root : String,
) -> Unit raise @object.GitError {
  let commit_obj = store.get(commit_id)
  match commit_obj {
    None => raise @object.GitError::InvalidObject("Missing commit object")
    Some(obj) => {
      if obj.obj_type != @object.ObjectType::Commit {
        raise @object.GitError::InvalidObject("Object is not a commit")
      }
      let info = parse_commit(obj.data)
      let files : Map[String, Bool] = Map([])
      let opaque_dirs : Map[String, Bool] = Map([])
      collect_tree_paths(store, info.tree, "", files, opaque_dirs)
      remove_stale_worktree_paths_async(fs, root, files, opaque_dirs)
      walk_tree_to_fs_async(store, info.tree, "", fs, root)
    }
  }
}

///|
async fn[FS : @types.AsyncFileSystem + @types.AsyncRepoFileSystem] remove_stale_worktree_paths_async(
  fs : FS,
  root : String,
  keep_files : Map[String, Bool],
  opaque_dirs : Map[String, Bool],
) -> Unit raise @object.GitError {
  ignore(remove_stale_dir_async(fs, root, "", keep_files, opaque_dirs))
}

///|
async fn[FS : @types.AsyncFileSystem + @types.AsyncRepoFileSystem] remove_stale_dir_async(
  fs : FS,
  root : String,
  rel_dir : String,
  keep_files : Map[String, Bool],
  opaque_dirs : Map[String, Bool],
) -> Bool raise @object.GitError {
  let full_dir = if rel_dir.length() == 0 {
    root
  } else {
    join_path(root, rel_dir)
  }
  if !@types.AsyncRepoFileSystem::is_dir(fs, full_dir) {
    return true
  }
  let names = @types.AsyncRepoFileSystem::readdir(fs, full_dir)
  let mut emptied = true
  for name in names {
    if rel_dir.length() == 0 && name == ".git" {
      emptied = false
      continue
    }
    let rel_path = if rel_dir.length() == 0 {
      name
    } else {
      rel_dir + "/" + name
    }
    if opaque_dirs.contains(rel_path) {
      emptied = false
      continue
    }
    let full_path = join_path(root, rel_path)
    if @types.AsyncRepoFileSystem::is_dir(fs, full_path) {
      let child_emptied = remove_stale_dir_async(
        fs, root, rel_path, keep_files, opaque_dirs,
      )
      if child_emptied {
        @types.AsyncFileSystem::remove_dir(fs, full_path)
      } else {
        emptied = false
      }
    } else if keep_files.contains(rel_path) {
      emptied = false
    } else {
      @types.AsyncFileSystem::remove_file(fs, full_path)
    }
  }
  emptied
}

///|
async fn[FS : @types.AsyncFileSystem] walk_tree_to_fs_async(
  store : ObjectStore,
  tree_id : @object.ObjectId,
  prefix : String,
  fs : FS,
  root : String,
) -> Unit raise @object.GitError {
  let tree_obj = store.get(tree_id)
  match tree_obj {
    None => raise @object.GitError::InvalidObject("Missing tree object")
    Some(obj) => {
      if obj.obj_type != @object.ObjectType::Tree {
        raise @object.GitError::InvalidObject("Object is not a tree")
      }
      let entries = parse_tree(obj.data)
      for entry in entries {
        verify_tree_entry_name(entry.name)
        let path = if prefix.length() == 0 {
          entry.name
        } else {
          prefix + "/" + entry.name
        }
        if is_tree_mode(entry.mode) {
          walk_tree_to_fs_async(store, entry.id, path, fs, root)
        } else if is_gitlink_mode(entry.mode) {
          @types.AsyncFileSystem::mkdir_p(fs, join_path(root, path))
        } else {
          let blob_obj = store.get(entry.id)
          match blob_obj {
            None => raise @object.GitError::InvalidObject("Missing blob object")
            Some(blob) => {
              if blob.obj_type != @object.ObjectType::Blob {
                raise @object.GitError::InvalidObject("Object is not a blob")
              }
              let full_path = join_path(root, path)
              @types.AsyncFileSystem::mkdir_p(fs, parent_dir(full_path))
              @types.AsyncFileSystem::write_file(fs, full_path, blob.data)
            }
          }
        }
      }
    }
  }
}
