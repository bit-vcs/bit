///|
test "reflog: short max-count option is parsed" {
  let parsed = parse_reflog_show_args(["-1"])
  assert_eq(parsed.max_count, Some(1))
  assert_eq(parsed.refname, "HEAD")
}

///|
test "reflog: short max-count can be combined with refname" {
  let parsed = parse_reflog_show_args(["-20", "refs/heads/main"])
  assert_eq(parsed.max_count, Some(20))
  assert_eq(parsed.refname, "refs/heads/main")
}

///|
test "reflog: non-numeric short options do not set max-count" {
  let parsed = parse_reflog_show_args(["-i", "--grep=merge"])
  assert_eq(parsed.max_count, None)
  assert_true(parsed.grep_ignore_case)
  assert_eq(parsed.grep_patterns, ["merge"])
}
