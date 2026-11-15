///|
async test "submodule transport: file is denied unless protocol.file.allow=always" {
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-submodule-transport-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root + "/.git")
  let global = root + "/global.gitconfig"
  fs.write_string(global, "")
  fs.write_string(root + "/.git/config", "[core]\n\tbare = false\n")
  let names = [
    "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM", "GIT_CONFIG_OVERRIDES", "GIT_CONFIG_COUNT",
    "GIT_CONFIG_KEY_0", "GIT_CONFIG_VALUE_0", "GIT_ALLOW_PROTOCOL",
  ]
  let saved = names.map(n => (n, @env.get_env_var(n)))
  defer {
    for pair in saved {
      add_test_restore_env(pair.0, pair.1)
    }
  }
  for n in names {
    @env.unset_env_var(n)
  }
  @env.set_env_var("GIT_CONFIG_GLOBAL", global)
  @env.set_env_var("GIT_CONFIG_NOSYSTEM", "1")

  // Default (`user`) and explicit `user` / `never` deny.
  assert_false(submodule_file_transport_allowed(fs, root))
  fs.write_string(global, "[protocol \"file\"]\n\tallow = user\n")
  assert_false(submodule_file_transport_allowed(fs, root))
  // Global `always` allows; a later repository `never` wins over it.
  fs.write_string(global, "[protocol \"file\"]\n\tallow = always\n")
  assert_true(submodule_file_transport_allowed(fs, root))
  fs.write_string(
    root + "/.git/config",
    "[core]\n\tbare = false\n[protocol \"file\"]\n\tallow = never\n",
  )
  assert_false(submodule_file_transport_allowed(fs, root))
  // `-c protocol.file.allow=always` overrides the files.
  @env.set_env_var("GIT_CONFIG_OVERRIDES", "protocol.file.allow=always")
  assert_true(submodule_file_transport_allowed(fs, root))
  @env.unset_env_var("GIT_CONFIG_OVERRIDES")
  // `protocol.allow` applies only when `protocol.file.allow` is unset.
  fs.write_string(root + "/.git/config", "[protocol]\n\tallow = always\n")
  fs.write_string(global, "")
  assert_true(submodule_file_transport_allowed(fs, root))
  fs.write_string(
    root + "/.git/config",
    "[protocol]\n\tallow = always\n[protocol \"file\"]\n\tallow = user\n",
  )
  assert_false(submodule_file_transport_allowed(fs, root))
  // GIT_CONFIG_COUNT pairs.
  @env.set_env_var("GIT_CONFIG_COUNT", "1")
  @env.set_env_var("GIT_CONFIG_KEY_0", "protocol.file.allow")
  @env.set_env_var("GIT_CONFIG_VALUE_0", "always")
  assert_true(submodule_file_transport_allowed(fs, root))
  @env.unset_env_var("GIT_CONFIG_COUNT")
  @env.unset_env_var("GIT_CONFIG_KEY_0")
  @env.unset_env_var("GIT_CONFIG_VALUE_0")
  // GIT_ALLOW_PROTOCOL is an explicit allowlist that overrides config.
  @env.set_env_var("GIT_ALLOW_PROTOCOL", "https:file")
  assert_true(submodule_file_transport_allowed(fs, root))
  @env.set_env_var("GIT_ALLOW_PROTOCOL", "https")
  assert_false(submodule_file_transport_allowed(fs, root))
  cleanup_tree(fs, root)
}
