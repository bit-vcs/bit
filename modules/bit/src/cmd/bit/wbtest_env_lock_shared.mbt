///|
let cmd_bit_wbtest_env_lock : @async.Semaphore = @async.Semaphore::new(
  1,
  initial_value=1,
)

///|
fn init {
  ignore(cmd_bit_wbtest_env_lock)
  ignore(wbtest_resolve_real_git)
}

///|
/// Resolve real git path for wbtests. Uses third_party/git/git if available,
/// otherwise falls back to system git.
fn wbtest_resolve_real_git(repo_root : String) -> String {
  let third_party = repo_root + "/third_party/git/git"
  let fs : &@bitcore.RepoFileSystem = OsFs::new()
  if fs.is_file(third_party) {
    third_party
  } else {
    "git"
  }
}
