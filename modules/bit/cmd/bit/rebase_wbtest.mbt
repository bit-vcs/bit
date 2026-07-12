///|
test "rebase: --root requires real git fallback" {
  assert_true(rebase_requires_real_git(["--root"]))
  assert_true(rebase_requires_real_git(["--force-rebase", "--root"]))
  assert_false(rebase_requires_real_git(["--force-rebase", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["--no-force-rebase", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["main"]))
}

///|
test "rebase: signing flags are handled natively" {
  assert_false(rebase_requires_real_git(["-S", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["-Skey-with-x-i", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["--gpg-sign", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["--gpg-sign=key", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["--no-gpg-sign", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["-i", "-S", "HEAD~1"]))
  assert_true(rebase_requires_real_git(["--rebase-merges", "-S", "HEAD~1"]))
}

///|
test "rebase: interactive and complex modes require real git fallback" {
  // -i and --interactive are now handled natively
  assert_false(rebase_requires_real_git(["-i", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["--interactive", "HEAD~1"]))
  // Short option clusters containing -x are still delegated.
  assert_true(rebase_requires_real_git(["-ix", "echo hi", "HEAD~1"]))
  // --exec is now handled natively.
  assert_false(rebase_requires_real_git(["--exec", "echo hi", "HEAD~1"]))
  // --autosquash is now handled natively
  assert_false(rebase_requires_real_git(["--autosquash", "HEAD~1"]))
  // --rebase-merges is now handled natively
  assert_false(rebase_requires_real_git(["--rebase-merges", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["--edit-todo"]))
  assert_false(rebase_requires_real_git(["--show-current-patch"]))
  assert_true(
    rebase_requires_real_git(["--strategy=recursive", "-Xours", "HEAD~1"]),
  )
}

///|
async test "rebase: commit.gpgsign is handled natively" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-rebase-signed-native-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "."])
  commit_wbtest_run_git(root, ["config", "commit.gpgsign", "true"])

  assert_false(rebase_requires_real_git(["HEAD~1"], git_dir=root + "/.git"))
  assert_false(
    rebase_requires_real_git(
      ["--no-gpg-sign", "HEAD~1"],
      git_dir=root + "/.git",
    ),
  )

  cleanup_tree(fs, root)
}

///|
async test "rebase: -S stores gpgsig header on rewritten commit" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-rebase-gpg-sign-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  commit_wbtest_run_git(repo_dir, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  let signer = root + "/fake-gpg.sh"
  signing_wbtest_write_fake_gpg(fs, signer)
  commit_wbtest_run_git(repo_dir, ["config", "gpg.program", signer])
  commit_wbtest_run_git(repo_dir, ["config", "gpg.format", "openpgp"])

  fs.write_string(repo_dir + "/base.txt", "base\n")
  commit_wbtest_run_git(repo_dir, ["add", "base.txt"])
  commit_wbtest_run_git(repo_dir, ["commit", "-q", "-m", "base"])

  commit_wbtest_run_git(repo_dir, ["switch", "-q", "-c", "feature"])
  fs.write_string(repo_dir + "/feature.txt", "feature\n")
  commit_wbtest_run_git(repo_dir, ["add", "feature.txt"])
  commit_wbtest_run_git(repo_dir, ["commit", "-q", "-m", "feature"])

  commit_wbtest_run_git(repo_dir, ["switch", "-q", "main"])
  fs.write_string(repo_dir + "/main.txt", "main\n")
  commit_wbtest_run_git(repo_dir, ["add", "main.txt"])
  commit_wbtest_run_git(repo_dir, ["commit", "-q", "-m", "main"])
  let main_id = trim_string(
    grep_test_git_stdout(repo_dir, ["rev-parse", "main"]),
  )

  commit_wbtest_run_git(repo_dir, ["switch", "-q", "feature"])
  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", repo_dir)

  // handle_rebase writes "Successfully rebased and updated refs. [...]"
  // to stdout via print_line. In `moon test` that bleeds into the
  // runner's JSON summary stream and breaks the parser, so redirect
  // fd 1 to /dev/null for the duration of the call.
  bench_stdout_suppress()
  let rebase_result : Result[Unit, Error] = try? handle_rebase(["-S", "main"])
  bench_stdout_restore()
  match rebase_result {
    Ok(_) => ()
    Err(err) => fail("handle_rebase failed: \{err}")
  }

  let git_dir = repo_dir + "/.git"
  let head = @bitlib.resolve_head_commit(fs, git_dir).unwrap()
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  let commit_obj = db.get(fs, head).unwrap()
  let commit_text = @utf8.decode_lossy(commit_obj.data[:]).to_string()
  let info = @bitcore.parse_commit(commit_obj.data)
  assert_eq(info.parents.length(), 1)
  assert_eq(info.parents[0].to_hex(), main_id)
  assert_true(
    commit_text.contains(
      "gpgsig -----BEGIN PGP SIGNATURE-----\n abc123\n -----END PGP SIGNATURE-----\n",
    ),
  )

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
