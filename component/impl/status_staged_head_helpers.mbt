///| WASM Component status staged head comparison helpers

///|
fn status_collect_staged_head_changes(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  index_map : Map[String, @bitlib.IndexEntry],
  staged_modified : Array[String],
  staged_deleted : Array[String],
) -> Unit raise @bit.GitError {
  match @bitlib.resolve_head_commit(fs, git_dir) {
    None => ()
    Some(commit_id) => {
      let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
      match db.get(fs, commit_id) {
        None => ()
        Some(obj) => {
          if obj.obj_type != @bit.ObjectType::Commit {
            raise @bit.GitError::InvalidObject("Object is not a commit")
          }
          let info = @bit.parse_commit(obj.data)
          status_collect_staged_tree_changes(
            db,
            fs,
            info.tree,
            "",
            index_map,
            staged_modified,
            staged_deleted,
          )
        }
      }
    }
  }
}
