///| Remote path helpers facade

///|
pub fn resolve_local_repo_path(
  fs : &@bit.RepoFileSystem,
  root : String,
  url : String,
) -> String? {
  @bitremote.resolve_local_repo_path(fs, root, url)
}

///|
pub fn resolve_gitdir(fs : &@bit.RepoFileSystem, bit_path : String) -> String {
  @bitremote.resolve_gitdir(fs, bit_path)
}

///|
pub fn detect_git_dir(
  fs : &@bit.RepoFileSystem,
  path : String,
) -> (String, Bool)? {
  @bitremote.detect_git_dir(fs, path)
}

///|
pub fn is_bare_git_dir(git_dir : String) -> Bool {
  @bitremote.is_bare_git_dir(git_dir)
}
