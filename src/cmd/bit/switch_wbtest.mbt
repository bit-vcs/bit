///|
async fn switch_wbtest_case_tracking_config_uses_short_branch_names() -> Unit raise Error {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-switch-tracking-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"
  let git_dir = repo_dir + "/.git"

  add_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  add_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  add_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  fs.write_string(repo_dir + "/init.t", "main\n")
  add_test_run_git(repo_dir, ["add", "init.t"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "main"])
  add_test_run_git(repo_dir, ["branch", "foo"])
  add_test_run_git(repo_dir, ["config", "branch.foo.remote", "origin"])
  add_test_run_git(repo_dir, ["config", "branch.foo.merge", "refs/heads/foo"])

  switch_apply_tracking_config(
    fs,
    fs,
    git_dir,
    "refs/heads/foo2",
    Some("foo"),
    Some("inherit"),
  )
  switch_apply_tracking_config(
    fs,
    fs,
    git_dir,
    "refs/heads/foo4",
    Some("foo"),
    Some("direct"),
  )

  let (_, branches) = @bitlib.read_repo_config(fs, git_dir)
  match branches.get("foo2") {
    Some(cfg) => {
      assert_eq(cfg.remote, Some("origin"))
      assert_eq(cfg.merges, ["refs/heads/foo"])
    }
    None => fail("expected inherited tracking config for foo2")
  }
  match branches.get("foo4") {
    Some(cfg) => {
      assert_eq(cfg.remote, Some("."))
      assert_eq(cfg.merges, ["refs/heads/foo"])
    }
    None => fail("expected direct tracking config for foo4")
  }
  assert_true(branches.get("refs/heads/foo2") is None)
  assert_true(branches.get("refs/heads/foo4") is None)

  cleanup_tree(fs, root)
}

///|
async fn switch_wbtest_case_branch_in_use_path_accepts_full_ref() -> Unit raise Error {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-switch-branch-in-use-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"
  let linked_dir = repo_dir + "/wt1"

  add_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  add_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  add_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  fs.write_string(repo_dir + "/init.t", "main\n")
  add_test_run_git(repo_dir, ["add", "init.t"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "main"])
  add_test_run_git(repo_dir, ["checkout", "-q", "-b", "shared"])
  fs.write_string(repo_dir + "/init.t", "shared\n")
  add_test_run_git(repo_dir, ["commit", "-qam", "shared"])
  add_test_run_git(repo_dir, ["worktree", "add", "-f", "wt1", "shared"])
  add_test_run_git(linked_dir, ["checkout", "--detach", "-q", "HEAD"])
  let expected_repo = add_test_git_stdout(repo_dir, [
      "rev-parse", "--show-toplevel",
    ])
    |> add_test_trim_trailing_newline

  assert_eq(
    switch_branch_in_use_path(fs, linked_dir, "refs/heads/shared"),
    Some(expected_repo),
  )

  cleanup_tree(fs, root)
}

///|
async test "switch: helper cases stay compatible" {
  switch_wbtest_case_tracking_config_uses_short_branch_names()
  switch_wbtest_case_branch_in_use_path_accepts_full_ref()
}
