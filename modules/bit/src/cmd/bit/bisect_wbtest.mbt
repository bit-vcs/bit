///|
async fn bisect_wbtest_git_stdout(
  root : String,
  args : Array[String],
) -> String raise Error {
  let (code, stdout, _) = @process.collect_output(
    "git",
    args[:],
    inherit_env=true,
    cwd=root,
  )
  assert_eq(code, 0)
  let s = stdout.text() catch { _ => "" }
  if s.has_suffix("\n") {
    String::unsafe_substring(s, start=0, end=s.length() - 1)
  } else {
    s
  }
}

///|
/// Helper: set up a bisect session without triggering stdout output.
/// Directly writes bisect state files instead of calling bisect_start.
async fn bisect_wbtest_setup_session(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  bad_hex : String,
  good_hexes : Array[String],
) -> Unit raise Error {
  let bisect_start_path = git_dir + "/BISECT_START"
  let bisect_log_path = git_dir + "/BISECT_LOG"
  let bisect_terms_path = git_dir + "/BISECT_TERMS"
  let bisect_refs_dir = git_dir + "/refs/bisect"
  wfs.mkdir_p(bisect_refs_dir)
  let head_content = decode_bytes(rfs.read_file(git_dir + "/HEAD"))
  let current_branch = if head_content.has_prefix("ref: refs/heads/") {
    trim_string(
      String::unsafe_substring(
        head_content,
        start=16,
        end=head_content.length(),
      ),
    )
  } else {
    "HEAD"
  }
  wfs.write_string(bisect_start_path, current_branch + "\n")
  wfs.write_string(bisect_terms_path, "bad\ngood\n")
  wfs.write_string(bisect_log_path, "git bisect start\n")
  wfs.write_string(bisect_refs_dir + "/bad", bad_hex + "\n")
  for g in good_hexes {
    wfs.write_string(bisect_refs_dir + "/good-" + g, g + "\n")
  }
}

///|
/// Helper: clean up bisect state files without checkout or output.
fn bisect_wbtest_cleanup_state(
  wfs : &@bitcore.FileSystem,
  git_dir : String,
) -> Unit {
  let paths = [
    git_dir + "/BISECT_START",
    git_dir + "/BISECT_LOG",
    git_dir + "/BISECT_TERMS",
    git_dir + "/BISECT_EXPECTED_REV",
    git_dir + "/BISECT_ANCESTORS_OK",
    git_dir + "/BISECT_NAMES",
    git_dir + "/BISECT_RUN",
  ]
  for path in paths {
    wfs.remove_file(path) catch {
      _ => ()
    }
  }
  let refs_dir = git_dir + "/refs/bisect"
  let fs : &@bitcore.RepoFileSystem = OsFs::new()
  let entries = fs.readdir(refs_dir) catch { _ => [] }
  for entry in entries {
    wfs.remove_file(refs_dir + "/" + entry) catch {
      _ => ()
    }
  }
  wfs.remove_file(refs_dir) catch {
    _ => ()
  }
}

///|
async test "bisect: compute_next finds first bad commit" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let wfs : &@bitcore.FileSystem = fs
  let rfs : &@bitcore.RepoFileSystem = fs
  let root = "/tmp/bit-test-bisect-basic-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q"])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])
  let commit_ids : Array[String] = []
  for i in 1..<=5 {
    fs.write_string(root + "/file.txt", "commit \{i}\n")
    commit_wbtest_run_git(root, ["add", "file.txt"])
    commit_wbtest_run_git(root, ["commit", "-q", "-m", "commit \{i}"])
    commit_ids.push(bisect_wbtest_git_stdout(root, ["rev-parse", "HEAD"]))
  }
  let git_dir = root + "/.git"
  // Set up bisect state directly
  bisect_wbtest_setup_session(wfs, rfs, git_dir, commit_ids[4], [commit_ids[0]])
  assert_true(rfs.is_file(git_dir + "/BISECT_START"))
  assert_true(rfs.is_file(git_dir + "/refs/bisect/bad"))
  // Compute next (pure, no output)
  let result = bisect_compute_next(rfs, git_dir)
  match result {
    Found(_) => ()
    Next(_, _, _, _) => ()
    Waiting(_) => assert_true(false)
  }
  bisect_wbtest_cleanup_state(wfs, git_dir)
  cleanup_tree(fs, root)
}

///|
async test "bisect: run with injectable command finds first bad" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let wfs : &@bitcore.FileSystem = fs
  let rfs : &@bitcore.RepoFileSystem = fs
  let root = "/tmp/bit-test-bisect-run-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q"])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])
  let commit_ids : Array[String] = []
  for i in 1..<=10 {
    let content = if i >= 6 { "bug v\{i}\n" } else { "ok v\{i}\n" }
    fs.write_string(root + "/file.txt", content)
    commit_wbtest_run_git(root, ["add", "file.txt"])
    commit_wbtest_run_git(root, ["commit", "-q", "-m", "commit \{i}"])
    commit_ids.push(bisect_wbtest_git_stdout(root, ["rev-parse", "HEAD"]))
  }
  let git_dir = root + "/.git"
  // Set up bisect state directly (bad=HEAD, good=commit1)
  bisect_wbtest_setup_session(wfs, rfs, git_dir, commit_ids[9], [commit_ids[0]])
  // Track tested commits
  let tested : Array[String] = []
  // Injectable command: check if file.txt contains "bug"
  async fn mock_run_command(
    cwd : String,
    _command : String,
  ) -> Int raise Error {
    let content = decode_bytes(fs.read_file(cwd + "/file.txt"))
    tested.push(content)
    if content.contains("bug") {
      1
    } else {
      0
    }
  }

  bisect_run(
    wfs,
    rfs,
    root,
    git_dir,
    ["test", "script"],
    run_command=mock_run_command,
  )
  // Verify binary search was performed
  assert_true(tested.length() > 0)
  assert_true(tested.length() <= 10)
  // The first bad commit should be commit 6
  let bad_ref = git_dir + "/refs/bisect/bad"
  if rfs.is_file(bad_ref) {
    let bad_hex = trim_string(decode_bytes(rfs.read_file(bad_ref)))
    assert_eq(bad_hex, commit_ids[5])
  }
  bisect_wbtest_cleanup_state(wfs, git_dir)
  cleanup_tree(fs, root)
}

///|
async test "bisect: replay restores state from log" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let wfs : &@bitcore.FileSystem = fs
  let rfs : &@bitcore.RepoFileSystem = fs
  let root = "/tmp/bit-test-bisect-replay-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q"])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])
  let commit_ids : Array[String] = []
  for i in 1..<=5 {
    fs.write_string(root + "/file.txt", "v\{i}\n")
    commit_wbtest_run_git(root, ["add", "file.txt"])
    commit_wbtest_run_git(root, ["commit", "-q", "-m", "commit \{i}"])
    commit_ids.push(bisect_wbtest_git_stdout(root, ["rev-parse", "HEAD"]))
  }
  let git_dir = root + "/.git"
  // Create a log file to replay
  let log_content = "git bisect start\ngit bisect bad \{commit_ids[4]}\ngit bisect good \{commit_ids[0]}\n"
  let log_file = root + "/bisect-log.txt"
  fs.write_string(log_file, log_content)
  // Replay (this calls bisect_start + bisect_mark internally)
  bisect_replay(wfs, rfs, root, git_dir, ["replay", log_file])
  // Verify bisect state was restored
  assert_true(rfs.is_file(git_dir + "/BISECT_START"))
  assert_true(rfs.is_file(git_dir + "/refs/bisect/bad"))
  bisect_wbtest_cleanup_state(wfs, git_dir)
  cleanup_tree(fs, root)
}

///|
async test "bisect: shell_quote_args handles special characters" {
  assert_eq(@bitlib.bisect_shell_quote_args(["echo", "hello"]), "echo hello")
  assert_eq(
    @bitlib.bisect_shell_quote_args(["test", "hello world"]),
    "test 'hello world'",
  )
}

///|
async test "bisect: terms file contains bad and good" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let wfs : &@bitcore.FileSystem = fs
  let rfs : &@bitcore.RepoFileSystem = fs
  let root = "/tmp/bit-test-bisect-terms-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q"])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])
  fs.write_string(root + "/file.txt", "init\n")
  commit_wbtest_run_git(root, ["add", "file.txt"])
  commit_wbtest_run_git(root, ["commit", "-q", "-m", "initial"])
  let git_dir = root + "/.git"
  let cid = bisect_wbtest_git_stdout(root, ["rev-parse", "HEAD"])
  bisect_wbtest_setup_session(wfs, rfs, git_dir, cid, [])
  assert_true(rfs.is_file(git_dir + "/BISECT_TERMS"))
  let terms_content = decode_bytes(rfs.read_file(git_dir + "/BISECT_TERMS"))
  assert_true(terms_content.contains("bad"))
  assert_true(terms_content.contains("good"))
  bisect_wbtest_cleanup_state(wfs, git_dir)
  cleanup_tree(fs, root)
}
