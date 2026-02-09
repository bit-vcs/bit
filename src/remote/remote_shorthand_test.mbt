///|
test "remote/shorthand: parse repo ref shorthand" {
  let parsed = parse_github_shorthand("user/repo@main")
  inspect(
    parsed,
    content="Some(Repo(\"https://github.com/user/repo\", Some(\"main\")))",
  )
}

///|
test "remote/shorthand: ambiguity detects first path segment" {
  let result = check_shorthand_ambiguity("user/repo:src", p => p == "user")
  assert_eq(result, Some("user"))
}
