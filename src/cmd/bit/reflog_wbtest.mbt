///|
test "reflog: short max-count option is parsed" {
  let parsed = parse_reflog_show_args(["-1"])
  assert_eq(parsed.max_count, Some(1))
  assert_eq(parsed.refname, "HEAD")
}

///|
test "reflog: short max-count can be combined with refname" {
  let parsed = parse_reflog_show_args(["-20", "refs/heads/main"])
  assert_eq(parsed.max_count, Some(20))
  assert_eq(parsed.refname, "refs/heads/main")
}

///|
test "reflog: non-numeric short options do not set max-count" {
  let parsed = parse_reflog_show_args(["-i", "--grep=merge"])
  assert_eq(parsed.max_count, None)
  assert_true(parsed.grep_ignore_case)
  assert_eq(parsed.grep_patterns, ["merge"])
}

///|
test "reflog: show with pathspec delegates to real git" {
  assert_true(reflog_requires_real_git(["show", "--", "--a-file"]))
}

///|
test "reflog: drop handled natively" {
  assert_false(reflog_requires_real_git(["drop", "refs/heads/main"]))
}

///|
test "reflog: plain expire refs stay in shim" {
  assert_false(
    reflog_requires_real_git(["expire", "root1/branch1", "root2/branch1"]),
  )
}

///|
test "reflog: simple show stays in shim" {
  assert_false(reflog_requires_real_git(["show", "refs/heads/main"]))
}

///|
test "reflog: ref selectors delegate to real git" {
  assert_true(reflog_requires_real_git(["HEAD@{1}"]))
}

///|
test "reflog: exists unknown option stays in shim usage path" {
  assert_false(reflog_requires_real_git(["exists", "--unknown-option"]))
}

///|
test "reflog: short branch name resolves to branch reflog path" {
  let fs = OsFs::new()
  let root = "/tmp/bit-reflog-refname-" + get_current_timestamp().to_string()
  fs.mkdir_p(root + "/.git/logs/refs/heads")
  fs.write_file(root + "/.git/logs/refs/heads/main", string_to_bytes(""))
  let rfs : &@bitcore.RepoFileSystem = fs
  inspect(
    normalize_reflog_refname(rfs, root + "/.git", "main"),
    content="refs/heads/main",
  )
  fs.remove_file(root + "/.git/logs/refs/heads/main") catch {
    _ => ()
  }
  fs.remove_dir(root + "/.git/logs/refs/heads") catch {
    _ => ()
  }
  fs.remove_dir(root + "/.git/logs/refs") catch {
    _ => ()
  }
  fs.remove_dir(root + "/.git/logs") catch {
    _ => ()
  }
  fs.remove_dir(root + "/.git") catch {
    _ => ()
  }
  fs.remove_dir(root) catch {
    _ => ()
  }
}

///|
test "reflog: expire honors per-ref gc patterns for plain refs" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.mkdir_p("/repo/.git/logs/refs/heads/root1")
  fs.mkdir_p("/repo/.git/logs/refs/heads/root2")
  let entry = "0000000000000000000000000000000000000000 " +
    "1111111111111111111111111111111111111111 " +
    "Test User <test@example.com> 1112912293 +0900\tbranch: Created from main\n"
  fs.write_string("/repo/.git/logs/refs/heads/root1/branch1", entry)
  fs.write_string("/repo/.git/logs/refs/heads/root2/branch1", entry)
  fs.write_string(
    "/repo/.git/config",
    "[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n\tbare = false\n\tlogallrefupdates = true\n" +
    "[gc]\n\treflogexpire = never\n" +
    "[gc \"refs/heads/root2/*\"]\n\treflogExpire = now\n",
  )

  let handled = reflog_builtin_expire_refs(fs, fs, "/repo/.git", [
    "root1/branch1", "root2/branch1",
  ])

  assert_true(handled)
  assert_eq(
    @utf8.decode_lossy(
      fs.read_file("/repo/.git/logs/refs/heads/root1/branch1")[:],
    ).to_string(),
    entry,
  )
  assert_eq(
    @utf8.decode_lossy(
      fs.read_file("/repo/.git/logs/refs/heads/root2/branch1")[:],
    ).to_string(),
    "",
  )
}

///|
test "reflog: expire rejects missing plain ref in builtin path" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string(
    "/repo/.git/config",
    "[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n\tbare = false\n\tlogallrefupdates = true\n" +
    "[gc]\n\treflogexpire = now\n",
  )

  let rejected = try {
    ignore(reflog_builtin_expire_refs(fs, fs, "/repo/.git", ["does-not-exist"]))
    false
  } catch {
    @bitcore.GitError::InvalidObject(msg) =>
      msg == "error: reflog could not be found: 'does-not-exist'"
    _ => false
  }

  assert_true(rejected)
}
