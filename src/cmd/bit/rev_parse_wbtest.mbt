///|
test "rev-parse: output-object-format uses loose-object-idx mapping" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git/objects")
  fs.write_string(
    "/repo/.git/config", "[extensions]\n\tobjectformat = sha1\n\tcompatobjectformat = sha256\n",
  )
  fs.write_string(
    "/repo/.git/objects/loose-object-idx", "# loose-object-idx\n1111111111111111111111111111111111111111 2222222222222222222222222222222222222222222222222222222222222222\n",
  )
  let oid = @bitcore.ObjectId::from_hex(
    "1111111111111111111111111111111111111111",
  )
  assert_eq(
    rev_parse_resolve_output_oid_hex(fs, "/repo/.git", oid, Some("sha256")),
    "2222222222222222222222222222222222222222222222222222222222222222",
  )
}

///|
test "rev-parse: output-object-format falls back to storage oid when mapping is absent" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string(
    "/repo/.git/config", "[extensions]\n\tobjectformat = sha1\n\tcompatobjectformat = sha256\n",
  )
  let oid = @bitcore.ObjectId::from_hex(
    "3333333333333333333333333333333333333333",
  )
  assert_eq(
    rev_parse_resolve_output_oid_hex(fs, "/repo/.git", oid, Some("sha256")),
    "3333333333333333333333333333333333333333",
  )
}

///|
test "rev-parse: --git-path resolves relative paths from git dir" {
  assert_eq(
    rev_parse_resolve_git_path("/repo", ".git", "objects/aa/bb"),
    ".git/objects/aa/bb",
  )
  assert_eq(
    rev_parse_resolve_git_path("/repo", ".", "objects/aa/bb"),
    "objects/aa/bb",
  )
}

///|
test "rev-parse: --git-path keeps absolute path argument" {
  assert_eq(
    rev_parse_resolve_git_path("/repo", ".git", "/tmp/custom-path"),
    "/tmp/custom-path",
  )
}

///|
test "rev-parse: --git-path prefers cwd-relative path for absolute git dir" {
  assert_eq(
    rev_parse_resolve_git_path("/repo", "/repo/.git", "objects/aa/bb"),
    ".git/objects/aa/bb",
  )
  assert_eq(
    rev_parse_resolve_git_path(
      "/repo/corrupt-loose.git", "/repo/corrupt-loose.git", "objects/aa/bb",
    ),
    "objects/aa/bb",
  )
}

///|
test "rev-parse: --git-path prefers caller pwd under -C" {
  let prev = @sys.get_env_var("GIT_SHIM_CALLER_PWD")
  @sys.set_env_var("GIT_SHIM_CALLER_PWD", "/repo")
  assert_eq(rev_parse_git_path_output_cwd("/repo/there"), "/repo")
  match prev {
    Some(value) => @sys.set_env_var("GIT_SHIM_CALLER_PWD", value)
    None => @sys.unset_env_var("GIT_SHIM_CALLER_PWD")
  }
}

///|
test "rev-parse: --git-path uses common dir for linked worktree objects" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git/worktrees/linked")
  fs.write_string("/repo/.git/worktrees/linked/commondir", "../..\n")
  assert_eq(
    rev_parse_resolve_git_path_with_config(
      fs,
      "/repo/linked",
      ".git/worktrees/linked",
      "/repo/.git/worktrees/linked",
      "objects",
      None,
    ),
    "/repo/.git/objects",
  )
}

///|
test "rev-parse: --is-bare-repository reads shared worktreeConfig-aware core.bare" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git/worktrees/linked")
  fs.write_string(
    "/repo/.git/config", "[core]\n\tbare = true\n[extensions]\n\tworktreeConfig = true\n",
  )
  fs.write_string("/repo/.git/worktrees/linked/commondir", "../..\n")
  assert_true(
    rev_parse_is_bare_repository(
      fs, "/repo/.git/worktrees/linked", "/repo/linked",
    ),
  )
}

///|
test "rev-parse: --is-bare-repository lets config.worktree override shared core.bare" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git/worktrees/linked")
  fs.write_string(
    "/repo/.git/config", "[core]\n\tbare = false\n[extensions]\n\tworktreeConfig = true\n",
  )
  fs.write_string("/repo/.git/worktrees/linked/commondir", "../..\n")
  fs.write_string(
    "/repo/.git/worktrees/linked/config.worktree", "[core]\n\tbare = true\n",
  )
  assert_true(
    rev_parse_is_bare_repository(
      fs, "/repo/.git/worktrees/linked", "/repo/linked",
    ),
  )
  assert_false(rev_parse_is_bare_repository(fs, "/repo/.git", "/repo"))
}

///|
test "rev-parse: --git-dir uses relative path at repository root" {
  assert_eq(rev_parse_display_git_dir("/repo", "/repo", "/repo/.git"), ".git")
}

///|
test "rev-parse: --git-dir stays absolute from subdirectory" {
  assert_eq(
    rev_parse_display_git_dir("/repo/sub", "/repo", "/repo/.git"),
    "/repo/.git",
  )
}

///|
test "rev-parse: apply prefix to colon path with ./" {
  assert_eq(
    rev_parse_apply_prefix_to_colon_path("HEAD:./file1", "sub1/"),
    "HEAD:sub1/file1",
  )
}

///|
test "rev-parse: apply prefix to colon path with ../" {
  assert_eq(
    rev_parse_apply_prefix_to_colon_path("HEAD:../top", "sub1/"),
    "HEAD:top",
  )
}

///|
test "rev-parse: prefix not applied to absolute colon path" {
  assert_eq(
    rev_parse_apply_prefix_to_colon_path("HEAD:top", "sub1/"),
    "HEAD:top",
  )
}

///|
test "rev-parse: apply empty prefix to colon path" {
  assert_eq(rev_parse_apply_prefix_to_colon_path("HEAD:./top", ""), "HEAD:top")
}

///|
test "rev-parse: apply prefix two-levels deep" {
  assert_eq(
    rev_parse_apply_prefix_to_colon_path("HEAD:./file2", "sub1/sub2/"),
    "HEAD:sub1/sub2/file2",
  )
}

///|
test "rev-parse: normalize path resolves .." {
  assert_eq(rev_parse_normalize_path("sub1/../top"), "top")
}

///|
test "rev-parse: normalize path resolves ." {
  assert_eq(rev_parse_normalize_path("sub1/./file1"), "sub1/file1")
}

///|
test "rev-parse: detached --glob consumes only non-option argument" {
  assert_eq(
    rev_parse_detached_glob_pattern(["--glob", "heads/subspace"], 0),
    Some("refs/heads/subspace"),
  )
  assert_eq(
    rev_parse_detached_glob_pattern(["--glob", "--symbolic", "main"], 0),
    None,
  )
}

///|
test "rev-parse: no colon means no prefix applied" {
  assert_eq(rev_parse_apply_prefix_to_colon_path("HEAD", "sub1/"), "HEAD")
}
