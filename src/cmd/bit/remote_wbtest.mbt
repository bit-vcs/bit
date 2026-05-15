///|
fn remote_wbtest_remote_config(url : String) -> @bitlib.RemoteConfig {
  {
    urls: [url],
    pushurls: [],
    fetch: [],
    push: [],
    promisor: false,
    partial_clone_filter: None,
    mirror: false,
    tagopt: None,
  }
}

///|
test "remote: update resolves repeated group entries" {
  let content =
    #|
    #|[remotes]
    #|  all = one
    #|  all = two
  let blocks = @bitlib.parse_config_blocks(content)
  let remotes : Map[String, @bitlib.RemoteConfig] = {
    "one": remote_wbtest_remote_config("../one"),
    "two": remote_wbtest_remote_config("../two"),
  }
  let (names, default_update, missing) = remote_update_collect_targets(
    remotes,
    blocks,
    ["all"],
  )
  assert_eq(names, ["one", "two"])
  assert_false(default_update)
  assert_eq(missing, None)
}

///|
test "remote: update reports missing group or remote" {
  let blocks = @bitlib.parse_config_blocks("")
  let remotes : Map[String, @bitlib.RemoteConfig] = {}
  let (names, default_update, missing) = remote_update_collect_targets(
    remotes,
    blocks,
    ["nonexistent"],
  )
  assert_eq(names, [])
  assert_false(default_update)
  assert_eq(missing, Some("nonexistent"))
}
