///|
test "worktree_admin: resolve_git_dir keeps an absolute Windows gitdir" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("C:/linked")
  fs.write_string("C:/linked/.git", "gitdir: C:/repo/.git/worktrees/linked\n")
  fs.mkdir_p("C:/repo/.git/worktrees/linked")
  fs.write_string("C:/repo/.git/worktrees/linked/commondir", "../..\n")
  assert_eq(resolve_git_dir(fs, "C:/linked"), "C:/repo/.git")
}

///|
test "worktree_admin: resolve_commondir keeps an absolute Windows commondir" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("C:/repo/.git/worktrees/linked")
  fs.write_string(
    "C:/repo/.git/worktrees/linked/commondir", "D:/shared/.git\n",
  )
  assert_eq(
    resolve_commondir(fs, "C:/repo/.git/worktrees/linked"),
    "D:/shared/.git",
  )
}

///|
test "worktree_admin: repair reads an absolute Windows gitfile target" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("C:/linked")
  fs.write_string("C:/linked/.git", "gitdir: C:/repo/.git/worktrees/linked\n")
  assert_eq(
    worktree_repair_gitfile_target(fs, "C:/linked"),
    Some("C:/repo/.git/worktrees/linked"),
  )
}
