///|
async fn commit_wbtest_run_git(
  cwd : String,
  args : Array[String],
) -> Unit raise Error {
  let code = @process.run("git", args[:], inherit_env=true, cwd~)
  assert_eq(code, 0)
}

///|
fn commit_wbtest_find_entry(
  entries : Array[@bitlib.IndexEntry],
  path : String,
) -> @bitlib.IndexEntry {
  for entry in entries {
    if entry.path == path {
      return entry
    }
  }
  panic()
}

///|
test "commit: signing options require standalone error" {
  assert_true(commit_args_require_standalone_error(["-S", "-m", "msg"]))
  assert_true(
    commit_args_require_standalone_error(["-S/path/to/key", "-m", "msg"]),
  )
  assert_true(commit_args_require_standalone_error(["--gpg-sign", "-m", "msg"]))
  assert_true(
    commit_args_require_standalone_error(["--gpg-sign=KEY", "-m", "msg"]),
  )
}

///|
test "commit: sha256 repository requires real git fallback" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string(
    "/repo/.git/config", "[extensions]\n\tobjectformat = sha256\n",
  )
  assert_true(commit_repo_requires_real_git(fs, "/repo/.git"))

  fs.write_string(
    "/repo/.git/config", "[core]\n\trepositoryformatversion = 0\n",
  )
  assert_false(commit_repo_requires_real_git(fs, "/repo/.git"))
}

///|
test "commit: compatobjectformat=sha256 does not require real git fallback" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git")
  // compat format is informational; primary sha1 is fine
  fs.write_string(
    "/repo/.git/config", "[extensions]\n\tcompatobjectformat = sha256\n",
  )
  assert_false(commit_repo_requires_real_git(fs, "/repo/.git"))

  fs.write_string(
    "/repo/.git/config", "[extensions]\n\tcompatobjectformat = sha1\n",
  )
  assert_false(commit_repo_requires_real_git(fs, "/repo/.git"))
}

///|
test "commit: no-edit prefers SQUASH_MSG and appends MERGE_MSG comments" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string("/repo/.git/SQUASH_MSG", "squash body\n")
  fs.write_string("/repo/.git/MERGE_MSG", "\n# Conflicts:\n#\tfile\n")
  let msg = resolve_no_edit_commit_message(fs, "/repo", "/repo/.git", false)
  assert_eq(msg, Some("squash body\n\n# Conflicts:\n#\tfile\n"))
}

///|
test "commit: no-edit prefers MERGE_MSG when MERGE_HEAD exists" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string(
    "/repo/.git/MERGE_HEAD", "1111111111111111111111111111111111111111\n",
  )
  fs.write_string("/repo/.git/SQUASH_MSG", "squash body\n")
  fs.write_string("/repo/.git/MERGE_MSG", "merge body\n")
  let msg = resolve_no_edit_commit_message(fs, "/repo", "/repo/.git", false)
  assert_eq(msg, Some("merge body\n"))
}

///|
test "commit: read MERGE_HEAD supports multiple parents" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string(
    "/repo/.git/MERGE_HEAD", "1111111111111111111111111111111111111111\n2222222222222222222222222222222222222222\n",
  )
  let merge_heads = read_merge_head_ids(fs, "/repo/.git")
  assert_eq(merge_heads.length(), 2)
  assert_eq(merge_heads[0].to_hex(), "1111111111111111111111111111111111111111")
  assert_eq(merge_heads[1].to_hex(), "2222222222222222222222222222222222222222")
}

///|
test "commit: storage runtime routing handles normal and -a mode" {
  assert_true(commit_should_use_storage_runtime(["-m", "msg"]))
  assert_true(commit_should_use_storage_runtime(["--no-verify", "-m", "msg"]))
  assert_true(commit_should_use_storage_runtime(["-am", "msg"]))

  assert_false(commit_should_use_storage_runtime(["--amend", "-m", "msg"]))
  assert_false(commit_should_use_storage_runtime(["-F", "MSG_FILE"]))
}

///|
async test "commit: pathspec staging updates submodule gitlink entry" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-commit-submodule-pathspec-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let sub_dir = root + "/sub"
  let super_dir = root + "/super"

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "sub"])
  commit_wbtest_run_git(sub_dir, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(sub_dir, ["config", "user.email", "test@example.com"])
  fs.write_string(sub_dir + "/a", "a\n")
  commit_wbtest_run_git(sub_dir, ["add", "a"])
  commit_wbtest_run_git(sub_dir, ["commit", "-q", "-m", "initial"])

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "super"])
  commit_wbtest_run_git(super_dir, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(super_dir, ["config", "user.email", "test@example.com"])

  let prev_allow_protocol = @sys.get_env_var("GIT_ALLOW_PROTOCOL")
  @sys.set_env_var("GIT_ALLOW_PROTOCOL", "file")
  commit_wbtest_run_git(super_dir, ["submodule", "add", "./../sub", "submodule"])
  commit_wbtest_run_git(super_dir, ["commit", "-qam", "initial"])
  match prev_allow_protocol {
    Some(value) => @sys.set_env_var("GIT_ALLOW_PROTOCOL", value)
    None => @sys.unset_env_var("GIT_ALLOW_PROTOCOL")
  }

  fs.write_string(super_dir + "/submodule/b", "b\n")
  commit_wbtest_run_git(super_dir + "/submodule", ["add", "b"])
  commit_wbtest_run_git(super_dir + "/submodule", [
    "commit", "-q", "-m", "second",
  ])

  let sub_git_dir = @bitlib.detect_git_dir(fs, super_dir + "/submodule")
    .map(pair => pair.0)
    .unwrap()
  let sub_head = @bitlib.resolve_head_commit(fs, sub_git_dir).unwrap()
  let before_entries = @bitlib.read_index_entries(fs, super_dir + "/.git")
  let before_submodule = commit_wbtest_find_entry(before_entries, "submodule")
  assert_true(before_submodule.id != sub_head)

  commit_handle_pathspec_staging(
    fs,
    fs,
    super_dir,
    super_dir + "/.git",
    ["submodule"],
    false,
    false,
  )

  let after_entries = @bitlib.read_index_entries(fs, super_dir + "/.git")
  let after_submodule = commit_wbtest_find_entry(after_entries, "submodule")
  assert_eq(after_submodule.id, sub_head)

  cleanup_tree(fs, root)
}
