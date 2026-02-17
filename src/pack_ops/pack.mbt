///| Pack object collection facade.

///|
pub fn collect_commit_tree_only(
  db : @bitlib.ObjectDb,
  fs : &@bit.RepoFileSystem,
  commit_id : @bit.ObjectId,
) -> Array[@bit.PackObject] raise @bit.GitError {
  @bitlib.collect_commit_tree_only(db, fs, commit_id)
}

///|
pub fn collect_diff_objects(
  db : @bitlib.ObjectDb,
  fs : &@bit.RepoFileSystem,
  base_commit : @bit.ObjectId,
  new_commit : @bit.ObjectId,
) -> Array[@bit.PackObject] raise @bit.GitError {
  @bitlib.collect_diff_objects(db, fs, base_commit, new_commit)
}

///|
pub fn collect_reachable_objects(
  db : @bitlib.ObjectDb,
  fs : &@bit.RepoFileSystem,
  commit_id : @bit.ObjectId,
) -> Array[@bit.PackObject] raise @bit.GitError {
  @bitlib.collect_reachable_objects(db, fs, commit_id)
}

///|
pub fn collect_reachable_objects_from_commits(
  db : @bitlib.ObjectDb,
  fs : &@bit.RepoFileSystem,
  commits : Array[@bit.ObjectId],
) -> Array[@bit.PackObject] raise @bit.GitError {
  @bitlib.collect_reachable_objects_from_commits(db, fs, commits)
}
