///|
fn restore_env_var_for_merge_wbtest(name : String, prev : String?) -> Unit {
  match prev {
    Some(value) => @sys.set_env_var(name, value)
    None => @sys.unset_env_var(name)
  }
}

///|
test "merge delegate gate: unavailable real git path stays in pure path" {
  let prev_primary = @sys.get_env_var("SHIM_REAL_GIT")
  let prev_secondary = @sys.get_env_var("GIT_SHIM_REAL_GIT")
  let fs = @git.TestFs::new()
  @sys.set_env_var("SHIM_REAL_GIT", "/tmp/mock-git")
  @sys.unset_env_var("GIT_SHIM_REAL_GIT")
  assert_false(merge_can_delegate_to_real_git(fs))
  assert_false(merge_should_delegate_to_real_git(fs, ["feature"]))
  assert_false(merge_should_delegate_to_real_git(fs, ["--abort"]))
  restore_env_var_for_merge_wbtest("SHIM_REAL_GIT", prev_primary)
  restore_env_var_for_merge_wbtest("GIT_SHIM_REAL_GIT", prev_secondary)
}

///|
test "merge delegate gate: available real git path is delegated" {
  let prev_primary = @sys.get_env_var("SHIM_REAL_GIT")
  let prev_secondary = @sys.get_env_var("GIT_SHIM_REAL_GIT")
  let fs = @git.TestFs::new()
  @sys.set_env_var("SHIM_REAL_GIT", "git")
  @sys.unset_env_var("GIT_SHIM_REAL_GIT")
  assert_true(merge_can_delegate_to_real_git(fs))
  assert_true(merge_should_delegate_to_real_git(fs, ["feature"]))
  assert_true(
    merge_should_delegate_to_real_git(fs, ["--message", "msg", "feature"]),
  )
  assert_true(merge_should_delegate_to_real_git(fs, ["feature-a", "feature-b"]))
  restore_env_var_for_merge_wbtest("SHIM_REAL_GIT", prev_primary)
  restore_env_var_for_merge_wbtest("GIT_SHIM_REAL_GIT", prev_secondary)
}

///|
test "merge help is handled by merge command path" {
  assert_true(command_handles_builtin_help("merge"))
}
