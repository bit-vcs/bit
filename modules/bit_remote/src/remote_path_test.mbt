///|
test "remote/path: resolve helper URL with relative local path" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/work/server/.git/objects")
  let resolved = @bit_remote.resolve_local_repo_path(
    fs, "/work/client", "testgit::../server",
  )
  @test.assert_eq(resolved, Some("/work/server"))
}

///|
test "remote/path: detect bare git dir" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/bare/objects")
  fs.write_string("/bare/HEAD", "ref: refs/heads/main\n")
  let detected = @bit_remote.detect_git_dir(fs, "/bare")
  debug_inspect(
    detected,
    content=(
      #|Some(("/bare", true))
    ),
  )
}

///|
fn gitdir_fixture(dot_git : String, target : String) -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  match dot_git.rev_find("/") {
    Some(i) => fs.mkdir_p(String::unsafe_substring(dot_git, start=0, end=i))
    None => ()
  }
  fs.write_string(dot_git, "gitdir: " + target + "\n")
  fs
}

///|
test "remote/path: resolve_gitdir keeps absolute Windows targets (issue #209)" {
  for
    target in [
      "C:/repo/.git/worktrees/linked", "c:/repo/.git/worktrees/linked", "C:\\repo\\.git\\worktrees\\linked",
      "\\\\server\\share\\repo\\.git\\worktrees\\linked", "/repo/.git/worktrees/linked",
    ] {
    let fs = gitdir_fixture("C:/linked/.git", target)
    @test.assert_eq(@bit_remote.resolve_gitdir(fs, "C:/linked/.git"), target)
  }
}

///|
test "remote/path: resolve_gitdir joins relative targets to the .git directory" {
  let fs = gitdir_fixture("/work/linked/.git", "../repo/.git/worktrees/linked")
  @test.assert_eq(
    @bit_remote.resolve_gitdir(fs, "/work/linked/.git"),
    "/work/linked/../repo/.git/worktrees/linked",
  )
  let win = gitdir_fixture("C:/linked/.git", "../repo/.git/worktrees/linked")
  @test.assert_eq(
    @bit_remote.resolve_gitdir(win, "C:/linked/.git"),
    "C:/linked/../repo/.git/worktrees/linked",
  )
}

///|
test "remote/path: resolve_gitdir leaves a drive-relative target as is" {
  // Like git, `C:relative` has a drive prefix and is not glued onto the
  // .git file's directory; it stays distinct from `C:/relative`.
  let fs = gitdir_fixture("C:/linked/.git", "C:relative")
  @test.assert_eq(@bit_remote.resolve_gitdir(fs, "C:/linked/.git"), "C:relative")
}
