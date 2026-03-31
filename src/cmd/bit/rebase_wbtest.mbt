///|
test "rebase: --root requires real git fallback" {
  assert_true(rebase_requires_real_git(["--root"]))
  assert_true(rebase_requires_real_git(["--force-rebase", "--root"]))
  assert_false(rebase_requires_real_git(["--force-rebase", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["--no-force-rebase", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["main"]))
}

///|
test "rebase: signing flags require real git fallback" {
  assert_true(rebase_requires_real_git(["-S", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["--gpg-sign", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["--gpg-sign=key", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["--no-gpg-sign", "HEAD~1"]))
}

///|
test "rebase: interactive and complex modes require real git fallback" {
  assert_true(rebase_requires_real_git(["-i", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["--interactive", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["-ix", "echo hi", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["--exec", "echo hi", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["--autosquash", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["--rebase-merges", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["--edit-todo"]))
  assert_true(rebase_requires_real_git(["--show-current-patch"]))
  assert_true(
    rebase_requires_real_git(["--strategy=recursive", "-Xours", "HEAD~1"]),
  )
}

///|
async test "rebase: commit.gpgsign requires real git fallback" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-rebase-signed-fallback-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "."])
  commit_wbtest_run_git(root, ["config", "commit.gpgsign", "true"])

  assert_true(rebase_requires_real_git(["HEAD~1"], git_dir=root + "/.git"))

  cleanup_tree(fs, root)
}

///|
async test "rebase: continue abort skip use real git for interactive state" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-rebase-interactive-state-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root + "/.git/rebase-merge")

  fs.write_string(root + "/.git/rebase-merge/interactive", "")
  fs.write_string(root + "/.git/rebase-merge/head-name", "refs/heads/main\n")
  fs.write_string(root + "/.git/rebase-merge/msgnum", "1\n")

  assert_true(rebase_requires_real_git(["--continue"], git_dir=root + "/.git"))
  assert_true(rebase_requires_real_git(["--abort"], git_dir=root + "/.git"))
  assert_true(rebase_requires_real_git(["--skip"], git_dir=root + "/.git"))

  cleanup_tree(fs, root)
}
