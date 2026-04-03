///|
test "parse_cross_repo_ref: owner/repo#id" {
  let (repo_ref, issue_id) = parse_cross_repo_ref("bit-vcs/other#a1b2c3d4")
  assert_eq(repo_ref, "bit-vcs/other")
  assert_eq(issue_id, "a1b2c3d4")
}

///|
test "parse_cross_repo_ref: local #id" {
  let (repo_ref, issue_id) = parse_cross_repo_ref("#local123")
  assert_eq(repo_ref, "")
  assert_eq(issue_id, "local123")
}

///|
test "parse_cross_repo_ref: bare id (no #)" {
  let (repo_ref, issue_id) = parse_cross_repo_ref("abc123")
  assert_eq(repo_ref, "")
  assert_eq(issue_id, "abc123")
}

///|
test "parse_alias_file: roundtrip" {
  let entries : Array[(String, String)] = [
    ("myapp", "/path/to/repo"),
    ("lib", "/other/path"),
  ]
  let serialized = serialize_alias_entries(entries)
  let parsed = parse_alias_entries(serialized)
  assert_eq(parsed.length(), 2)
  assert_eq(parsed[0].0, "myapp")
  assert_eq(parsed[0].1, "/path/to/repo")
  assert_eq(parsed[1].0, "lib")
  assert_eq(parsed[1].1, "/other/path")
}

///|
test "parse_alias_entries: empty string" {
  let parsed = parse_alias_entries("")
  assert_eq(parsed.length(), 0)
}

///|
test "parse_alias_entries: blank lines and comments ignored" {
  let content =
    #|# comment line
    #|
    #|myapp /path/to/repo
    #|
  let parsed = parse_alias_entries(content)
  assert_eq(parsed.length(), 1)
  assert_eq(parsed[0].0, "myapp")
  assert_eq(parsed[0].1, "/path/to/repo")
}

///|
test "hub_remotes_path" {
  let path = hub_remotes_path("/home/user/repo/.git")
  assert_eq(path, "/home/user/repo/.git/hub/remotes")
}

///|
test "resolve_repo_ref_to_path: alias match" {
  let aliases : Map[String, String] = { "myapp": "/path/to/myapp" }
  let result = resolve_repo_ref_to_path("myapp", "/home/user", aliases~)
  assert_eq(result, "/path/to/myapp")
}

///|
test "resolve_repo_ref_to_path: ghq path" {
  // This tests the ghq path resolution logic (owner/repo format)
  let aliases : Map[String, String] = {}
  let result = resolve_repo_ref_to_path(
    "bit-vcs/bit",
    "/home/user",
    aliases~,
  )
  assert_eq(result, "/home/user/ghq/github.com/bit-vcs/bit")
}

///|
test "resolve_repo_ref_to_path: unknown raises error" {
  let aliases : Map[String, String] = {}
  let result = try {
    resolve_repo_ref_to_path("unknown-alias", "/home/user", aliases~)
  } catch {
    e => {
      assert_true(e.to_string().contains("Cannot resolve"))
      return
    }
  }
  ignore(result)
  fail("expected error for unknown repo ref")
}
