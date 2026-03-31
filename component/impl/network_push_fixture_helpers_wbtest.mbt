///|
fn component_impl_prepare_push_repo(
  fs : @bit.TestFs,
  root : String,
) -> String raise @bit.GitError {
  git_init_with_fs(fs, root, "main")
  fs.write_string(root + "/hello.txt", "hello\n")
  add_with_fs(fs, fs, root, ["hello.txt"])
  commit_with_fs(fs, fs, root, "initial\n", "Test <t@example.com>", 1700000000L)
}

///|
fn component_impl_assert_push_success(result : String) -> Unit raise {
  assert_eq(result, "Push successful")
}

///|
fn component_impl_assert_push_state(
  refname : String,
  head_id : @bit.ObjectId,
  pack : Bytes,
  expected_refname : String,
  expected_head : String,
) -> Unit raise {
  assert_eq(refname, expected_refname)
  assert_eq(head_id.to_hex(), expected_head)
  assert_true(pack.length() > 0)
}
