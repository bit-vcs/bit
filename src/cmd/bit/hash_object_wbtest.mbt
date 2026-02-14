///|
test "hash-object: delegate only when -w and compat format is sha256" {
  assert_true(
    hash_object_requires_standalone_error(true, Some("sha256"), true),
  )
  assert_false(
    hash_object_requires_standalone_error(false, Some("sha256"), true),
  )
  assert_false(
    hash_object_requires_standalone_error(true, Some("sha1"), true),
  )
  assert_false(hash_object_requires_standalone_error(true, None, true))
}

///|
test "hash-object: delegate check normalizes compat format value" {
  assert_true(
    hash_object_requires_standalone_error(true, Some(" \"SHA256\" "), true),
  )
}

///|
test "hash-object: unavailable real git path keeps pure execution" {
  assert_false(
    hash_object_requires_standalone_error(true, Some("sha256"), false),
  )
}
