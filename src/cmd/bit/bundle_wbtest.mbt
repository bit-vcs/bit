///|
fn restore_env_var_for_bundle_wbtest(name : String, prev : String?) -> Unit {
  match prev {
    Some(value) => @sys.set_env_var(name, value)
    None => @sys.unset_env_var(name)
  }
}

///|
test "bundle delegate gate: unavailable real git path stays in pure path" {
  let prev_primary = @sys.get_env_var("SHIM_REAL_GIT")
  let prev_secondary = @sys.get_env_var("GIT_SHIM_REAL_GIT")
  let fs = @git.TestFs::new()
  @sys.set_env_var("SHIM_REAL_GIT", "/tmp/mock-git")
  @sys.unset_env_var("GIT_SHIM_REAL_GIT")
  assert_false(bundle_can_delegate_to_real_git(fs))
  assert_false(bundle_should_delegate_to_real_git(fs, ["create", "a.bundle", "HEAD"]))
  assert_false(bundle_should_delegate_to_real_git(fs, ["verify", "a.bundle"]))
  restore_env_var_for_bundle_wbtest("SHIM_REAL_GIT", prev_primary)
  restore_env_var_for_bundle_wbtest("GIT_SHIM_REAL_GIT", prev_secondary)
}

///|
test "bundle delegate gate: available real git path is delegated" {
  let prev_primary = @sys.get_env_var("SHIM_REAL_GIT")
  let prev_secondary = @sys.get_env_var("GIT_SHIM_REAL_GIT")
  let fs = @git.TestFs::new()
  @sys.set_env_var("SHIM_REAL_GIT", "git")
  @sys.unset_env_var("GIT_SHIM_REAL_GIT")
  assert_true(bundle_can_delegate_to_real_git(fs))
  assert_true(bundle_should_delegate_to_real_git(fs, ["create", "a.bundle", "HEAD"]))
  assert_true(bundle_should_delegate_to_real_git(fs, ["verify", "a.bundle"]))
  restore_env_var_for_bundle_wbtest("SHIM_REAL_GIT", prev_primary)
  restore_env_var_for_bundle_wbtest("GIT_SHIM_REAL_GIT", prev_secondary)
}
