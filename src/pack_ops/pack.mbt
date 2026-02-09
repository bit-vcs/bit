///| Pack object collection facade.

///|
pub fn collect_commit_tree_only(
  db : @gitlib.ObjectDb,
  fs : &@git.RepoFileSystem,
  commit_id : @git.ObjectId,
) -> Array[@git.PackObject] raise @git.GitError {
  @gitlib.collect_commit_tree_only(db, fs, commit_id)
}

///|
pub fn collect_diff_objects(
  db : @gitlib.ObjectDb,
  fs : &@git.RepoFileSystem,
  base_commit : @git.ObjectId,
  new_commit : @git.ObjectId,
) -> Array[@git.PackObject] raise @git.GitError {
  @gitlib.collect_diff_objects(db, fs, base_commit, new_commit)
}

///|
pub fn collect_reachable_objects(
  db : @gitlib.ObjectDb,
  fs : &@git.RepoFileSystem,
  commit_id : @git.ObjectId,
) -> Array[@git.PackObject] raise @git.GitError {
  @gitlib.collect_reachable_objects(db, fs, commit_id)
}

///|
pub fn collect_reachable_objects_from_commits(
  db : @gitlib.ObjectDb,
  fs : &@git.RepoFileSystem,
  commits : Array[@git.ObjectId],
) -> Array[@git.PackObject] raise @git.GitError {
  @gitlib.collect_reachable_objects_from_commits(db, fs, commits)
}
