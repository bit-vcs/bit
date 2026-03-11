///| Tests for merge

///|
fn setup_repo_merge() -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs
}

///|
test "merge: content-level merge non-overlapping changes" {
  let fs = setup_repo_merge()
  // Create base with multi-line file
  fs.write_string("/repo/file.txt", "line1\nline2\nline3\nline4\nline5\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(commit(fs, fs, "/repo", "base", "Test <t@example.com>", 1700000000L))
  // Feature branch: change line2
  switch_branch(fs, fs, "/repo", "feature", create=true, checkout_files=true)
  fs.write_string("/repo/file.txt", "line1\nchanged2\nline3\nline4\nline5\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  let feature_commit = commit(
    fs, fs, "/repo", "feature", "Test <t@example.com>", 1700000001L,
  )
  // Main branch: change line4
  switch_branch(fs, fs, "/repo", "main", checkout_files=true)
  fs.write_string("/repo/file.txt", "line1\nline2\nline3\nchanged4\nline5\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(commit(fs, fs, "/repo", "main", "Test <t@example.com>", 1700000002L))
  // Merge should succeed with content merge
  let result = merge(
    fs, fs, "/repo", feature_commit, "merge", "Test <t@example.com>", 1700000003L,
  )
  match result.status {
    Merged => ()
    _ => {
      println("Expected Merged, got conflicts: \{result.conflicts}")
      assert_true(false)
    }
  }
  let content = fs.read_string("/repo/file.txt")
  assert_eq(content, "line1\nchanged2\nline3\nchanged4\nline5\n")
}

///|
test "merge: content-level merge with conflict" {
  let fs = setup_repo_merge()
  fs.write_string("/repo/file.txt", "line1\nline2\nline3\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(commit(fs, fs, "/repo", "base", "Test <t@example.com>", 1700000000L))
  // Feature branch: change line2 to X
  switch_branch(fs, fs, "/repo", "feature", create=true, checkout_files=true)
  fs.write_string("/repo/file.txt", "line1\nfeature_change\nline3\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  let feature_commit = commit(
    fs, fs, "/repo", "feature", "Test <t@example.com>", 1700000001L,
  )
  // Main branch: change line2 to Y
  switch_branch(fs, fs, "/repo", "main", checkout_files=true)
  fs.write_string("/repo/file.txt", "line1\nmain_change\nline3\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  ignore(commit(fs, fs, "/repo", "main", "Test <t@example.com>", 1700000002L))
  // Merge should produce conflict
  let result = merge(
    fs, fs, "/repo", feature_commit, "merge", "Test <t@example.com>", 1700000003L,
  )
  match result.status {
    Conflicted => ()
    _ => {
      println("Expected Conflicted")
      assert_true(false)
    }
  }
  assert_true(result.conflicts.contains("file.txt"))
  // Conflict markers should be written to worktree
  let content = fs.read_string("/repo/file.txt")
  assert_true(content.contains("<<<<<<< HEAD"))
  assert_true(content.contains(">>>>>>> incoming"))
  let staged = read_index_stage_entries(fs, "/repo/.git")
  assert_eq(staged.length(), 3)
  assert_eq(staged[0].entry.path, "file.txt")
  assert_eq(staged[0].stage, 1)
  assert_eq(staged[1].stage, 2)
  assert_eq(staged[2].stage, 3)
  assert_true(
    fs.read_string("/repo/.git/MERGE_HEAD").contains(feature_commit.to_hex()),
  )
}

///|
test "merge: file-level merge without conflicts" {
  let fs = setup_repo_merge()
  fs.write_string("/repo/a.txt", "base\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(commit(fs, fs, "/repo", "base\n", "Test <t@example.com>", 1700000000L))
  switch_branch(fs, fs, "/repo", "feature", create=true, checkout_files=true)
  fs.write_string("/repo/b.txt", "feature\n")
  add_paths(fs, fs, "/repo", ["b.txt"])
  let feature_commit = commit(
    fs, fs, "/repo", "feature\n", "Test <t@example.com>", 1700000001L,
  )
  switch_branch(fs, fs, "/repo", "main", checkout_files=true)
  fs.write_string("/repo/a.txt", "main\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  let main_commit = commit(
    fs, fs, "/repo", "main\n", "Test <t@example.com>", 1700000002L,
  )
  let result = merge(
    fs, fs, "/repo", feature_commit, "merge\n", "Test <t@example.com>", 1700000003L,
  )
  match result.status {
    Merged => ()
    Conflicted => {
      println("CONFLICT: \{result.conflicts}")
      assert_true(false)
    }
    AlreadyUpToDate => {
      println("AlreadyUpToDate merge")
      assert_true(false)
    }
    FastForward => {
      println("FastForward merge")
      assert_true(false)
    }
  }
  let head = fs.read_string("/repo/.git/refs/heads/main")
  match result.commit_id {
    None => assert_true(false)
    Some(id) => assert_true(head.contains(id.to_hex()))
  }
  let content_a = fs.read_string("/repo/a.txt")
  let content_b = fs.read_string("/repo/b.txt")
  assert_true(content_a == "main\n")
  assert_true(content_b == "feature\n")
  let db = ObjectDb::load(fs, "/repo/.git")
  match result.commit_id {
    None => ()
    Some(id) => {
      let obj = db.get(fs, id)
      match obj {
        None => assert_true(false)
        Some(o) => {
          let info = @bit.parse_commit(o.data)
          assert_true(info.parents.length() == 2)
          assert_true(info.parents.contains(main_commit))
          assert_true(info.parents.contains(feature_commit))
        }
      }
    }
  }
}

///|
test "merge: unborn branch fast-forwards to target" {
  let fs = setup_repo_merge()
  fs.write_string("/repo/file.txt", "base\n")
  add_paths(fs, fs, "/repo", ["file.txt"])
  let target = commit(
    fs, fs, "/repo", "base", "Test <t@example.com>", 1700000000L,
  )
  fs.remove_file("/repo/.git/refs/heads/main") catch {
    _ => ()
  }
  fs.remove_file("/repo/.git/index") catch {
    _ => ()
  }
  fs.remove_file("/repo/file.txt") catch {
    _ => ()
  }
  let result = merge(
    fs, fs, "/repo", target, "merge", "Test <t@example.com>", 1700000001L,
  )
  match result.status {
    FastForward => ()
    _ => fail("expected fast-forward merge")
  }
  assert_eq(result.commit_id, Some(target))
  let head_ref = fs.read_string("/repo/.git/refs/heads/main")
  assert_true(head_ref.contains(target.to_hex()))
  assert_eq(fs.read_string("/repo/file.txt"), "base\n")
}

///|
test "merge: fast-forward preserves initialized submodule on removal" {
  let fs = setup_repo_merge()
  fs.write_string("/repo/a.txt", "one\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial", "Test <t@example.com>", 1700000100L),
  )

  init_repo_with_options(fs, "/repo/vendor/sub", {
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
  add_paths(fs, fs, "/repo/vendor/sub", ["a"])
  let submodule_commit = commit(
    fs, fs, "/repo/vendor/sub", "submodule", "Test <t@example.com>", 1700000101L,
  )
  fs.write_string(
    "/repo/.gitmodules", "[submodule \"example\"]\n\tpath = vendor/sub\n\turl = ../example\n",
  )
  add_paths(fs, fs, "/repo", [".gitmodules"])
  let entries = read_index_entries(fs, "/repo/.git")
  entries.push(IndexEntry::new("vendor/sub", submodule_commit, 0o160000, 0))
  write_index_entries(fs, "/repo/.git", entries)
  ignore(
    commit(
      fs, fs, "/repo", "with-submodule", "Test <t@example.com>", 1700000102L,
    ),
  )

  switch_branch(fs, fs, "/repo", "feature", create=true, checkout_files=false)
  let remove_entries = read_index_entries(fs, "/repo/.git")
  let remaining : Array[IndexEntry] = []
  for entry in remove_entries {
    if entry.path != ".gitmodules" && entry.path != "vendor/sub" {
      remaining.push(entry)
    }
  }
  write_index_entries(fs, "/repo/.git", remaining)
  let remove_commit = commit(
    fs, fs, "/repo", "remove-submodule", "Test <t@example.com>", 1700000103L,
  )

  switch_branch(fs, fs, "/repo", "main", checkout_files=false)
  let result = merge(
    fs, fs, "/repo", remove_commit, "merge", "Test <t@example.com>", 1700000104L,
  )

  match result.status {
    FastForward => ()
    _ => fail("expected fast-forward merge")
  }
  assert_true(fs.is_dir("/repo/vendor/sub"))
  assert_true(fs.is_file("/repo/vendor/sub/.git"))
  assert_eq(fs.read_string("/repo/vendor/sub/a"), "sub\n")
}
