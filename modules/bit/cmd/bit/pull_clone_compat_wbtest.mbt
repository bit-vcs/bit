///| git-compat regressions for `pull --ff-only` and `clone --branch`, run
///| against the built bit.exe (pull exits the process on refusal).

///|
async fn pcc_wbtest_bit(
  cwd : String,
  args : Array[String],
) -> (Int, String) raise Error {
  let bit_exe = wbtest_resolve_bit_exe(wbtest_resolve_repo_root())
  let fs = OsFs::new()
  if !fs.is_file(bit_exe) {
    fail("bit.exe not found at \{bit_exe}; build it first")
  }
  // bit resolves its working directory from PWD / GIT_SHIM_CWD before the
  // process cwd, so pin all of them (and pass -C) to `cwd`.
  let full_args = ["-C", cwd]
  for a in args {
    full_args.push(a)
  }
  let result = @process.run(
    bit_exe,
    full_args[:],
    inherit_env=true,
    extra_env={ "PWD": cwd, "GIT_SHIM_CWD": cwd, "GIT_SHIM_PWD": cwd },
    cwd~,
    stdout=Collect,
    stderr=Collect,
  )
  (result.exit_code, @utf8.decode_lossy(result.stderr_binary()))
}

///|
async fn pcc_wbtest_git_out(cwd : String, args : Array[String]) -> String raise Error {
  let result = @process.run(
    "git",
    args[:],
    inherit_env=true,
    cwd~,
    stdout=Collect,
    stderr=Collect,
  )
  trim_string(@utf8.decode_lossy(result.stdout_binary()))
}

///|
/// `<root>/up.git` with `main` (a) and `develop` (a, d), seeded from
/// `<root>/seed` via real git.
async fn pcc_wbtest_upstream(fs : OsFs, root : String) -> Unit raise Error {
  fs.mkdir_p(root)
  add_test_run_git(root, ["init", "-q", "--bare", "--initial-branch=main", "up.git"])
  add_test_run_git(root, ["clone", "-q", "up.git", "seed"])
  let seed = root + "/seed"
  add_test_run_git(seed, ["config", "user.name", "T"])
  add_test_run_git(seed, ["config", "user.email", "t@example.com"])
  fs.write_string(seed + "/a", "a\n")
  add_test_run_git(seed, ["add", "a"])
  add_test_run_git(seed, ["commit", "-q", "-m", "a"])
  add_test_run_git(seed, ["checkout", "-q", "-b", "develop"])
  fs.write_string(seed + "/d", "d\n")
  add_test_run_git(seed, ["add", "d"])
  add_test_run_git(seed, ["commit", "-q", "-m", "d"])
  add_test_run_git(seed, ["push", "-q", "origin", "main", "develop"])
  add_test_run_git(seed, ["checkout", "-q", "main"])
}

///|
async test "pull --ff-only refuses divergent history" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-pull-ff-only-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  pcc_wbtest_upstream(fs, root)
  let (code, _) = pcc_wbtest_bit(root, ["clone", "-q", root + "/up.git", "c"])
  @test.assert_eq(code, 0)
  let clone = root + "/c"
  add_test_run_git(clone, ["config", "user.name", "T"])
  add_test_run_git(clone, ["config", "user.email", "t@example.com"])
  // Upstream moves on; the clone commits locally: history diverges.
  let seed = root + "/seed"
  fs.write_string(seed + "/b", "b\n")
  add_test_run_git(seed, ["add", "b"])
  add_test_run_git(seed, ["commit", "-q", "-m", "b"])
  add_test_run_git(seed, ["push", "-q", "origin", "main"])
  fs.write_string(clone + "/l", "l\n")
  add_test_run_git(clone, ["add", "l"])
  add_test_run_git(clone, ["commit", "-q", "-m", "local"])
  let before = pcc_wbtest_git_out(clone, ["rev-parse", "HEAD"])

  let (ff_code, ff_err) = pcc_wbtest_bit(clone, ["pull", "-q", "--ff-only"])
  @test.assert_eq(ff_code, 128)
  assert_true(ff_err.contains("Not possible to fast-forward"))
  @test.assert_eq(pcc_wbtest_git_out(clone, ["rev-parse", "HEAD"]), before)

  // pull.ff=only in config behaves the same; --no-ff on the command line
  // overrides it and merges.
  add_test_run_git(clone, ["config", "pull.ff", "only"])
  let (cfg_code, _) = pcc_wbtest_bit(clone, ["pull", "-q"])
  @test.assert_eq(cfg_code, 128)
  @test.assert_eq(pcc_wbtest_git_out(clone, ["rev-parse", "HEAD"]), before)
  let (merge_code, _) = pcc_wbtest_bit(clone, ["pull", "-q", "--no-ff"])
  @test.assert_eq(merge_code, 0)
  @test.assert_eq(
    pcc_wbtest_git_out(clone, ["rev-list", "--count", "--merges", "HEAD"]),
    "1",
  )
  cleanup_tree(fs, root)
}

///|
async test "pull --ff-only still fast-forwards" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-pull-ff-only-ok-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  pcc_wbtest_upstream(fs, root)
  let (code, _) = pcc_wbtest_bit(root, ["clone", "-q", root + "/up.git", "c"])
  @test.assert_eq(code, 0)
  let seed = root + "/seed"
  fs.write_string(seed + "/b", "b\n")
  add_test_run_git(seed, ["add", "b"])
  add_test_run_git(seed, ["commit", "-q", "-m", "b"])
  add_test_run_git(seed, ["push", "-q", "origin", "main"])
  let (ff_code, _) = pcc_wbtest_bit(root + "/c", ["pull", "-q", "--ff-only"])
  @test.assert_eq(ff_code, 0)
  @test.assert_eq(
    pcc_wbtest_git_out(root + "/c", ["rev-parse", "HEAD"]),
    pcc_wbtest_git_out(seed, ["rev-parse", "HEAD"]),
  )
  cleanup_tree(fs, root)
}

///|
async test "clone --branch checks out a tracking local branch" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-clone-branch-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  pcc_wbtest_upstream(fs, root)
  for source in [root + "/up.git", "file://" + root + "/up.git"] {
    let dest = if source.has_prefix("file://") { "cf" } else { "cp" }
    let (code, err) = pcc_wbtest_bit(root, ["clone", "-q", "--branch", "develop", source, dest])
    if code != 0 {
      fail("clone \{source} failed: \{err}")
    }
    let repo = root + "/" + dest
    @test.assert_eq(
      trim_string(decode_bytes(fs.read_file(repo + "/.git/HEAD"))),
      "ref: refs/heads/develop",
    )
    @test.assert_eq(
      pcc_wbtest_git_out(repo, ["config", "branch.develop.merge"]),
      "refs/heads/develop",
    )
    @test.assert_eq(
      pcc_wbtest_git_out(repo, ["rev-parse", "--abbrev-ref", "develop@{u}"]),
      "origin/develop",
    )
    assert_true(fs.is_file(repo + "/d"))
  }
  cleanup_tree(fs, root)
}
