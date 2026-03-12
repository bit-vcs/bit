///|
test "main: parse_global_options keeps raw -C path for diagnostics" {
  let opts = parse_global_options(["bit", "-C", "missing/repo", "init"])
  assert_eq(opts.cwd_raw, Some("missing/repo"))
  assert_true(opts.cwd is Some(_))
}

///|
test "main: missing_global_cwd_error uses raw -C path" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/existing")
  assert_eq(
    missing_global_cwd_error(fs, Some("/repo/existing"), Some("existing")),
    None,
  )
  assert_eq(
    missing_global_cwd_error(fs, Some("/repo/missing"), Some("missing")),
    Some("fatal: cannot change to 'missing': No such file or directory"),
  )
}

///|
test "main: log supported -c overrides stay in shim" {
  let opts = parse_global_options([
    "bit", "-c", "core.abbrev=false", "log", "--abbrev-commit",
  ])
  assert_false(
    should_delegate_to_real_git(
      ["bit", "-c", "core.abbrev=false", "log", "--abbrev-commit"],
      opts,
    ),
  )
  let opts2 = parse_global_options([
    "bit", "-c", "grep.patternType=fixed", "whatchanged", "--i-still-use-this",
  ])
  assert_false(
    should_delegate_to_real_git(
      [
        "bit", "-c", "grep.patternType=fixed", "whatchanged", "--i-still-use-this",
      ],
      opts2,
    ),
  )
}

///|
test "main: grep supported -c overrides stay in shim" {
  let opts = parse_global_options(["bit", "-c", "grep.threads=0", "grep", "."])
  assert_false(
    should_delegate_to_real_git(
      ["bit", "-c", "grep.threads=0", "grep", "."],
      opts,
    ),
  )
  let opts2 = parse_global_options([
    "bit", "-c", "grep.patternType=fixed", "grep", "hello",
  ])
  assert_false(
    should_delegate_to_real_git(
      ["bit", "-c", "grep.patternType=fixed", "grep", "hello"],
      opts2,
    ),
  )
}

///|
test "main: config overrides use last matching value" {
  let prev = @sys.get_env_var("GIT_CONFIG_OVERRIDES")
  @sys.set_env_var(
    "GIT_CONFIG_OVERRIDES", "grep.patternType=extended\ngrep.patternType=default\ngrep.patternType=fixed",
  )
  assert_eq(get_config_override("grep.patternType"), Some("fixed"))
  match prev {
    Some(value) => @sys.set_env_var("GIT_CONFIG_OVERRIDES", value)
    None => @sys.unset_env_var("GIT_CONFIG_OVERRIDES")
  }
}

///|
test "main: unsupported -c overrides still delegate" {
  let opts = parse_global_options(["bit", "-c", "log.decorate=full", "log"])
  assert_true(
    should_delegate_to_real_git(["bit", "-c", "log.decorate=full", "log"], opts),
  )
}

///|
test "main: worktree stays in shim without config overrides" {
  let opts = parse_global_options(["bit", "worktree", "add", "wt", "-"])
  assert_false(
    should_delegate_to_real_git(["bit", "worktree", "add", "wt", "-"], opts),
  )
}

///|
test "main: worktree stays in shim with config env overrides" {
  let prev = @sys.get_env_var("GIT_CONFIG_PARAMETERS")
  @sys.set_env_var("GIT_CONFIG_PARAMETERS", "'core.abbrev'='false'")
  let opts = parse_global_options(["bit", "worktree", "add", "wt", "-"])
  assert_false(
    should_delegate_to_real_git(["bit", "worktree", "add", "wt", "-"], opts),
  )
  match prev {
    Some(value) => @sys.set_env_var("GIT_CONFIG_PARAMETERS", value)
    None => @sys.unset_env_var("GIT_CONFIG_PARAMETERS")
  }
}
