///|
test "component impl: status tree mode helpers parse tree mode and octal mode" {
  assert_true(status_is_tree_mode("40000"))
  assert_true(status_is_tree_mode("040000"))
  assert_true(not(status_is_tree_mode("100644")))

  assert_eq(status_parse_octal_mode("100644"), 33188)
  assert_eq(status_parse_octal_mode("040000"), 16384)
  assert_eq(status_parse_octal_mode("bad100755"), 33261)
}
