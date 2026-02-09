///| Remote path helpers facade

///|
pub fn resolve_local_repo_path(
  fs : &@git.RepoFileSystem,
  root : String,
  url : String,
) -> String? {
  @gitremote.resolve_local_repo_path(fs, root, url)
}

///|
pub fn resolve_gitdir(fs : &@git.RepoFileSystem, git_path : String) -> String {
  @gitremote.resolve_gitdir(fs, git_path)
}

///|
pub fn detect_git_dir(
  fs : &@git.RepoFileSystem,
  path : String,
) -> (String, Bool)? {
  @gitremote.detect_git_dir(fs, path)
}

///|
pub fn is_bare_git_dir(git_dir : String) -> Bool {
  @gitremote.is_bare_git_dir(git_dir)
}
