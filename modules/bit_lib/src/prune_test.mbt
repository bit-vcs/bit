///| Tests for prune

///|
fn setup_repo_prune() -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  ignore(@bit_lib.init_repo(fs, "/repo")) catch {
    _ => ()
  }
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
  @bit_lib.add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(@bit_lib.commit(fs, fs, "/repo", "msg\n", "Test <t@example.com>", 1700000000L))
  let git_dir = "/repo/.git"
  let orphan = @bit_lib.write_loose_object(
    fs,
    git_dir,
    @bit.ObjectType::Blob,
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
  let result = @bit_lib.prune_repo(fs, fs, "/repo")
  assert_true(result.pruned.contains(orphan))
  assert_true(!fs.is_file(obj_path))
}
