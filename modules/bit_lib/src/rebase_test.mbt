///| Tests for rebase

///|
fn setup_repo_rebase() -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  ignore(@bit_lib.init_repo(fs, "/repo")) catch {
    _ => ()
  }
  fs
}

///|
async test "rebase: start with onto rebases commits onto new base" {
  let fs = setup_repo_rebase()
  fs.write_string("/repo/a.txt", "A\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  let commit_a = @bit_lib.commit(
    fs, fs, "/repo", "A", "Test <t@example.com>", 1700000000L,
  )

  @bit_lib.create_branch_at(fs, fs, "/repo", "topic", commit_a)
  @bit_lib.switch_branch(fs, fs, "/repo", "topic", checkout_files=true)
  fs.write_string("/repo/d.txt", "D\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["d.txt"])
  ignore(@bit_lib.commit(fs, fs, "/repo", "D", "Test <t@example.com>", 1700000001L))
  fs.write_string("/repo/e.txt", "E\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["e.txt"])
  ignore(@bit_lib.commit(fs, fs, "/repo", "E", "Test <t@example.com>", 1700000002L))

  @bit_lib.switch_branch(fs, fs, "/repo", "main", checkout_files=true)
  fs.write_string("/repo/b.txt", "B\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["b.txt"])
  ignore(@bit_lib.commit(fs, fs, "/repo", "B", "Test <t@example.com>", 1700000003L))
  fs.write_string("/repo/c.txt", "C\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["c.txt"])
  let commit_c = @bit_lib.commit(
    fs, fs, "/repo", "C", "Test <t@example.com>", 1700000004L,
  )

  @bit_lib.switch_branch(fs, fs, "/repo", "topic", checkout_files=true)
  let result = @bit_lib.rebase_start_with_onto(fs, fs, "/repo", commit_c, commit_a)
  match result.status {
    @bit_lib.RebaseStatus::Complete => ()
    _ => fail("expected complete rebase")
  }

  let head = @bit_lib.resolve_head_commit(fs, "/repo/.git")
  guard head is Some(head_id) else { fail("expected rebased head") }
  let db = @bit_lib.ObjectDb::load(fs, "/repo/.git")
  let head_obj = db.get(fs, head_id)
  guard head_obj is Some(head_commit) else {
    fail("expected head commit object")
  }
  let head_info = @bit.parse_commit(head_commit.data)
  @test.assert_eq(head_info.parents.length(), 1)

  let parent_obj = db.get(fs, head_info.parents[0])
  guard parent_obj is Some(parent_commit) else {
    fail("expected parent commit object")
  }
  let parent_info = @bit.parse_commit(parent_commit.data)
  @test.assert_eq(parent_info.parents.length(), 1)
  @test.assert_eq(parent_info.parents[0], commit_c)
  @test.assert_eq(fs.read_string("/repo/b.txt"), "B\n")
  @test.assert_eq(fs.read_string("/repo/c.txt"), "C\n")
  @test.assert_eq(fs.read_string("/repo/d.txt"), "D\n")
  @test.assert_eq(fs.read_string("/repo/e.txt"), "E\n")
}

///|
async test "rebase: start fast-forwards when HEAD is behind upstream" {
  let fs = setup_repo_rebase()
  fs.write_string("/repo/a.txt", "A\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  let commit_a = @bit_lib.commit(
    fs, fs, "/repo", "A", "Test <t@example.com>", 1700000000L,
  )

  @bit_lib.create_branch_at(fs, fs, "/repo", "topic", commit_a)
  fs.write_string("/repo/b.txt", "B\n")
  @bit_lib.add_paths(fs, fs, "/repo", ["b.txt"])
  let commit_b = @bit_lib.commit(
    fs, fs, "/repo", "B", "Test <t@example.com>", 1700000001L,
  )

  @bit_lib.switch_branch(fs, fs, "/repo", "topic", checkout_files=true)
  let result = @bit_lib.rebase_start(fs, fs, "/repo", commit_b)
  match result.status {
    @bit_lib.RebaseStatus::Complete => ()
    _ => fail("expected complete rebase")
  }
  @test.assert_eq(result.commit_id, Some(commit_b))
  @test.assert_eq(@bit_lib.resolve_head_commit(fs, "/repo/.git"), Some(commit_b))
  @test.assert_eq(fs.read_string("/repo/a.txt"), "A\n")
  @test.assert_eq(fs.read_string("/repo/b.txt"), "B\n")
}

///|
async test "rebase: start skips commit whose patch already exists upstream" {
  let fs = setup_repo_rebase()
  let base_content = "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n"
  fs.write_string("/repo/stuff", base_content)
  @bit_lib.add_paths(fs, fs, "/repo", ["stuff"])
  let base_commit = @bit_lib.commit(
    fs, fs, "/repo", "base", "Test <t@example.com>", 1700000000L,
  )

  @bit_lib.create_branch_at(fs, fs, "/repo", "topic", base_commit)

  let upstream_once = "1\n2\n3\n4\n43\n6\n7\n8\n9\n10\n"
  fs.write_string("/repo/stuff", upstream_once)
  @bit_lib.add_paths(fs, fs, "/repo", ["stuff"])
  ignore(@bit_lib.commit(fs, fs, "/repo", "5->43", "Test <t@example.com>", 1700000001L))

  let upstream_twice = "1\n2\n3\n4\n43\n42\n7\n8\n9\n10\n"
  fs.write_string("/repo/stuff", upstream_twice)
  @bit_lib.add_paths(fs, fs, "/repo", ["stuff"])
  let upstream_head = @bit_lib.commit(
    fs, fs, "/repo", "Make it bigger", "Test <t@example.com>", 1700000002L,
  )

  @bit_lib.switch_branch(fs, fs, "/repo", "topic", checkout_files=true)
  fs.write_string("/repo/stuff", upstream_once)
  @bit_lib.add_paths(fs, fs, "/repo", ["stuff"])
  ignore(
    @bit_lib.commit(
      fs, fs, "/repo", "Independent discovery of 5->43", "Test <t@example.com>",
      1700000003L,
    ),
  )

  let result = @bit_lib.rebase_start(fs, fs, "/repo", upstream_head)
  match result.status {
    @bit_lib.RebaseStatus::Complete => ()
    _ => fail("expected rebase to skip already-upstreamed patch")
  }

  @test.assert_eq(@bit_lib.resolve_head_commit(fs, "/repo/.git"), Some(upstream_head))
  @test.assert_eq(fs.read_string("/repo/stuff"), upstream_twice)
}
