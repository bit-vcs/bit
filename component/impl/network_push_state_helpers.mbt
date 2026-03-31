///| WASM Component push state preparation helpers

///|
fn net_select_push_refname(refspec : String) -> String {
  if refspec.length() > 0 {
    refspec
  } else {
    "refs/heads/main"
  }
}

///|
fn net_prepare_push_state(
  rfs : &@bit.RepoFileSystem,
  root : String,
  refspec : String,
) -> (String, @bit.ObjectId, Bytes) raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let head = @bitlib.resolve_head_commit(rfs, git_dir)
  guard head is Some(head_id) else {
    raise @bit.GitError::InvalidObject("HEAD not found")
  }
  let db = @bitlib.ObjectDb::load_lazy(rfs, git_dir)
  let objects = @bitlib.collect_reachable_objects(db, rfs, head_id)
  let pack = @pack.create_packfile(objects)
  (net_select_push_refname(refspec), head_id, pack)
}
