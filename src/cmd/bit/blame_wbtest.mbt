///|
test "blame: explicit textconv flag stays native" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  assert_false(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", [
      "--textconv", "file.bin",
    ]),
  )
  assert_false(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", [
      "--no-textconv", "file.bin",
    ]),
  )
}

///|
test "blame: unsupported option requires real git" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  assert_true(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", ["-c", "file.txt"]),
  )
}

///|
test "blame: multiple positional args require real git" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  assert_true(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", ["HEAD", "file.txt"]),
  )
}

///|
test "blame: porcelain mode requires real git" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  assert_true(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", [
      "--porcelain", "file.txt",
    ]),
  )
}

///|
test "blame: blame.showEmail=true requires real git" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string(
    "/repo/.git/config", "[core]\n\trepositoryformatversion = 0\n[blame]\n\tshowEmail = true\n",
  )
  assert_true(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", ["file.txt"]),
  )
}

///|
test "blame: textconv diff driver on target path stays native" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/.gitattributes", "*.bin diff=test\n")
  fs.write_string(
    "/repo/.git/config", "[core]\n\trepositoryformatversion = 0\n[diff \"test\"]\n\ttextconv = ./helper\n",
  )
  fs.write_string("/repo/file.bin", "bin: content\n")
  assert_false(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", ["file.bin"]),
  )
  guard blame_effective_textconv_command(
      fs,
      "/repo",
      "/repo/.git",
      "file.bin",
      None,
    )
    is Some(cmd) else {
    assert_true(false)
    return
  }
  assert_eq(cmd, "./helper")
  assert_true(
    blame_effective_textconv_command(
      fs,
      "/repo",
      "/repo/.git",
      "file.bin",
      Some(false),
    )
    is None,
  )
}

///|
async test "blame: textconv transforms target blob content" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let root = "/tmp/bit-test-blame-textconv-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q"])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])
  fs.write_string(root + "/.gitattributes", "*.bin diff=test\n")
  fs.write_string(
    root + "/textconv.sh",
    "#!/bin/sh\nsed 's/raw/text/g' \"$1\"\n",
  )
  assert_eq(
    @process.run("chmod", ["+x", root + "/textconv.sh"], inherit_env=true),
    0,
  )
  commit_wbtest_run_git(root, ["config", "diff.test.textconv", "./textconv.sh"])
  fs.write_string(root + "/file.bin", "raw one\n")
  commit_wbtest_run_git(root, [
    "add", ".gitattributes", "textconv.sh", "file.bin",
  ])
  commit_wbtest_run_git(root, ["commit", "-q", "-m", "base"])
  let git_dir = root + "/.git"
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  guard @bitrepo.rev_parse(rfs, git_dir, "HEAD") is Some(head) else {
    assert_true(false)
    cleanup_tree(fs, root)
    return
  }
  guard blame_effective_textconv_command(rfs, root, git_dir, "file.bin", None)
    is Some(command) else {
    assert_true(false)
    cleanup_tree(fs, root)
    return
  }
  let content = blame_get_file_at_commit_for_display(
    fs,
    db,
    rfs,
    root,
    git_dir,
    head,
    "file.bin",
    Some(command),
  )
  assert_eq(content, Some("text one\n"))
  let raw_content = blame_get_file_at_commit_for_display(
    fs,
    db,
    rfs,
    root,
    git_dir,
    head,
    "file.bin",
    None,
  )
  assert_eq(raw_content, Some("raw one\n"))
  cleanup_tree(fs, root)
}

///|
test "blame: normal blame does not require real git" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  assert_false(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", ["file.txt"]),
  )
}
