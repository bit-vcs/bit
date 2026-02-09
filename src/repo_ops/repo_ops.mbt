///| Repository-oriented operations facade.

///|
pub fn init_repo(
  fs : &@types.FileSystem,
  root : String,
  default_branch? : String = "main",
  bare? : Bool = false,
) -> Unit raise @object.GitError {
  @gitlib.init_repo(fs, root, default_branch~, bare~)
}

///|
pub fn init_repo_with_options(
  fs : &@types.FileSystem,
  root : String,
  opts : @gitlib.InitOptions,
) -> Unit raise @object.GitError {
  @gitlib.init_repo_with_options(fs, root, opts)
}

///|
pub fn apply_template(
  wfs : &@types.FileSystem,
  rfs : &@types.RepoFileSystem,
  git_dir : String,
  template_dir : String,
) -> Unit raise @object.GitError {
  @gitlib.apply_template(wfs, rfs, git_dir, template_dir)
}

///|
pub fn reflog_exists(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Bool {
  @gitlib.reflog_exists(fs, git_dir, refname)
}

///|
pub fn read_reflog(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Array[@gitlib.ReflogEntry] raise @object.GitError {
  @gitlib.read_reflog(fs, git_dir, refname)
}

///|
pub fn append_reflog(
  wfs : &@types.FileSystem,
  rfs : &@types.RepoFileSystem,
  git_dir : String,
  refname : String,
  old_id : @object.ObjectId,
  new_id : @object.ObjectId,
  author : String,
  email : String,
  timestamp : Int64,
  timezone : String,
  message : String,
) -> Unit raise @object.GitError {
  @gitlib.append_reflog(
    wfs, rfs, git_dir, refname, old_id, new_id, author, email, timestamp, timezone,
    message,
  )
}

///|
pub fn create_reflog(
  wfs : &@types.FileSystem,
  rfs : &@types.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Unit raise @object.GitError {
  @gitlib.create_reflog(wfs, rfs, git_dir, refname)
}

///|
pub fn delete_reflog(
  wfs : &@types.FileSystem,
  rfs : &@types.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Unit raise @object.GitError {
  @gitlib.delete_reflog(wfs, rfs, git_dir, refname)
}

///|
pub fn should_log_ref(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  refname : String,
  is_bare : Bool,
) -> (Bool, Bool) raise @object.GitError {
  @gitlib.should_log_ref(fs, git_dir, refname, is_bare)
}
