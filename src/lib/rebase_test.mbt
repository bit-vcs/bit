///| Tests for rebase

///|
fn setup_repo_rebase() -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs
}

///|
test "rebase: start with onto rebases commits onto new base" {
  let fs = setup_repo_rebase()
  fs.write_string("/repo/a.txt", "A\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  let commit_a = commit(
    fs, fs, "/repo", "A", "Test <t@example.com>", 1700000000L,
  )

  create_branch_at(fs, fs, "/repo", "topic", commit_a)
  switch_branch(fs, fs, "/repo", "topic", checkout_files=true)
  fs.write_string("/repo/d.txt", "D\n")
  add_paths(fs, fs, "/repo", ["d.txt"])
  ignore(commit(fs, fs, "/repo", "D", "Test <t@example.com>", 1700000001L))
  fs.write_string("/repo/e.txt", "E\n")
  add_paths(fs, fs, "/repo", ["e.txt"])
  ignore(commit(fs, fs, "/repo", "E", "Test <t@example.com>", 1700000002L))

  switch_branch(fs, fs, "/repo", "main", checkout_files=true)
  fs.write_string("/repo/b.txt", "B\n")
  add_paths(fs, fs, "/repo", ["b.txt"])
  ignore(commit(fs, fs, "/repo", "B", "Test <t@example.com>", 1700000003L))
  fs.write_string("/repo/c.txt", "C\n")
  add_paths(fs, fs, "/repo", ["c.txt"])
  let commit_c = commit(
    fs, fs, "/repo", "C", "Test <t@example.com>", 1700000004L,
  )

  switch_branch(fs, fs, "/repo", "topic", checkout_files=true)
  let result = rebase_start_with_onto(fs, fs, "/repo", commit_c, commit_a)
  match result.status {
    RebaseStatus::Complete => ()
    _ => fail("expected complete rebase")
  }

  let head = resolve_head_commit(fs, "/repo/.git")
  guard head is Some(head_id) else { fail("expected rebased head") }
  let db = ObjectDb::load(fs, "/repo/.git")
  let head_obj = db.get(fs, head_id)
  guard head_obj is Some(head_commit) else {
    fail("expected head commit object")
  }
  let head_info = @bit.parse_commit(head_commit.data)
  assert_eq(head_info.parents.length(), 1)

  let parent_obj = db.get(fs, head_info.parents[0])
  guard parent_obj is Some(parent_commit) else {
    fail("expected parent commit object")
  }
  let parent_info = @bit.parse_commit(parent_commit.data)
  assert_eq(parent_info.parents.length(), 1)
  assert_eq(parent_info.parents[0], commit_c)
  assert_eq(fs.read_string("/repo/b.txt"), "B\n")
  assert_eq(fs.read_string("/repo/c.txt"), "C\n")
  assert_eq(fs.read_string("/repo/d.txt"), "D\n")
  assert_eq(fs.read_string("/repo/e.txt"), "E\n")
}

///|
test "rebase: start fast-forwards when HEAD is behind upstream" {
  let fs = setup_repo_rebase()
  fs.write_string("/repo/a.txt", "A\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  let commit_a = commit(
    fs, fs, "/repo", "A", "Test <t@example.com>", 1700000000L,
  )

  create_branch_at(fs, fs, "/repo", "topic", commit_a)
  fs.write_string("/repo/b.txt", "B\n")
  add_paths(fs, fs, "/repo", ["b.txt"])
  let commit_b = commit(
    fs, fs, "/repo", "B", "Test <t@example.com>", 1700000001L,
  )

  switch_branch(fs, fs, "/repo", "topic", checkout_files=true)
  let result = rebase_start(fs, fs, "/repo", commit_b)
  match result.status {
    RebaseStatus::Complete => ()
    _ => fail("expected complete rebase")
  }
  assert_eq(result.commit_id, Some(commit_b))
  assert_eq(resolve_head_commit(fs, "/repo/.git"), Some(commit_b))
  assert_eq(fs.read_string("/repo/a.txt"), "A\n")
  assert_eq(fs.read_string("/repo/b.txt"), "B\n")
}

///|
test "rebase: start skips commit whose patch already exists upstream" {
  let fs = setup_repo_rebase()
  let base_content = "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n"
  fs.write_string("/repo/stuff", base_content)
  add_paths(fs, fs, "/repo", ["stuff"])
  let base_commit = commit(
    fs, fs, "/repo", "base", "Test <t@example.com>", 1700000000L,
  )

  create_branch_at(fs, fs, "/repo", "topic", base_commit)

  let upstream_once = "1\n2\n3\n4\n43\n6\n7\n8\n9\n10\n"
  fs.write_string("/repo/stuff", upstream_once)
  add_paths(fs, fs, "/repo", ["stuff"])
  ignore(commit(fs, fs, "/repo", "5->43", "Test <t@example.com>", 1700000001L))

  let upstream_twice = "1\n2\n3\n4\n43\n42\n7\n8\n9\n10\n"
  fs.write_string("/repo/stuff", upstream_twice)
  add_paths(fs, fs, "/repo", ["stuff"])
  let upstream_head = commit(
    fs, fs, "/repo", "Make it bigger", "Test <t@example.com>", 1700000002L,
  )

  switch_branch(fs, fs, "/repo", "topic", checkout_files=true)
  fs.write_string("/repo/stuff", upstream_once)
  add_paths(fs, fs, "/repo", ["stuff"])
  ignore(
    commit(
      fs, fs, "/repo", "Independent discovery of 5->43", "Test <t@example.com>",
      1700000003L,
    ),
  )

  let result = rebase_start(fs, fs, "/repo", upstream_head)
  match result.status {
    RebaseStatus::Complete => ()
    _ => fail("expected rebase to skip already-upstreamed patch")
  }

  assert_eq(resolve_head_commit(fs, "/repo/.git"), Some(upstream_head))
  assert_eq(fs.read_string("/repo/stuff"), upstream_twice)
}
