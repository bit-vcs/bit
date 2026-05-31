///|
test "component impl: clone config helpers write origin remote config" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")

  net_write_clone_remote_config(
    fs, "/repo/.git", component_impl_fixture_remote_url,
  )

  let config = fs.read_string("/repo/.git/config")
  inspect(config.contains("[remote \"origin\"]"), content="true")
  inspect(
    config.contains("\turl = " + component_impl_fixture_remote_url),
    content="true",
  )
  inspect(
    config.contains("\tfetch = +refs/heads/*:refs/remotes/origin/*"),
    content="true",
  )
}
