///|
fn cleanup_tree(fs : OsFs, path : String) -> Unit {
  if fs.is_dir(path) {
    @bitlib.remove_tree(fs, fs, path)
  }
}

///|
fn add_test_restore_env(name : String, value : String?) -> Unit {
  match value {
    Some(val) => @sys.set_env_var(name, val)
    None => @sys.unset_env_var(name)
  }
}

///|
test "hub backend: parse backend kind aliases" {
  match parse_hub_repo_backend_kind("bit") {
    Some(HubRepoBackendKind::Bit) => ()
    _ => fail("expected bit backend")
  }
  match parse_hub_repo_backend_kind("git") {
    Some(HubRepoBackendKind::Git) => ()
    _ => fail("expected git backend")
  }
  match parse_hub_repo_backend_kind("libgit2") {
    Some(HubRepoBackendKind::Git) => ()
    _ => fail("expected libgit2 alias to resolve to git backend")
  }
  match parse_hub_repo_backend_kind("bogus") {
    None => ()
    _ => fail("expected unknown backend to be rejected")
  }
}

///|
test "hub backend: forced bit env selects bit backend" {
  let prev_backend = @sys.get_env_var("BIT_HUB_BACKEND")
  @sys.set_env_var("BIT_HUB_BACKEND", "bit")
  match resolve_hub_repo_backend_kind() {
    HubRepoBackendKind::Bit => ()
    _ => fail("expected bit backend")
  }
  add_test_restore_env("BIT_HUB_BACKEND", prev_backend)
}

///|
test "hub backend: resolve shared git dir follows commondir file" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-hub-backend-commondir-" +
    get_current_timestamp().to_string()
  let worktree_git = root + "/repo/.git/worktrees/topic"
  cleanup_tree(fs, root)
  fs.mkdir_p(worktree_git)
  fs.write_string(worktree_git + "/commondir", "../..\n")
  assert_eq(resolve_hub_common_git_dir(worktree_git), root + "/repo/.git")
  cleanup_tree(fs, root)
}

///|
async test "hub backend: git backend resolves git dir and current branch" {
  if not(can_use_hub_git_backend()) {
    return ()
  }
  let fs = OsFs::new()
  let root = "/tmp/bit-test-hub-backend-git-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)

  let prev_backend = @sys.get_env_var("BIT_HUB_BACKEND")
  let prev_default_branch = @sys.get_env_var(
    "GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME",
  )
  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")

  @sys.set_env_var("BIT_HUB_BACKEND", "git")
  @sys.set_env_var("GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME", "main")
  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.set_env_var("GIT_SHIM_PWD", ".")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")

  @bitrepo.init_repo(fs, root, default_branch="main")

  assert_eq(resolve_hub_git_dir(root), root + "/.git")
  assert_eq(detect_hub_current_branch_name(root), Some("main"))

  add_test_restore_env("BIT_HUB_BACKEND", prev_backend)
  add_test_restore_env(
    "GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME", prev_default_branch,
  )
  add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  add_test_restore_env("GIT_DIR", prev_git_dir)
  add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  cleanup_tree(fs, root)
}
