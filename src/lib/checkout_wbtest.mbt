///|
test "checkout: restore_paths rejects traversal pathspecs" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "hello\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  assert_true(restore_paths_is_rejected(fs, "/repo", ["../a.txt"]))
  assert_false(fs.is_file("/a.txt"))
  assert_true(fs.is_file("/repo/a.txt"))
}

///|
test "checkout: restore_paths rejects index paths outside repository" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo")
  let (blob_id, blob) = @bit.create_blob_string("outside.txt")
  let entries : Array[IndexEntry] = [
    IndexEntry::new("../outside.txt", blob_id, 33188, blob.length()),
  ]
  write_object_bytes(fs, "/repo/.git", blob_id, blob)
  write_index_entries(fs, "/repo/.git", entries)
  assert_true(restore_paths_is_rejected(fs, "/repo", ["a.txt"]))
}

///|
fn restore_paths_is_rejected(
  fs : @bit.TestFs,
  root : String,
  paths : Array[String],
) -> Bool {
  restore_paths(fs, fs, root, paths) catch {
    _ => return true
  }
  false
}

///|
test "tree_ops: finds submodule name by path from gitmodules" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo")
  fs.write_string(
    "/repo/.gitmodules", "[submodule \"example\"]\n\tpath = vendor/sub\n\turl = ../example\n",
  )
  assert_eq(
    tree_ops_find_submodule_name_by_path(fs, "/repo", "vendor/sub"),
    "example",
  )
}

///|
test "tree_ops: restore_gitlink_worktree recreates submodule worktree" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo")
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
    fs, fs, "/repo/vendor/sub", "submodule\n", "Test <t@example.com>", 1700000400L,
  )
  fs.write_string(
    "/repo/.gitmodules", "[submodule \"example\"]\n\tpath = vendor/sub\n\turl = ../example\n",
  )
  remove_worktree_path_recursive(fs, fs, "/repo/vendor")

  restore_gitlink_worktree(
    fs, fs, "/repo", "/repo/.git", "vendor/sub", submodule_commit,
  )

  assert_true(fs.is_file("/repo/vendor/sub/.git"))
  assert_eq(fs.read_string("/repo/vendor/sub/a"), "sub\n")
}

///|
test "tree_ops: restore_gitlink_worktree replaces tracked file path" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo")
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
    fs, fs, "/repo/vendor/sub", "submodule\n", "Test <t@example.com>", 1700000450L,
  )
  fs.write_string(
    "/repo/.gitmodules", "[submodule \"example\"]\n\tpath = vendor/sub\n\turl = ../example\n",
  )
  fs.remove_file("/repo/vendor/sub/.git")
  remove_worktree_path_recursive(fs, fs, "/repo/vendor/sub")
  fs.mkdir_p("/repo/vendor")
  fs.write_string("/repo/vendor/sub", "plain file\n")

  restore_gitlink_worktree(
    fs, fs, "/repo", "/repo/.git", "vendor/sub", submodule_commit,
  )

  assert_true(fs.is_dir("/repo/vendor/sub"))
  assert_true(fs.is_file("/repo/vendor/sub/.git"))
  assert_eq(fs.read_string("/repo/vendor/sub/a"), "sub\n")
}

///|
test "tree_ops: write_worktree_and_build_index restores gitlink entries" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "one\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(
    commit(fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000500L),
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
    fs, fs, "/repo/vendor/sub", "submodule\n", "Test <t@example.com>", 1700000501L,
  )

  fs.write_string(
    "/repo/.gitmodules", "[submodule \"example\"]\n\tpath = vendor/sub\n\turl = ../example\n",
  )
  add_paths(fs, fs, "/repo", [".gitmodules"])
  let entries = read_index_entries(fs, "/repo/.git")
  entries.push(IndexEntry::new("vendor/sub", submodule_commit, 0o160000, 0))
  write_index_entries(fs, "/repo/.git", entries)
  let commit_id = commit(
    fs, fs, "/repo", "with-submodule\n", "Test <t@example.com>", 1700000502L,
  )
  remove_worktree_path_recursive(fs, fs, "/repo/vendor")
  fs.remove_file("/repo/.gitmodules")
  let db = ObjectDb::load_lazy(fs, "/repo/.git")
  let files = collect_tree_files_from_commit(db, fs, commit_id)

  ignore(
    write_worktree_and_build_index(
      db,
      fs,
      fs,
      "/repo",
      "/repo/.git",
      files,
      remove_missing=true,
    ),
  )

  assert_true(fs.is_file("/repo/vendor/sub/.git"))
  assert_eq(fs.read_string("/repo/vendor/sub/a"), "sub\n")
}

///|
test "tree_ops: write_worktree_from_files preserves initialized submodule on removal" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo")
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
    fs, fs, "/repo/vendor/sub", "submodule\n", "Test <t@example.com>", 1700000550L,
  )
  let entries = read_index_entries(fs, "/repo/.git")
  entries.push(IndexEntry::new("vendor/sub", submodule_commit, 0o160000, 0))
  write_index_entries(fs, "/repo/.git", entries)

  let db = ObjectDb::load_lazy(fs, "/repo/.git")
  let files : Map[String, TreeFileEntry] = {}
  write_worktree_from_files(
    db,
    fs,
    fs,
    "/repo",
    "/repo/.git",
    files,
    remove_missing=true,
    preserve_removed_gitlinks=true,
  )

  assert_true(fs.is_dir("/repo/vendor/sub"))
  assert_true(fs.is_file("/repo/vendor/sub/.git"))
  assert_eq(fs.read_string("/repo/vendor/sub/a"), "sub\n")
}
