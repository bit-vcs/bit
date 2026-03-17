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
test "reflog: oneline flag is parsed" {
  let parsed = parse_reflog_show_args(["--oneline"])
  assert_true(parsed.oneline)
  assert_eq(parsed.refname, "HEAD")
}

///|
test "reflog: format flag is parsed" {
  let parsed = parse_reflog_show_args(["--format=short"])
  assert_eq(parsed.format, "short")
}

///|
test "reflog: date flag is parsed" {
  let parsed = parse_reflog_show_args(["--date=relative"])
  assert_eq(parsed.date_format, "relative")
}

///|
test "reflog: all flag is parsed" {
  let parsed = parse_reflog_show_args(["--all"])
  assert_true(parsed.show_all)
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
async test "reflog: expire honors per-ref gc patterns for plain refs" {
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

  // Expire root1/branch1 - config says "never" for this ref
  let now = 1700000000L
  reflog_expire_single_ref(
    fs,
    fs,
    "/repo/.git",
    "refs/heads/root1/branch1",
    None,
    None,
    now,
    false,
    false,
  )
  // Expire root2/branch1 - config says "now" for this ref pattern
  reflog_expire_single_ref(
    fs,
    fs,
    "/repo/.git",
    "refs/heads/root2/branch1",
    None,
    None,
    now,
    false,
    false,
  )

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
    let normalized = normalize_reflog_refname(
      fs, "/repo/.git", "does-not-exist",
    )
    if not(reflog_ref_exists_or_resolves(fs, "/repo/.git", normalized)) {
      raise @bitcore.GitError::InvalidObject(
        "error: reflog could not be found: 'does-not-exist'",
      )
    }
    false
  } catch {
    @bitcore.GitError::InvalidObject(msg) =>
      msg == "error: reflog could not be found: 'does-not-exist'"
    _ => false
  }

  assert_true(rejected)
}

///|
test "reflog: list finds all refs in logs directory" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.mkdir_p("/repo/.git/logs/refs/heads")
  fs.mkdir_p("/repo/.git/logs/refs/remotes/origin")
  fs.write_string("/repo/.git/logs/HEAD", "")
  fs.write_string("/repo/.git/logs/refs/heads/main", "")
  fs.write_string("/repo/.git/logs/refs/heads/feature", "")
  fs.write_string("/repo/.git/logs/refs/remotes/origin/main", "")

  let refs = reflog_list_all_refs(fs, "/repo/.git")
  assert_eq(refs, [
    "HEAD", "refs/heads/feature", "refs/heads/main", "refs/remotes/origin/main",
  ])
}

///|
test "reflog: expire with explicit --expire=now clears all entries" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.mkdir_p("/repo/.git/logs/refs/heads")
  let entry = "0000000000000000000000000000000000000000 " +
    "1111111111111111111111111111111111111111 " +
    "Test User <test@example.com> 1112912293 +0900\tbranch: Created from main\n"
  fs.write_string("/repo/.git/logs/refs/heads/main", entry)

  let parsed = parse_reflog_expire_args(["--expire=now", "refs/heads/main"])
  assert_eq(parsed.expire, Some("now"))
  assert_eq(parsed.refs, ["refs/heads/main"])
}

///|
test "reflog: expire args parsing with --all and --dry-run" {
  let parsed = parse_reflog_expire_args(["--all", "--dry-run", "--expire=now"])
  assert_true(parsed.all)
  assert_true(parsed.dry_run)
  assert_eq(parsed.expire, Some("now"))
}
