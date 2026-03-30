///|
test "init: normalize path preserves leading parent segments in relative paths" {
  assert_eq(init_normalize_path("./../realgit"), "../realgit")
  assert_eq(init_normalize_path("../../repo/.git"), "../../repo/.git")
}

///|
test "init: normalize path keeps absolute parent traversal rooted" {
  assert_eq(init_normalize_path("/tmp/work/../realgit"), "/tmp/realgit")
  assert_eq(init_normalize_path("/tmp/../../realgit"), "/realgit")
}

///|
test "init: shared mode parsing supports symbolic and octal values" {
  assert_eq(init_shared_file_mode(Some("group")), Some(0o660))
  assert_eq(init_shared_file_mode(Some("all")), Some(0o664))
  assert_eq(init_shared_file_mode(Some("0660")), Some(0o660))
  assert_eq(init_shared_file_mode(Some("umask")), None)
  assert_eq(init_shared_file_mode(Some("bogus")), None)
}

///|
test "init: shared directory mode derives traversal bits and setgid" {
  assert_eq(init_shared_dir_mode(0o660), 0o2770)
  assert_eq(init_shared_dir_mode(0o664), 0o2775)
  assert_eq(init_shared_dir_mode(0o640), 0o2750)
}

///|
async test "init: --object-format sha256 creates SHA-256 repo with valid config" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-init-sha256-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.set_env_var("GIT_SHIM_PWD", ".")

  handle_init(["-q", "--object-format", "sha256", root])

  // Verify repo structure
  assert_true(fs.is_dir(root + "/.git"))
  assert_true(fs.is_file(root + "/.git/HEAD"))

  // Verify config has objectformat = sha256
  let config_text = decode_bytes(fs.read_file(root + "/.git/config"))
  assert_true(config_text.contains("objectFormat = sha256"))

  // Verify SHA-256 hashing produces 64-char hex OIDs
  let content = Bytes::from_array(@utf8.encode("hello sha256\n").to_array())
  let id = @bitobject.hash_object_content_with_algo(
    @bitobject.HashAlgorithm::Sha256,
    @bitcore.ObjectType::Blob,
    content,
  )
  assert_eq(id.to_hex().length(), 64)
  assert_eq(id.hash_size(), 32)

  // Verify SHA-1 produces 40-char hex OIDs (baseline)
  let id_sha1 = @bitobject.hash_object_content_with_algo(
    @bitobject.HashAlgorithm::Sha1,
    @bitcore.ObjectType::Blob,
    content,
  )
  assert_eq(id_sha1.to_hex().length(), 40)
  assert_eq(id_sha1.hash_size(), 20)

  // Verify SHA-256 and SHA-1 produce different hashes
  assert_true(id.to_hex() != id_sha1.to_hex())

  // Verify round-trip: hex -> ObjectId -> hex
  let recovered = @bitcore.ObjectId::from_hex(id.to_hex())
  assert_eq(recovered.to_hex(), id.to_hex())
  assert_eq(recovered.hash_size(), 32)

  // Write object to SHA-256 repo and read it back
  let git_dir = root + "/.git"
  let (write_id, compressed) = @bitobject.create_object_with_algo(
    @bitobject.HashAlgorithm::Sha256,
    @bitcore.ObjectType::Blob,
    content,
  )
  assert_eq(write_id.to_hex().length(), 64)
  @bitlib.write_object_bytes(fs, git_dir, write_id, compressed)

  // Verify the loose object file exists at correct path
  let hex = write_id.to_hex()
  let obj_path = git_dir +
    "/objects/" +
    String::unsafe_substring(hex, start=0, end=2) +
    "/" +
    String::unsafe_substring(hex, start=2, end=hex.length())
  assert_true(fs.is_file(obj_path))

  // Read back and verify content matches
  let stored = fs.read_file(obj_path)
  let decompressed = @zlib.zlib_decompress(stored)
  let expected_header = "blob \{content.length()}\u0000"
  let header_bytes = Bytes::from_array(@utf8.encode(expected_header).to_array())
  // Verify decompressed data starts with correct header
  for i in 0..<header_bytes.length() {
    assert_eq(decompressed[i], header_bytes[i])
  }

  add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  add_test_restore_env("GIT_DIR", prev_git_dir)
  add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  cleanup_tree(fs, root)
}

///|
async test "init: respects GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-init-default-branch-env-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  let prev_default_branch = @sys.get_env_var(
    "GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME",
  )

  @sys.set_env_var("GIT_SHIM_CWD", root)
  @sys.set_env_var("GIT_SHIM_PWD", root)
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME", "main")

  handle_init(["-q", "repo"])

  assert_eq(
    decode_bytes(fs.read_file(root + "/repo/.git/HEAD")),
    "ref: refs/heads/main\n",
  )

  add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  add_test_restore_env("GIT_DIR", prev_git_dir)
  add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  add_test_restore_env(
    "GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME", prev_default_branch,
  )
  cleanup_tree(fs, root)
}
