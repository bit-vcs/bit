///|
test "is_valid_submodule_name: rejects traversal and config-breaking names" {
  for name in [
    "", "..", "../evil", "../../evil", "a/../../b", "a/..", "..\\evil", "a\\..\\b",
    "/abs", "a\"b", "a\"] [core] hooksPath = /tmp/x #", "a\nb", "a\rb", "a\u{0}b",
  ] {
    if is_valid_submodule_name(name) {
      fail("expected '\{name}' to be rejected")
    }
  }
}

///|
test "is_valid_submodule_name: accepts ordinary names" {
  for name in ["sub", "lib/sub", "a..b", "...", ".hidden", "x/.y", "v1.0"] {
    if !is_valid_submodule_name(name) {
      fail("expected '\{name}' to be accepted")
    }
  }
}
