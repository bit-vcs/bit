///|
test "clone caps contain token: direct token word" {
  let caps = ["multi_ack thin-pack filter side-band-64k"]
  assert_true(clone_caps_contain_token(caps, "filter"))
}

///|
test "clone caps contain token: token with value" {
  let caps = ["filter=blob:none"]
  assert_true(clone_caps_contain_token(caps, "filter"))
}

///|
test "clone caps contain token: fetch equals token" {
  let caps = ["fetch=filter", "agent=git/2.45.0"]
  assert_true(clone_caps_contain_token(caps, "filter"))
}

///|
test "clone caps contain token: fetch embedded token list" {
  let caps = ["fetch=shallow deepen-since filter", "agent=git/2.45.0"]
  assert_true(clone_caps_contain_token(caps, "filter"))
}

///|
test "clone caps contain token: missing token" {
  let caps = ["multi_ack thin-pack", "fetch=shallow deepen-since"]
  assert_false(clone_caps_contain_token(caps, "filter"))
}

///|
test "clone local source file resolver: existing relative bundle path" {
  let fs = @bitcore.TestFs::new()
  fs.write_string("/work/repo/repo.bundle", "bundle")
  let resolved = resolve_local_clone_source_file(
    fs, "/work/repo", "repo.bundle",
  )
  assert_eq(resolved, Some("/work/repo/repo.bundle"))
}

///|
test "clone local source file resolver: file URL path" {
  let fs = @bitcore.TestFs::new()
  fs.write_string("/tmp/repo.bundle", "bundle")
  let resolved = resolve_local_clone_source_file(
    fs, "/work/repo", "file:///tmp/repo.bundle",
  )
  assert_eq(resolved, Some("/tmp/repo.bundle"))
}

///|
test "clone local source file resolver: remote URL is ignored" {
  let fs = @bitcore.TestFs::new()
  let resolved = resolve_local_clone_source_file(
    fs, "/work/repo", "https://example.com/repo.bundle",
  )
  assert_eq(resolved, None)
}

///|
test "clone reftable advanced compat depends on ref-format only" {
  assert_true(clone_ref_format_requires_advanced_compat("reftable"))
  assert_false(clone_ref_format_requires_advanced_compat("files"))
}

///|
test "clone relay: remote detection handles explicit relay schemes" {
  assert_true(clone_remote_uses_relay_signaling("relay+http://127.0.0.1:8788"))
  assert_true(
    clone_remote_uses_relay_signaling("relay+https://relay.example.com"),
  )
  assert_true(clone_remote_uses_relay_signaling("relay://relay.example.com"))
  assert_false(clone_remote_uses_relay_signaling("https://relay.example.com"))
  assert_false(
    clone_remote_uses_relay_signaling("git@github.com:mizchi/bit.git"),
  )
}

///|
test "clone relay: select preferred sender when available" {
  let peers : Array[(String, String, String?)] = [
    ("node-a", "http://node-a:9418/repo.git", Some("repo-a")),
    ("node-b", "http://node-b:9418/repo.git", Some("repo-b")),
  ]
  let selected = clone_select_relay_peer(
    peers,
    preferred_sender=Some("node-b"),
    preferred_repo=None,
  )
  assert_eq(selected, Some(("node-b", "http://node-b:9418/repo.git")))
}

///|
test "clone relay: fallback to first sender when preferred missing" {
  let peers : Array[(String, String, String?)] = [
    ("node-a", "http://node-a:9418/repo.git", Some("repo-a")),
    ("node-b", "http://node-b:9418/repo.git", Some("repo-b")),
  ]
  let selected = clone_select_relay_peer(
    peers,
    preferred_sender=Some("node-z"),
    preferred_repo=None,
  )
  assert_eq(selected, Some(("node-a", "http://node-a:9418/repo.git")))
}

///|
test "clone relay: no peers returns none" {
  let peers : Array[(String, String, String?)] = []
  let selected = clone_select_relay_peer(
    peers,
    preferred_sender=None,
    preferred_repo=None,
  )
  assert_eq(selected, None)
}

///|
test "clone relay: preferred sender env is trimmed and optional" {
  @sys.set_env_var("BIT_RELAY_CLONE_SENDER", " node-preferred ")
  assert_eq(clone_relay_preferred_sender(), Some("node-preferred"))
  @sys.set_env_var("BIT_RELAY_CLONE_SENDER", "   ")
  assert_eq(clone_relay_preferred_sender(), None)
  @sys.unset_env_var("BIT_RELAY_CLONE_SENDER")
  assert_eq(clone_relay_preferred_sender(), None)
}

///|
test "clone relay: preferred repo env is trimmed and optional" {
  @sys.set_env_var("BIT_RELAY_CLONE_REPO", " repo-b ")
  assert_eq(clone_relay_preferred_repo(), Some("repo-b"))
  @sys.set_env_var("BIT_RELAY_CLONE_REPO", "   ")
  assert_eq(clone_relay_preferred_repo(), None)
  @sys.unset_env_var("BIT_RELAY_CLONE_REPO")
  assert_eq(clone_relay_preferred_repo(), None)
}

///|
test "clone relay: preferred repo selects matching peer" {
  let peers : Array[(String, String, String?)] = [
    ("node-a", "http://node-a:9418/repo-a.git", Some("repo-a")),
    ("node-b", "http://node-b:9418/repo-b.git", Some("repo-b")),
  ]
  let selected = clone_select_relay_peer(
    peers,
    preferred_sender=None,
    preferred_repo=Some("repo-b"),
  )
  assert_eq(selected, Some(("node-b", "http://node-b:9418/repo-b.git")))
}

///|
test "clone relay: sender filter is applied before repo filter" {
  let peers : Array[(String, String, String?)] = [
    ("node-a", "http://node-a:9418/repo-a.git", Some("repo-a")),
    ("node-b", "http://node-b:9418/repo-b.git", Some("repo-b")),
  ]
  let selected = clone_select_relay_peer(
    peers,
    preferred_sender=Some("node-a"),
    preferred_repo=Some("repo-b"),
  )
  assert_eq(selected, Some(("node-a", "http://node-a:9418/repo-a.git")))
}

///|
fn cleanup_clone_wbtest_tree(fs : OsFs, path : String) -> Unit {
  if fs.is_file(path) {
    fs.remove_file(path) catch {
      _ => ()
    }
    return
  }
  if !(fs.is_dir(path)) {
    return
  }
  let entries = fs.readdir(path) catch { _ => [] }
  for entry in entries {
    if entry == "." || entry == ".." {
      continue
    }
    cleanup_clone_wbtest_tree(fs, path + "/" + entry)
  }
  fs.remove_dir(path) catch {
    _ => ()
  }
}

///|
fn restore_clone_env(name : String, value : String?) -> Unit {
  match value {
    Some(v) => @sys.set_env_var(name, v)
    None => @sys.unset_env_var(name)
  }
}

///|
test "clone: configure_reftable_ref_storage writes reftable metadata" {
  let fs = OsFs::new()
  let root = "/tmp/bit-clone-reftable-" + get_current_timestamp().to_string()
  cleanup_clone_wbtest_tree(fs, root)
  fs.mkdir_p(root)
  fs.write_string(root + "/config", "[core]\n\trepositoryformatversion = 0\n")
  configure_reftable_ref_storage(fs, root) catch {
    err => fail("unexpected error: \{err}")
  }
  assert_true(fs.is_dir(root + "/reftable"))
  assert_true(fs.is_file(root + "/reftable/tables.list"))
  let config = decode_bytes(fs.read_file(root + "/config"))
  assert_true(config.contains("[extensions]"))
  assert_true(config.contains("refStorage = reftable"))
  cleanup_clone_wbtest_tree(fs, root)
}

///|
test "clone: command root prefers shim pwd when cwd is absent" {
  let prev_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.set_env_var("GIT_SHIM_PWD", "/tmp/bit-clone-command-root")
  let resolved = clone_command_root("/tmp/bit-clone-fallback")
  restore_clone_env("GIT_SHIM_CWD", prev_cwd)
  restore_clone_env("GIT_SHIM_PWD", prev_pwd)
  assert_eq(resolved, "/tmp/bit-clone-command-root")
}

///|
test "clone: recurse-submodules option keeps exact filter value" {
  assert_eq(
    clone_parse_recurse_submodules_filter("--recurse-submodules=sub0"),
    "sub0",
  )
  assert_eq(
    clone_parse_recurse_submodules_filter("--recurse-submodules=:(exclude)sub0"),
    ":(exclude)sub0",
  )
}

///|
test "clone: recurse submodule filters are forwarded to update args" {
  assert_eq(
    clone_build_recurse_submodules_args([".", ":(exclude)sub0"], false),
    ["update", "--init", "--recursive", ".", ":(exclude)sub0"],
  )
  assert_eq(clone_build_recurse_submodules_args(["sub0"], true), [
    "update", "--init", "--recursive", "-q", "sub0",
  ])
}

///|
test "clone: recurse submodule filters are written as config multivar" {
  let fs = OsFs::new()
  let root = "/tmp/bit-clone-submodule-active-" +
    get_current_timestamp().to_string()
  cleanup_clone_wbtest_tree(fs, root)
  fs.mkdir_p(root)
  fs.write_string(root + "/config", "[core]\n\trepositoryformatversion = 0\n")
  clone_configure_submodule_active_filters(fs, root, [".", ":(exclude)sub0"])
  let values = get_all_config_values(
    fs,
    root + "/config",
    "submodule.active",
    (None : String?),
    false,
  )
  assert_eq(values, [".", ":(exclude)sub0"])
  cleanup_clone_wbtest_tree(fs, root)
}

///|
test "clone: sparse flag initializes cone sparse-checkout metadata" {
  let fs = OsFs::new()
  let root = "/tmp/bit-clone-sparse-" + get_current_timestamp().to_string()
  let git_dir = root + "/.git"
  cleanup_clone_wbtest_tree(fs, root)
  fs.mkdir_p(git_dir)
  fs.write_string(
    git_dir + "/config",
    "[core]\n\trepositoryformatversion = 0\n",
  )
  clone_maybe_enable_sparse_checkout(fs, root, true, false) catch {
    err => fail("unexpected error: \{err}")
  }
  assert_eq(
    decode_bytes(fs.read_file(git_dir + "/info/sparse-checkout")),
    "/*\n!/*/\n",
  )
  let config = decode_bytes(fs.read_file(git_dir + "/config"))
  let worktree_config = decode_bytes(fs.read_file(git_dir + "/config.worktree"))
  assert_true(config.contains("[extensions]"))
  assert_true(config.contains("worktreeConfig = true"))
  assert_true(worktree_config.contains("sparseCheckout = true"))
  assert_true(worktree_config.contains("sparseCheckoutCone = true"))
  cleanup_clone_wbtest_tree(fs, root)
}

///|
async test "clone: run_postclone_hook is no-op when hook is absent" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-postclone-noop-" +
    get_current_timestamp().to_string()
  cleanup_clone_wbtest_tree(fs, root)
  let git_dir = root + "/.git"
  fs.mkdir_p(git_dir + "/hooks")
  run_postclone_hook(fs, fs, root, git_dir, false) catch {
    err => fail("unexpected error: \{err}")
  }
  cleanup_clone_wbtest_tree(fs, root)
}

///|
async test "clone: run_postclone_hook remains skipped without hook file even with approval cache" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-postclone-skip-with-cache-" +
    get_current_timestamp().to_string()
  let git_dir = root + "/.git"
  cleanup_clone_wbtest_tree(fs, root)
  fs.mkdir_p(git_dir + "/hooks")
  fs.write_string(git_dir + "/hooks/postclone", "#!/bin/sh\necho executed\n")
  let checksum = hooks_active_checksum(fs, root, "postclone").unwrap_or("")
  hooks_write_approved_checksum(fs, fs, root, "postclone", checksum)
  fs.remove_file(git_dir + "/hooks/postclone") catch {
    _ => ()
  }
  run_postclone_hook(fs, fs, root, git_dir, false) catch {
    err => fail("unexpected error: \{err}")
  }
  assert_false(fs.is_file(root + "/postclone-marker"))
  cleanup_clone_wbtest_tree(fs, root)
}

///|
async test "clone: run_postclone_hook skips execution when skip-hooks is enabled" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-postclone-skip-hook-" +
    get_current_timestamp().to_string()
  let git_dir = root + "/.git"
  cleanup_clone_wbtest_tree(fs, root)
  fs.mkdir_p(git_dir + "/hooks")
  fs.write_string(
    git_dir + "/hooks/postclone",
    "#!/bin/sh\necho should_not_run > \"" + root + "/postclone-marker\"\n",
  )
  let checksum = hooks_active_checksum(fs, root, "postclone").unwrap_or("")
  hooks_write_approved_checksum(fs, fs, root, "postclone", checksum)
  run_postclone_hook(fs, fs, root, git_dir, true) catch {
    err => fail("unexpected error: \{err}")
  }
  assert_false(fs.is_file(root + "/postclone-marker"))
  cleanup_clone_wbtest_tree(fs, root)
}

///|
test "clone transport tracking: writes origin head and branch config for checked out branch" {
  let fs = OsFs::new()
  let root = "/tmp/bit-clone-transport-tracking-" +
    get_current_timestamp().to_string()
  let git_dir = root + "/.git"
  let head_id = @bitcore.ObjectId::from_hex(
    "1111111111111111111111111111111111111111",
  )
  cleanup_clone_wbtest_tree(fs, root)
  fs.mkdir_p(git_dir + "/refs/heads")
  fs.write_string(git_dir + "/HEAD", "ref: refs/heads/main\n")
  fs.write_string(git_dir + "/refs/heads/main", head_id.to_hex() + "\n")
  let config_text =
    #|[core]
    #|	repositoryformatversion = 0
    #|[remote "origin"]
    #|	url = /src
    #|	fetch = +refs/heads/*:refs/remotes/origin/*
    #|
  fs.write_string(git_dir + "/config", config_text)
  finalize_transport_clone_tracking(fs, git_dir, "origin", false) catch {
    err => fail("unexpected error: \{err}")
  }
  assert_eq(
    @bitlib.resolve_ref(fs, git_dir, "refs/remotes/origin/main").map(fn(id) {
      id.to_hex()
    }),
    Some(head_id.to_hex()),
  )
  let remote_head = decode_bytes(
    fs.read_file(git_dir + "/refs/remotes/origin/HEAD"),
  )
  assert_eq(remote_head, "ref: refs/remotes/origin/main\n")
  let config = decode_bytes(fs.read_file(git_dir + "/config"))
  assert_true(config.contains("[branch \"main\"]"))
  assert_true(config.contains("remote = origin"))
  assert_true(config.contains("merge = refs/heads/main"))
  cleanup_clone_wbtest_tree(fs, root)
}

///|
test "clone empty transport: initializes empty repo metadata" {
  let fs = OsFs::new()
  let root = "/tmp/bit-clone-empty-transport-" +
    get_current_timestamp().to_string()
  let zero = @bitcore.ObjectId::zero()
  let refs : Array[(@bitcore.ObjectId, String)] = [
    (zero, "HEAD"),
    (zero, "refs/heads/main"),
  ]
  cleanup_clone_wbtest_tree(fs, root)
  let initialized = initialize_empty_transport_clone(
    fs, root, "/remote/src.git", false, "origin", "files", refs,
  ) catch {
    err => fail("unexpected error: \{err}")
  }
  assert_true(initialized)
  let git_dir = root + "/.git"
  assert_eq(
    decode_bytes(fs.read_file(git_dir + "/HEAD")),
    "ref: refs/heads/main\n",
  )
  let config = decode_bytes(fs.read_file(git_dir + "/config"))
  assert_true(config.contains("[remote \"origin\"]"))
  assert_true(config.contains("url = /remote/src.git"))
  assert_true(config.contains("[branch \"main\"]"))
  assert_false(fs.is_file(git_dir + "/refs/heads/main"))
  cleanup_clone_wbtest_tree(fs, root)
}
