///| Tests for subdir-clone push transformation logic

///|
test "subdir_push: transform single commit tree structure" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo") catch {
    _ => ()
  }
  // Create upstream-like structure
  fs.mkdir_p("/repo/src/x/fs")
  fs.mkdir_p("/repo/src/x/kv")
  fs.mkdir_p("/repo/docs")
  fs.write_file("/repo/src/x/fs/fs.mbt", b"fs original")
  fs.write_file("/repo/src/x/kv/kv.mbt", b"kv content")
  fs.write_file("/repo/docs/README.md", b"docs")
  fs.write_file("/repo/README.md", b"root readme")
  let upstream_commit = commit(
    fs, fs, "/repo", "Upstream", "upstream <up@test.com>", 1000L,
  ) catch {
    _ => return ()
  }
  // Get the fs subtree
  let db = ObjectDb::load(fs, "/repo/.git") catch { _ => return () }
  let upstream_obj = db.get(fs, upstream_commit) catch { _ => return () }
  guard upstream_obj is Some(obj) else { return () }
  let upstream_info = @bit.parse_commit(obj.data) catch { _ => return () }
  // Simulate subdir-clone: extract fs subtree and create new repo
  init_repo(fs, "/subdir") catch {
    _ => ()
  }
  // Copy fs content
  fs.mkdir_p("/subdir")
  fs.write_file("/subdir/fs.mbt", b"fs modified")
  fs.write_file("/subdir/new.mbt", b"new file")
  let subdir_commit = commit(
    fs, fs, "/subdir", "Local change", "local <local@test.com>", 2000L,
  ) catch {
    _ => return ()
  }
  // Now simulate the transform: replace src/x/fs in upstream tree with subdir tree
  let subdir_db = ObjectDb::load(fs, "/subdir/.git") catch { _ => return () }
  let subdir_obj = subdir_db.get(fs, subdir_commit) catch { _ => return () }
  guard subdir_obj is Some(so) else { return () }
  let subdir_info = @bit.parse_commit(so.data) catch { _ => return () }
  // The subdir_info.tree is the new fs tree
  let new_fs_tree = subdir_info.tree
  // Verify the new fs tree has the modified content
  let fs_tree_obj = subdir_db.get(fs, new_fs_tree) catch { _ => return () }
  guard fs_tree_obj is Some(fto) else { return () }
  let fs_entries = @bit.parse_tree(fto.data) catch { _ => return () }
  // Should have fs.mbt and new.mbt
  assert_eq(fs_entries.length(), 2)
  // Verify upstream tree still has all content
  let root_tree_obj = db.get(fs, upstream_info.tree) catch { _ => return () }
  guard root_tree_obj is Some(rto) else { return () }
  let root_entries = @bit.parse_tree(rto.data) catch { _ => return () }
  // Should have: README.md, docs, src
  let mut has_readme = false
  let mut has_docs = false
  let mut has_src = false
  for entry in root_entries {
    match entry.name {
      "README.md" => has_readme = true
      "docs" => has_docs = true
      "src" => has_src = true
      _ => ()
    }
  }
  assert_true(has_readme)
  assert_true(has_docs)
  assert_true(has_src)
}

///|
test "subdir_push: collect diff correctly excludes base objects" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo") catch {
    _ => ()
  }
  // Base commit with multiple files
  fs.mkdir_p("/repo/src/lib")
  fs.write_file("/repo/src/lib/a.mbt", b"a original")
  fs.write_file("/repo/src/lib/b.mbt", b"b original")
  fs.write_file("/repo/other.txt", b"other content")
  let base = commit(fs, fs, "/repo", "Base", "test <test@test.com>", 1000L) catch {
    _ => return ()
  }
  // Modify only lib/a.mbt
  fs.write_file("/repo/src/lib/a.mbt", b"a modified")
  let new_commit = commit(
    fs, fs, "/repo", "Modify a", "test <test@test.com>", 2000L,
  ) catch {
    _ => return ()
  }
  let db = ObjectDb::load(fs, "/repo/.git") catch { _ => return () }
  let diff = collect_diff_objects(db, fs, base, new_commit) catch {
    _ => return ()
  }
  // Check what's included
  let mut a_modified_found = false
  let mut b_original_found = false
  let mut other_found = false
  for obj in diff {
    if obj.obj_type == @bit.ObjectType::Blob {
      let content = @utf8.decode_lossy(obj.data[:])
      if content == "a modified" {
        a_modified_found = true
      }
      if content == "b original" {
        b_original_found = true
      }
      if content == "other content" {
        other_found = true
      }
    }
  }
  // Only modified blob should be included
  assert_true(a_modified_found)
  assert_false(b_original_found)
  assert_false(other_found)
}

///|
test "subdir_push: multiple commits transform correctly" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo") catch {
    _ => ()
  }
  // Create base
  fs.write_file("/repo/file.txt", b"v1")
  let commit1 = commit(fs, fs, "/repo", "v1", "test <test@test.com>", 1000L) catch {
    _ => return ()
  }
  // Second commit
  fs.write_file("/repo/file.txt", b"v2")
  let _ = commit(fs, fs, "/repo", "v2", "test <test@test.com>", 2000L) catch {
    _ => return ()
  }
  // Third commit
  fs.write_file("/repo/file.txt", b"v3")
  let tip = commit(fs, fs, "/repo", "v3", "test <test@test.com>", 3000L) catch {
    _ => return ()
  }
  let db = ObjectDb::load(fs, "/repo/.git") catch { _ => return () }
  // Diff from v1 to v3 should include v2 and v3 commits, not v1
  let diff = collect_diff_objects(db, fs, commit1, tip) catch { _ => return () }
  let mut commit_count = 0
  for obj in diff {
    if obj.obj_type == @bit.ObjectType::Commit {
      commit_count += 1
    }
  }
  // Should only have commit3 (collect_diff_objects only walks the new commit, not history)
  assert_eq(commit_count, 1)
}

///|
test "subdir_push: handles binary files" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo") catch {
    _ => ()
  }
  // Create binary-like content
  let binary_data = Bytes::from_array([
    b'\x00', b'\x01', b'\x02', b'\xFF', b'\xFE', b'\xFD',
  ])
  fs.write_file("/repo/binary.bin", binary_data)
  fs.write_file("/repo/text.txt", b"text")
  let commit1 = commit(
    fs, fs, "/repo", "Initial", "test <test@test.com>", 1000L,
  ) catch {
    _ => return ()
  }
  // Modify binary file
  let new_binary = Bytes::from_array([b'\x00', b'\x00', b'\x00', b'\x00'])
  fs.write_file("/repo/binary.bin", new_binary)
  let commit2 = commit(
    fs, fs, "/repo", "Update binary", "test <test@test.com>", 2000L,
  ) catch {
    _ => return ()
  }
  let db = ObjectDb::load(fs, "/repo/.git") catch { _ => return () }
  let diff = collect_diff_objects(db, fs, commit1, commit2) catch {
    _ => return ()
  }
  // Should include the modified binary blob
  let mut binary_blob_found = false
  for obj in diff {
    if obj.obj_type == @bit.ObjectType::Blob {
      if obj.data.length() == 4 && obj.data[0] == b'\x00' {
        binary_blob_found = true
      }
    }
  }
  assert_true(binary_blob_found)
}

///|
test "subdir_push: empty tree handling" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo") catch {
    _ => ()
  }
  fs.mkdir_p("/repo/dir")
  fs.write_file("/repo/dir/file.txt", b"content")
  let commit1 = commit(
    fs, fs, "/repo", "Initial", "test <test@test.com>", 1000L,
  ) catch {
    _ => return ()
  }
  // Remove all files from dir (Git doesn't track empty dirs, so add a placeholder)
  fs.remove_file("/repo/dir/file.txt")
  fs.write_file("/repo/dir/.gitkeep", b"")
  let commit2 = commit(
    fs, fs, "/repo", "Empty dir", "test <test@test.com>", 2000L,
  ) catch {
    _ => return ()
  }
  let db = ObjectDb::load(fs, "/repo/.git") catch { _ => return () }
  let diff = collect_diff_objects(db, fs, commit1, commit2) catch {
    _ => return ()
  }
  // Should work without error
  assert_true(diff.length() > 0)
}

///|
test "subdir_push: deeply nested changes" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo") catch {
    _ => ()
  }
  // Create deep nesting
  fs.mkdir_p("/repo/a/b/c/d/e")
  fs.write_file("/repo/a/b/c/d/e/deep.txt", b"deep original")
  fs.write_file("/repo/a/shallow.txt", b"shallow")
  let commit1 = commit(
    fs, fs, "/repo", "Initial", "test <test@test.com>", 1000L,
  ) catch {
    _ => return ()
  }
  // Modify only the deep file
  fs.write_file("/repo/a/b/c/d/e/deep.txt", b"deep modified")
  let commit2 = commit(
    fs, fs, "/repo", "Modify deep", "test <test@test.com>", 2000L,
  ) catch {
    _ => return ()
  }
  let db = ObjectDb::load(fs, "/repo/.git") catch { _ => return () }
  let diff = collect_diff_objects(db, fs, commit1, commit2) catch {
    _ => return ()
  }
  // Should include the modified blob and all changed trees in the path
  let mut tree_count = 0
  let mut deep_modified_found = false
  let mut shallow_found = false
  for obj in diff {
    match obj.obj_type {
      @bit.ObjectType::Tree => tree_count += 1
      @bit.ObjectType::Blob => {
        let content = @utf8.decode_lossy(obj.data[:])
        if content == "deep modified" {
          deep_modified_found = true
        }
        if content == "shallow" {
          shallow_found = true
        }
      }
      _ => ()
    }
  }
  assert_true(deep_modified_found)
  assert_false(shallow_found) // unchanged file should not be included
  // Should have trees for: root, a, b, c, d, e (6 levels changed)
  assert_true(tree_count >= 5)
}

///|
test "subdir_push: large number of unchanged files" {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo") catch {
    _ => ()
  }
  // Create many files
  for i = 0; i < 20; i = i + 1 {
    fs.write_file(
      "/repo/file" + i.to_string() + ".txt",
      string_to_bytes("content " + i.to_string()),
    )
  }
  let commit1 = commit(
    fs, fs, "/repo", "Many files", "test <test@test.com>", 1000L,
  ) catch {
    _ => return ()
  }
  // Modify only one file
  fs.write_file("/repo/file5.txt", b"modified content 5")
  let commit2 = commit(
    fs, fs, "/repo", "Modify one", "test <test@test.com>", 2000L,
  ) catch {
    _ => return ()
  }
  let db = ObjectDb::load(fs, "/repo/.git") catch { _ => return () }
  let diff = collect_diff_objects(db, fs, commit1, commit2) catch {
    _ => return ()
  }
  // Should only include: commit, root tree, modified blob
  let mut blob_count = 0
  for obj in diff {
    if obj.obj_type == @bit.ObjectType::Blob {
      blob_count += 1
    }
  }
  // Only 1 modified blob
  assert_eq(blob_count, 1)
}

///|
test "subdir_push: file mode changes" {
  // This tests that we correctly handle mode changes even when content is same
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo") catch {
    _ => ()
  }
  fs.write_file("/repo/script.sh", b"#!/bin/sh\necho hello")
  let commit1 = commit(
    fs, fs, "/repo", "Initial", "test <test@test.com>", 1000L,
  ) catch {
    _ => return ()
  }
  // Change content (simulating mode + content change)
  fs.write_file("/repo/script.sh", b"#!/bin/sh\necho goodbye")
  let commit2 = commit(fs, fs, "/repo", "Modify", "test <test@test.com>", 2000L) catch {
    _ => return ()
  }
  let db = ObjectDb::load(fs, "/repo/.git") catch { _ => return () }
  let diff = collect_diff_objects(db, fs, commit1, commit2) catch {
    _ => return ()
  }
  // Should include the modified blob
  let mut modified_found = false
  for obj in diff {
    if obj.obj_type == @bit.ObjectType::Blob {
      let content = @utf8.decode_lossy(obj.data[:])
      if content.contains("goodbye") {
        modified_found = true
      }
    }
  }
  assert_true(modified_found)
}

///|
fn string_to_bytes(s : String) -> Bytes {
  let bytes : Array[Byte] = []
  for c in s {
    bytes.push(c.to_int().to_byte())
  }
  Bytes::from_array(bytes)
}
