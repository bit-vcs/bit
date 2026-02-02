///| Tests for stash

///|
fn setup_stash_repo() -> @git.TestFs {
  let fs = @git.TestFs::new()
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
