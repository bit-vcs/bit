///|
test "cherry-pick: 3way flags are accepted without fallback" {
  assert_true(cherry_pick_is_supported_noop_arg("-3"))
  assert_true(cherry_pick_is_supported_noop_arg("--3way"))
  assert_false(cherry_pick_is_supported_noop_arg("--abort"))
}

///|
test "cherry-pick: lone dash is treated as positional revision" {
  assert_true(cherry_pick_is_positional_arg("-"))
  assert_true(cherry_pick_is_positional_arg("HEAD"))
  assert_false(cherry_pick_is_positional_arg("--abort"))
}

///|
fn cherry_pick_wbtest_setup_linear_repo() -> (
  @bitcore.TestFs,
  @bitcore.ObjectId,
  @bitcore.ObjectId,
  @bitcore.ObjectId,
) raise Error {
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

  (fs, first, second, third)
}

///|
test "cherry-pick: 3way mode replays linear commits from merge-base" {
  let (fs, first, second, third) = cherry_pick_wbtest_setup_linear_repo()
  let commits = cherry_pick_collect_linear_replay_commits(
    fs, "/repo/.git", first, third,
  )
  assert_eq(commits.length(), 2)
  assert_eq(commits[0].to_hex(), second.to_hex())
  assert_eq(commits[1].to_hex(), third.to_hex())
}

///|
fn cherry_pick_wbtest_commit_tree(
  fs : @bitcore.TestFs,
  commit_id : @bitcore.ObjectId,
) -> (@bitcore.ObjectId, Int) raise Error {
  let db = @bitlib.ObjectDb::load(fs, "/repo/.git")
  let obj = db.get(fs, commit_id).unwrap()
  let info = @bitcore.parse_commit(obj.data)
  (info.tree, info.parents.length())
}

///|
fn cherry_pick_wbtest_make_unborn(fs : @bitcore.TestFs) -> Unit {
  fs.remove_file("/repo/.git/refs/heads/main") catch {
    _ => ()
  }
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/unborn\n")
}

///|
test "cherry-pick: initial commit can be picked onto unborn branch with empty index" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  fs.write_string("/repo/oops", "aaa\n")
  @bitlib.add_paths(fs, fs, "/repo", ["oops"])
  let initial = @bitlib.commit(
    fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L,
  )
  cherry_pick_wbtest_make_unborn(fs)
  @bitlib.write_index_entries(fs, "/repo/.git", [])

  let result = @bitlib.cherry_pick(
    fs, fs, "/repo", initial, "Test <t@example.com>", 1700000100L,
  )
  match result.status {
    @bitlib.CherryPickStatus::Success => ()
    _ => fail("expected cherry-pick success")
  }
  let head_id = @bitlib.resolve_head_commit(fs, "/repo/.git").unwrap()
  let (head_tree, parent_count) = cherry_pick_wbtest_commit_tree(fs, head_id)
  let (initial_tree, _) = cherry_pick_wbtest_commit_tree(fs, initial)
  assert_eq(head_tree.to_hex(), initial_tree.to_hex())
  assert_eq(parent_count, 0)
}

///|
test "cherry-pick: initial commit can be picked onto unborn branch with matching index" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  fs.write_string("/repo/oops", "aaa\n")
  @bitlib.add_paths(fs, fs, "/repo", ["oops"])
  let initial = @bitlib.commit(
    fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L,
  )
  fs.write_string("/repo/opos", "leftover\n")
  cherry_pick_wbtest_make_unborn(fs)

  let result = @bitlib.cherry_pick(
    fs,
    fs,
    "/repo",
    initial,
    "Test <t@example.com>",
    1700000100L,
    allow_empty=true,
  )
  match result.status {
    @bitlib.CherryPickStatus::Success => ()
    _ => fail("expected cherry-pick success")
  }
  let head_id = @bitlib.resolve_head_commit(fs, "/repo/.git").unwrap()
  let (head_tree, parent_count) = cherry_pick_wbtest_commit_tree(fs, head_id)
  let (initial_tree, _) = cherry_pick_wbtest_commit_tree(fs, initial)
  assert_eq(head_tree.to_hex(), initial_tree.to_hex())
  assert_eq(parent_count, 0)
  assert_true(fs.is_file("/repo/opos"))
}
