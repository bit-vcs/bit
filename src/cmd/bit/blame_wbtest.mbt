///|
test "blame: explicit textconv flag requires real git" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  assert_true(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", [
      "--textconv", "file.bin",
    ]),
  )
  assert_true(
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
test "blame: textconv diff driver on target path requires real git" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/.gitattributes", "*.bin diff=test\n")
  fs.write_string(
    "/repo/.git/config", "[core]\n\trepositoryformatversion = 0\n[diff \"test\"]\n\ttextconv = ./helper\n",
  )
  fs.write_string("/repo/file.bin", "bin: content\n")
  assert_true(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", ["file.bin"]),
  )
}

///|
test "blame: normal blame does not require real git" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  assert_false(
    blame_repo_requires_real_git(fs, "/repo", "/repo/.git", ["file.txt"]),
  )
}
