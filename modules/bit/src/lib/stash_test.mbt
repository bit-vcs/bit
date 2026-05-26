///| Tests for stash

///|
fn setup_stash_repo() -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs
}

///|
async test "stash: push saves changes and restores worktree" {
  let fs = setup_stash_repo()
  // Create initial commit
  fs.write_string("/repo/file.txt", "original\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L),
  )
  // Modify file
  fs.write_string("/repo/file.txt", "modified\n")
  // Stash push
  let stash_id = stash_push(
    fs, fs, "/repo", "test stash", "Test <t@example.com>", 1700000001L,
  )
  assert_true(stash_id is Some(_))
  // Worktree should be restored to original
  let content = fs.read_string("/repo/file.txt")
  assert_eq(content, "original\n")
}

///|
async test "stash: list shows stashed entries" {
  let fs = setup_stash_repo()
  // Create initial commit
  fs.write_string("/repo/file.txt", "original\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L),
  )
  // Modify and stash
  fs.write_string("/repo/file.txt", "modified\n")
  ignore(
    stash_push(
      fs, fs, "/repo", "my stash message", "Test <t@example.com>", 1700000001L,
    ),
  )
  // List stash
  let entries = stash_list(fs, "/repo/.git")
  assert_eq(entries.length(), 1)
  assert_true(entries[0].message.contains("my stash message"))
}

///|
async test "stash: apply restores stashed changes" {
  let fs = setup_stash_repo()
  // Create initial commit
  fs.write_string("/repo/file.txt", "original\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L),
  )
  // Modify and stash
  fs.write_string("/repo/file.txt", "modified\n")
  ignore(
    stash_push(
      fs, fs, "/repo", "test stash", "Test <t@example.com>", 1700000001L,
    ),
  )
  // Verify worktree is restored to original
  let content_after_push = fs.read_string("/repo/file.txt")
  assert_eq(content_after_push, "original\n")
  // Apply stash (without drop)
  stash_apply(fs, fs, "/repo", 0, false)
  // Worktree should now have the stashed content
  let content_after_apply = fs.read_string("/repo/file.txt")
  assert_eq(content_after_apply, "modified\n")
  // Stash should still exist
  let entries = stash_list(fs, "/repo/.git")
  assert_eq(entries.length(), 1)
}

///|
async test "stash: pop restores and drops stash" {
  let fs = setup_stash_repo()
  // Create initial commit
  fs.write_string("/repo/file.txt", "original\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L),
  )
  // Modify and stash
  fs.write_string("/repo/file.txt", "modified\n")
  ignore(
    stash_push(
      fs, fs, "/repo", "test stash", "Test <t@example.com>", 1700000001L,
    ),
  )
  // Pop stash (apply with drop=true)
  stash_apply(fs, fs, "/repo", 0, true)
  // Worktree should have the stashed content
  let content = fs.read_string("/repo/file.txt")
  assert_eq(content, "modified\n")
  // Stash should be empty
  let entries = stash_list(fs, "/repo/.git")
  assert_eq(entries.length(), 0)
}

///|
async test "stash: drop removes entry" {
  let fs = setup_stash_repo()
  // Create initial commit
  fs.write_string("/repo/file.txt", "original\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L),
  )
  // Modify and stash
  fs.write_string("/repo/file.txt", "modified\n")
  ignore(
    stash_push(
      fs, fs, "/repo", "test stash", "Test <t@example.com>", 1700000001L,
    ),
  )
  // Drop stash
  stash_drop(fs, fs, "/repo", 0)
  // Stash should be empty
  let entries = stash_list(fs, "/repo/.git")
  assert_eq(entries.length(), 0)
}

///|
async test "stash: push with no changes returns None" {
  let fs = setup_stash_repo()
  // Create initial commit
  fs.write_string("/repo/file.txt", "original\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L),
  )
  // No changes - stash should return None
  let stash_id = stash_push(
    fs, fs, "/repo", "empty stash", "Test <t@example.com>", 1700000001L,
  )
  assert_true(stash_id is None)
}

///|
async test "stash: multiple stashes stack correctly" {
  let fs = setup_stash_repo()
  // Create initial commit
  fs.write_string("/repo/file.txt", "original\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L),
  )
  // First stash
  fs.write_string("/repo/file.txt", "first change\n")
  ignore(
    stash_push(
      fs, fs, "/repo", "first stash", "Test <t@example.com>", 1700000001L,
    ),
  )
  // Second stash
  fs.write_string("/repo/file.txt", "second change\n")
  ignore(
    stash_push(
      fs, fs, "/repo", "second stash", "Test <t@example.com>", 1700000002L,
    ),
  )
  // List should show 2 entries, newest first
  let entries = stash_list(fs, "/repo/.git")
  assert_eq(entries.length(), 2)
  assert_true(entries[0].message.contains("second stash"))
  assert_true(entries[1].message.contains("first stash"))
}

///|
fn stash_test_blob_text(
  fs : @bit.TestFs,
  stash_id : @bit.ObjectId,
  path : String,
) -> String raise @bit.GitError {
  let db = ObjectDb::load(fs, "/repo/.git")
  let obj = db.get(fs, stash_id).unwrap()
  let info = @bit.parse_commit(obj.data)
  let files = collect_tree_files(db, fs, info.tree)
  let entry = files[path]
  let blob = db.get(fs, entry.id).unwrap()
  @utf8.decode_lossy(blob.data[:])
}

///|
async fn stash_test_async_boundary(fs : @bit.TestFs) -> Unit {
  ignore(status(fs, "/repo"))
}

///|
async test "stash: patch push stores selected hunk and leaves unselected hunk" {
  let fs = setup_stash_repo()
  let original = "l01\nl02\nl03\nl04\nl05\nl06\nl07\nl08\nl09\nl10\nl11\nl12\n"
  fs.write_string("/repo/file.txt", original)
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L),
  )
  fs.write_string(
    "/repo/file.txt", "L01\nl02\nl03\nl04\nl05\nl06\nl07\nl08\nl09\nl10\nl11\nL12\n",
  )
  let selector = async fn(
    _hunk : StashPatchHunk,
    index : Int,
    _total : Int,
  ) -> Bool {
    stash_test_async_boundary(fs)
    index == 0
  }
  let stash_id = stash_push_patch(
    fs, fs, "/repo", "partial", "Test <t@example.com>", 1700000001L, selector,
  )
  guard stash_id is Some(id) else { fail("expected patch stash") }
  assert_eq(
    fs.read_string("/repo/file.txt"),
    "l01\nl02\nl03\nl04\nl05\nl06\nl07\nl08\nl09\nl10\nl11\nL12\n",
  )
  assert_eq(
    stash_test_blob_text(fs, id, "file.txt"),
    "L01\nl02\nl03\nl04\nl05\nl06\nl07\nl08\nl09\nl10\nl11\nl12\n",
  )
}

///|
async test "stash: patch push preserves index state" {
  let fs = setup_stash_repo()
  fs.write_string("/repo/file.txt", "original\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L),
  )
  fs.write_string("/repo/file.txt", "staged\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  let before = read_index_entries(fs, "/repo/.git")[0].id
  let selector = async fn(
    _hunk : StashPatchHunk,
    _index : Int,
    _total : Int,
  ) -> Bool {
    stash_test_async_boundary(fs)
    true
  }
  let stash_id = stash_push_patch(
    fs, fs, "/repo", "staged", "Test <t@example.com>", 1700000001L, selector,
  )
  assert_true(stash_id is Some(_))
  assert_eq(fs.read_string("/repo/file.txt"), "original\n")
  let after = read_index_entries(fs, "/repo/.git")[0].id
  assert_eq(after, before)
}
