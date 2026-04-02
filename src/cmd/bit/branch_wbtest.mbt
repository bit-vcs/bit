///|
test "branch: format columns row-major" {
  let items = [
    "  a/b/c", "  abc", "  bam", "  bar", "  foo", "  j/k", "  l", "  m/m", "* main",
    "  mb", "  n", "  o/o", "  o/p", "  q", "  r", "  topic",
  ]
  let lines = branch_format_columns(items, 81)
  let expected = [
    "  a/b/c   bam     foo     l     * main    n       o/p     r", "  abc     bar     j/k     m/m     mb      o/o     q       topic",
  ]
  assert_eq(lines, expected)
}

///|
test "branch: format columns falls back for long branch names" {
  let long = "  zthis/is/a/part/of/long/branch/name/this/is/a/part/of/long/branch/name/this/is/a/part/of/long/branch/name/this/is/a/part/of/long/branch/name"
  let items = [
    "  a/b/c", "  abc", "  bam", "  bar", "  foo", "  j/k", "  l", "  m/m", "* main",
    "  mb", "  n", "  o/o", "  o/p", "  q", "  r", "  topic", long,
  ]
  let lines = branch_format_columns(items, 80)
  assert_eq(lines.length(), items.length())
  assert_eq(lines[0], "  a/b/c")
  assert_eq(lines[8], "* main")
  assert_eq(lines.last().unwrap_or(""), long)
}

///|
test "branch: column config enables dense layout when non-verbose" {
  let (active, dense, explicit_enabled) = branch_resolve_column_mode(
    None,
    false,
    Some("column"),
    Some("dense"),
  )
  assert_true(active)
  assert_true(dense)
  assert_true(!explicit_enabled)
}

///|
test "branch: verbose ignores config columns but tracks explicit column" {
  let (config_active, _, config_explicit) = branch_resolve_column_mode(
    None,
    true,
    Some("column"),
    Some("dense"),
  )
  assert_true(!config_active)
  assert_true(!config_explicit)

  let (explicit_active, explicit_dense, explicit_enabled) = branch_resolve_column_mode(
    Some("column"),
    true,
    Some("column"),
    Some("dense"),
  )
  assert_true(explicit_active)
  assert_true(!explicit_dense)
  assert_true(explicit_enabled)
}
