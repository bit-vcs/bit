///|
test "log: storage runtime routing only for oneline subset" {
  assert_true(log_should_use_storage_runtime(["--oneline"]))
  assert_true(log_should_use_storage_runtime(["--oneline", "-n", "3"]))
  assert_true(log_should_use_storage_runtime(["--oneline", "--max-count=2"]))

  assert_false(log_should_use_storage_runtime(["-n", "3"]))
  assert_false(log_should_use_storage_runtime(["--graph", "--oneline"]))
  assert_false(log_should_use_storage_runtime(["HEAD"]))
}
