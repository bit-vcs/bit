///| Tests for GitHub subdir shorthand parsing
///| Verifies that the shorthand doesn't conflict with existing git URL patterns

///|
test "subdir shorthand: basic 3-component path" {
  let result = parse_subdir_shorthand("user/repo/src")
  assert_eq(result, Some(("https://github.com/user/repo", "src")))
}

///|
test "subdir shorthand: deep path" {
  let result = parse_subdir_shorthand("user/repo/src/lib/core")
  assert_eq(result, Some(("https://github.com/user/repo", "src/lib/core")))
}

///|
test "subdir shorthand: mizchi/bit example" {
  let result = parse_subdir_shorthand("mizchi/bit/src/x/bitfs")
  assert_eq(result, Some(("https://github.com/mizchi/bit", "src/x/bitfs")))
}

// ============================================================================
// Tests for patterns that should NOT trigger shorthand (existing git patterns)
// ============================================================================

///|
test "NOT shorthand: full HTTPS URL" {
  let result = parse_subdir_shorthand("https://github.com/user/repo")
  assert_eq(result, None)
}

///|
test "NOT shorthand: full HTTPS URL with path" {
  let result = parse_subdir_shorthand("https://github.com/user/repo/tree/main/src")
  assert_eq(result, None)
}

///|
test "NOT shorthand: SSH URL" {
  let result = parse_subdir_shorthand("git@github.com:user/repo.git")
  assert_eq(result, None)
}

///|
test "NOT shorthand: SSH URL without .git" {
  let result = parse_subdir_shorthand("git@github.com:user/repo")
  assert_eq(result, None)
}

///|
test "NOT shorthand: 2-component GitHub shorthand (user/repo)" {
  // This is standard GitHub CLI shorthand, should NOT trigger subdir
  let result = parse_subdir_shorthand("user/repo")
  assert_eq(result, None)
}

///|
test "NOT shorthand: repo with .git suffix" {
  let result = parse_subdir_shorthand("user/repo.git")
  assert_eq(result, None)
}

///|
test "NOT shorthand: path with .git suffix" {
  let result = parse_subdir_shorthand("user/repo/src.git")
  assert_eq(result, None)
}

///|
test "NOT shorthand: hostname-like first component" {
  // github.com/user/repo looks like a URL without protocol
  let result = parse_subdir_shorthand("github.com/user/repo")
  assert_eq(result, None)
}

///|
test "NOT shorthand: gitlab.com style" {
  let result = parse_subdir_shorthand("gitlab.com/user/repo/src")
  assert_eq(result, None)
}

///|
test "NOT shorthand: local path style ./" {
  let result = parse_subdir_shorthand("./local/repo/path")
  assert_eq(result, None)
}

///|
test "NOT shorthand: local path style ../" {
  let result = parse_subdir_shorthand("../local/repo/path")
  assert_eq(result, None)
}

///|
test "NOT shorthand: absolute path" {
  let result = parse_subdir_shorthand("/home/user/repo")
  assert_eq(result, None)
}

///|
test "NOT shorthand: absolute path deep" {
  let result = parse_subdir_shorthand("/var/git/repos/project")
  assert_eq(result, None)
}

// ============================================================================
// Edge cases
// ============================================================================

///|
test "NOT shorthand: single component" {
  let result = parse_subdir_shorthand("repo")
  assert_eq(result, None)
}

///|
test "NOT shorthand: empty string" {
  let result = parse_subdir_shorthand("")
  assert_eq(result, None)
}

///|
test "subdir shorthand: trailing slash" {
  let result = parse_subdir_shorthand("user/repo/src/")
  assert_eq(result, Some(("https://github.com/user/repo", "src")))
}

///|
test "subdir shorthand: multiple trailing slashes" {
  let result = parse_subdir_shorthand("user/repo/src//lib")
  assert_eq(result, Some(("https://github.com/user/repo", "src/lib")))
}
