///|
test "format_patch: parse options keeps count revision and output file" {
  let opts = parse_format_patch_options([
    "--output=outfile", "--signature=my sig", "--no-signature", "-3", "HEAD",
  ])
  assert_eq(opts.output_file, Some("outfile"))
  assert_eq(opts.signature, Some("my sig"))
  assert_true(opts.no_signature)
  assert_eq(opts.revisions.length(), 2)
  assert_eq(opts.revisions[0], "-3")
  assert_eq(opts.revisions[1], "HEAD")
}

///|
test "format_patch: parse revisions accepts count with explicit end ref" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")

  fs.write_string("/repo/file", "one\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file"])
  ignore(
    @bitlib.commit(
      fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000600L,
    ),
  )

  fs.write_string("/repo/file", "two\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file"])
  let second = @bitlib.commit(
    fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000601L,
  )

  fs.write_string("/repo/file", "three\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file"])
  let third = @bitlib.commit(
    fs, fs, "/repo", "third\n", "Test <t@example.com>", 1700000602L,
  )

  let (_, commits) = parse_format_patch_revisions(fs, "/repo/.git", [
    "-2", "HEAD",
  ])
  assert_eq(commits.length(), 2)
  assert_eq(commits[0].to_hex(), second.to_hex())
  assert_eq(commits[1].to_hex(), third.to_hex())
}

///|
test "format_patch: range excludes commits reachable from base branch" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")

  let head_ref_view = fs
    .read_string("/repo/.git/HEAD")
    .trim()
    .replace(old="ref: ", new="")
  let head_ref = head_ref_view.to_string()
  fs.write_string("/repo/file", "one\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file"])
  let initial = @bitlib.commit(
    fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000600L,
  )

  fs.write_string("/repo/.git/refs/heads/side", initial.to_hex() + "\n")
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/side\n")
  fs.write_string("/repo/file", "side-one\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file"])
  let side_one = @bitlib.commit(
    fs, fs, "/repo", "side one\n", "Test <t@example.com>", 1700000601L,
  )

  fs.write_string("/repo/file", "side-two\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file"])
  let side_two = @bitlib.commit(
    fs, fs, "/repo", "side two\n", "Test <t@example.com>", 1700000602L,
  )

  fs.write_string("/repo/.git/HEAD", "ref: " + head_ref + "\n")
  fs.write_string("/repo/file", "main-two\n")
  @bitlib.add_paths(fs, fs, "/repo", ["file"])
  let main_two = @bitlib.commit(
    fs, fs, "/repo", "main two\n", "Test <t@example.com>", 1700000603L,
  )

  let commits = collect_commits_in_range(fs, "/repo/.git", main_two, side_two)
  assert_eq(commits.length(), 2)
  assert_eq(commits[0].to_hex(), side_one.to_hex())
  assert_eq(commits[1].to_hex(), side_two.to_hex())
}

///|
async test "format_patch: range excludes main history on OsFs" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-format-patch-range-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo = root + "/repo"
  let git_dir = repo + "/.git"

  let code = @process.run(
    "git",
    ["init", "--initial-branch=main", "-q", "repo"][:],
    cwd=root,
  )
  assert_eq(code, 0)
  assert_eq(
    @process.run("git", ["config", "user.name", "Test User"][:], cwd=repo),
    0,
  )
  assert_eq(
    @process.run(
      "git",
      ["config", "user.email", "test@example.com"][:],
      cwd=repo,
    ),
    0,
  )

  fs.write_string(repo + "/file", "one\n")
  assert_eq(@process.run("git", ["add", "file"][:], cwd=repo), 0)
  assert_eq(
    @process.run("git", ["commit", "-q", "-m", "initial"][:], cwd=repo),
    0,
  )
  assert_eq(
    @process.run("git", ["checkout", "-q", "-b", "side"][:], cwd=repo),
    0,
  )

  fs.write_string(repo + "/file", "side-one\n")
  assert_eq(@process.run("git", ["add", "file"][:], cwd=repo), 0)
  assert_eq(
    @process.run("git", ["commit", "-q", "-m", "side one"][:], cwd=repo),
    0,
  )
  let side_one = @bitrepo.rev_parse(fs, git_dir, "HEAD").unwrap()

  fs.write_string(repo + "/file", "side-two\n")
  assert_eq(@process.run("git", ["add", "file"][:], cwd=repo), 0)
  assert_eq(
    @process.run("git", ["commit", "-q", "-m", "side two"][:], cwd=repo),
    0,
  )
  let side_two = @bitrepo.rev_parse(fs, git_dir, "HEAD").unwrap()

  fs.write_string(repo + "/file", "side-three\n")
  assert_eq(@process.run("git", ["add", "file"][:], cwd=repo), 0)
  assert_eq(
    @process.run("git", ["commit", "-q", "-m", "side three"][:], cwd=repo),
    0,
  )
  let side_three = @bitrepo.rev_parse(fs, git_dir, "HEAD").unwrap()

  assert_eq(@process.run("git", ["checkout", "-q", "main"][:], cwd=repo), 0)
  fs.write_string(repo + "/file", "main-two\n")
  assert_eq(@process.run("git", ["add", "file"][:], cwd=repo), 0)
  assert_eq(
    @process.run("git", ["commit", "-q", "-m", "main two"][:], cwd=repo),
    0,
  )
  let main_two = @bitrepo.rev_parse(fs, git_dir, "HEAD").unwrap()

  let commits = collect_commits_in_range(fs, git_dir, main_two, side_three)
  assert_eq(commits.length(), 3)
  assert_eq(commits[0].to_hex(), side_one.to_hex())
  assert_eq(commits[1].to_hex(), side_two.to_hex())
  assert_eq(commits[2].to_hex(), side_three.to_hex())

  cleanup_tree(fs, root)
}

///|
test "format_patch: signature suffix handles text file and none" {
  assert_eq(format_patch_signature_suffix(None), "")
  assert_eq(format_patch_signature_suffix(Some("my sig")), "-- \nmy sig\n\n")
  assert_eq(
    format_patch_signature_suffix(Some("\nline1\nline2\n")),
    "-- \n\nline1\nline2\n\n",
  )
}

///|
test "format_patch: default signature drops bit suffix" {
  assert_false(format_patch_default_signature().contains("(bit"))
}

///|
test "format_patch: generate_commit_diff renders gitlink patch" {
  let fs = @bitcore.TestFs::new()
  @bitlib.init_repo(fs, "/repo")

  fs.write_string(
    "/repo/.gitmodules", "[submodule \"example\"]\n\tpath = init\n\turl = ../example\n",
  )
  @bitlib.add_paths(fs, fs, "/repo", [".gitmodules"])
  let entries1 = @bitlib.read_index_entries(fs, "/repo/.git")
  let rev1 = @bitcore.ObjectId::from_hex(
    "0123456789abcdef0123456789abcdef01234567",
  )
  entries1.push(@bitlib.IndexEntry::new("init", rev1, 0o160000, 0))
  @bitlib.write_index_entries(fs, "/repo/.git", entries1)
  let commit1 = @bitlib.commit(
    fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000600L,
  )

  let entries2 = @bitlib.read_index_entries(fs, "/repo/.git")
  let rev2 = @bitcore.ObjectId::from_hex(
    "89abcdef0123456789abcdef0123456789abcdef",
  )
  for i in 0..<entries2.length() {
    if entries2[i].path == "init" {
      entries2[i] = @bitlib.IndexEntry::new("init", rev2, 0o160000, 0)
    }
  }
  @bitlib.write_index_entries(fs, "/repo/.git", entries2)
  let commit2 = @bitlib.commit(
    fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000601L,
  )

  let db = @bitlib.ObjectDb::load(fs, "/repo/.git")
  let diff = generate_commit_diff(db, fs, "/repo/.git", commit2, Some(commit1))
  assert_true(diff.contains("diff --git a/init b/init"))
  assert_true(diff.contains("index 0123456..89abcde 160000"))
  assert_true(diff.contains("-Subproject commit " + rev1.to_hex()))
  assert_true(diff.contains("+Subproject commit " + rev2.to_hex()))
}
