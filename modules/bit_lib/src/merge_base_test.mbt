///| Tests for merge-base algorithms

///|
/// Build a diamond commit graph: A -> B, A -> C, B -> D, C -> D
/// Returns (A, B, C, D) ObjectIds
fn build_diamond_graph(
  fs : @bit.TestFs,
  git_dir : String,
) -> (@bit.ObjectId, @bit.ObjectId, @bit.ObjectId, @bit.ObjectId) raise @bit.GitError {
  // A: root commit
  let (blob_a_id, blob_a_bytes) = @bit.create_blob_string("a\n")
  write_object_bytes(fs, git_dir, blob_a_id, blob_a_bytes)
  let entry_a = @bit.TreeEntry::new("100644", "a.txt", blob_a_id)
  let (tree_a_id, tree_a_bytes) = @bit.create_tree([entry_a])
  write_object_bytes(fs, git_dir, tree_a_id, tree_a_bytes)
  let commit_a = @bit.Commit::new(
    tree_a_id,
    [],
    "Test <t@x.com>",
    1000L,
    "+0000",
    "Test <t@x.com>",
    1000L,
    "+0000",
    "A\n",
  )
  let (a_id, a_bytes) = @bit.create_commit(commit_a)
  write_object_bytes(fs, git_dir, a_id, a_bytes)
  // B: child of A
  let (blob_b_id, blob_b_bytes) = @bit.create_blob_string("b\n")
  write_object_bytes(fs, git_dir, blob_b_id, blob_b_bytes)
  let entry_b = @bit.TreeEntry::new("100644", "b.txt", blob_b_id)
  let (tree_b_id, tree_b_bytes) = @bit.create_tree([entry_a, entry_b])
  write_object_bytes(fs, git_dir, tree_b_id, tree_b_bytes)
  let commit_b = @bit.Commit::new(
    tree_b_id,
    [a_id],
    "Test <t@x.com>",
    2000L,
    "+0000",
    "Test <t@x.com>",
    2000L,
    "+0000",
    "B\n",
  )
  let (b_id, b_bytes) = @bit.create_commit(commit_b)
  write_object_bytes(fs, git_dir, b_id, b_bytes)
  // C: child of A
  let (blob_c_id, blob_c_bytes) = @bit.create_blob_string("c\n")
  write_object_bytes(fs, git_dir, blob_c_id, blob_c_bytes)
  let entry_c = @bit.TreeEntry::new("100644", "c.txt", blob_c_id)
  let (tree_c_id, tree_c_bytes) = @bit.create_tree([entry_a, entry_c])
  write_object_bytes(fs, git_dir, tree_c_id, tree_c_bytes)
  let commit_c = @bit.Commit::new(
    tree_c_id,
    [a_id],
    "Test <t@x.com>",
    3000L,
    "+0000",
    "Test <t@x.com>",
    3000L,
    "+0000",
    "C\n",
  )
  let (c_id, c_bytes) = @bit.create_commit(commit_c)
  write_object_bytes(fs, git_dir, c_id, c_bytes)
  // D: child of B and C (merge commit)
  let (tree_d_id, tree_d_bytes) = @bit.create_tree([entry_a, entry_b, entry_c])
  write_object_bytes(fs, git_dir, tree_d_id, tree_d_bytes)
  let commit_d = @bit.Commit::new(
    tree_d_id,
    [b_id, c_id],
    "Test <t@x.com>",
    4000L,
    "+0000",
    "Test <t@x.com>",
    4000L,
    "+0000",
    "D\n",
  )
  let (d_id, d_bytes) = @bit.create_commit(commit_d)
  write_object_bytes(fs, git_dir, d_id, d_bytes)
  (a_id, b_id, c_id, d_id)
}

///|
test "merge_base_is_ancestor: A is ancestor of D" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  init_repo(fs, "/repo")
  let (a, _b, _c, d) = build_diamond_graph(fs, git_dir)
  let db = ObjectDb::load(fs, git_dir)
  assert_true(merge_base_is_ancestor(db, fs, a, d))
}

///|
test "merge_base_is_ancestor: D is not ancestor of A" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  init_repo(fs, "/repo")
  let (a, _b, _c, d) = build_diamond_graph(fs, git_dir)
  let db = ObjectDb::load(fs, git_dir)
  assert_false(merge_base_is_ancestor(db, fs, d, a))
}

///|
test "merge_base_is_ancestor: same commit" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  init_repo(fs, "/repo")
  let (a, _b, _c, _d) = build_diamond_graph(fs, git_dir)
  let db = ObjectDb::load(fs, git_dir)
  assert_true(merge_base_is_ancestor(db, fs, a, a))
}

///|
test "merge_base_all: merge-base(B, C) = A" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  init_repo(fs, "/repo")
  let (a, b, c, _d) = build_diamond_graph(fs, git_dir)
  let db = ObjectDb::load(fs, git_dir)
  let bases = merge_base_all(db, fs, b, c)
  assert_eq(bases.length(), 1)
  assert_eq(bases[0].to_hex(), a.to_hex())
}

///|
test "merge_base_independent: B and C are independent" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  init_repo(fs, "/repo")
  let (_a, b, c, _d) = build_diamond_graph(fs, git_dir)
  let db = ObjectDb::load(fs, git_dir)
  let indep = merge_base_independent(db, fs, [b, c])
  assert_eq(indep.length(), 2)
}

///|
test "merge_base_independent: A and D — only D is independent" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  init_repo(fs, "/repo")
  let (a, _b, _c, d) = build_diamond_graph(fs, git_dir)
  let db = ObjectDb::load(fs, git_dir)
  let indep = merge_base_independent(db, fs, [a, d])
  assert_eq(indep.length(), 1)
  assert_eq(indep[0].to_hex(), d.to_hex())
}
