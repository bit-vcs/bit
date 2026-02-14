///|
test "commit: signing options trigger real-git delegation when enabled" {
  let prev_shim_real_git = @sys.get_env_var("SHIM_REAL_GIT")
  let prev_legacy_real_git = @sys.get_env_var("GIT_SHIM_REAL_GIT")
  @sys.set_env_var("SHIM_REAL_GIT", "/usr/bin/git")
  @sys.unset_env_var("GIT_SHIM_REAL_GIT")
  assert_true(commit_should_delegate_to_real_git(["-S", "-m", "msg"]))
  assert_true(
    commit_should_delegate_to_real_git(["-S/path/to/key", "-m", "msg"]),
  )
  assert_true(commit_should_delegate_to_real_git(["--gpg-sign", "-m", "msg"]))
  assert_true(
    commit_should_delegate_to_real_git(["--gpg-sign=KEY", "-m", "msg"]),
  )
  match prev_shim_real_git {
    Some(value) => @sys.set_env_var("SHIM_REAL_GIT", value)
    None => @sys.unset_env_var("SHIM_REAL_GIT")
  }
  match prev_legacy_real_git {
    Some(value) => @sys.set_env_var("GIT_SHIM_REAL_GIT", value)
    None => @sys.unset_env_var("GIT_SHIM_REAL_GIT")
  }
}

///|
test "commit: no-edit prefers SQUASH_MSG and appends MERGE_MSG comments" {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string("/repo/.git/SQUASH_MSG", "squash body\n")
  fs.write_string("/repo/.git/MERGE_MSG", "\n# Conflicts:\n#\tfile\n")
  let msg = resolve_no_edit_commit_message(fs, "/repo", "/repo/.git", false)
  assert_eq(msg, Some("squash body\n\n# Conflicts:\n#\tfile\n"))
}

///|
test "commit: no-edit prefers MERGE_MSG when MERGE_HEAD exists" {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string("/repo/.git/MERGE_HEAD", "1111111111111111111111111111111111111111\n")
  fs.write_string("/repo/.git/SQUASH_MSG", "squash body\n")
  fs.write_string("/repo/.git/MERGE_MSG", "merge body\n")
  let msg = resolve_no_edit_commit_message(fs, "/repo", "/repo/.git", false)
  assert_eq(msg, Some("merge body\n"))
}

///|
test "commit: read MERGE_HEAD supports multiple parents" {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string(
    "/repo/.git/MERGE_HEAD",
    "1111111111111111111111111111111111111111\n2222222222222222222222222222222222222222\n",
  )
  let merge_heads = read_merge_head_ids(fs, "/repo/.git")
  assert_eq(merge_heads.length(), 2)
  assert_eq(
    merge_heads[0].to_hex(),
    "1111111111111111111111111111111111111111",
  )
  assert_eq(
    merge_heads[1].to_hex(),
    "2222222222222222222222222222222222222222",
  )
}
