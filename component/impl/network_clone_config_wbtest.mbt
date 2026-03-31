///|
test "component impl: clone config helpers write origin remote config" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")

  net_write_clone_remote_config(
    fs, "/repo/.git", "git@github.com:user/repo.git",
  )

  let config = fs.read_string("/repo/.git/config")
  inspect(config.contains("[remote \"origin\"]"), content="true")
  inspect(
    config.contains("\turl = git@github.com:user/repo.git"),
    content="true",
  )
  inspect(
    config.contains("\tfetch = +refs/heads/*:refs/remotes/origin/*"),
    content="true",
  )
}
