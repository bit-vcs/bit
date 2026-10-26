///|
test "remote/shorthand: parse repo ref shorthand" {
  let parsed = @bit_remote.parse_github_shorthand("user/repo@main")
  debug_inspect(
    parsed,
    content="Some(Repo(\"https://github.com/user/repo\", Some(\"main\")))",
  )
}

///|
test "remote/shorthand: ambiguity detects first path segment" {
  let result = @bit_remote.check_shorthand_ambiguity("user/repo:src", p => p == "user")
  @test.assert_eq(result, Some("user"))
}
