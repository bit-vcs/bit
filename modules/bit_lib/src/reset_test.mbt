///| Tests for reset

///|
fn setup_repo_reset() -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  ignore(@bit_lib.init_repo(fs, "/repo")) catch {
    _ => ()
  }
  fs
}

///|
test "reset: hard to previous commit" {
  let fs = setup_repo_reset()
  fs.write_string("/repo/a.txt", "one\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  let first = @bit_lib.commit(
    fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000000L,
  )
  fs.write_string("/repo/a.txt", "two\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(
    @bit_lib.commit(fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000001L),
  )
  let target = @bit_lib.reset(fs, fs, "/repo", first.to_hex(), @bit_lib.ResetMode::Hard)
  assert_true(target == first)
  let content = fs.read_string("/repo/a.txt")
  assert_true(content == "one\n")
  let ref_text = fs.read_string("/repo/.git/refs/heads/main")
  assert_true(ref_text.contains(first.to_hex()))
  let reflog = @bit_lib.read_reflog(fs, "/repo/.git", "refs/heads/main")
  @test.assert_eq(reflog.length(), 3)
  @test.assert_eq(reflog[2].message, "reset: moving to " + first.to_hex())
}

///|
test "reset: soft keeps worktree" {
  let fs = setup_repo_reset()
  fs.write_string("/repo/a.txt", "one\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  let first = @bit_lib.commit(
    fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000000L,
  )
  fs.write_string("/repo/a.txt", "two\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(
    @bit_lib.commit(fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000001L),
  )
  ignore(@bit_lib.reset(fs, fs, "/repo", first.to_hex(), @bit_lib.ResetMode::Soft))
  let content = fs.read_string("/repo/a.txt")
  assert_true(content == "two\n")
}

///|
test "reset: mixed keeps worktree" {
  let fs = setup_repo_reset()
  fs.write_string("/repo/a.txt", "one\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  let first = @bit_lib.commit(
    fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000000L,
  )
  fs.write_string("/repo/a.txt", "two\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(
    @bit_lib.commit(fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000001L),
  )
  ignore(@bit_lib.reset(fs, fs, "/repo", first.to_hex(), @bit_lib.ResetMode::Mixed))
  let content = fs.read_string("/repo/a.txt")
  assert_true(content == "two\n")
}

///|
test "reset: hard preserves initialized submodule worktree state" {
  let fs = setup_repo_reset()
  fs.write_string("/repo/a.txt", "one\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(
    @bit_lib.commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000100L),
  )

  @bit_lib.init_repo_with_options(fs, "/repo/vendor/sub", {
    default_branch: "main",
    bare: false,
    separate_git_dir: Some("/repo/.git/modules/example"),
    template_dir: None,
    ref_format: "files",
    object_format: "sha1",
    is_reinit: false,
    git_dir: None,
    work_tree: Some("/repo/vendor/sub"),
    shared: None,
  })
  fs.write_string("/repo/vendor/sub/a", "sub\n")
  @bit_lib.add_paths(fs, fs, "/repo/vendor/sub", ["a"])
  let submodule_first = @bit_lib.commit(
    fs, fs, "/repo/vendor/sub", "sub-1\n", "Test <t@example.com>", 1700000101L,
  )

  fs.write_string(
    "/repo/.gitmodules", "[submodule \"example\"]\n\tpath = vendor/sub\n\turl = ../example\n",
  )
  @bit_lib.add_paths(fs, fs, "/repo", [".gitmodules"])
  let entries = @bit_lib.read_index_entries(fs, "/repo/.git")
  entries.push(@bit_lib.IndexEntry::new("vendor/sub", submodule_first, 0o160000, 0))
  @bit_lib.write_index_entries(fs, "/repo/.git", entries)
  let with_submodule = @bit_lib.commit(
    fs, fs, "/repo", "with-submodule\n", "Test <t@example.com>", 1700000102L,
  )

  fs.write_string("/repo/vendor/sub/b", "change\n")
  @bit_lib.add_paths(fs, fs, "/repo/vendor/sub", ["b"])
  let submodule_second = @bit_lib.commit(
    fs, fs, "/repo/vendor/sub", "sub-2\n", "Test <t@example.com>", 1700000103L,
  )
  let head_before_reset = fs.read_string("/repo/.git/modules/example/HEAD")

  ignore(@bit_lib.reset(fs, fs, "/repo", with_submodule.to_hex(), @bit_lib.ResetMode::Hard))

  @test.assert_eq(
    fs.read_string("/repo/.git/modules/example/HEAD"),
    head_before_reset,
  )
  @test.assert_eq(
    @bit_lib.resolve_head_commit(fs, "/repo/.git/modules/example"),
    Some(submodule_second),
  )
  assert_true(fs.is_file("/repo/vendor/sub/b"))
}

///|
test "reset: hard replaces directory path with file from target commit" {
  let fs = setup_repo_reset()
  fs.mkdir_p("/repo/folder1/0/0")
  fs.write_string("/repo/folder1/0/0/0", "nested\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["folder1/0/0/0"])
  let dir_commit = @bit_lib.commit(
    fs, fs, "/repo", "dir\n", "Test <t@example.com>", 1700000200L,
  )

  @bit_lib.rm_paths(fs, fs, "/repo", ["folder1/0/0/0"])
  fs.write_string("/repo/folder1/0/0", "file\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["folder1/0/0"])
  let file_commit = @bit_lib.commit(
    fs, fs, "/repo", "file\n", "Test <t@example.com>", 1700000201L,
  )

  ignore(@bit_lib.checkout(fs, fs, "/repo", dir_commit.to_hex()))
  assert_true(fs.is_dir("/repo/folder1/0/0"))

  let target = @bit_lib.reset(fs, fs, "/repo", file_commit.to_hex(), @bit_lib.ResetMode::Hard)
  assert_true(target == file_commit)
  assert_true(fs.is_file("/repo/folder1/0/0"))
  @test.assert_eq(fs.read_string("/repo/folder1/0/0"), "file\n")
}
