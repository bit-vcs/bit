///| Tests for commit-graph writer

///|
test "cgraph: write_u32 via midx_push_u32" {
  let buf : Array[Byte] = []
  midx_push_u32(buf, 0x43475048)
  assert_eq(buf[0].to_int(), 0x43)
  assert_eq(buf[1].to_int(), 0x47)
  assert_eq(buf[2].to_int(), 0x50)
  assert_eq(buf[3].to_int(), 0x48)
}

///|
test "cgraph: compare_oid_bytes equal" {
  let a = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let b = @bitcore.ObjectId::from_hex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  assert_eq(cgraph_compare_oid_bytes(a.bytes, b.bytes, 20), 0)
}

///|
test "cgraph: compare_oid_bytes less" {
  let a = @bitcore.ObjectId::from_hex(
    "1111111111111111111111111111111111111111",
  )
  let b = @bitcore.ObjectId::from_hex(
    "2222222222222222222222222222222222222222",
  )
  assert_true(cgraph_compare_oid_bytes(a.bytes, b.bytes, 20) < 0)
  assert_true(cgraph_compare_oid_bytes(b.bytes, a.bytes, 20) > 0)
}

///|
test "cgraph: extract_committer_timestamp" {
  let commit_text = "tree aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\nauthor Test <test@test.com> 1700000000 +0000\ncommitter Test <test@test.com> 1700000001 +0000\n\ntest commit\n"
  let data = @utf8.encode(commit_text)
  assert_eq(@tar.tar_parse_committer_timestamp(data), 1700000001L)
}

///|
test "cgraph: extract_committer_timestamp missing" {
  let commit_text = "tree aaaa\n\nno committer\n"
  let data = @utf8.encode(commit_text)
  assert_eq(@tar.tar_parse_committer_timestamp(data), 0L)
}

///|
fn cgraph_setup_sha256_repo(
  fs : OsFs,
  root : String,
) -> (String, @bitcore.ObjectId) raise @bitcore.GitError {
  let git_dir = root + "/.git"
  @bitlib.init_repo_with_options(fs, root, {
    default_branch: "main",
    bare: false,
    separate_git_dir: None,
    template_dir: None,
    ref_format: "files",
    object_format: "sha256",
    is_reinit: false,
    git_dir: None,
    work_tree: None,
    shared: None,
  })
  let algo = @bitobject.HashAlgorithm::Sha256
  let blob = @utf8.encode("hello\n")
  let (blob_id, blob_bytes) = @bitobject.create_object_with_algo(
    algo,
    @bitcore.ObjectType::Blob,
    blob,
  )
  @bitlib.write_object_bytes(fs, git_dir, blob_id, blob_bytes)
  let entry = @bitcore.TreeEntry::new("100644", "hello.txt", blob_id)
  let (tree_id, tree_bytes) = @bitobject.create_tree_with_algo(algo, [entry])
  @bitlib.write_object_bytes(fs, git_dir, tree_id, tree_bytes)
  let commit = @bitcore.Commit::new(
    tree_id,
    [],
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "Test <test@example.com>",
    1700000000L,
    "+0000",
    "test commit\n",
  )
  let (commit_id, commit_bytes) = @bitobject.create_commit_with_algo(
    algo, commit,
  )
  @bitlib.write_object_bytes(fs, git_dir, commit_id, commit_bytes)
  fs.write_string(git_dir + "/refs/heads/main", commit_id.to_hex() + "\n")
  (git_dir, commit_id)
}

///|
async test "cgraph: write_commit_graph uses sha256 trailer in sha256 repo" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-cgraph-sha256-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  let (git_dir, commit_id) = cgraph_setup_sha256_repo(fs, root)
  write_commit_graph(fs, git_dir, true)
  let graph_path = git_dir + "/objects/info/commit-graph"
  assert_true(fs.is_file(graph_path))
  let graph = fs.read_file(graph_path)
  assert_true(graph.length() > 32)
  assert_eq(graph[5].to_int(), 2)
  let body_len = graph.length() - 32
  let trailer = @bitcore.ObjectId::from_bytes_at(graph, body_len, hash_size=32)
  let expected = @bitcore.hash_prefix(graph, body_len, hash_size=32)
  assert_eq(trailer, expected)
  let reader = @bitlib.CommitGraphFile::load(fs, git_dir)
  assert_true(reader is Some(_))
  let graph_file = reader.unwrap()
  assert_true(graph_file.find_commit(commit_id) >= 0)
  cleanup_tree(fs, root)
}
