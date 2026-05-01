///|
test "check-ignore: validation errors match git precedence" {
  assert_eq(
    check_ignore_validation_error(true, true, false, false, false, 1),
    Some("cannot have both --quiet and --verbose"),
  )
  assert_eq(
    check_ignore_validation_error(false, false, true, false, false, 1),
    Some("cannot specify pathnames with --stdin"),
  )
  assert_eq(
    check_ignore_validation_error(false, false, false, true, false, 1),
    Some("-z only makes sense with --stdin"),
  )
  assert_eq(
    check_ignore_validation_error(false, false, false, false, false, 0),
    Some("no path specified"),
  )
  assert_eq(
    check_ignore_validation_error(true, false, false, false, false, 2),
    Some("--quiet is only valid with a single pathname"),
  )
  assert_eq(
    check_ignore_validation_error(false, false, false, false, true, 1),
    Some("--non-matching is only valid with --verbose"),
  )
}

///|
test "check-ignore: repo path resolves cwd-relative input" {
  assert_eq(check_ignore_repo_relative_path("file", ""), "file")
  assert_eq(check_ignore_repo_relative_path("./file", ""), "file")
  assert_eq(check_ignore_repo_relative_path("file", "a/b"), "a/b/file")
  assert_eq(check_ignore_repo_relative_path("../file", "a/b"), "../file")
  assert_eq(check_ignore_repo_relative_path("/tmp/file", "a/b"), "/tmp/file")
}

///|
test "check-ignore: tracked paths are suppressed unless no-index is set" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  fs.write_string("/repo/ignored", "tracked\n")
  ignore(try? @bitlib.add_paths(fs, fs, "/repo", ["ignored"]))

  let tracked = check_ignore_tracked_paths(fs, "/repo/.git", false)
  assert_true(tracked.contains("ignored"))

  let no_index = check_ignore_tracked_paths(fs, "/repo/.git", true)
  assert_false(no_index.contains("ignored"))
}

///|
test "check-ignore: standard rules include configured global excludes" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  fs.write_string(
    "/repo/.git/config", "[core]\n\texcludesfile = global-excludes\n",
  )
  fs.write_string("/repo/global-excludes", "global\n")

  let matcher = @ignore.Matcher::new()
  check_ignore_add_standard_rules(fs, "/repo", "/repo/.git", matcher)
  assert_true(matcher.is_ignored("global", false))

  let info = check_ignore_find_rule(fs, "/repo", "/repo/.git", "global", false)
  assert_eq(info.0, "global-excludes")
  assert_eq(info.1, 1)
  assert_eq(info.2, "global")
}

///|
test "check-ignore: verbose rule lookup reports negation matches" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  fs.write_string("/repo/.gitignore", "one\n!on*\n")

  let matcher = @ignore.Matcher::new()
  check_ignore_add_standard_rules(fs, "/repo", "/repo/.git", matcher)
  assert_false(matcher.is_ignored("one", false))

  let info = check_ignore_find_rule(fs, "/repo", "/repo/.git", "one", false)
  assert_eq(info.0, ".gitignore")
  assert_eq(info.1, 2)
  assert_eq(info.2, "!on*")
}
