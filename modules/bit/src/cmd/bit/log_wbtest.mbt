///|
test "log: raw rotate uses first path after target when absent" {
  let zero = @bitcore.ObjectId::zero()
  let raw_results : Array[LogRawResult] = [
    {
      sort_key: "sample1.t",
      old_mode: "100644",
      new_mode: "100644",
      old_id: zero,
      new_id: zero,
      status: "M",
      old_path: "sample1.t",
      new_path: "sample1.t",
    },
    {
      sort_key: "sample2.t",
      old_mode: "100644",
      new_mode: "100644",
      old_id: zero,
      new_id: zero,
      status: "M",
      old_path: "sample2.t",
      new_path: "sample2.t",
    },
    {
      sort_key: "sample4.t",
      old_mode: "100644",
      new_mode: "100644",
      old_id: zero,
      new_id: zero,
      status: "M",
      old_path: "sample4.t",
      new_path: "sample4.t",
    },
  ]
  let rotated = log_apply_rotate_skip_raw_results(
    raw_results,
    Some("sample3.t"),
    None,
  )
  @test.assert_eq(rotated.map(item => item.new_path), [
    "sample4.t", "sample1.t", "sample2.t",
  ])
  let skipped = log_apply_rotate_skip_raw_results(
    raw_results,
    None,
    Some("sample3.t"),
  )
  @test.assert_eq(skipped.map(item => item.new_path), ["sample4.t"])
}

///|
test "log: config reader handles inline section key" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  let base_config = fs.read_string("/repo/.git/config")
  fs.write_string("/repo/.git/config", base_config + "\n[log] decorate\n")

  let entries = log_read_config_entries(fs, "/repo/.git", "log", "decorate")
  @test.assert_eq(entries.length(), 1)
  assert_false(entries[0].has_value)
}

///|
test "log: log_find_dotdot parses A..B ranges" {
  // Normal range
  @test.assert_eq(log_find_dotdot("main..develop"), 4)
  // Range with no left side
  @test.assert_eq(log_find_dotdot("..develop"), 0)
  // Range with no right side
  @test.assert_eq(log_find_dotdot("main.."), 4)
  // Triple dot is NOT a range
  @test.assert_eq(log_find_dotdot("main...develop"), -1)
  // No dots
  @test.assert_eq(log_find_dotdot("HEAD"), -1)
  @test.assert_eq(log_find_dotdot("HEAD~3"), -1)
  // Single dot
  @test.assert_eq(log_find_dotdot("a.b"), -1)
}

///|
test "log: log_find_tripledot parses A...B ranges" {
  @test.assert_eq(log_find_tripledot("main...topic"), 4)
  @test.assert_eq(log_find_tripledot("...topic"), 0)
  @test.assert_eq(log_find_tripledot("main..."), 4)
  @test.assert_eq(log_find_tripledot("main..topic"), -1)
  @test.assert_eq(log_find_tripledot("HEAD"), -1)
}

///|
test "log: revision input handles caret and not-mode excludes" {
  let revs : Array[String] = []
  let excludes : Array[String] = []
  let symmetric : Array[(String, String)] = []
  log_push_revision_input("^topic", revs, excludes, symmetric, false)
  log_push_revision_input("main", revs, excludes, symmetric, true)

  @test.assert_eq(revs.length(), 0)
  @test.assert_eq(excludes, ["topic", "main"])
}

///|
test "log: stdin parser reads revisions, excludes, and pathspecs" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  let revs : Array[String] = []
  let excludes : Array[String] = []
  let symmetric : Array[(String, String)] = []
  let pathspecs : Array[String] = []
  let branch_patterns : Array[String] = []

  let (saw_revision_input, all_refs) = log_parse_stdin_input(
    fs, "/repo/.git", "HEAD\n^HEAD~1\n--\nfile-2\n", revs, excludes, symmetric, pathspecs,
    branch_patterns,
  )

  assert_true(saw_revision_input)
  assert_false(all_refs)
  @test.assert_eq(revs, ["HEAD"])
  @test.assert_eq(excludes, ["HEAD~1"])
  @test.assert_eq(symmetric.length(), 0)
  @test.assert_eq(pathspecs, ["file-2"])
  @test.assert_eq(branch_patterns.length(), 0)
}

///|
test "log: ancestry and remaining simplify options fallback boundaries" {
  assert_false(log_need_real_git(["--stdin"]))
  assert_false(log_need_real_git(["--boundary"]))
  assert_false(log_need_real_git(["--ancestry-path", "A..B"]))
  assert_false(log_need_real_git(["--ancestry-path=topic", "B"]))
  assert_false(log_need_real_git(["--graph", "--ancestry-path", "A..B"]))
  assert_false(log_need_real_git(["--simplify-by-decoration"]))
  assert_false(log_need_real_git(["--simplify-merges"]))
  assert_false(log_need_real_git(["--full-history"]))
  assert_false(log_need_real_git(["--show-pulls"]))
  assert_false(log_need_real_git(["--graph", "--show-pulls"]))
  assert_false(log_need_real_git(["--exclude-first-parent-only"]))
  assert_false(log_need_real_git(["--show-signature", "HEAD"]))
  assert_true(log_need_real_git(["--show-signature", "--oneline", "HEAD"]))
  assert_true(log_need_real_git(["--show-signature", "--graph", "HEAD"]))
  assert_true(
    log_need_real_git(["--show-signature", "--format=fuller", "HEAD"]),
  )
  assert_false(log_need_real_git(["--show-signature", "--format=%s", "HEAD"]))
  assert_true(log_need_real_git(["--format=%G?%n%GK", "HEAD"]))
  assert_true(log_need_real_git(["--pretty=format:%GT", "HEAD"]))
  assert_false(log_need_real_git(["--oneline", "HEAD"]))
  // These flags are now handled natively
  assert_false(log_need_real_git(["--", "file"]))
  assert_false(log_need_real_git(["--stat"]))
  assert_false(log_need_real_git(["--graph"]))
  assert_false(log_need_real_git(["--name-only"]))
  assert_false(log_need_real_git(["--name-status"]))
  assert_false(log_need_real_git(["--topo-order"]))
  assert_false(log_need_real_git(["--date-order"]))
  assert_false(log_need_real_git(["--author-date-order"]))
  assert_false(log_need_real_git(["--parents"]))
}

///|
async test "log: simplify-merges drops path merge that is TREESAME to a parent" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-log-simplify-merges-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  grep_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  grep_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  grep_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])

  fs.write_string(repo_dir + "/target", "base\n")
  fs.write_string(repo_dir + "/other", "base\n")
  grep_test_run_git(repo_dir, ["add", "target", "other"])
  grep_test_run_git(repo_dir, ["commit", "-qm", "base"])
  grep_test_run_git(repo_dir, ["branch", "side"])
  fs.write_string(repo_dir + "/other", "main\n")
  grep_test_run_git(repo_dir, ["commit", "-am", "main", "-q"])
  grep_test_run_git(repo_dir, ["checkout", "-q", "side"])
  fs.write_string(repo_dir + "/target", "side\n")
  grep_test_run_git(repo_dir, ["commit", "-am", "side", "-q"])
  grep_test_run_git(repo_dir, ["checkout", "-q", "main"])
  grep_test_run_git(repo_dir, ["merge", "--no-ff", "-m", "merge", "side"])

  @test.assert_eq(
    trim_string(
      grep_test_git_stdout(repo_dir, [
        "log", "--full-history", "--format=%s", "--", "target",
      ]),
    ),
    "merge\nside\nbase",
  )
  @test.assert_eq(
    trim_string(
      grep_test_git_stdout(repo_dir, [
        "log", "--simplify-merges", "--format=%s", "--", "target",
      ]),
    ),
    "side\nbase",
  )

  let git_dir = repo_dir + "/.git"
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let merge_id = @bitrepo.rev_parse(fs, git_dir, "HEAD")
  let side_id = @bitrepo.rev_parse(fs, git_dir, "side")
  let base_id = @bitrepo.rev_parse(fs, git_dir, "HEAD^1^")
  guard merge_id is Some(merge_commit) else { fail("expected merge commit") }
  guard side_id is Some(side_commit) else { fail("expected side commit") }
  guard base_id is Some(base_commit) else { fail("expected base commit") }
  let include_bits : Map[String, Bool] = {}
  let exclude_bits : Map[String, Bool] = {}
  // Default path-limited history simplification also drops the merge: it is
  // TREESAME to its second parent (side) on `target`, so history follows that
  // parent. (--full-history would keep it; that is covered by the git oracle
  // assertions above.)
  assert_false(
    log_commit_matches_history_filters(
      fs,
      git_dir,
      db,
      merge_commit,
      ["target"],
      include_bits,
      exclude_bits,
      false,
      false,
      false,
    ),
  )
  // --simplify-merges drops it as well.
  assert_false(
    log_commit_matches_history_filters(
      fs,
      git_dir,
      db,
      merge_commit,
      ["target"],
      include_bits,
      exclude_bits,
      false,
      false,
      true,
    ),
  )
  assert_true(
    log_commit_matches_history_filters(
      fs,
      git_dir,
      db,
      side_commit,
      ["target"],
      include_bits,
      exclude_bits,
      false,
      false,
      true,
    ),
  )
  assert_true(
    log_commit_matches_history_filters(
      fs,
      git_dir,
      db,
      base_commit,
      ["target"],
      include_bits,
      exclude_bits,
      false,
      false,
      true,
    ),
  )

  cleanup_tree(fs, root)
}

///|
test "log: signature output drops status protocol lines" {
  @test.assert_eq(
    log_signature_output_lines(
      "[GNUPG:] GOODSIG 0000000000000000 Test User <test@example.com>\n", "gpg: Good signature from \"Test User <test@example.com>\"\n",
    ),
    ["gpg: Good signature from \"Test User <test@example.com>\""],
  )
}

///|
fn log_wbtest_write_commit_object(
  fs : @bitcore.TestFs,
  git_dir : String,
  filename : String,
  content : String,
  parents : Array[@bitcore.ObjectId],
  timestamp : Int64,
  message : String,
) -> @bitcore.ObjectId raise Error {
  let (blob_id, blob_bytes) = @bitcore.create_blob_string(content)
  @bitlib.write_object_bytes(fs, git_dir, blob_id, blob_bytes)
  let entry = @bitcore.TreeEntry::new("100644", filename, blob_id)
  let (tree_id, tree_bytes) = @bitcore.create_tree([entry])
  @bitlib.write_object_bytes(fs, git_dir, tree_id, tree_bytes)
  let commit = @bitcore.Commit::new(
    tree_id,
    parents,
    "Test <t@example.com>",
    timestamp,
    "+0000",
    "Test <t@example.com>",
    timestamp,
    "+0000",
    message + "\n",
  )
  let (commit_id, commit_bytes) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(fs, git_dir, commit_id, commit_bytes)
  commit_id
}

///|
test "log: ancestry path keeps commits descended from bottom commits" {
  let fs = @bitcore.TestFs::new()
  let git_dir = "/repo/.git"
  ignore(try? @bitlib.init_repo(fs, "/repo"))

  let root = log_wbtest_write_commit_object(
    fs,
    git_dir,
    "root.txt",
    "root\n",
    [],
    1700000000L,
    "root",
  )
  let bottom = log_wbtest_write_commit_object(
    fs,
    git_dir,
    "bottom.txt",
    "bottom\n",
    [root],
    1700000001L,
    "bottom",
  )
  let side = log_wbtest_write_commit_object(
    fs,
    git_dir,
    "side.txt",
    "side\n",
    [root],
    1700000002L,
    "side",
  )
  let merge = log_wbtest_write_commit_object(
    fs,
    git_dir,
    "merge.txt",
    "merge\n",
    [bottom, side],
    1700000003L,
    "merge",
  )

  let exclude_ids : Map[String, Bool] = {}
  exclude_ids[root.to_hex()] = true
  exclude_ids[bottom.to_hex()] = true
  let entries = log_walk_commits(
    fs,
    git_dir,
    [merge],
    exclude_ids,
    10,
    0L,
    9223372036854775807L,
    false,
  )
  @test.assert_eq(entries.length(), 2)
  assert_true(log_commit_has_ancestor(fs, git_dir, merge, [bottom]))
  assert_false(log_commit_has_ancestor(fs, git_dir, side, [bottom]))

  let ancestry_entries : Array[LogWalkEntry] = []
  for entry in entries {
    if log_commit_has_ancestor(fs, git_dir, entry.id, [bottom]) {
      ancestry_entries.push(entry)
    }
  }
  @test.assert_eq(ancestry_entries.length(), 1)
  @test.assert_eq(ancestry_entries[0].id.to_hex(), merge.to_hex())
}

///|
test "log: boundary walk appends excluded parent with marker flag" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))

  fs.write_string("/repo/file.txt", "a\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file.txt"])
  let first = @bitlib.commit(
    fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000000L,
  )

  fs.write_string("/repo/file.txt", "b\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file.txt"])
  let second = @bitlib.commit(
    fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000001L,
  )

  fs.write_string("/repo/file.txt", "c\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file.txt"])
  let third = @bitlib.commit(
    fs, fs, "/repo", "third\n", "Test <t@example.com>", 1700000002L,
  )

  let exclude_ids : Map[String, Bool] = {}
  exclude_ids[first.to_hex()] = true
  exclude_ids[second.to_hex()] = true
  let entries = log_walk_commits(
    fs,
    "/repo/.git",
    [third],
    exclude_ids,
    1,
    0L,
    9223372036854775807L,
    false,
    show_boundary=true,
  )

  @test.assert_eq(entries.length(), 2)
  @test.assert_eq(entries[0].id.to_hex(), third.to_hex())
  assert_false(entries[0].boundary)
  @test.assert_eq(entries[1].id.to_hex(), second.to_hex())
  assert_true(entries[1].boundary)
  @test.assert_eq(entries[1].message, "second")
}

///|
test "log: parents format extends commit identity" {
  let id = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let p1 = @bitcore.ObjectId::from_hex(
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  )
  let p2 = @bitcore.ObjectId::from_hex(
    "cccccccccccccccccccccccccccccccccccccccc",
  )

  @test.assert_eq(
    log_format_commit_identity(id, [p1, p2], 7, false, true),
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb cccccccccccccccccccccccccccccccccccccccc",
  )
  @test.assert_eq(
    log_format_commit_identity(id, [p1, p2], 7, true, true),
    "aaaaaaa bbbbbbb ccccccc",
  )
  @test.assert_eq(
    log_format_commit_identity(id, [p1], 12, true, true),
    "aaaaaaaaaaaa bbbbbbbbbbbb",
  )
  @test.assert_eq(
    log_format_commit_identity(id, [p1], 7, false, false),
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
}

///|
async test "log: log.showsignature config enables native signature display" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-log-showsignature-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "."])
  commit_wbtest_run_git(root, ["config", "log.showsignature", "true"])

  assert_false(log_need_real_git(["HEAD"], git_dir=root + "/.git"))
  assert_true(log_need_real_git(["--oneline", "HEAD"], git_dir=root + "/.git"))

  cleanup_tree(fs, root)
}

///|
test "log: ref glob normalization expands bare namespaces" {
  @test.assert_eq(log_normalize_ref_glob_pattern("refs/heads"), "refs/heads/*")
  @test.assert_eq(
    log_normalize_ref_glob_pattern("heads/topic/*"),
    "refs/heads/topic/*",
  )
}

///|
test "log: branch pattern matching handles exact and nested names" {
  assert_true(log_branch_pattern_matches("main", "main"))
  assert_true(log_branch_pattern_matches("topic/sub", "topic"))
  assert_true(log_branch_pattern_matches("topic/sub", "topic/*"))
  assert_false(log_branch_pattern_matches("main", "does-not-exist"))
}

///|
async test "log: command path supports excludes and pathspec separator" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-log-exclude-pathspec-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  grep_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  grep_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  grep_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])

  fs.write_string(repo_dir + "/file-1", "base\n")
  fs.write_string(repo_dir + "/file-2", "base\n")
  grep_test_run_git(repo_dir, ["add", "file-1", "file-2"])
  grep_test_run_git(repo_dir, ["commit", "-q", "-m", "base"])

  fs.write_string(repo_dir + "/file-1", "touch-1\n")
  grep_test_run_git(repo_dir, ["commit", "-q", "-am", "touch-1"])

  fs.write_string(repo_dir + "/file-2", "touch-2\n")
  grep_test_run_git(repo_dir, ["commit", "-q", "-am", "touch-2"])

  let stdout = grep_test_git_stdout(repo_dir, [
    "log", "--format=%s", "HEAD", "^HEAD~1", "--", "file-2",
  ])
  @test.assert_eq(trim_string(stdout), "touch-2")

  cleanup_tree(fs, root)
}

///|
async test "log: command path supports --all with --not" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-log-all-not-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  grep_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  grep_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  grep_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])

  fs.write_string(repo_dir + "/base.txt", "base\n")
  grep_test_run_git(repo_dir, ["add", "base.txt"])
  grep_test_run_git(repo_dir, ["commit", "-q", "-m", "base"])
  grep_test_run_git(repo_dir, ["checkout", "-q", "-b", "side"])
  fs.write_string(repo_dir + "/side.txt", "side\n")
  grep_test_run_git(repo_dir, ["add", "side.txt"])
  grep_test_run_git(repo_dir, ["commit", "-q", "-m", "side"])
  grep_test_run_git(repo_dir, ["checkout", "-q", "main"])

  let stdout = grep_test_git_stdout(repo_dir, [
    "log", "--format=%s", "--all", "--not", "main",
  ])
  @test.assert_eq(trim_string(stdout), "side")

  cleanup_tree(fs, root)
}

///|
test "log: reflog target selection prefers branch patterns over HEAD" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git/refs/heads/root1")
  fs.mkdir_p("/repo/.git/refs/heads/root2")
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/root1/branch1", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/root1/branch2", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/root2/branch1", "cccccccccccccccccccccccccccccccccccccccc\n",
  )

  let targets = log_collect_reflog_targets(fs, "/repo/.git", [], ["root*"])
  @test.assert_eq(targets, ["root1/branch1", "root1/branch2", "root2/branch1"])
  @test.assert_eq(log_collect_reflog_targets(fs, "/repo/.git", [], []), ["HEAD"])
}

///|
test "log: reflog selector helpers split and format explicit selectors" {
  @test.assert_eq(log_split_reflog_target("HEAD@{0}"), ("HEAD", Some("0")))
  @test.assert_eq(log_split_reflog_target("HEAD@{now}"), ("HEAD", Some("now")))
  @test.assert_eq(
    log_format_reflog_selector("HEAD", 0, 1112911993L, "-0700", None, "raw"),
    "HEAD@{1112911993 -0700}",
  )
  @test.assert_eq(
    log_format_reflog_selector(
      "HEAD",
      0,
      1112911993L,
      "-0700",
      Some("0"),
      "raw",
    ),
    "HEAD@{0}",
  )
}

///|
test "log: format_reflog_entry keeps %gD selector without message" {
  @test.assert_eq(
    format_reflog_entry(
      Some("%gD"),
      "root1/branch1@{0}",
      "branch: Created from main",
    ),
    "root1/branch1@{0}",
  )
  @test.assert_eq(
    format_reflog_entry(
      Some("%gD %gs"),
      "root1/branch1@{0}",
      "branch: Created from main",
    ),
    "root1/branch1@{0} branch: Created from main",
  )
}

///|
fn log_test_format_data(
  subject : String,
  body? : String = "",
  message? : String = subject,
  encoding? : String = "",
  pretty_color_enabled? : Bool = false,
) -> CommitFormatData {
  let id = @bitcore.ObjectId::new(FixedArray::make(20, b'\xaa'))
  let tree = @bitcore.ObjectId::new(FixedArray::make(20, b'\xbb'))
  {
    id,
    tree,
    parents: [],
    abbrev_len: 7,
    encoding,
    author_name: "Test User",
    author_email: "test@example.com",
    author_timestamp: 1700000000L,
    author_tz: "+0000",
    committer_name: "Test User",
    committer_email: "test@example.com",
    committer_timestamp: 1700000000L,
    committer_tz: "+0000",
    subject,
    body,
    message,
    ref_names: {},
    date_format: "",
    left_right_marker: "",
    reflog_selector_short: Some("HEAD@{0}"),
    reflog_selector: Some("HEAD@{0}"),
    reflog_message: Some("commit: " + subject),
    reflog_author_name: Some("C O Mitter"),
    reflog_author_email: Some("committer@example.com"),
    pretty_color_enabled,
    pretty_auto_color: "\u001b[33m",
  }
}

///|
test "log: format_commit_string honors reflog placeholders" {
  let data = log_test_format_data("sixth")

  @test.assert_eq(
    format_commit_string("%gD %gs %H", data),
    "HEAD@{0} commit: sixth aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  @test.assert_eq(
    format_commit_string("%gn:%ge", data),
    "C O Mitter:committer@example.com",
  )
}

///|
test "log: format_commit_string honors left-right marker" {
  let id = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let tree = @bitcore.ObjectId::from_hex(
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  )
  let data : CommitFormatData = {
    id,
    tree,
    parents: [],
    abbrev_len: 7,
    encoding: "",
    author_name: "Test User",
    author_email: "test@example.com",
    author_timestamp: 1700000000L,
    author_tz: "+0000",
    committer_name: "Test User",
    committer_email: "test@example.com",
    committer_timestamp: 1700000000L,
    committer_tz: "+0000",
    subject: "sixth",
    body: "",
    message: "sixth",
    ref_names: {},
    date_format: "",
    left_right_marker: ">",
    reflog_selector_short: None,
    reflog_selector: None,
    reflog_message: None,
    reflog_author_name: None,
    reflog_author_email: None,
    pretty_color_enabled: false,
    pretty_auto_color: "\u001b[33m",
  }

  @test.assert_eq(format_commit_string("%m %s", data), "> sixth")
}

///|
test "log: format_commit_string honors line and space modifiers" {
  let without_body = log_test_format_data("subject")
  let with_body = log_test_format_data(
    "subject",
    body="body line",
    message="subject\n\nbody line",
  )

  @test.assert_eq(format_commit_string("x%n%-b", without_body), "x")
  @test.assert_eq(format_commit_string("x%+b", without_body), "x")
  @test.assert_eq(format_commit_string("x% b", without_body), "x")
  @test.assert_eq(format_commit_string("x%n%-b", with_body), "x\nbody line")
  @test.assert_eq(format_commit_string("x%+b", with_body), "x\nbody line")
  @test.assert_eq(format_commit_string("x% b", with_body), "x body line")
  @test.assert_eq(format_commit_string("x% s", without_body), "x subject")
  @test.assert_eq(
    format_commit_string(
      "%e",
      log_test_format_data("subject", encoding="ISO-8859-1"),
    ),
    "ISO-8859-1",
  )
}

///|
test "log: format_commit_string honors truncation and width padding" {
  let long_subject = log_test_format_data("abcdefghijklmnopqrstuvwxyz")
  let short_subject = log_test_format_data("short")

  @test.assert_eq(
    format_commit_string("%<(20,trunc)%s", long_subject),
    "abcdefghijklmnopqr..",
  )
  @test.assert_eq(
    format_commit_string("%<(20,mtrunc)%s", long_subject),
    "abcdefghi..rstuvwxyz",
  )
  @test.assert_eq(
    format_commit_string("%<(20,ltrunc)%s", long_subject),
    "..ijklmnopqrstuvwxyz",
  )
  @test.assert_eq(
    format_commit_string("%<(20,trunc)%s", short_subject),
    "short               ",
  )
}

///|
test "log: format_commit_string honors pretty color directives" {
  let data = log_test_format_data("subject", pretty_color_enabled=true)

  @test.assert_eq(
    format_commit_string("%C(always,red)foo%C(always,reset)", data),
    "\u001b[31mfoo\u001b[m",
  )
  @test.assert_eq(
    format_commit_string("%Credfoo%Creset", data),
    "\u001b[31mfoo\u001b[m",
  )
  @test.assert_eq(
    format_commit_string("%C(auto)%H", data),
    "\u001b[33maaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\u001b[m",
  )
  @test.assert_eq(
    format_commit_string("%Credfoo%Creset", log_test_format_data("subject")),
    "foo",
  )
}

///|
test "log: pretty color mode honors cli and config precedence" {
  assert_false(
    log_resolve_pretty_color_enabled_from_values(None, None, None, false),
  )
  assert_true(
    log_resolve_pretty_color_enabled_from_values(
      Some("always"),
      None,
      None,
      false,
    ),
  )
  assert_true(
    log_resolve_pretty_color_enabled_from_values(
      None,
      Some("always"),
      None,
      false,
    ),
  )
  assert_false(
    log_resolve_pretty_color_enabled_from_values(
      Some("always"),
      None,
      Some("never"),
      false,
    ),
  )
  assert_true(
    log_resolve_pretty_color_enabled_from_values(None, None, Some("auto"), true),
  )
  assert_false(
    log_resolve_pretty_color_enabled_from_values(
      None,
      None,
      Some("auto"),
      false,
    ),
  )
}

///|
test "log: identity patterns use union semantics" {
  assert_true(
    log_identity_patterns_match(
      "Thor <thor@example.com>",
      ["Thor", "Aster"],
      GrepPatternType::Basic,
      false,
    ),
  )
  assert_true(
    log_identity_patterns_match(
      "Thor <thor@example.com>",
      ["Aster", "thor@example\\.com>$"],
      GrepPatternType::Basic,
      false,
    ),
  )
  assert_false(
    log_identity_patterns_match(
      "Thor <thor@example.com>",
      ["Aster", "-0700"],
      GrepPatternType::Basic,
      false,
    ),
  )
}

///|
test "log: grep reflog requires walk_reflogs" {
  let raised = try {
    log_validate_reflog_grep_options(false, ["commit: third"])
    false
  } catch {
    _ => true
  }
  assert_true(raised)
  let ok = try {
    log_validate_reflog_grep_options(true, ["commit: third"])
    true
  } catch {
    _ => false
  }
  assert_true(ok)
}

///|
test "log: format_decoration" {
  let ref_names : Map[String, Array[String]] = {}
  // No decoration
  @test.assert_eq(format_decoration(ref_names, "abc1234"), "")
  // Single decoration
  ref_names["abc1234"] = ["HEAD -> main"]
  @test.assert_eq(format_decoration(ref_names, "abc1234"), " (HEAD -> main)")
  // Multiple decorations
  ref_names["def5678"] = ["HEAD -> main", "origin/main"]
  @test.assert_eq(
    format_decoration(ref_names, "def5678"),
    " (HEAD -> main, origin/main)",
  )
}

///|
test "log: decoration pattern matching handles HEAD and trailing slash" {
  assert_true(log_decoration_pattern_matches("HEAD", "HEAD"))
  assert_false(log_decoration_pattern_matches("refs/heads/main", "HEAD"))
  assert_true(log_decoration_pattern_matches("refs/tags/reach", "tags/"))
  assert_true(
    log_decoration_pattern_matches("refs/heads/topic/sub", "heads/topic"),
  )
  assert_false(
    log_decoration_pattern_matches("refs/heads/topic-2", "heads/topic"),
  )
}

///|
test "log: decoration ref visibility respects defaults and clear mode" {
  assert_false(
    log_should_include_decoration_ref("refs/hidden/tangle", [], [], false),
  )
  assert_true(
    log_should_include_decoration_ref("refs/hidden/tangle", [], [], true),
  )
  assert_false(
    log_should_include_decoration_ref(
      "refs/heads/octopus-a",
      ["heads/*"],
      ["heads/octopus*"],
      true,
    ),
  )
}

///|
test "log: log_extract_committer_timestamp" {
  // Simulate a commit object data
  let commit_data = "tree 0000000000000000000000000000000000000000\nauthor Test User <test@example.com> 1699999999 +0000\ncommitter Test User <test@example.com> 1700000000 +0000\n\nTest commit message\n"
  let data = @utf8.encode(commit_data[:])
  let ts = log_extract_committer_timestamp(data)
  @test.assert_eq(ts, 1700000000L)
}

///|
test "log: log_parse_entry_from_obj" {
  let commit_data = "tree 0000000000000000000000000000000000000000\nauthor Test User <test@example.com> 1700000000 +0000\ncommitter Test User <test@example.com> 1700000000 +0000\n\nTest commit message\n"
  let data = @utf8.encode(commit_data[:])
  let id = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let tree = @bitcore.ObjectId::from_hex(
    "0000000000000000000000000000000000000000",
  )
  let entry = log_parse_entry_from_obj(id, data, tree, [])
  @test.assert_eq(entry.message, "Test commit message")
  @test.assert_eq(entry.author, "Test User <test@example.com>")
  @test.assert_eq(entry.timestamp, 1700000000L)
  @test.assert_eq(entry.parent_count, 0)
}

///|
test "log: is_short_count_flag" {
  assert_true(is_short_count_flag("-5"))
  assert_true(is_short_count_flag("-10"))
  assert_false(is_short_count_flag("-n"))
  assert_false(is_short_count_flag("--oneline"))
  assert_false(is_short_count_flag("5"))
}

///|
test "log: log_queue_insert maintains descending order" {
  let queue : Array[(Int64, @bitcore.ObjectId)] = []
  let id1 = @bitcore.ObjectId::from_hex(
    "1111111111111111111111111111111111111111",
  )
  let id2 = @bitcore.ObjectId::from_hex(
    "2222222222222222222222222222222222222222",
  )
  let id3 = @bitcore.ObjectId::from_hex(
    "3333333333333333333333333333333333333333",
  )
  log_queue_insert(queue, (100L, id1))
  log_queue_insert(queue, (300L, id3))
  log_queue_insert(queue, (200L, id2))
  @test.assert_eq(queue[0].0, 300L)
  @test.assert_eq(queue[1].0, 200L)
  @test.assert_eq(queue[2].0, 100L)
}

///|
fn log_test_commit(
  fs : @bitcore.TestFs,
  root : String,
  path : String,
  content : String,
  message : String,
  ts : Int64,
) -> @bitcore.ObjectId raise Error {
  fs.write_string(root + "/" + path, content)
  @bitlib.add_paths(fs, fs, root, [path])
  @bitlib.commit(
    fs,
    fs,
    root,
    message + "\n",
    "Test User <test@example.com>",
    ts,
  )
}

///|
test "log: build ref names peels nested annotated tags" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  ignore(try? log_test_commit(fs, "/repo", "file.txt", "one\n", "one", 1L))
  let head = log_test_commit(fs, "/repo", "file.txt", "two\n", "two", 2L) catch {
    err => fail("unexpected commit error: \{err}")
  }

  ignore(
    try? @bitlib.create_lightweight_tag(
      fs, fs, "/repo/.git", "lightweight", head,
    ),
  )
  ignore(
    try? @bitlib.create_annotated_tag(
      fs, fs, "/repo/.git", "annotated", head, "annotated", "Test User <test@example.com>",
      3L,
    ),
  )
  ignore(try? @bitlib.create_branch_at(fs, fs, "/repo", "reach", head))
  ignore(
    try? @bitlib.create_annotated_tag(
      fs, fs, "/repo/.git", "double-0", head, "double-0", "Test User <test@example.com>",
      4L,
    ),
  )
  let double_0 = @bitrepo.rev_parse(fs, "/repo/.git", "refs/tags/double-0").unwrap_or(
    @bitcore.ObjectId::from_hex("0000000000000000000000000000000000000000"),
  )
  ignore(
    try? @bitlib.create_annotated_tag(
      fs, fs, "/repo/.git", "double-1", double_0, "double-1", "Test User <test@example.com>",
      5L,
    ),
  )

  let ref_names = log_build_ref_names(fs, "/repo/.git", {
    mode: LogDecorationDisplayMode::Short,
    include_patterns: [],
    exclude_patterns: [],
    include_all_refs: false,
  }) catch {
    _ => {}
  }
  match ref_names.get(head.to_hex()) {
    Some(names) =>
      @test.assert_eq(names, [
        "HEAD -> main", "tag: lightweight", "tag: double-1", "tag: double-0", "tag: annotated",
        "reach",
      ])
    None => fail("expected decorations for HEAD commit")
  }

  let full_ref_names = log_build_ref_names(fs, "/repo/.git", {
    mode: LogDecorationDisplayMode::Full,
    include_patterns: [],
    exclude_patterns: [],
    include_all_refs: false,
  }) catch {
    _ => {}
  }
  match full_ref_names.get(head.to_hex()) {
    Some(names) =>
      @test.assert_eq(names, [
        "HEAD -> refs/heads/main", "tag: refs/tags/lightweight", "tag: refs/tags/double-1",
        "tag: refs/tags/double-0", "tag: refs/tags/annotated", "refs/heads/reach",
      ])
    None => fail("expected full decorations for HEAD commit")
  }
}

///|
test "log: resolve targets preserves tag revision names" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  let head = log_test_commit(fs, "/repo", "file.txt", "one\n", "one", 1L) catch {
    err => fail("unexpected commit error: \{err}")
  }
  ignore(try? @bitlib.create_branch_at(fs, fs, "/repo", "source-a", head))
  ignore(
    try? @bitlib.create_annotated_tag(
      fs, fs, "/repo/.git", "source-tag", head, "source-tag", "Test User <test@example.com>",
      2L,
    ),
  )

  let targets = log_resolve_targets(
    fs,
    "/repo/.git",
    ["source-tag", "source-a"],
    [],
    false,
    default_head=false,
  ) catch {
    err => fail("unexpected resolve error: \{err}")
  }
  @test.assert_eq(targets.length(), 2)
  @test.assert_eq(targets[0].0, "source-tag")
  @test.assert_eq(targets[1].0, "source-a")
}

///|
test "log: grafts affect fast-path history in main and linked worktrees" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  let abc = log_test_commit(fs, "/repo", "file.txt", "abc\n", "abc", 1L) catch {
    err => fail("unexpected commit error: \{err}")
  }
  ignore(
    log_test_commit(fs, "/repo", "file.txt", "def\n", "def", 2L) catch {
      err => fail("unexpected commit error: \{err}")
    },
  )
  let xyz = log_test_commit(fs, "/repo", "file.txt", "xyz\n", "xyz", 3L) catch {
    err => fail("unexpected commit error: \{err}")
  }
  fs.write_string(
    "/repo/.git/info/grafts",
    xyz.to_hex() + " " + abc.to_hex() + "\n",
  )

  let main_lines = @bitlib.log_head_oneline(fs, "/repo/.git", max_count=2) catch {
    err => fail("unexpected log error: \{err}")
  }
  @test.assert_eq(main_lines.length(), 2)
  assert_true(main_lines[0].has_suffix(" xyz"))
  assert_true(main_lines[1].has_suffix(" abc"))

  ignore(
    try? @bitlib.create_worktree(
      fs,
      fs,
      "/repo",
      "/grafted",
      Some("main"),
      detach=true,
      new_branch=None,
    ),
  )
  let linked_lines = @bitlib.log_head_oneline(
    fs,
    "/repo/.git/worktrees/grafted",
    max_count=2,
  ) catch {
    err => fail("unexpected linked log error: \{err}")
  }
  @test.assert_eq(linked_lines.length(), 2)
  assert_true(linked_lines[0].has_suffix(" xyz"))
  assert_true(linked_lines[1].has_suffix(" abc"))
}

///|
test "log: apply wrap spec indents and wraps subject text" {
  let wrapped = log_apply_wrap("This is the sixth commit.", {
    width: 11,
    indent1: 1,
    indent2: 2,
  })
  @test.assert_eq(wrapped, " This is\n  the sixth\n  commit.")
}

///|
test "log: format_commit_string honors %w prefix" {
  let id = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let tree = @bitcore.ObjectId::from_hex(
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  )
  let data : CommitFormatData = {
    id,
    tree,
    parents: [],
    abbrev_len: 7,
    encoding: "",
    author_name: "Test User",
    author_email: "test@example.com",
    author_timestamp: 1700000000L,
    author_tz: "+0000",
    committer_name: "Test User",
    committer_email: "test@example.com",
    committer_timestamp: 1700000000L,
    committer_tz: "+0000",
    subject: "sixth",
    body: "",
    message: "sixth",
    ref_names: {},
    date_format: "",
    left_right_marker: "",
    reflog_selector_short: None,
    reflog_selector: None,
    reflog_message: None,
    reflog_author_name: None,
    reflog_author_email: None,
    pretty_color_enabled: false,
    pretty_auto_color: "\u001b[33m",
  }
  let wrapped = format_commit_string("%w(11,1,2)This is the %s commit.", data)
  @test.assert_eq(wrapped, " This is\n  the sixth\n  commit.")

  let explicit_breaks = format_commit_string(
    "%w(,1,2)This is%nthe %s%ncommit.", data,
  )
  @test.assert_eq(explicit_breaks, " This is\n  the sixth\n  commit.")

  let sanitized_data : CommitFormatData = {
    id,
    tree,
    parents: [],
    abbrev_len: 7,
    encoding: "",
    author_name: "Test User",
    author_email: "test@example.com",
    author_timestamp: 1700000000L,
    author_tz: "+0000",
    committer_name: "Test User",
    committer_email: "test@example.com",
    committer_timestamp: 1700000000L,
    committer_tz: "+0000",
    subject: "Merge tag 'reach'",
    body: "",
    message: "Merge tag 'reach'",
    ref_names: {},
    date_format: "",
    left_right_marker: "",
    reflog_selector_short: None,
    reflog_selector: None,
    reflog_message: None,
    reflog_author_name: None,
    reflog_author_email: None,
    pretty_color_enabled: false,
    pretty_auto_color: "\u001b[33m",
  }
  let sanitized = format_commit_string("%f", sanitized_data)
  @test.assert_eq(sanitized, "Merge-tag-reach")
}

///|
test "log: abbrev helpers respect bool and numeric config" {
  @test.assert_eq(log_parse_abbrev_length_value("false"), Some(40))
  @test.assert_eq(log_parse_abbrev_length_value("9000"), Some(40))
  @test.assert_eq(log_parse_abbrev_length_value("3"), Some(4))
  @test.assert_eq(log_parse_abbrev_length_value("12"), Some(12))
  @test.assert_eq(log_abbrev_hex("0123456789abcdef", 7), "0123456")
  @test.assert_eq(log_abbrev_hex("012345", 40), "012345")
}

///|
test "log: diff-filter parser splits include and exclude bits" {
  let include_bits : Map[String, Bool] = {}
  let exclude : Map[String, Bool] = {}
  log_add_diff_filter_chars("Ra", include_bits, exclude)
  log_add_diff_filter_chars("d", include_bits, exclude)
  assert_true(include_bits.contains("R"))
  assert_true(exclude.contains("A"))
  assert_true(exclude.contains("D"))
  assert_false(include_bits.contains("D"))
}

///|
test "log: diff-filter matching respects positive and negative bits" {
  let statuses : Map[String, Bool] = { "R": true }
  let include_bits : Map[String, Bool] = { "R": true }
  let exclude : Map[String, Bool] = { "A": true }
  assert_true(log_has_diff_filter(include_bits, exclude))
  assert_true(
    log_commit_matches_diff_filter_with_statuses(
      statuses, include_bits, exclude,
    ),
  )

  statuses["A"] = true
  assert_false(
    log_commit_matches_diff_filter_with_statuses(
      statuses, include_bits, exclude,
    ),
  )

  let negative_only_statuses : Map[String, Bool] = { "A": true, "D": true }
  let negative_only_include : Map[String, Bool] = {}
  let negative_only_exclude : Map[String, Bool] = { "D": true }
  assert_true(
    log_commit_matches_diff_filter_with_statuses(
      negative_only_statuses, negative_only_include, negative_only_exclude,
    ),
  )

  let deleted_only_statuses : Map[String, Bool] = { "D": true }
  assert_false(
    log_commit_matches_diff_filter_with_statuses(
      deleted_only_statuses, negative_only_include, negative_only_exclude,
    ),
  )
}

///|
test "log: grep helper supports any-match and all-match" {
  let patterns = ["second", "initial"]
  assert_true(
    log_grep_patterns_match(
      "second commit message",
      patterns,
      GrepPatternType::Fixed,
      false,
      false,
    ),
  )
  assert_false(
    log_grep_patterns_match(
      "second commit message",
      patterns,
      GrepPatternType::Fixed,
      false,
      true,
    ),
  )
  assert_true(
    log_grep_patterns_match(
      "second initial",
      patterns,
      GrepPatternType::Fixed,
      false,
      true,
    ),
  )
}
