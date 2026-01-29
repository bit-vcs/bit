///| Tests for prune

///|
fn setup_repo_prune() -> TestFs {
  let fs = TestFs::new()
  ignore(try? init_repo(fs, "/repo"))
  fs
}

///|
fn test_join_path(root : String, path : String) -> String {
  if root.has_suffix("/") {
    root + path
  } else {
    root + "/" + path
  }
}

///|
test "prune: removes unreachable loose objects" {
  let fs = setup_repo_prune()
  fs.write_string("/repo/a.txt", "hello\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(commit(fs, fs, "/repo", "msg\n", "Test <t@example.com>", 1700000000L))
  let git_dir = "/repo/.git"
  let orphan = write_loose_object(
    fs,
    git_dir,
    ObjectType::Blob,
    Bytes::from_array([b'a', b'b', b'c']),
  )
  let hex = orphan.to_hex()
  let dir = String::unsafe_substring(hex, start=0, end=2)
  let name = String::unsafe_substring(hex, start=2, end=hex.length())
  let obj_path = test_join_path(
    test_join_path(test_join_path(git_dir, "objects"), dir),
    name,
  )
  assert_true(fs.is_file(obj_path))
  let result = prune_repo(fs, fs, "/repo")
  assert_true(result.pruned.contains(orphan))
  assert_true(not(fs.is_file(obj_path)))
}
