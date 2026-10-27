///| Tests for subdir path resolution

///|
test "subdir: get_subdir_tree_from_commit rejects missing or file path" {
  let fs = @bit.TestFs::new()
  @bit_lib.init_repo(fs, "/repo") catch {
    _ => return ()
  }
  fs.mkdir_p("/repo/src")
  fs.write_file("/repo/src/fs.mbt", b"data")
  let commit_id = @bit_lib.commit(fs, fs, "/repo", "init", "test <test@test.com>", 1000L) catch {
    _ => return ()
  }
  let db = @bit_lib.ObjectDb::load(fs, "/repo/.git") catch { _ => return () }
  let missing = @bit_lib.get_subdir_tree_from_commit(db, fs, commit_id, "src/missing")
  assert_true(missing is None)
  let file_path = @bit_lib.get_subdir_tree_from_commit(db, fs, commit_id, "src/fs.mbt")
  assert_true(file_path is None)
}

///|
test "subdir: rewrite_subdir_commit swaps tree and parents, drops signatures" {
  let old_tree = "1111111111111111111111111111111111111111"
  let old_parent = "2222222222222222222222222222222222222222"
  let raw = @utf8.encode(
    (
      $|tree \{old_tree}
      $|parent \{old_parent}
      $|author A U Thor <author@example.com> 1700000000 +0900
      $|committer C O Mitter <committer@example.com> 1700000100 +0000
      $|gpgsig -----BEGIN PGP SIGNATURE-----
      $| 
      $| abcdef
      $| -----END PGP SIGNATURE-----
      $|
      $|Subject line
      $|
      $|Body text
      $|
    ),
  )
  let tree = @bit.ObjectId::from_hex("3333333333333333333333333333333333333333")
  let parent = @bit.ObjectId::from_hex(
    "4444444444444444444444444444444444444444",
  )
  let rewritten = @bit_lib.rewrite_subdir_commit(raw, tree, [parent])
  inspect(
    @utf8.decode(rewritten),
    content=(
      #|tree 3333333333333333333333333333333333333333
      #|parent 4444444444444444444444444444444444444444
      #|author A U Thor <author@example.com> 1700000000 +0900
      #|committer C O Mitter <committer@example.com> 1700000100 +0000
      #|
      #|Subject line
      #|
      #|Body text
      #|
    ),
  )
  let root = @bit_lib.rewrite_subdir_commit(raw, tree, [])
  assert_true(@utf8.decode(root).has_prefix("tree 3333333333333333333333333333333333333333\nauthor "))
}
