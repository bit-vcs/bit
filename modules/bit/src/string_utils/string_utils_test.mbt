///|
test "trim_string" {
  assert_eq(@string_utils.trim_string("  hello  "), "hello")
  assert_eq(@string_utils.trim_string("\t\nhello\r\n"), "hello")
  assert_eq(@string_utils.trim_string("hello"), "hello")
  assert_eq(@string_utils.trim_string(""), "")
  assert_eq(@string_utils.trim_string("   "), "")
}

///|
test "to_octal_string" {
  assert_eq(@string_utils.to_octal_string(0), "0")
  assert_eq(@string_utils.to_octal_string(8), "10")
  assert_eq(@string_utils.to_octal_string(0o100644), "100644")
  assert_eq(@string_utils.to_octal_string(0o100755), "100755")
  assert_eq(@string_utils.to_octal_string(0o40000), "40000")
}

///|
test "mode_to_string" {
  assert_eq(@string_utils.mode_to_string(33188), "100644")
  assert_eq(@string_utils.mode_to_string(0o100755), "100755")
  assert_eq(@string_utils.mode_to_string(0o40000), "40000")
}

///|
test "decode_bytes" {
  let data = b"hello world"
  assert_eq(@string_utils.decode_bytes(data), "hello world")
  let empty = b""
  assert_eq(@string_utils.decode_bytes(empty), "")
}
