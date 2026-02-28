///|
test "log: storage runtime routing only for oneline subset" {
  assert_true(log_should_use_storage_runtime(["--oneline"]))
  assert_true(log_should_use_storage_runtime(["--oneline", "-n", "3"]))
  assert_true(log_should_use_storage_runtime(["--oneline", "--max-count=2"]))

  assert_false(log_should_use_storage_runtime(["-n", "3"]))
  assert_false(log_should_use_storage_runtime(["--graph", "--oneline"]))
  assert_false(log_should_use_storage_runtime(["HEAD"]))
}

///|
test "log: storage runtime not used for --all, --decorate, ranges" {
  // --all is not --oneline alone, so storage runtime should be false
  assert_false(log_should_use_storage_runtime(["--all"]))
  assert_false(log_should_use_storage_runtime(["--all", "--oneline"]))
  assert_false(log_should_use_storage_runtime(["--decorate"]))
  assert_false(log_should_use_storage_runtime(["--decorate", "--oneline"]))
  // positional args (including ranges) are not pure --oneline
  assert_false(log_should_use_storage_runtime(["main..develop"]))
  assert_false(log_should_use_storage_runtime(["HEAD~3"]))
  assert_false(log_should_use_storage_runtime(["main"]))
}

///|
test "log: log_find_dotdot parses A..B ranges" {
  // Normal range
  assert_eq(log_find_dotdot("main..develop"), 4)
  // Range with no left side
  assert_eq(log_find_dotdot("..develop"), 0)
  // Range with no right side
  assert_eq(log_find_dotdot("main.."), 4)
  // Triple dot is NOT a range
  assert_eq(log_find_dotdot("main...develop"), -1)
  // No dots
  assert_eq(log_find_dotdot("HEAD"), -1)
  assert_eq(log_find_dotdot("HEAD~3"), -1)
  // Single dot
  assert_eq(log_find_dotdot("a.b"), -1)
}

///|
test "log: format_decoration" {
  let ref_names : Map[String, Array[String]] = {}
  // No decoration
  assert_eq(format_decoration(ref_names, "abc1234"), "")
  // Single decoration
  ref_names["abc1234"] = ["HEAD -> main"]
  assert_eq(format_decoration(ref_names, "abc1234"), " (HEAD -> main)")
  // Multiple decorations
  ref_names["def5678"] = ["HEAD -> main", "origin/main"]
  assert_eq(
    format_decoration(ref_names, "def5678"),
    " (HEAD -> main, origin/main)",
  )
}

///|
test "log: log_extract_author_timestamp" {
  // Simulate a commit object data
  let commit_data = "tree 0000000000000000000000000000000000000000\nauthor Test User <test@example.com> 1700000000 +0000\ncommitter Test User <test@example.com> 1700000000 +0000\n\nTest commit message\n"
  let data = @utf8.encode(commit_data[:])
  let ts = log_extract_author_timestamp(data)
  assert_eq(ts, 1700000000L)
}

///|
test "log: log_parse_entry_from_obj" {
  let commit_data = "tree 0000000000000000000000000000000000000000\nauthor Test User <test@example.com> 1700000000 +0000\ncommitter Test User <test@example.com> 1700000000 +0000\n\nTest commit message\n"
  let data = @utf8.encode(commit_data[:])
  let id = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let tree = @bitcore.ObjectId::from_hex(
    "0000000000000000000000000000000000000000",
  )
  let entry = log_parse_entry_from_obj(id, data, tree)
  assert_eq(entry.message, "Test commit message")
  assert_eq(entry.author, "Test User <test@example.com>")
  assert_eq(entry.timestamp, 1700000000L)
}
