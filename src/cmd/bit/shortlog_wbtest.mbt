///|
test "shortlog: detached --glob consumes following token verbatim" {
  @test.assert_eq(shortlog_strip_detached_glob_args(["--glob", "heads/*", "main"]), [
    "main",
  ])
  @test.assert_eq(shortlog_strip_detached_glob_args(["--glob", "-e", "main"]), [
    "main",
  ])
  @test.assert_eq(
    shortlog_strip_detached_glob_args(["-n", "--glob", "--symbolic", "main"]),
    ["-n", "main"],
  )
}
