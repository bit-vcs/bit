///| Tests for worktree administration

///|
fn setup_worktree_admin_fs() -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.mkdir_p("/repo/.git/refs/heads")
  fs.mkdir_p("/repo/.git/objects")
  fs.mkdir_p("/repo/.git/objects/pack")
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/repo/.git/refs/heads/main", "1111111111111111111111111111111111111111\n",
  )
  fs
}

///|
fn setup_worktree_repo_fs() -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs.write_string("/repo/init.t", "main\n")
  ignore(try? add_paths(fs, fs, "/repo", ["init.t"]))
  ignore(
    try? commit(fs, fs, "/repo", "main\n", "Test <t@example.com>", 1700000700L),
  )
  fs
}

///|
fn remove_test_dir(fs : @bit.TestFs, path : String) -> Unit {
  if fs.is_dir(path) {
    for entry in (fs.readdir(path) catch { _ => [] }) {
      if entry == "." || entry == ".." {
        continue
      }
      let child = if path.has_suffix("/") {
        path + entry
      } else {
        path + "/" + entry
      }
      remove_test_dir(fs, child)
    }
    fs.remove_dir(path) catch {
      _ => ()
    }
  } else if fs.is_file(path) {
    fs.remove_file(path) catch {
      _ => ()
    }
  }
}

///|
test "worktree admin: list main worktree only" {
  let fs = setup_worktree_admin_fs()
  let worktrees = list_worktrees(fs, "/repo")
  assert_eq(worktrees.length(), 1)
  assert_eq(worktrees[0].path, "/repo")
  assert_eq(worktrees[0].branch, Some("main"))
  assert_true(worktrees[0].is_main)
  assert_false(worktrees[0].is_bare)
  assert_false(worktrees[0].locked)
}

///|
test "worktree admin: list with linked worktree" {
  let fs = setup_worktree_admin_fs()
  // Create a linked worktree admin dir
  fs.mkdir_p("/repo/.git/worktrees/wt1")
  fs.write_string("/repo/.git/worktrees/wt1/gitdir", "/worktree1/.git\n")
  fs.write_string("/repo/.git/worktrees/wt1/HEAD", "ref: refs/heads/feature\n")
  fs.write_string("/repo/.git/worktrees/wt1/commondir", "../..\n")
  fs.write_string(
    "/repo/.git/refs/heads/feature", "2222222222222222222222222222222222222222\n",
  )
  let worktrees = list_worktrees(fs, "/repo")
  assert_eq(worktrees.length(), 2)
  // Main worktree
  assert_eq(worktrees[0].path, "/repo")
  assert_eq(worktrees[0].branch, Some("main"))
  // Linked worktree
  assert_eq(worktrees[1].path, "/worktree1")
  assert_eq(worktrees[1].branch, Some("feature"))
  assert_false(worktrees[1].is_main)
  assert_false(worktrees[1].is_bare)
}

///|
test "worktree admin: list detached head worktree" {
  let fs = setup_worktree_admin_fs()
  fs.mkdir_p("/repo/.git/worktrees/wt-detached")
  fs.write_string(
    "/repo/.git/worktrees/wt-detached/gitdir", "/detached-wt/.git\n",
  )
  fs.write_string(
    "/repo/.git/worktrees/wt-detached/HEAD", "3333333333333333333333333333333333333333\n",
  )
  fs.write_string("/repo/.git/worktrees/wt-detached/commondir", "../..\n")
  let worktrees = list_worktrees(fs, "/repo")
  assert_eq(worktrees.length(), 2)
  assert_eq(worktrees[1].path, "/detached-wt")
  assert_eq(worktrees[1].branch, None)
}

///|
test "worktree admin: list locked worktree" {
  let fs = setup_worktree_admin_fs()
  fs.mkdir_p("/repo/.git/worktrees/locked-wt")
  fs.write_string(
    "/repo/.git/worktrees/locked-wt/gitdir", "/locked-path/.git\n",
  )
  fs.write_string(
    "/repo/.git/worktrees/locked-wt/HEAD", "4444444444444444444444444444444444444444\n",
  )
  fs.write_string("/repo/.git/worktrees/locked-wt/commondir", "../..\n")
  fs.write_string("/repo/.git/worktrees/locked-wt/locked", "")
  let worktrees = list_worktrees(fs, "/repo")
  assert_eq(worktrees.length(), 2)
  assert_true(worktrees[1].locked)
}

///|
test "worktree admin: is_branch_checked_out main" {
  let fs = setup_worktree_admin_fs()
  let result = is_branch_checked_out(fs, "/repo", "main")
  assert_eq(result, Some("/repo"))
}

///|
test "worktree admin: is_branch_checked_out untracked" {
  let fs = setup_worktree_admin_fs()
  let result = is_branch_checked_out(fs, "/repo", "nonexistent")
  assert_eq(result, None)
}

///|
test "worktree admin: is_branch_checked_out in linked worktree" {
  let fs = setup_worktree_admin_fs()
  fs.mkdir_p("/repo/.git/worktrees/wt1")
  fs.write_string("/repo/.git/worktrees/wt1/gitdir", "/worktree1/.git\n")
  fs.write_string("/repo/.git/worktrees/wt1/HEAD", "ref: refs/heads/feature\n")
  fs.write_string("/repo/.git/worktrees/wt1/commondir", "../..\n")
  fs.write_string(
    "/repo/.git/refs/heads/feature", "2222222222222222222222222222222222222222\n",
  )
  let result = is_branch_checked_out(fs, "/repo", "feature")
  assert_eq(result, Some("/worktree1"))
}

///|
test "worktree admin: prune missing worktree" {
  let fs = setup_worktree_admin_fs()
  // Create admin dir for a worktree that doesn't exist
  fs.mkdir_p("/repo/.git/worktrees/missing")
  fs.write_string("/repo/.git/worktrees/missing/gitdir", "/nonexistent/.git\n")
  fs.write_string(
    "/repo/.git/worktrees/missing/HEAD", "5555555555555555555555555555555555555555\n",
  )
  fs.write_string("/repo/.git/worktrees/missing/commondir", "../..\n")
  // Prune should remove it
  let pruned = prune_worktrees(fs, fs, "/repo")
  assert_eq(pruned.length(), 1)
  assert_eq(pruned[0], "missing")
  // Admin dir should be removed
  assert_false(fs.is_dir("/repo/.git/worktrees/missing"))
}

///|
test "worktree admin: prune invalid file entry reports reason" {
  let fs = setup_worktree_admin_fs()
  fs.mkdir_p("/repo/.git/worktrees")
  fs.write_string("/repo/.git/worktrees/abc", "")

  let pruned = prune_worktrees_detailed(fs, fs, "/repo")
  assert_eq(pruned.length(), 1)
  assert_eq(pruned[0].name, "abc")
  assert_eq(pruned[0].reason, "not a valid directory")
  assert_false(fs.is_file("/repo/.git/worktrees/abc"))
}

///|
test "worktree admin: prune duplicate linked worktree keeps lexical first entry" {
  let fs = setup_worktree_admin_fs()
  fs.mkdir_p("/repo/.git/worktrees/w1")
  fs.mkdir_p("/repo/.git/worktrees/w2")
  fs.write_string("/repo/.git/worktrees/w1/gitdir", "/repo/w1/.git\n")
  fs.write_string("/repo/.git/worktrees/w2/gitdir", "/repo/w1/.git\n")
  fs.write_string("/repo/w1/.git", "gitdir: /repo/.git/worktrees/w1\n")

  let pruned = prune_worktrees_detailed(fs, fs, "/repo", dry_run=true)
  assert_eq(pruned.length(), 1)
  assert_eq(pruned[0].name, "w2")
  assert_eq(pruned[0].reason, "duplicate entry")
}

///|
test "worktree admin: prune linked entry duplicated by main git dir" {
  let fs = setup_worktree_admin_fs()
  fs.mkdir_p("/repo/.git/worktrees/wt")
  fs.write_string("/repo/.git/worktrees/wt/gitdir", "/repo/.git\n")

  let pruned = prune_worktrees_detailed(fs, fs, "/repo", dry_run=true)
  assert_eq(pruned.length(), 1)
  assert_eq(pruned[0].name, "wt")
  assert_eq(pruned[0].reason, "duplicate entry")
}

///|
test "worktree admin: prune dry run" {
  let fs = setup_worktree_admin_fs()
  fs.mkdir_p("/repo/.git/worktrees/missing")
  fs.write_string("/repo/.git/worktrees/missing/gitdir", "/nonexistent/.git\n")
  fs.write_string(
    "/repo/.git/worktrees/missing/HEAD", "5555555555555555555555555555555555555555\n",
  )
  fs.write_string("/repo/.git/worktrees/missing/commondir", "../..\n")
  // Dry run should not remove
  let pruned = prune_worktrees(fs, fs, "/repo", dry_run=true)
  assert_eq(pruned.length(), 1)
  // Admin dir should still exist
  assert_true(fs.is_dir("/repo/.git/worktrees/missing"))
}

///|
test "worktree admin: prune locked worktree not pruned" {
  let fs = setup_worktree_admin_fs()
  fs.mkdir_p("/repo/.git/worktrees/locked-missing")
  fs.write_string(
    "/repo/.git/worktrees/locked-missing/gitdir", "/nonexistent-locked/.git\n",
  )
  fs.write_string(
    "/repo/.git/worktrees/locked-missing/HEAD", "6666666666666666666666666666666666666666\n",
  )
  fs.write_string("/repo/.git/worktrees/locked-missing/commondir", "../..\n")
  fs.write_string("/repo/.git/worktrees/locked-missing/locked", "")
  // Locked worktrees should not be pruned even if missing
  let pruned = prune_worktrees(fs, fs, "/repo")
  assert_eq(pruned.length(), 0)
  assert_true(fs.is_dir("/repo/.git/worktrees/locked-missing"))
}

///|
test "worktree admin: bare repo includes pseudo main worktree" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/bare/objects")
  fs.mkdir_p("/bare/refs/heads")
  fs.write_string("/bare/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/bare/refs/heads/main", "1111111111111111111111111111111111111111\n",
  )
  fs.mkdir_p("/bare/worktrees/wt")
  fs.write_string("/bare/worktrees/wt/gitdir", "/bare/wt/.git\n")
  fs.write_string("/bare/worktrees/wt/HEAD", "ref: refs/heads/wt\n")
  fs.write_string("/bare/worktrees/wt/commondir", "../..\n")
  fs.write_string(
    "/bare/refs/heads/wt", "2222222222222222222222222222222222222222\n",
  )
  let worktrees = list_worktrees(fs, "/bare")
  assert_eq(worktrees.length(), 2)
  assert_eq(worktrees[0].path, "/bare")
  assert_true(worktrees[0].is_main)
  assert_true(worktrees[0].is_bare)
  assert_eq(worktrees[1].path, "/bare/wt")
  assert_eq(worktrees[1].branch, Some("wt"))
}

///|
test "worktree admin: list from .git directory reports main worktree" {
  let fs = setup_worktree_admin_fs()
  let worktrees = list_worktrees(fs, "/repo/.git")
  assert_eq(worktrees.length(), 1)
  assert_eq(worktrees[0].path, "/repo")
  assert_false(worktrees[0].is_bare)
}

///|
test "worktree admin: linked worktree with bare main shows bare root first" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/bare/objects")
  fs.mkdir_p("/bare/refs/heads")
  fs.mkdir_p("/there")
  fs.write_string("/bare/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    "/bare/refs/heads/main", "1111111111111111111111111111111111111111\n",
  )
  fs.mkdir_p("/bare/worktrees/wt")
  fs.write_string("/there/.git", "gitdir: /bare/worktrees/wt\n")
  fs.write_string("/bare/worktrees/wt/gitdir", "/there/.git\n")
  fs.write_string("/bare/worktrees/wt/HEAD", "ref: refs/heads/wt\n")
  fs.write_string("/bare/worktrees/wt/commondir", "../..\n")
  fs.write_string(
    "/bare/refs/heads/wt", "2222222222222222222222222222222222222222\n",
  )

  let worktrees = list_worktrees(fs, "/there")
  assert_eq(worktrees.length(), 2)
  assert_eq(worktrees[0].path, "/bare")
  assert_true(worktrees[0].is_bare)
  assert_eq(worktrees[1].path, "/there")
}

///|
test "worktree admin: linked worktrees are sorted lexically by path" {
  let fs = setup_worktree_admin_fs()
  fs.mkdir_p("/repo/.git/worktrees/locked_lf")
  fs.write_string(
    "/repo/.git/worktrees/locked_lf/gitdir", "/repo/locked_lf/.git\n",
  )
  fs.write_string(
    "/repo/.git/worktrees/locked_lf/HEAD", "ref: refs/heads/locked_lf\n",
  )
  fs.write_string("/repo/.git/worktrees/locked_lf/commondir", "../..\n")
  fs.write_string(
    "/repo/.git/refs/heads/locked_lf", "2222222222222222222222222222222222222222\n",
  )
  fs.mkdir_p("/repo/.git/worktrees/locked_crlf")
  fs.write_string(
    "/repo/.git/worktrees/locked_crlf/gitdir", "/repo/locked_crlf/.git\n",
  )
  fs.write_string(
    "/repo/.git/worktrees/locked_crlf/HEAD", "ref: refs/heads/locked_crlf\n",
  )
  fs.write_string("/repo/.git/worktrees/locked_crlf/commondir", "../..\n")
  fs.write_string(
    "/repo/.git/refs/heads/locked_crlf", "3333333333333333333333333333333333333333\n",
  )

  let worktrees = list_worktrees(fs, "/repo")
  assert_eq(worktrees[1].path, "/repo/locked_crlf")
  assert_eq(worktrees[2].path, "/repo/locked_lf")
}

///|
test "worktree admin: create_worktree resolves dash to previous checkout branch" {
  let fs = @bit.TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs.write_string("/repo/init.t", "main\n")
  add_paths(fs, fs, "/repo", ["init.t"])
  ignore(commit(fs, fs, "/repo", "main\n", "Test <t@example.com>", 1700000400L))

  switch_branch(fs, fs, "/repo", "newbranch", create=true, checkout_files=true)
  fs.write_string("/repo/init.t", "newbranch\n")
  add_paths(fs, fs, "/repo", ["init.t"])
  ignore(
    commit(fs, fs, "/repo", "newbranch\n", "Test <t@example.com>", 1700000401L),
  )
  ignore(checkout(fs, fs, "/repo", "main"))
  fs.write_string("/repo/.git/bit-prev-checkout", "newbranch\n")

  create_worktree(fs, fs, "/repo", "short-hand", Some("-"), new_branch=None)

  assert_eq(
    fs.read_string("/repo/.git/worktrees/short-hand/HEAD"),
    "ref: refs/heads/newbranch\n",
  )
  assert_eq(fs.read_string("/repo/short-hand/init.t"), "newbranch\n")
}

///|
test "worktree admin: create_worktree with new branch writes branch and HEAD reflogs" {
  let fs = setup_worktree_repo_fs()

  create_worktree(fs, fs, "/repo", "wt", Some("main"), new_branch=Some("wt"))

  let branch_entries = read_reflog(fs, "/repo/.git", "refs/heads/wt")
  assert_eq(branch_entries.length(), 1)
  assert_eq(branch_entries[0].message, "branch: Created from main")

  let head_entries = read_reflog(fs, "/repo/.git/worktrees/wt", "HEAD")
  assert_eq(head_entries.length(), 1)
}

///|
test "worktree admin: create_worktree resolves HEAD to detached commit" {
  let fs = @bit.TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs.write_string("/repo/init.t", "main\n")
  add_paths(fs, fs, "/repo", ["init.t"])
  ignore(commit(fs, fs, "/repo", "main\n", "Test <t@example.com>", 1700000450L))

  create_worktree(
    fs,
    fs,
    "/repo",
    "head-detached",
    Some("HEAD"),
    new_branch=None,
  )

  let linked_head = fs.read_string("/repo/.git/worktrees/head-detached/HEAD")
  assert_true(not(linked_head.has_prefix("ref: ")))
  assert_eq(fs.read_string("/repo/head-detached/init.t"), "main\n")
}

///|
test "worktree admin: create_worktree rejects nonempty existing directory" {
  let fs = @bit.TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs.write_string("/repo/init.t", "main\n")
  add_paths(fs, fs, "/repo", ["init.t"])
  ignore(commit(fs, fs, "/repo", "main\n", "Test <t@example.com>", 1700000500L))
  fs.mkdir_p("/repo/existing/subtree")

  let err = try {
    create_worktree(fs, fs, "/repo", "existing", Some("main"), new_branch=None)
    None
  } catch {
    err => Some(err.to_string())
  }

  assert_true(err is Some(_))
  assert_true(err.unwrap_or("").contains("already exists"))
}

///|
test "worktree admin: create_worktree disambiguates duplicate basename" {
  let fs = @bit.TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs.write_string("/repo/init.t", "main\n")
  add_paths(fs, fs, "/repo", ["init.t"])
  ignore(commit(fs, fs, "/repo", "main\n", "Test <t@example.com>", 1700000600L))
  fs.mkdir_p("/repo/sub")

  create_worktree(
    fs,
    fs,
    "/repo",
    "/repo/here",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  create_worktree(
    fs,
    fs,
    "/repo",
    "/repo/sub/here",
    Some("main"),
    detach=true,
    new_branch=None,
  )

  assert_true(fs.is_dir("/repo/.git/worktrees/here"))
  assert_true(fs.is_dir("/repo/.git/worktrees/here1"))
  assert_eq(
    fs.read_string("/repo/.git/worktrees/here1/gitdir"),
    "/repo/sub/here/.git\n",
  )
}

///|
test "worktree admin: move_worktree nests destination under existing directory" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "source",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  fs.mkdir_p("/repo/some-dir")

  move_worktree(fs, fs, "/repo", "source", "some-dir")

  assert_false(fs.is_dir("/repo/source"))
  assert_true(fs.is_dir("/repo/some-dir/source"))
  assert_eq(
    fs.read_string("/repo/.git/worktrees/source/gitdir"),
    "/repo/some-dir/source/.git\n",
  )
  assert_eq(
    fs.read_string("/repo/some-dir/source/.git"),
    "gitdir: /repo/.git/worktrees/source\n",
  )
}

///|
test "worktree admin: move_worktree requires force for missing destination admin" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "gnoo",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  create_worktree(
    fs,
    fs,
    "/repo",
    "pneu",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  remove_test_dir(fs, "/repo/pneu")

  let err = try {
    move_worktree(fs, fs, "/repo", "gnoo", "pneu")
    None
  } catch {
    err => Some(err.to_string())
  }
  assert_true(err.unwrap_or("").contains("already exists"))

  move_worktree(fs, fs, "/repo", "gnoo", "pneu", force_level=1)
  assert_true(fs.is_dir("/repo/pneu"))

  create_worktree(
    fs,
    fs,
    "/repo",
    "nu",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  lock_worktree(fs, fs, "/repo", "nu", reason=None)
  remove_test_dir(fs, "/repo/nu")

  let locked_err = try {
    move_worktree(fs, fs, "/repo", "pneu", "nu", force_level=1)
    None
  } catch {
    err => Some(err.to_string())
  }
  assert_true(locked_err.unwrap_or("").contains("locked"))

  move_worktree(fs, fs, "/repo", "pneu", "nu", force_level=2)
  assert_true(fs.is_dir("/repo/nu"))
}

///|
test "worktree admin: move_worktree refuses initialized submodule" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "third",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  fs.mkdir_p("/repo/third/sub")
  fs.write_string("/repo/third/sub/.git", "gitdir: /repo/.git/modules/sub\n")

  let err = try {
    move_worktree(fs, fs, "/repo", "third", "forth")
    None
  } catch {
    err => Some(err.to_string())
  }

  assert_true(err.unwrap_or("").contains("submodule"))
  assert_true(fs.is_dir("/repo/third"))
  assert_false(fs.is_dir("/repo/forth"))
}

///|
test "worktree admin: remove_worktree rejects dirty and untracked unless forced" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "destination",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  fs.write_string("/repo/destination/init.t", "main\ndirty\n")

  let dirty_err = try {
    remove_worktree(fs, fs, "/repo", "destination")
    None
  } catch {
    err => Some(err.to_string())
  }
  assert_true(dirty_err.unwrap_or("").contains("modified or untracked"))
  assert_true(fs.is_dir("/repo/destination"))

  fs.write_string("/repo/destination/init.t", "main\n")
  fs.write_string("/repo/destination/untracked", "")

  let untracked_err = try {
    remove_worktree(fs, fs, "/repo", "destination")
    None
  } catch {
    err => Some(err.to_string())
  }
  assert_true(untracked_err.unwrap_or("").contains("modified or untracked"))

  remove_worktree(fs, fs, "/repo", "destination", force=true)
  assert_false(fs.is_dir("/repo/destination"))
}

///|
test "worktree admin: remove_worktree requires double force for locked worktree" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "gumby",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  lock_worktree(fs, fs, "/repo", "gumby", reason=None)

  let err = try {
    remove_worktree(fs, fs, "/repo", "gumby", force=true)
    None
  } catch {
    err => Some(err.to_string())
  }

  assert_true(err.unwrap_or("").contains("locked"))

  remove_worktree(fs, fs, "/repo", "gumby", force_level=2)
  assert_false(fs.is_dir("/repo/gumby"))
  assert_false(fs.is_dir("/repo/.git/worktrees"))
}

///|
test "worktree admin: missing worktree errors say not a working tree" {
  let fs = setup_worktree_repo_fs()
  let err = try {
    lock_worktree(fs, fs, "/repo", "noodle", reason=None)
    None
  } catch {
    err => Some(err.to_string())
  }
  assert_true(err.unwrap_or("").contains("not a working tree"))
}

///|
test "worktree admin: relative gitdir entries resolve linked worktree paths" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "source",
    Some("main"),
    detach=true,
    new_branch=None,
  )

  move_worktree(
    fs,
    fs,
    "/repo",
    "source",
    "relative",
    relative_paths=Some(true),
  )

  let worktrees = list_worktrees(fs, "/repo")
  assert_eq(worktrees.length(), 2)
  assert_eq(worktrees[1].path, "/repo/relative")
  remove_worktree(fs, fs, "/repo", "relative")
  assert_false(fs.is_dir("/repo/relative"))
  assert_false(fs.is_dir("/repo/.git/worktrees/source"))
}

///|
test "worktree admin: create_worktree honors worktree.useRelativePaths" {
  let fs = setup_worktree_repo_fs()
  fs.write_string(
    "/repo/.git/config",
    fs.read_string("/repo/.git/config") +
    "[worktree]\n\tuseRelativePaths = true\n",
  )

  create_worktree(
    fs,
    fs,
    "/repo",
    "relative",
    Some("main"),
    detach=true,
    new_branch=None,
  )

  assert_eq(
    fs.read_string("/repo/relative/.git"),
    "gitdir: ../.git/worktrees/relative\n",
  )
  assert_eq(
    fs.read_string("/repo/.git/worktrees/relative/gitdir"),
    "../../../relative/.git\n",
  )
  let config = fs.read_string("/repo/.git/config")
  assert_true(config.contains("repositoryformatversion = 1"))
  assert_true(config.contains("relativeworktrees = true"))
}

///|
test "worktree admin: create_worktree sanitizes funny basename" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    ".  weird*..?.lock.lock",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  assert_true(fs.is_dir("/repo/.git/worktrees/---weird-.-"))
}

///|
test "worktree admin: create_worktree rejects existing orphan branch" {
  let fs = setup_worktree_repo_fs()
  fs.write_string(
    "/repo/.git/refs/heads/existingbranch", "0123456789abcdef0123456789abcdef01234567\n",
  )
  let err = try {
    create_worktree(
      fs,
      fs,
      "/repo",
      "orphandir",
      None,
      new_branch=Some("existingbranch"),
      orphan=true,
    )
    None
  } catch {
    err => Some(err.to_string())
  }
  assert_true(err.unwrap_or("").contains("already exists"))
}

///|
test "worktree admin: remove_worktree ignores empty uninitialized submodule directory" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "destination",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  let admin_dir = "/repo/.git/worktrees/destination"
  let entries = read_index_entries(fs, admin_dir)
  entries.push(IndexEntry::new("sub", entries[0].id, 0o160000, 0))
  write_index_entries(fs, admin_dir, entries)
  fs.mkdir_p("/repo/destination/sub")

  remove_worktree(fs, fs, "/repo", "destination")

  assert_false(fs.is_dir("/repo/destination"))
  assert_false(fs.is_dir(admin_dir))
}

///|
test "worktree admin: repair rejects explicit path that is not a directory" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "notdir",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  remove_test_dir(fs, "/repo/notdir")
  fs.write_string("/repo/notdir", "file\n")

  let err = try {
    ignore(repair_worktree_detailed(fs, fs, "/repo", worktree_paths=["notdir"]))
    None
  } catch {
    err => Some(err.to_string())
  }

  assert_true(err.unwrap_or("").contains("not a directory"))
}

///|
test "worktree admin: repair rejects invalid explicit path without linked worktrees" {
  let fs = setup_worktree_repo_fs()

  let err = try {
    ignore(
      repair_worktree_detailed(fs, fs, "/repo", worktree_paths=["/notvalid"]),
    )
    None
  } catch {
    err => Some(err.to_string())
  }

  assert_true(err.unwrap_or("").contains("not a valid path"))
}

///|
test "worktree admin: repair rejects explicit path whose .git is a directory" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "repo",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  remove_test_dir(fs, "/repo/repo")
  ignore(try? init_repo(fs, "/repo/repo"))

  let err = try {
    ignore(repair_worktree_detailed(fs, fs, "/repo", worktree_paths=["repo"]))
    None
  } catch {
    err => Some(err.to_string())
  }

  assert_true(err.unwrap_or("").contains(".git is not a file"))
}

///|
test "worktree admin: repair rejects implicit path that is not a directory" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "notdir",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  remove_test_dir(fs, "/repo/notdir")
  fs.write_string("/repo/notdir", "file\n")

  let err = try {
    ignore(repair_worktree_detailed(fs, fs, "/repo"))
    None
  } catch {
    err => Some(err.to_string())
  }

  assert_true(err.unwrap_or("").contains("not a directory"))
}

///|
test "worktree admin: repair recreates missing gitfile with warning" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "corrupt",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  fs.remove_file("/repo/corrupt/.git")

  let result = repair_worktree_detailed(fs, fs, "/repo")

  assert_true(result.warnings.contains(".git file broken: /repo/corrupt"))
  assert_true(result.repaired.contains(".git: /repo/corrupt"))
  assert_eq(
    fs.read_string("/repo/corrupt/.git"),
    "gitdir: /repo/.git/worktrees/corrupt\n",
  )
}

///|
test "worktree admin: repair explicit moved path updates stale gitdir" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "orig",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  fs.mkdir_p("/repo/moved")
  fs.write_string("/repo/moved/.git", fs.read_string("/repo/orig/.git"))
  remove_test_dir(fs, "/repo/orig")

  let result = repair_worktree_detailed(fs, fs, "/repo", worktree_paths=[
    "moved",
  ])

  assert_true(
    result.warnings.contains(
      "gitdir incorrect: /repo/.git/worktrees/orig/gitdir",
    ),
  )
  assert_eq(
    fs.read_string("/repo/.git/worktrees/orig/gitdir"),
    "/repo/moved/.git\n",
  )
  assert_eq(
    fs.read_string("/repo/moved/.git"),
    "gitdir: /repo/.git/worktrees/orig\n",
  )
}

///|
test "worktree admin: repair respects configured relative paths for missing gitfile" {
  let fs = setup_worktree_repo_fs()
  fs.write_string(
    "/repo/.git/config",
    fs.read_string("/repo/.git/config") +
    "[worktree]\n\tuseRelativePaths = true\n",
  )
  create_worktree(
    fs,
    fs,
    "/repo",
    "wt",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  fs.remove_file("/repo/wt/.git")

  let result = repair_worktree_detailed(fs, fs, "/repo")

  assert_true(result.warnings.contains(".git file broken: /repo/wt"))
  assert_eq(fs.read_string("/repo/wt/.git"), "gitdir: ../.git/worktrees/wt\n")
}

///|
test "worktree admin: repair defaults relative repository to absolute paths" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "side",
    Some("main"),
    detach=true,
    new_branch=None,
    relative_paths=Some(true),
  )
  fs.mkdir_p("/repo/sidemoved")
  fs.write_string("/repo/sidemoved/.git", fs.read_string("/repo/side/.git"))
  remove_test_dir(fs, "/repo/side")

  let result = repair_worktree_detailed(fs, fs, "/repo", worktree_paths=[
    "sidemoved",
  ])

  assert_true(
    result.warnings.contains(
      "gitdir incorrect: /repo/.git/worktrees/side/gitdir",
    ),
  )
  assert_eq(
    fs.read_string("/repo/.git/worktrees/side/gitdir"),
    "/repo/sidemoved/.git\n",
  )
  assert_eq(
    fs.read_string("/repo/sidemoved/.git"),
    "gitdir: /repo/.git/worktrees/side\n",
  )
}

///|
test "worktree admin: repair rejects explicit path whose gitfile points to non repository" {
  let fs = setup_worktree_repo_fs()
  create_worktree(
    fs,
    fs,
    "/repo",
    "side",
    Some("main"),
    detach=true,
    new_branch=None,
  )
  fs.mkdir_p("/repo/not-a-repo")
  fs.write_string("/repo/side/.git", "gitdir: /repo/not-a-repo\n")

  let err = try {
    ignore(repair_worktree_detailed(fs, fs, "/repo", worktree_paths=["side"]))
    None
  } catch {
    err => Some(err.to_string())
  }

  assert_true(err.unwrap_or("").contains("does not reference a repository"))
}
