///|
fn restore_env_var_for_fetch_wbtest(name : String, prev : String?) -> Unit {
  match prev {
    Some(value) => @sys.set_env_var(name, value)
    None => @sys.unset_env_var(name)
  }
}

///|
test "fetch-delegate: collects global path overrides in deterministic order" {
  let prev_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_explicit_git_dir = @sys.get_env_var("GIT_SHIM_EXPLICIT_GIT_DIR")
  @sys.set_env_var("GIT_SHIM_CWD", "/tmp/bit-delegate-cwd")
  @sys.set_env_var("GIT_SHIM_PWD", "/tmp/bit-delegate-pwd")
  @sys.set_env_var("GIT_DIR", "/tmp/bit-delegate-gitdir")
  @sys.set_env_var("GIT_SHIM_EXPLICIT_GIT_DIR", "1")
  let args = collect_global_path_overrides_for_delegate()
  @test.assert_eq(args.length(), 3)
  @test.assert_eq(args[0], "-C")
  @test.assert_eq(args[1], "/tmp/bit-delegate-cwd")
  @test.assert_eq(args[2], "--git-dir=/tmp/bit-delegate-gitdir")
  restore_env_var_for_fetch_wbtest("GIT_SHIM_CWD", prev_cwd)
  restore_env_var_for_fetch_wbtest("GIT_SHIM_PWD", prev_pwd)
  restore_env_var_for_fetch_wbtest("GIT_DIR", prev_git_dir)
  restore_env_var_for_fetch_wbtest(
    "GIT_SHIM_EXPLICIT_GIT_DIR", prev_explicit_git_dir,
  )
}

///|
test "fetch-delegate: falls back to GIT_SHIM_PWD when CWD is missing" {
  let prev_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_explicit_git_dir = @sys.get_env_var("GIT_SHIM_EXPLICIT_GIT_DIR")
  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.set_env_var("GIT_SHIM_PWD", "/tmp/bit-delegate-pwd")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_SHIM_EXPLICIT_GIT_DIR")
  let args = collect_global_path_overrides_for_delegate()
  @test.assert_eq(args.length(), 2)
  @test.assert_eq(args[0], "-C")
  @test.assert_eq(args[1], "/tmp/bit-delegate-pwd")
  restore_env_var_for_fetch_wbtest("GIT_SHIM_CWD", prev_cwd)
  restore_env_var_for_fetch_wbtest("GIT_SHIM_PWD", prev_pwd)
  restore_env_var_for_fetch_wbtest("GIT_DIR", prev_git_dir)
  restore_env_var_for_fetch_wbtest(
    "GIT_SHIM_EXPLICIT_GIT_DIR", prev_explicit_git_dir,
  )
}

///|
test "fetch-delegate: skips unset global path overrides" {
  let prev_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_explicit_git_dir = @sys.get_env_var("GIT_SHIM_EXPLICIT_GIT_DIR")
  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_SHIM_PWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_SHIM_EXPLICIT_GIT_DIR")
  let args = collect_global_path_overrides_for_delegate()
  @test.assert_eq(args.length(), 0)
  restore_env_var_for_fetch_wbtest("GIT_SHIM_CWD", prev_cwd)
  restore_env_var_for_fetch_wbtest("GIT_SHIM_PWD", prev_pwd)
  restore_env_var_for_fetch_wbtest("GIT_DIR", prev_git_dir)
  restore_env_var_for_fetch_wbtest(
    "GIT_SHIM_EXPLICIT_GIT_DIR", prev_explicit_git_dir,
  )
}

///|
test "fetch-delegate: does not append --git-dir without explicit marker" {
  let prev_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_explicit_git_dir = @sys.get_env_var("GIT_SHIM_EXPLICIT_GIT_DIR")
  @sys.set_env_var("GIT_SHIM_CWD", "/tmp/bit-delegate-cwd")
  @sys.unset_env_var("GIT_SHIM_PWD")
  @sys.set_env_var("GIT_DIR", "/tmp/bit-delegate-gitdir")
  @sys.unset_env_var("GIT_SHIM_EXPLICIT_GIT_DIR")
  let args = collect_global_path_overrides_for_delegate()
  @test.assert_eq(args.length(), 2)
  @test.assert_eq(args[0], "-C")
  @test.assert_eq(args[1], "/tmp/bit-delegate-cwd")
  restore_env_var_for_fetch_wbtest("GIT_SHIM_CWD", prev_cwd)
  restore_env_var_for_fetch_wbtest("GIT_SHIM_PWD", prev_pwd)
  restore_env_var_for_fetch_wbtest("GIT_DIR", prev_git_dir)
  restore_env_var_for_fetch_wbtest(
    "GIT_SHIM_EXPLICIT_GIT_DIR", prev_explicit_git_dir,
  )
}

///|
test "fetch-delegate: parses multiline -c overrides and ignores empty lines" {
  let prev_overrides = @sys.get_env_var("GIT_CONFIG_OVERRIDES")
  @sys.set_env_var(
    "GIT_CONFIG_OVERRIDES", "push.default=upstream\n\ncore.eol=lf\n",
  )
  let args = collect_global_config_overrides_for_delegate()
  @test.assert_eq(args.length(), 4)
  @test.assert_eq(args[0], "-c")
  @test.assert_eq(args[1], "push.default=upstream")
  @test.assert_eq(args[2], "-c")
  @test.assert_eq(args[3], "core.eol=lf")
  restore_env_var_for_fetch_wbtest("GIT_CONFIG_OVERRIDES", prev_overrides)
}

///|
test "fetch relay: remote detection handles explicit relay schemes" {
  assert_true(fetch_remote_uses_relay_signaling("relay+http://127.0.0.1:8788"))
  assert_true(
    fetch_remote_uses_relay_signaling("relay+https://relay.example.com"),
  )
  assert_true(fetch_remote_uses_relay_signaling("relay://relay.example.com"))
  assert_false(
    fetch_remote_uses_relay_signaling("https://relay.example.com/repo.git"),
  )
  assert_false(
    fetch_remote_uses_relay_signaling("git@github.com:mizchi/bit.git"),
  )
}

///|
test "fetch relay: preferred sender env is trimmed and optional" {
  let prev_sender = @sys.get_env_var("BIT_RELAY_FETCH_SENDER")
  @sys.set_env_var("BIT_RELAY_FETCH_SENDER", " node-a ")
  @test.assert_eq(fetch_relay_preferred_sender(), Some("node-a"))
  @sys.set_env_var("BIT_RELAY_FETCH_SENDER", "   ")
  @test.assert_eq(fetch_relay_preferred_sender(), None)
  restore_env_var_for_fetch_wbtest("BIT_RELAY_FETCH_SENDER", prev_sender)
}

///|
test "fetch relay: preferred repo env is trimmed and optional" {
  let prev_repo = @sys.get_env_var("BIT_RELAY_FETCH_REPO")
  @sys.set_env_var("BIT_RELAY_FETCH_REPO", " repo-b ")
  @test.assert_eq(fetch_relay_preferred_repo(), Some("repo-b"))
  @sys.set_env_var("BIT_RELAY_FETCH_REPO", "   ")
  @test.assert_eq(fetch_relay_preferred_repo(), None)
  restore_env_var_for_fetch_wbtest("BIT_RELAY_FETCH_REPO", prev_repo)
}

///|
test "fetch relay: sender filter is preferred over repo filter" {
  let peers : Array[(String, String, String?)] = [
    ("node-a", "http://node-a:9418/repo-a.git", Some("repo-a")),
    ("node-b", "http://node-b:9418/repo-b.git", Some("repo-b")),
  ]
  let selected = fetch_select_relay_peer(
    peers,
    preferred_sender=Some("node-a"),
    preferred_repo=Some("repo-b"),
  )
  @test.assert_eq(selected, Some(("node-a", "http://node-a:9418/repo-a.git")))
}

///|
test "fetch relay: falls back to repo and then first peer" {
  let peers : Array[(String, String, String?)] = [
    ("node-a", "http://node-a:9418/repo-a.git", Some("repo-a")),
    ("node-b", "http://node-b:9418/repo-b.git", Some("repo-b")),
  ]
  let by_repo = fetch_select_relay_peer(
    peers,
    preferred_sender=Some("node-z"),
    preferred_repo=Some("repo-b"),
  )
  @test.assert_eq(by_repo, Some(("node-b", "http://node-b:9418/repo-b.git")))
  let first = fetch_select_relay_peer(
    peers,
    preferred_sender=None,
    preferred_repo=Some("repo-z"),
  )
  @test.assert_eq(first, Some(("node-a", "http://node-a:9418/repo-a.git")))
}

///|
async test "fetch: depth and unshallow update shallow metadata natively" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-fetch-depth-" + get_current_timestamp().to_string()
  let src = root + "/src"
  let dst = root + "/dst"
  cleanup_tree(fs, root)
  fs.mkdir_p(src)
  fs.mkdir_p(dst)
  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_SHIM_PWD")
  commit_wbtest_run_git(src, ["init", "--initial-branch=main", "-q"])
  commit_wbtest_run_git(src, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(src, ["config", "user.email", "test@example.com"])
  fs.write_string(src + "/file.txt", "one\n")
  commit_wbtest_run_git(src, ["add", "file.txt"])
  commit_wbtest_run_git(src, ["commit", "-q", "-m", "one"])
  fs.write_string(src + "/file.txt", "two\n")
  commit_wbtest_run_git(src, ["commit", "-q", "-am", "two"])
  fs.write_string(src + "/file.txt", "three\n")
  commit_wbtest_run_git(src, ["commit", "-q", "-am", "three"])
  let expected_boundary = trim_string(
    add_test_git_stdout(src, ["rev-parse", "HEAD^"]),
  )
  commit_wbtest_run_git(dst, ["init", "--initial-branch=main", "-q"])
  let remote_url = "file://" + src
  let git_dir = dst + "/.git"
  fetch_from_remote(
    fs,
    git_dir,
    dst,
    "origin",
    remote_url,
    [],
    force_transport=true,
    depth=2,
    quiet=true,
  )
  assert_true(fs.is_file(git_dir + "/shallow"))
  @test.assert_eq(
    trim_string(decode_bytes(fs.read_file(git_dir + "/shallow"))),
    expected_boundary,
  )
  fetch_from_remote(
    fs,
    git_dir,
    dst,
    "origin",
    remote_url,
    [],
    force_transport=true,
    unshallow=true,
    quiet=true,
  )
  assert_false(fs.is_file(git_dir + "/shallow"))
  @test.assert_eq(
    trim_string(
      add_test_git_stdout(dst, [
        "rev-list", "--count", "refs/remotes/origin/main",
      ]),
    ),
    "3",
  )
  cleanup_tree(fs, root)
}
