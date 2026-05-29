///|
test "active_issues: parse and serialize roundtrip" {
  let entries = ["#local123", "bit-vcs/other#a1b2c3d4", "myapp#deadbeef"]
  let serialized = serialize_active_issues(entries)
  let parsed = parse_active_issues(serialized)
  @test.assert_eq(parsed, entries)
}

///|
test "active_issues: add and remove" {
  let entries : Array[String] = ["#local123"]
  let added = add_active_issue(entries, "bit-vcs/other#abc")
  @test.assert_eq(added.length(), 2)
  let removed = remove_active_issue(added, "bit-vcs/other#abc")
  @test.assert_eq(removed.length(), 1)
  @test.assert_eq(removed[0], "#local123")
}

///|
test "active_issues: no duplicates" {
  let entries : Array[String] = ["#local123"]
  let added = add_active_issue(entries, "#local123")
  @test.assert_eq(added.length(), 1)
}

///|
test "active_issues: parse empty string" {
  let parsed = parse_active_issues("")
  @test.assert_eq(parsed.length(), 0)
}

///|
test "active_issues: parse with blank lines" {
  let parsed = parse_active_issues("#abc\n\n#def\n")
  @test.assert_eq(parsed.length(), 2)
  @test.assert_eq(parsed[0], "#abc")
  @test.assert_eq(parsed[1], "#def")
}

///|
test "active_issues: remove nonexistent entry" {
  let entries : Array[String] = ["#local123"]
  let removed = remove_active_issue(entries, "#nonexistent")
  @test.assert_eq(removed.length(), 1)
  @test.assert_eq(removed[0], "#local123")
}

///|
test "hub_active_issues_path" {
  let path = hub_active_issues_path("/home/user/repo/.git")
  @test.assert_eq(path, "/home/user/repo/.git/hub/active-issues")
}
