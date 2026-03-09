///|
test "init: normalize path preserves leading parent segments in relative paths" {
  assert_eq(init_normalize_path("./../realgit"), "../realgit")
  assert_eq(init_normalize_path("../../repo/.git"), "../../repo/.git")
}

///|
test "init: normalize path keeps absolute parent traversal rooted" {
  assert_eq(init_normalize_path("/tmp/work/../realgit"), "/tmp/realgit")
  assert_eq(init_normalize_path("/tmp/../../realgit"), "/realgit")
}

///|
test "init: shared mode parsing supports symbolic and octal values" {
  assert_eq(init_shared_file_mode(Some("group")), Some(0o660))
  assert_eq(init_shared_file_mode(Some("all")), Some(0o664))
  assert_eq(init_shared_file_mode(Some("0660")), Some(0o660))
  assert_eq(init_shared_file_mode(Some("umask")), None)
  assert_eq(init_shared_file_mode(Some("bogus")), None)
}

///|
test "init: shared directory mode derives traversal bits and setgid" {
  assert_eq(init_shared_dir_mode(0o660), 0o2770)
  assert_eq(init_shared_dir_mode(0o664), 0o2775)
  assert_eq(init_shared_dir_mode(0o640), 0o2750)
}
