///|
let cmd_bit_wbtest_env_lock : @async.Semaphore = @async.Semaphore::new(
  1,
  initial_value=1,
)

///|
fn init {
  ignore(cmd_bit_wbtest_env_lock)
  ignore(wbtest_resolve_real_git)
  ignore(wbtest_resolve_bit_exe)
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

///|
/// Resolve the freshly built `bit.exe` for wbtests. The native binary lives
/// under a debug or release build directory depending on how it was compiled,
/// so prefer whichever exists (debug first, since that is the default build).
fn wbtest_resolve_bit_exe(repo_root : String) -> String {
  let fs : &@bitcore.RepoFileSystem = OsFs::new()
  let debug_path = repo_root +
    "/_build/native/debug/build/mizchi/bit/cmd/bit/bit.exe"
  let release_path = repo_root +
    "/_build/native/release/build/mizchi/bit/cmd/bit/bit.exe"
  if fs.is_file(debug_path) {
    debug_path
  } else {
    release_path
  }
}
