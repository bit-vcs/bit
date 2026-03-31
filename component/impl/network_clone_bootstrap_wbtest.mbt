///|
test "component impl: clone bootstrap helpers initialize repo and origin config" {
  let fs = @bit.TestFs::new()

  net_prepare_clone_repo(fs, "/repo", "git@github.com:user/repo.git")

  assert_true(fs.is_dir("/repo"))
  assert_true(fs.is_dir("/repo/.git"))
  let config = fs.read_string("/repo/.git/config")
  inspect(config.contains("[remote \"origin\"]"), content="true")
  inspect(
    config.contains("\turl = git@github.com:user/repo.git"),
    content="true",
  )
}
