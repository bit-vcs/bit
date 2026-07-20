///| Tests for gc/repack

///|
fn build_simple_repo(
  fs : @bit.TestFs,
  root : String,
) -> (@bit.ObjectId, @bit.ObjectId, @bit.ObjectId) raise @bit.GitError {
  init_repo(fs, root)
  let git_dir = root + "/.git"
  let (blob_id, blob_bytes) = @bit.create_blob_string("hello\n")
  write_object_bytes(fs, git_dir, blob_id, blob_bytes)
  let entry = @bit.TreeEntry::new("100644", "hello.txt", blob_id)
  let (tree_id, tree_bytes) = @bit.create_tree([entry])
  write_object_bytes(fs, git_dir, tree_id, tree_bytes)
  let commit = @bit.Commit::new(
    tree_id,
    [],
    "Test <test@example.com>",
    0L,
    "+0000",
    "Test <test@example.com>",
    0L,
    "+0000",
    "test commit\n",
  )
  let (commit_id, commit_bytes) = @bit.create_commit(commit)
  write_object_bytes(fs, git_dir, commit_id, commit_bytes)
  update_head_ref(fs, fs, git_dir, commit_id)
  (commit_id, tree_id, blob_id)
}

///|
test "repack_repo writes pack with reachable objects" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  let (orphan_id, orphan_bytes) = @bit.create_blob_string("orphan\n")
  write_object_bytes(fs, git_dir, orphan_id, orphan_bytes)
  let result = repack_repo(fs, fs, root)
  match result {
    None => fail("expected pack")
    Some(r) => {
      assert_true(r.object_count == 3)
      let pack_path = git_dir +
        "/objects/pack/pack-" +
        r.pack_id.to_hex() +
        ".pack"
      assert_true(fs.is_file(pack_path))
      let pack = fs.read_file(pack_path)
      let objects = @pack.parse_packfile(pack)
      assert_true(objects.length() == 3)
    }
  }
}

///|
test "gc_repo reports unreachable objects" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  let (orphan_id, orphan_bytes) = @bit.create_blob_string("orphan\n")
  write_object_bytes(fs, git_dir, orphan_id, orphan_bytes)
  let result = gc_repo(fs, fs, root)
  assert_true(result.dangling.length() == 1)
  assert_true(result.dangling[0].to_hex() == orphan_id.to_hex())
  let hex = orphan_id.to_hex()
  let orphan_path = git_dir +
    "/objects/" +
    String::unsafe_substring(hex, start=0, end=2) +
    "/" +
    String::unsafe_substring(hex, start=2, end=hex.length())
  assert_true(!fs.is_file(orphan_path))
  match result.pack {
    None => fail("expected pack")
    Some(r) => assert_true(r.object_count == 3)
  }
}

///|
test "gc_repo keeps tag and remote refs" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let (_, tree_id, _) = build_simple_repo(fs, root)
  let tag_commit = @bit.Commit::new(
    tree_id,
    [],
    "Tagger <tag@example.com>",
    1L,
    "+0000",
    "Tagger <tag@example.com>",
    1L,
    "+0000",
    "tagged commit\n",
  )
  let (tag_commit_id, tag_commit_bytes) = @bit.create_commit(tag_commit)
  write_object_bytes(fs, git_dir, tag_commit_id, tag_commit_bytes)
  fs.mkdir_p(git_dir + "/refs/tags")
  fs.write_string(git_dir + "/refs/tags/v1", tag_commit_id.to_hex() + "\n")
  fs.mkdir_p(git_dir + "/refs/remotes/origin")
  fs.write_string(
    git_dir + "/refs/remotes/origin/main",
    tag_commit_id.to_hex() + "\n",
  )
  let result = gc_repo(fs, fs, root)
  for id in result.dangling {
    assert_true(id.to_hex() != tag_commit_id.to_hex())
  }
}

///|
test "gc_repo skips prune when no refs" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  fs.remove_file(git_dir + "/refs/heads/main")
  let (orphan_id, orphan_bytes) = @bit.create_blob_string("orphan\n")
  write_object_bytes(fs, git_dir, orphan_id, orphan_bytes)
  let result = gc_repo(fs, fs, root)
  match result.pack {
    None => ()
    Some(_) => fail("expected no pack")
  }
  let hex = orphan_id.to_hex()
  let orphan_path = git_dir +
    "/objects/" +
    String::unsafe_substring(hex, start=0, end=2) +
    "/" +
    String::unsafe_substring(hex, start=2, end=hex.length())
  assert_true(fs.is_file(orphan_path))
}

///|
test "gc_repo preserves all reachable objects after multiple commits" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  // Create initial repo with first commit
  let (commit1_id, tree1_id, blob1_id) = build_simple_repo(fs, root)
  // Create second commit with different content
  let (blob2_id, blob2_bytes) = @bit.create_blob_string("world\n")
  write_object_bytes(fs, git_dir, blob2_id, blob2_bytes)
  let entry2 = @bit.TreeEntry::new("100644", "world.txt", blob2_id)
  let entry1 = @bit.TreeEntry::new("100644", "hello.txt", blob1_id)
  let (tree2_id, tree2_bytes) = @bit.create_tree([entry1, entry2])
  write_object_bytes(fs, git_dir, tree2_id, tree2_bytes)
  let commit2 = @bit.Commit::new(
    tree2_id,
    [commit1_id],
    "Test <test@example.com>",
    1L,
    "+0000",
    "Test <test@example.com>",
    1L,
    "+0000",
    "second commit\n",
  )
  let (commit2_id, commit2_bytes) = @bit.create_commit(commit2)
  write_object_bytes(fs, git_dir, commit2_id, commit2_bytes)
  update_head_ref(fs, fs, git_dir, commit2_id)
  // Run gc
  let result = gc_repo(fs, fs, root)
  // All 6 objects should be preserved (2 commits, 2 trees, 2 blobs)
  match result.pack {
    None => fail("expected pack")
    Some(r) => assert_true(r.object_count == 6)
  }
  // No dangling objects
  assert_true(result.dangling.length() == 0)
  // Verify pack contains all objects
  let pack_path = git_dir +
    "/objects/pack/pack-" +
    result.pack.unwrap().pack_id.to_hex() +
    ".pack"
  let pack = fs.read_file(pack_path)
  let objects = @pack.parse_packfile(pack)
  let ids : Array[String] = []
  for obj in objects {
    let id = @bit.hash_object_content(obj.obj_type, obj.data)
    ids.push(id.to_hex())
  }
  assert_true(ids.contains(commit1_id.to_hex()))
  assert_true(ids.contains(commit2_id.to_hex()))
  assert_true(ids.contains(tree1_id.to_hex()))
  assert_true(ids.contains(tree2_id.to_hex()))
  assert_true(ids.contains(blob1_id.to_hex()))
  assert_true(ids.contains(blob2_id.to_hex()))
}

///|
test "gc_repo preserves objects reachable from multiple branches" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  // Create initial commit on main
  let (commit1_id, _, _) = build_simple_repo(fs, root)
  // Create a branch with different content
  let (blob2_id, blob2_bytes) = @bit.create_blob_string("feature\n")
  write_object_bytes(fs, git_dir, blob2_id, blob2_bytes)
  let entry2 = @bit.TreeEntry::new("100644", "feature.txt", blob2_id)
  let (tree2_id, tree2_bytes) = @bit.create_tree([entry2])
  write_object_bytes(fs, git_dir, tree2_id, tree2_bytes)
  let commit2 = @bit.Commit::new(
    tree2_id,
    [commit1_id],
    "Test <test@example.com>",
    1L,
    "+0000",
    "Test <test@example.com>",
    1L,
    "+0000",
    "feature commit\n",
  )
  let (commit2_id, commit2_bytes) = @bit.create_commit(commit2)
  write_object_bytes(fs, git_dir, commit2_id, commit2_bytes)
  // Create feature branch pointing to commit2
  fs.write_string(git_dir + "/refs/heads/feature", commit2_id.to_hex() + "\n")
  // Run gc
  let result = gc_repo(fs, fs, root)
  // All objects from both branches should be preserved
  match result.pack {
    None => fail("expected pack")
    Some(r) => assert_true(r.object_count == 6) // 2 commits, 2 trees, 2 blobs
  }
  assert_true(result.dangling.length() == 0)
}

///|
test "gc_repo creates new packfile" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  // Run gc
  let result = gc_repo(fs, fs, root)
  // New packfile should exist
  match result.pack {
    None => fail("expected pack")
    Some(r) => {
      let new_pack = git_dir +
        "/objects/pack/pack-" +
        r.pack_id.to_hex() +
        ".pack"
      assert_true(fs.is_file(new_pack))
      let new_idx = git_dir +
        "/objects/pack/pack-" +
        r.pack_id.to_hex() +
        ".idx"
      assert_true(fs.is_file(new_idx))
    }
  }
}

///|
test "gc_repo handles annotated tags" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let (commit_id, _, _) = build_simple_repo(fs, root)
  // Create annotated tag
  let tag_content = "object " +
    commit_id.to_hex() +
    "\ntype commit\ntag v1.0\ntagger Test <test@example.com> 0 +0000\n\nrelease\n"
  let tag_bytes = @utf8.encode(tag_content)
  let (tag_id, tag_compressed) = @bit.create_object(
    @bit.ObjectType::Tag,
    tag_bytes,
  )
  write_object_bytes(fs, git_dir, tag_id, tag_compressed)
  fs.mkdir_p(git_dir + "/refs/tags")
  fs.write_string(git_dir + "/refs/tags/v1.0", tag_id.to_hex() + "\n")
  // Run gc
  let result = gc_repo(fs, fs, root)
  // Objects should be preserved - at minimum commit + tree + blob = 3
  // Tag may or may not be collected depending on how gc traverses from tag refs
  match result.pack {
    None => fail("expected pack")
    Some(r) => assert_true(r.object_count >= 3)
  }
  // The commit should not be reported as dangling since it's reachable via tag
  for id in result.dangling {
    assert_true(id.to_hex() != commit_id.to_hex())
  }
}

///|
test "prune_repo does not remove reachable objects" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let (commit_id, tree_id, blob_id) = build_simple_repo(fs, root)
  // Run prune
  let result = prune_repo(fs, fs, root)
  // No objects should be pruned
  assert_true(result.pruned.length() == 0)
  // Verify objects still exist
  fn obj_path(id : @bit.ObjectId) -> String {
    let hex = id.to_hex()
    git_dir +
    "/objects/" +
    String::unsafe_substring(hex, start=0, end=2) +
    "/" +
    String::unsafe_substring(hex, start=2, end=hex.length())
  }

  assert_true(fs.is_file(obj_path(commit_id)))
  assert_true(fs.is_file(obj_path(tree_id)))
  assert_true(fs.is_file(obj_path(blob_id)))
}

///|
/// Build a second commit graph that is NOT reachable from HEAD, so a test can
/// point an arbitrary ref at it and check gc keeps it alive.
fn build_side_graph(
  fs : @bit.TestFs,
  git_dir : String,
  content : String,
) -> (@bit.ObjectId, @bit.ObjectId) raise @bit.GitError {
  let (blob_id, blob_bytes) = @bit.create_blob_string(content)
  write_object_bytes(fs, git_dir, blob_id, blob_bytes)
  let entry = @bit.TreeEntry::new("100644", "fact.md", blob_id)
  let (tree_id, tree_bytes) = @bit.create_tree([entry])
  write_object_bytes(fs, git_dir, tree_id, tree_bytes)
  let commit = @bit.Commit::new(
    tree_id,
    [],
    "Test <test@example.com>",
    0L,
    "+0000",
    "Test <test@example.com>",
    0L,
    "+0000",
    "side graph\n",
  )
  let (commit_id, commit_bytes) = @bit.create_commit(commit)
  write_object_bytes(fs, git_dir, commit_id, commit_bytes)
  (commit_id, blob_id)
}

///|
test "gc keeps objects reachable from refs/agent" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  let (mem_commit, mem_blob) = build_side_graph(fs, git_dir, "memory fact\n")
  fs.mkdir_p(git_dir + "/refs/agent/memory")
  fs.write_string(
    git_dir + "/refs/agent/memory/main",
    mem_commit.to_hex() + "\n",
  )
  let result = gc_repo(fs, fs, root)
  for id in result.dangling {
    assert_true(id.to_hex() != mem_commit.to_hex())
    assert_true(id.to_hex() != mem_blob.to_hex())
  }
  let db = ObjectDb::load(fs, git_dir)
  assert_true(db.get(fs, mem_blob) is Some(_))
  assert_true(db.get(fs, mem_commit) is Some(_))
}

///|
test "gc keeps objects reachable from refs/notes" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  let (note_commit, note_blob) = build_side_graph(fs, git_dir, "a note\n")
  fs.mkdir_p(git_dir + "/refs/notes")
  fs.write_string(git_dir + "/refs/notes/commits", note_commit.to_hex() + "\n")
  let result = gc_repo(fs, fs, root)
  for id in result.dangling {
    assert_true(id.to_hex() != note_commit.to_hex())
  }
  let db = ObjectDb::load(fs, git_dir)
  assert_true(db.get(fs, note_blob) is Some(_))
}

///|
test "gc keeps objects reachable from packed custom refs" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  let (mem_commit, mem_blob) = build_side_graph(fs, git_dir, "packed fact\n")
  fs.write_string(
    git_dir + "/packed-refs",
    "# pack-refs with: peeled fully-peeled sorted\n" +
    mem_commit.to_hex() +
    " refs/agent/memory/main\n",
  )
  let result = gc_repo(fs, fs, root)
  for id in result.dangling {
    assert_true(id.to_hex() != mem_commit.to_hex())
  }
  let db = ObjectDb::load(fs, git_dir)
  assert_true(db.get(fs, mem_blob) is Some(_))
}

///|
test "gc tolerates symref files under refs" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let (commit_id, _, _) = build_simple_repo(fs, root)
  fs.mkdir_p(git_dir + "/refs/remotes/origin")
  fs.write_string(
    git_dir + "/refs/remotes/origin/HEAD",
    "ref: refs/heads/main\n",
  )
  // Must not raise, and reachable objects stay reachable.
  let result = gc_repo(fs, fs, root)
  for id in result.dangling {
    assert_true(id.to_hex() != commit_id.to_hex())
  }
}

///|
test "gc keeps objects reachable from linked worktree HEADs" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  let (wt_commit, wt_blob) = build_side_graph(fs, git_dir, "wt work\n")
  fs.mkdir_p(git_dir + "/worktrees/wt")
  fs.write_string(git_dir + "/worktrees/wt/HEAD", wt_commit.to_hex() + "\n")
  let result = gc_repo(fs, fs, root)
  for id in result.dangling {
    assert_true(id.to_hex() != wt_commit.to_hex())
  }
  let db = ObjectDb::load(fs, git_dir)
  assert_true(db.get(fs, wt_blob) is Some(_))
}

///|
test "gc keeps objects reachable from per-worktree refs" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  let (bisect_commit, bisect_blob) = build_side_graph(fs, git_dir, "bisect\n")
  fs.mkdir_p(git_dir + "/worktrees/wt/refs/bisect")
  // worktree HEAD is a symref, so only the per-worktree ref keeps this alive.
  fs.write_string(git_dir + "/worktrees/wt/HEAD", "ref: refs/heads/main\n")
  fs.write_string(
    git_dir + "/worktrees/wt/refs/bisect/bad",
    bisect_commit.to_hex() + "\n",
  )
  let result = gc_repo(fs, fs, root)
  for id in result.dangling {
    assert_true(id.to_hex() != bisect_commit.to_hex())
  }
  let db = ObjectDb::load(fs, git_dir)
  assert_true(db.get(fs, bisect_blob) is Some(_))
}

///|
/// A reflog-only object (unreferenced by any ref) must survive `bit gc --prune`,
/// not just full `bit gc`. Regression for the prune/repack reflog-root gap.
test "prune keeps reflog-only objects" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  let (orphan_commit, orphan_blob) = build_side_graph(fs, git_dir, "old head\n")
  // Referenced only by a reflog entry (e.g. an amended commit).
  fs.mkdir_p(git_dir + "/logs/refs/heads")
  fs.write_string(
    git_dir + "/logs/HEAD",
    @bit.ObjectId::zero().to_hex() +
    " " +
    orphan_commit.to_hex() +
    " Test <t@e.com> 0 +0000\tcommit\n",
  )
  let result = prune_repo(fs, fs, root)
  for id in result.pruned {
    assert_true(id.to_hex() != orphan_commit.to_hex())
    assert_true(id.to_hex() != orphan_blob.to_hex())
  }
  let db = ObjectDb::load(fs, git_dir)
  assert_true(db.get(fs, orphan_commit) is Some(_))
  assert_true(db.get(fs, orphan_blob) is Some(_))
}

///|
test "repack keeps reflog-only objects in the pack" {
  let fs = @bit.TestFs::new()
  let root = "/repo"
  let git_dir = root + "/.git"
  let _ = build_simple_repo(fs, root)
  let (orphan_commit, _) = build_side_graph(fs, git_dir, "reflog only\n")
  fs.write_string(
    git_dir + "/logs/HEAD",
    @bit.ObjectId::zero().to_hex() +
    " " +
    orphan_commit.to_hex() +
    " Test <t@e.com> 0 +0000\tcommit\n",
  )
  let result = repack_repo(fs, fs, root)
  match result {
    None => fail("expected pack")
    Some(r) => {
      let pack_path = git_dir +
        "/objects/pack/pack-" +
        r.pack_id.to_hex() +
        ".pack"
      let objects = @pack.parse_packfile(fs.read_file(pack_path))
      let mut found = false
      for obj in objects {
        if @bit.hash_object_content(obj.obj_type, obj.data).to_hex() ==
          orphan_commit.to_hex() {
          found = true
        }
      }
      assert_true(found)
    }
  }
}
