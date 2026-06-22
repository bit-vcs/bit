///|
test "update-ref stdin extra-input reconstructs the unconsumed tail" {
  // Fields after `consumed` are rejoined with their separating space, matching
  // git's "extra input:" report (which includes the leading separator).
  let extra = update_ref_extra_input(
    ["create", "refs/tags/v1", "deadbeef", "cafef00d"],
    3,
  )
  assert_eq(extra, " cafef00d")
  assert_eq(
    update_ref_extra_input(["delete", "refs/tags/v1"], 2),
    "",
  )
}

///|
test "update-ref stdin base args keep flags and message" {
  let args = update_ref_stdin_base_args(true, true, Some("from-stdin"))
  assert_eq(args.length(), 4)
  assert_eq(args[0], "--no-deref")
  assert_eq(args[1], "--create-reflog")
  assert_eq(args[2], "-m")
  assert_eq(args[3], "from-stdin")
}

///|
test "update-ref: storage runtime routing follows simple parser support" {
  assert_true(
    update_ref_should_use_storage_runtime_args([
      "refs/heads/main", "0123456789012345678901234567890123456789",
    ]),
  )
  assert_true(
    update_ref_should_use_storage_runtime_args([
      "-d", "refs/heads/main", "0123456789012345678901234567890123456789",
    ]),
  )

  assert_false(update_ref_should_use_storage_runtime_args(["--stdin"]))
  assert_false(
    update_ref_should_use_storage_runtime_args([
      "--create-reflog", "refs/heads/main", "0123456789012345678901234567890123456789",
    ]),
  )
}
