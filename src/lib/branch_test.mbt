///| Tests for git branch listing

///|
fn setup_branch_fs() -> @git.TestFs {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.mkdir_p("/repo/.git/refs/heads")
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
  let fs = @git.TestFs::new()
  fs.mkdir_p("/bare/refs/heads")
  fs.mkdir_p("/bare/objects")
  fs.write_string("/bare/HEAD", "ref: refs/heads/main\n")
  create_branch_at(
    fs,
    fs,
    "/bare",
    "wt",
    @git.ObjectId::from_hex("dddddddddddddddddddddddddddddddddddddddd"),
  )
  let content = fs.read_string("/bare/refs/heads/wt")
  assert_true(content.has_prefix("dddddddddd"))
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
