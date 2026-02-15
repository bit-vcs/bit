///|
test "status: storage runtime routing only for porcelain/short subset" {
  assert_true(status_should_use_storage_runtime(["--porcelain"]))
  assert_true(status_should_use_storage_runtime(["-sb"]))
  assert_true(status_should_use_storage_runtime(["--short"]))

  assert_false(status_should_use_storage_runtime([]))
  assert_false(status_should_use_storage_runtime(["README.md"]))
  assert_false(status_should_use_storage_runtime(["--ignored"]))
}
