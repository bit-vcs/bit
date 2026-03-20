///| JS export bridge tests for `mizchi/bit/lib`.

///|
fn[T] js_exports_unwrap_ok(label : String, result : Result[T, String]) -> T {
  match result {
    Ok(value) => value
    Err(error) => abort("\{label}: \{error}")
  }
}

///|
fn js_exports_parse_loose_header(raw : Bytes) -> (String, Int) {
  let type_buf = StringBuilder::new()
  let mut i = 0
  while i < raw.length() && raw[i] != b' ' {
    type_buf.write_char(raw[i].to_int().unsafe_to_char())
    i += 1
  }
  i += 1
  while i < raw.length() && raw[i] != b'\x00' {
    i += 1
  }
  i += 1
  (type_buf.to_string(), i)
}

///|
test "js exports: memory host supports local git flow" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init", js_git_init(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "hostWriteString",
    js_host_write_string(host_id, "/repo/hello.txt", "hello\n"),
  )

  let before_add = js_exports_unwrap_ok(
    "status before add",
    js_status(host_id, "/repo"),
  )
  assert_eq(before_add.untracked, ["hello.txt"])
  assert_eq(before_add.staged_added, [])

  js_exports_unwrap_ok("add", js_add_paths(host_id, "/repo", ["hello.txt"]))

  let after_add = js_exports_unwrap_ok(
    "status after add",
    js_status(host_id, "/repo"),
  )
  assert_eq(after_add.staged_added, ["hello.txt"])
  assert_eq(after_add.untracked, [])

  let commit_id = js_exports_unwrap_ok(
    "commit",
    js_commit(
      host_id, "/repo", "initial commit", "Tester <tester@example.com>", 1700000000,
    ),
  )
  assert_true(commit_id.length() == 40)

  js_exports_unwrap_ok("checkoutB", js_checkout_b(host_id, "/repo", "feature"))

  let branches = js_exports_unwrap_ok(
    "branchList",
    js_branch_list(host_id, "/repo"),
  )
  let mut saw_feature = false
  let mut saw_main = false
  for branch in branches {
    if branch.name == "feature" {
      saw_feature = true
      assert_true(branch.is_current)
    }
    if branch.name == "main" {
      saw_main = true
    }
  }
  assert_true(saw_feature)
  assert_true(saw_main)

  let log_entries = js_exports_unwrap_ok("log", js_log(host_id, "/repo", 10))
  assert_eq(log_entries.length(), 1)
  assert_eq(log_entries[0].message, "initial commit")
  assert_eq(log_entries[0].author, "Tester <tester@example.com>")

  let head_text = js_exports_unwrap_ok(
    "hostReadString",
    js_host_read_string(host_id, "/repo/.git/HEAD"),
  )
  assert_eq(head_text, "ref: refs/heads/feature\n")

  js_destroy_host(host_id)
}

///|
test "js exports: signed commit stores gpgsig header" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init", js_git_init(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "hostWriteString",
    js_host_write_string(host_id, "/repo/hello.txt", "hello\n"),
  )
  js_exports_unwrap_ok("add", js_add_paths(host_id, "/repo", ["hello.txt"]))

  let payload = js_exports_unwrap_ok(
    "buildCommitPayload",
    js_build_commit_payload(
      host_id, "/repo", "signed commit", "Signer <signer@example.com>", 1700000000,
    ),
  )
  assert_true(payload.contains("tree "))
  assert_false(payload.contains("gpgsig "))

  let commit_id = js_exports_unwrap_ok(
    "commitSigned",
    js_commit_signed(
      host_id, "/repo", "signed commit", "Signer <signer@example.com>", 1700000000,
      "-----BEGIN TEST SIGNATURE-----\nabc123\n-----END TEST SIGNATURE-----\n",
    ),
  )

  let fs = js_make_host_fs(host_id)
  let object_dir = String::unsafe_substring(commit_id, start=0, end=2)
  let object_file = String::unsafe_substring(
    commit_id,
    start=2,
    end=commit_id.length(),
  )
  let object_path = join_path(
    join_path("/repo/.git/objects", object_dir),
    object_file,
  )
  let compressed = fs.read_file(object_path)
  let raw = @zlib.zlib_decompress(compressed)
  let (obj_type, content_start) = js_exports_parse_loose_header(raw)
  assert_eq(obj_type, "commit")
  let content = Bytes::from_array(
    FixedArray::makei(raw.length() - content_start, fn(i) {
      raw[content_start + i]
    }),
  )
  let text = @utf8.decode_lossy(content[:])
  assert_true(
    text.contains(
      "gpgsig -----BEGIN TEST SIGNATURE-----\n abc123\n -----END TEST SIGNATURE-----\n",
    ),
  )
  assert_true(text.contains("\n\nsigned commit\n"))

  js_destroy_host(host_id)
}
