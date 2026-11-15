///| Checkout must replace worktree symlinks, never write or delete through them.

///|
async fn checkout_symlink_wbtest_run(
  cwd : String,
  cmd : String,
  args : Array[String],
) -> Int raise Error {
  @process.run(
    cmd,
    args[:],
    inherit_env=true,
    cwd~,
    stdout=Discard,
    stderr=Discard,
  ).exit_code
}

///|
async fn checkout_symlink_wbtest_is_symlink(path : String) -> Bool raise Error {
  checkout_symlink_wbtest_run("/", "test", ["-L", path]) == 0
}

///|
/// Repo at `<root>/repo` whose `main` has `link -> <target>` (a symlink) and
/// whose branch `x` replaces `link` with a regular file holding `content`.
/// The worktree is left on `main`, so `link` exists on disk as a symlink.
async fn checkout_symlink_wbtest_setup(
  fs : OsFs,
  root : String,
  target : String,
  content : String,
) -> String raise Error {
  let repo_dir = root + "/repo"
  add_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  add_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  add_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  @test.assert_eq(
    checkout_symlink_wbtest_run(repo_dir, "ln", ["-s", target, "link"]),
    0,
  )
  add_test_run_git(repo_dir, ["add", "link"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "symlink"])
  add_test_run_git(repo_dir, ["checkout", "-q", "-b", "x"])
  add_test_run_git(repo_dir, ["rm", "-q", "link"])
  fs.write_string(repo_dir + "/link", content)
  add_test_run_git(repo_dir, ["add", "link"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "regular file"])
  add_test_run_git(repo_dir, ["checkout", "-q", "main"])
  assert_true(checkout_symlink_wbtest_is_symlink(repo_dir + "/link"))
  repo_dir
}

///|
async fn checkout_symlink_wbtest_checkout(
  repo_dir : String,
  branch : String,
) -> Unit raise Error {
  let prev_shim_cwd = @env.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @env.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @env.get_env_var("GIT_DIR")
  let prev_work_tree = @env.get_env_var("GIT_WORK_TREE")
  @env.set_env_var("GIT_SHIM_CWD", repo_dir)
  @env.set_env_var("GIT_SHIM_PWD", repo_dir)
  @env.unset_env_var("GIT_DIR")
  @env.unset_env_var("GIT_WORK_TREE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  // In-process, so the test exercises this build's checkout (the shim
  // helpers run a prebuilt bit.exe).
  handle_checkout(["-q", branch])
}

///|
async test "checkout: a blob replacing a symlink does not write through it" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-checkout-symlink-file-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let victim = root + "/victim.txt"
  fs.write_string(victim, "original\n")
  let repo_dir = checkout_symlink_wbtest_setup(
    fs, root, "../victim.txt", "ATTACKER\n",
  )

  checkout_symlink_wbtest_checkout(repo_dir, "x")

  // The file outside the worktree is untouched ...
  @test.assert_eq(fs.read_file(victim), b"original\n")
  // ... and the symlink was replaced by a regular file with the blob.
  assert_false(checkout_symlink_wbtest_is_symlink(repo_dir + "/link"))
  @test.assert_eq(fs.read_file(repo_dir + "/link"), b"ATTACKER\n")
  cleanup_tree(fs, root)
}

///|
async test "checkout: replacing a symlinked directory keeps the link target" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-checkout-symlink-dir-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root + "/outside")
  fs.write_string(root + "/outside/keep.txt", "keep\n")
  let repo_dir = checkout_symlink_wbtest_setup(
    fs, root, "../outside", "now a file\n",
  )

  checkout_symlink_wbtest_checkout(repo_dir, "x")

  // Removing the old `link` must unlink the symlink, not empty the
  // directory it points to.
  @test.assert_eq(fs.read_file(root + "/outside/keep.txt"), b"keep\n")
  assert_false(checkout_symlink_wbtest_is_symlink(repo_dir + "/link"))
  @test.assert_eq(fs.read_file(repo_dir + "/link"), b"now a file\n")
  cleanup_tree(fs, root)
}

///|
async test "revert: does not restore a file through a symlinked parent" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-revert-symlink-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"
  add_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  add_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  add_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  // P: a regular directory `a` holding `config`.
  fs.mkdir_p(repo_dir + "/a")
  fs.write_string(repo_dir + "/a/config", "[core]\n\thooksPath = /tmp/pwned\n")
  add_test_run_git(repo_dir, ["add", "a/config"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "P"])
  // C: `a` becomes a symlink to `.git`.
  add_test_run_git(repo_dir, ["rm", "-q", "-r", "a"])
  @test.assert_eq(checkout_symlink_wbtest_run(repo_dir, "ln", ["-s", ".git", "a"]), 0)
  add_test_run_git(repo_dir, ["add", "a"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "C"])
  let config_before = fs.read_file(repo_dir + "/.git/config")

  let prev_shim_cwd = @env.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @env.get_env_var("GIT_SHIM_PWD")
  @env.set_env_var("GIT_SHIM_CWD", repo_dir)
  @env.set_env_var("GIT_SHIM_PWD", repo_dir)
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  // Reverting C would restore `a/config`, i.e. write `.git/config` through
  // the symlink. It must be refused.
  let refused = try {
    handle_revert(["--no-edit", "HEAD"])
    false
  } catch {
    _ => true
  }
  assert_true(refused)
  @test.assert_eq(fs.read_file(repo_dir + "/.git/config"), config_before)
  cleanup_tree(fs, root)
}

///|
async test "verify_worktree_dir_path: a symlinked submodule path is refused" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-dir-path-symlink-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root + "/repo/real")
  fs.mkdir_p(root + "/outside")
  @test.assert_eq(
    checkout_symlink_wbtest_run(root + "/repo", "ln", ["-s", "../outside", "sub"]),
    0,
  )
  let rejected = fn(rel : String) -> Bool {
    try {
      @bitlib.verify_worktree_dir_path(root + "/repo", rel)
      false
    } catch {
      _ => true
    }
  }
  assert_false(rejected("real"))
  assert_false(rejected("not-yet-created"))
  assert_true(rejected("sub"))
  assert_true(rejected("sub/inner"))
  assert_true(rejected(".git"))
  cleanup_tree(fs, root)
}
