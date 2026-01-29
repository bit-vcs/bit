///| Tests for reset

///|
fn setup_repo_reset() -> TestFs {
  let fs = TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs
}

///|
test "reset: hard to previous commit" {
  let fs = setup_repo_reset()
  fs.write_string("/repo/a.txt", "one\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  let first = commit(
    fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000000L,
  )
  fs.write_string("/repo/a.txt", "two\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(
    commit(fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000001L),
  )
  let target = reset(fs, fs, "/repo", first.to_hex(), @git.ResetMode::Hard)
  assert_true(target == first)
  let content = fs.read_string("/repo/a.txt")
  assert_true(content == "one\n")
  let ref_text = fs.read_string("/repo/.git/refs/heads/main")
  assert_true(ref_text.contains(first.to_hex()))
}

///|
test "reset: soft keeps worktree" {
  let fs = setup_repo_reset()
  fs.write_string("/repo/a.txt", "one\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  let first = commit(
    fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000000L,
  )
  fs.write_string("/repo/a.txt", "two\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(
    commit(fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000001L),
  )
  ignore(reset(fs, fs, "/repo", first.to_hex(), @git.ResetMode::Soft))
  let content = fs.read_string("/repo/a.txt")
  assert_true(content == "two\n")
}

///|
test "reset: mixed keeps worktree" {
  let fs = setup_repo_reset()
  fs.write_string("/repo/a.txt", "one\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  let first = commit(
    fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000000L,
  )
  fs.write_string("/repo/a.txt", "two\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(
    commit(fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000001L),
  )
  ignore(reset(fs, fs, "/repo", first.to_hex(), @git.ResetMode::Mixed))
  let content = fs.read_string("/repo/a.txt")
  assert_true(content == "two\n")
}
