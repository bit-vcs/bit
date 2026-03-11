///|
test "init: normalize path preserves leading parent segments in relative paths" {
  assert_eq(init_normalize_path("./../realgit"), "../realgit")
  assert_eq(init_normalize_path("../../repo/.git"), "../../repo/.git")
}

///|
test "init: normalize path keeps absolute parent traversal rooted" {
  assert_eq(init_normalize_path("/tmp/work/../realgit"), "/tmp/realgit")
  assert_eq(init_normalize_path("/tmp/../../realgit"), "/realgit")
}

///|
test "init: shared mode parsing supports symbolic and octal values" {
  assert_eq(init_shared_file_mode(Some("group")), Some(0o660))
  assert_eq(init_shared_file_mode(Some("all")), Some(0o664))
  assert_eq(init_shared_file_mode(Some("0660")), Some(0o660))
  assert_eq(init_shared_file_mode(Some("umask")), None)
  assert_eq(init_shared_file_mode(Some("bogus")), None)
}

///|
test "init: shared directory mode derives traversal bits and setgid" {
  assert_eq(init_shared_dir_mode(0o660), 0o2770)
  assert_eq(init_shared_dir_mode(0o664), 0o2775)
  assert_eq(init_shared_dir_mode(0o640), 0o2750)
}

///|
async test "init: respects GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-init-default-branch-env-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  let prev_default_branch = @sys.get_env_var(
    "GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME",
  )

  @sys.set_env_var("GIT_SHIM_CWD", root)
  @sys.set_env_var("GIT_SHIM_PWD", root)
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME", "main")

  handle_init(["-q", "repo"])

  assert_eq(
    decode_bytes(fs.read_file(root + "/repo/.git/HEAD")),
    "ref: refs/heads/main\n",
  )

  add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  add_test_restore_env("GIT_DIR", prev_git_dir)
  add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  add_test_restore_env(
    "GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME", prev_default_branch,
  )
  cleanup_tree(fs, root)
}
