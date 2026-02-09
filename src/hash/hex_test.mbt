///|
test "short_hex truncates" {
  assert_eq(short_hex("abcdef", 4), "abcd")
  assert_eq(short_hex("abc", 4), "abc")
}

///|
test "is_hex_string" {
  assert_true(is_hex_string("deadBEEF"))
  assert_false(is_hex_string(""))
  assert_false(is_hex_string("zzzz"))
}

///|
test "lower_hex_string" {
  assert_eq(lower_hex_string("DEADbeef"), "deadbeef")
}

///|
test "int_to_hex4" {
  assert_eq(int_to_hex4(0), "0000")
  assert_eq(int_to_hex4(10), "000a")
  assert_eq(int_to_hex4(4660), "1234")
}

///|
test "hex_char_to_int" {
  assert_eq(hex_char_to_int('0'), 0)
  assert_eq(hex_char_to_int('9'), 9)
  assert_eq(hex_char_to_int('a'), 10)
  assert_eq(hex_char_to_int('F'), 15)
}
