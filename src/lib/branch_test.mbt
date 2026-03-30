///| Tests for git branch listing

///|
fn setup_branch_fs() -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.mkdir_p("/repo/.git/refs/heads")
  fs.mkdir_p("/repo/.git/objects")
  fs
}

///|
test "branch: list with current" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "1111111111111111111111111111111111111111\n",
  )
  fs.mkdir_p("/repo/.git/refs/heads/feature")
  fs.write_string(
    "/repo/.git/refs/heads/feature/x", "2222222222222222222222222222222222222222\n",
  )
  fs.write_string(
    "/repo/.git/packed-refs", "# pack-refs with: peeled\n3333333333333333333333333333333333333333 refs/heads/dev\n",
  )
  let lines = list_branches_text(fs, "/repo/.git")
  assert_true(lines.contains("* main"))
  assert_true(lines.contains("  dev"))
  assert_true(lines.contains("  feature/x"))
}

///|
test "branch: detached head" {
  let fs = setup_branch_fs()
  fs.write_string(
    "/repo/.git/HEAD", "4444444444444444444444444444444444444444\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/main", "1111111111111111111111111111111111111111\n",
  )
  let lines = list_branches_text(fs, "/repo/.git")
  assert_true(lines[0].has_prefix("* (HEAD detached at 4444444"))
  assert_true(lines.contains("  main"))
}

///|
test "branch: create branch" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  create_branch(fs, fs, "/repo", "feature")
  let content = fs.read_string("/repo/.git/refs/heads/feature")
  assert_true(content.has_prefix("aaaaaaaaaa"))
}

///|
test "branch: switch branch updates head" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  switch_branch(fs, fs, "/repo", "feature", create=true, checkout_files=false)
  let head = fs.read_string("/repo/.git/HEAD")
  assert_true(head.has_prefix("ref: refs/heads/feature"))
  let feature = fs.read_string("/repo/.git/refs/heads/feature")
  assert_true(feature.has_prefix("bbbbbbbbbb"))
}

///|
test "branch: create branch in unborn repo does not create empty ref file" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  create_branch(fs, fs, "/repo", "main")
  assert_true(not(fs.is_file("/repo/.git/refs/heads/main")))
}

///|
test "branch: switching unborn branches does not fail on empty refs" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  switch_branch(fs, fs, "/repo", "main", create=true, checkout_files=false)
  switch_branch(
    fs,
    fs,
    "/repo",
    "foo-branch",
    create=true,
    checkout_files=false,
  )
  let head = fs.read_string("/repo/.git/HEAD")
  assert_true(head.has_prefix("ref: refs/heads/foo-branch"))
}

///|
test "branch: resolve_ref follows linked worktree commondir" {
  let fs = setup_branch_fs()
  fs.mkdir_p("/repo/.git/worktrees/wt")
  fs.write_string("/repo/.git/worktrees/wt/commondir", "../..\n")
  fs.write_string(
    "/repo/.git/refs/heads/new-wt", "cccccccccccccccccccccccccccccccccccccccc\n",
  )
  let resolved = resolve_ref(fs, "/repo/.git/worktrees/wt", "refs/heads/new-wt")
  match resolved {
    Some(id) =>
      assert_eq(id.to_hex(), "cccccccccccccccccccccccccccccccccccccccc")
    None => fail("expected resolve_ref to resolve via commondir")
  }
}

///|
test "branch: create_branch_at writes refs in bare repository root" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/bare/refs/heads")
  fs.mkdir_p("/bare/objects")
  fs.write_string("/bare/HEAD", "ref: refs/heads/main\n")
  create_branch_at(
    fs,
    fs,
    "/bare",
    "wt",
    @bit.ObjectId::from_hex("dddddddddddddddddddddddddddddddddddddddd"),
  )
  let content = fs.read_string("/bare/refs/heads/wt")
  assert_true(content.has_prefix("dddddddddd"))
}

///|
test "branch: create_branch writes reflog from current branch" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )

  create_branch(fs, fs, "/repo", "topic")

  let entries = read_reflog(fs, "/repo/.git", "refs/heads/topic")
  assert_eq(entries.length(), 1)
  assert_eq(
    entries[0].new_id.to_hex(),
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  assert_eq(entries[0].message, "branch: Created from main")
}

///|
test "branch: create_branch_at writes reflog with explicit start point" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )

  create_branch_at(
    fs,
    fs,
    "/repo",
    "topic",
    @bit.ObjectId::from_hex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
    start_point=Some("main^"),
  )

  let entries = read_reflog(fs, "/repo/.git", "refs/heads/topic")
  assert_eq(entries.length(), 1)
  assert_eq(
    entries[0].new_id.to_hex(),
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  )
  assert_eq(entries[0].message, "branch: Created from main^")
}

///|
test "branch: create_branch_at rejects checked out branch" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/topic\n")
  fs.write_string(
    "/repo/.git/refs/heads/topic", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  let result = try? create_branch_at(
    fs,
    fs,
    "/repo",
    "topic",
    @bit.ObjectId::from_hex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
  )
  assert_true(result is Err(_))
  assert_eq(
    fs.read_string("/repo/.git/refs/heads/topic"),
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
}

///|
test "branch: create_branch_at rejects branch checked out in linked worktree" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/topic", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.mkdir_p("/repo/.git/worktrees/wt1")
  fs.write_string("/repo/.git/worktrees/wt1/gitdir", "/worktree1/.git\n")
  fs.write_string("/repo/.git/worktrees/wt1/HEAD", "ref: refs/heads/topic\n")
  fs.write_string("/repo/.git/worktrees/wt1/commondir", "../..\n")
  let result = try? create_branch_at(
    fs,
    fs,
    "/repo",
    "topic",
    @bit.ObjectId::from_hex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
  )
  assert_true(result is Err(_))
}

///|
test "branch: delete_branch prunes empty parent directories for nested refs" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.mkdir_p("/repo/.git/refs/heads/branch")
  fs.write_string(
    "/repo/.git/refs/heads/branch/conflict", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  delete_branch(fs, fs, "/repo", "branch/conflict", force=true)
  assert_true(not(fs.is_file("/repo/.git/refs/heads/branch/conflict")))
  assert_true(not(fs.is_dir("/repo/.git/refs/heads/branch")))
}

///|
test "branch: delete_branch rejects branch checked out in linked worktree" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/topic", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  fs.mkdir_p("/repo/.git/worktrees/wt1")
  fs.write_string("/repo/.git/worktrees/wt1/gitdir", "/worktree1/.git\n")
  fs.write_string("/repo/.git/worktrees/wt1/HEAD", "ref: refs/heads/topic\n")
  fs.write_string("/repo/.git/worktrees/wt1/commondir", "../..\n")
  let result = try? delete_branch(fs, fs, "/repo", "topic", force=true)
  assert_true(result is Err(_))
  assert_true(fs.is_file("/repo/.git/refs/heads/topic"))
}

///|
test "branch: delete_branch removes reflog for deleted ref" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/topic", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  fs.write_string(
    "/repo/.git/logs/refs/heads/topic", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb Test <test@example.com> 0 +0000\tbranch: Created from main\n",
  )
  delete_branch(fs, fs, "/repo", "topic", force=true)
  assert_true(not(fs.is_file("/repo/.git/logs/refs/heads/topic")))
}

///|
test "branch: rename_branch rejects target checked out in linked worktree" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/bar", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/foo", "cccccccccccccccccccccccccccccccccccccccc\n",
  )
  fs.mkdir_p("/repo/.git/worktrees/wt1")
  fs.write_string("/repo/.git/worktrees/wt1/gitdir", "/worktree1/.git\n")
  fs.write_string("/repo/.git/worktrees/wt1/HEAD", "ref: refs/heads/foo\n")
  fs.write_string("/repo/.git/worktrees/wt1/commondir", "../..\n")
  let result = try? rename_branch(fs, fs, "/repo", "bar", "foo", force=true)
  assert_true(result is Err(_))
}

///|
test "branch: rename_branch can move parent ref to nested child" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/m", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  fs.write_string(
    "/repo/.git/logs/refs/heads/m", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb Test <test@example.com> 0 +0000\tbranch: Created from main\n",
  )
  rename_branch(fs, fs, "/repo", "m", "m/m")
  assert_true(not(fs.is_file("/repo/.git/refs/heads/m")))
  assert_eq(
    fs.read_string("/repo/.git/refs/heads/m/m"),
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  assert_true(fs.is_file("/repo/.git/logs/refs/heads/m/m"))
}

///|
test "branch: rename_branch updates linked worktree HEADs" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/baz", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  fs.mkdir_p("/repo/.git/worktrees/wt1")
  fs.write_string("/repo/.git/worktrees/wt1/gitdir", "/worktree1/.git\n")
  fs.write_string("/repo/.git/worktrees/wt1/HEAD", "ref: refs/heads/baz\n")
  fs.write_string("/repo/.git/worktrees/wt1/commondir", "../..\n")
  rename_branch(fs, fs, "/repo", "baz", "bam")
  assert_eq(
    fs.read_string("/repo/.git/worktrees/wt1/HEAD"),
    "ref: refs/heads/bam\n",
  )
}

///|
test "branch: rename_branch from linked worktree root updates common refs" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/baz", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  fs.mkdir_p("/repo/.git/worktrees/wt1")
  fs.write_string("/repo/.git/worktrees/wt1/gitdir", "/worktree/.git\n")
  fs.write_string("/repo/.git/worktrees/wt1/HEAD", "ref: refs/heads/baz\n")
  fs.write_string("/repo/.git/worktrees/wt1/commondir", "../..\n")
  fs.write_string("/worktree/.git", "gitdir: /repo/.git/worktrees/wt1\n")
  rename_branch(fs, fs, "/worktree", "baz", "bam")
  assert_true(not(fs.is_file("/repo/.git/refs/heads/baz")))
  assert_eq(
    fs.read_string("/repo/.git/refs/heads/bam"),
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  assert_eq(
    fs.read_string("/repo/.git/worktrees/wt1/HEAD"),
    "ref: refs/heads/bam\n",
  )
}

///|
test "branch: rename_branch can move nested child to parent" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.mkdir_p("/repo/.git/refs/heads/n")
  fs.write_string(
    "/repo/.git/refs/heads/n/n", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  fs.write_string(
    "/repo/.git/logs/refs/heads/n/n", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb Test <test@example.com> 0 +0000\tbranch: Created from main\n",
  )
  rename_branch(fs, fs, "/repo", "n/n", "n")
  assert_true(not(fs.is_dir("/repo/.git/refs/heads/n/n")))
  assert_eq(
    fs.read_string("/repo/.git/refs/heads/n"),
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  assert_true(fs.is_file("/repo/.git/logs/refs/heads/n"))
}

///|
test "branch: rename_branch replaces dangling symref target" {
  let fs = setup_branch_fs()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/m", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  fs.write_string(
    "/repo/.git/refs/heads/broken_symref", "ref: refs/heads/i_am_broken\n",
  )
  rename_branch(fs, fs, "/repo", "m", "broken_symref")
  assert_eq(
    fs.read_string("/repo/.git/refs/heads/broken_symref"),
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
  assert_true(not(fs.is_file("/repo/.git/refs/heads/m")))
}

///|
test "branch: create_lightweight_tag rejects conflicting parent ref path" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/refs/tags/foo")
  fs.write_string(
    "/repo/.git/refs/tags/foo/bar", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  let result = try? create_lightweight_tag(
    fs,
    fs,
    "/repo/.git",
    "foo",
    @bit.ObjectId::from_hex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
  )
  assert_true(result is Err(_))
  assert_true(fs.is_file("/repo/.git/refs/tags/foo/bar"))
  assert_true(not(fs.is_file("/repo/.git/refs/tags/foo")))
}

///|
test "branch: create_lightweight_tag rejects conflicting packed ref path" {
  let fs = @bit.TestFs::new()
  fs.write_string(
    "/repo/.git/packed-refs", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/tags/foo/bar\n",
  )
  let result = try? create_lightweight_tag(
    fs,
    fs,
    "/repo/.git",
    "foo",
    @bit.ObjectId::from_hex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
  )
  assert_true(result is Err(_))
  assert_true(not(fs.is_file("/repo/.git/refs/tags/foo")))
}

///|
test "branch: create_lightweight_tag creates parent directories for nested refs" {
  let fs = @bit.TestFs::new()
  create_lightweight_tag(
    fs,
    fs,
    "/repo/.git",
    "foo/bar",
    @bit.ObjectId::from_hex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
  )
  assert_true(fs.is_dir("/repo/.git/refs/tags/foo"))
  assert_eq(
    fs.read_string("/repo/.git/refs/tags/foo/bar"),
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n",
  )
}

///|
test "branch: delete_tag removes reflog and prunes empty parent directories" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/refs/tags/foo")
  fs.mkdir_p("/repo/.git/logs/refs/tags/foo")
  fs.write_string(
    "/repo/.git/refs/tags/foo/bar", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  fs.write_string(
    "/repo/.git/logs/refs/tags/foo/bar", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb A U Thor <a@example.com> 1 +0000\ttag: tagging\n",
  )

  delete_tag(fs, fs, "/repo/.git", "foo/bar")

  assert_true(not(fs.exists("/repo/.git/refs/tags/foo/bar")))
  assert_true(not(fs.exists("/repo/.git/logs/refs/tags/foo/bar")))
  assert_true(not(fs.exists("/repo/.git/refs/tags/foo")))
  assert_true(not(fs.exists("/repo/.git/logs/refs/tags/foo")))
}

///|
test "branch: create_annotated_tag uses storage hash and records compat mapping" {
  let fs = setup_sha256_compat_repo()
  fs.write_string("/repo/hello", "Hello World!\n")
  add_paths(fs, fs, "/repo", ["hello"])
  let commit_id = commit(
    fs,
    fs,
    "/repo",
    "Initial commit\n",
    "A U Thor <author@example.com>",
    1112354055L,
    committer="C O Mitter <committer@example.com>",
    committer_timestamp=1112354055L,
    timezone="+0200",
  )
  create_annotated_tag(
    fs,
    fs,
    "/repo/.git",
    "v1",
    commit_id,
    "tag message",
    "C O Mitter <committer@example.com>",
    1112354055L,
    timezone="+0200",
  )
  let tag_id = resolve_ref(fs, "/repo/.git", "refs/tags/v1").unwrap()
  assert_true(fs.is_file(worktree_test_object_path("/repo/.git", tag_id)))
  let compat = compat_lookup_loose_object_idx(fs, "/repo/.git", tag_id.to_hex())
  assert_true(compat is Some(_))
  assert_true(compat.unwrap().length() == 40)
}
