///|
test "is_lfs_pointer: valid pointer" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 12345\n"
  @test.assert_eq(is_lfs_pointer(content), true)
}

///|
test "is_lfs_pointer: empty content" {
  @test.assert_eq(is_lfs_pointer(b""), false)
}

///|
test "is_lfs_pointer: regular file content" {
  @test.assert_eq(is_lfs_pointer(b"hello world\n"), false)
}

///|
test "is_lfs_pointer: wrong version" {
  let content = b"version https://example.com/v1\noid sha256:abcd\nsize 100\n"
  @test.assert_eq(is_lfs_pointer(content), false)
}

///|
test "parse_lfs_pointer: valid pointer" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 12345\n"
  let ptr = parse_lfs_pointer(content)
  @test.assert_eq(ptr is None, false)
  let p = ptr.unwrap()
  @test.assert_eq(
    p.oid,
    "4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393",
  )
  @test.assert_eq(p.size, 12345L)
}

///|
test "parse_lfs_pointer: missing oid" {
  let content = b"version https://git-lfs.github.com/spec/v1\nsize 100\n"
  @test.assert_eq(parse_lfs_pointer(content) is None, true)
}

///|
test "parse_lfs_pointer: missing size" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\n"
  @test.assert_eq(parse_lfs_pointer(content) is None, true)
}

///|
test "parse_lfs_pointer: wrong version" {
  let content = b"version https://example.com/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 100\n"
  assert_true(parse_lfs_pointer(content) is None)
}

///|
test "parse_lfs_pointer: non-hex oid" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ\nsize 100\n"
  assert_true(parse_lfs_pointer(content) is None)
}

///|
test "lfs_object_path: correct sharding" {
  let path = lfs_object_path(
    "/repo/.git", "4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393",
  )
  @test.assert_eq(
    path, "/repo/.git/lfs/objects/4d/7a/4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393",
  )
}

///|
test "resolve_lfs_url: from lfs.url config" {
  let url = resolve_lfs_url_from_config(
    lfs_url="https://custom-lfs.example.com",
    remote_lfs_url="",
    remote_url="https://github.com/user/repo.git",
  )
  @test.assert_eq(url, "https://custom-lfs.example.com")
}

///|
test "resolve_lfs_url: from remote lfsurl" {
  let url = resolve_lfs_url_from_config(
    lfs_url="",
    remote_lfs_url="https://remote-lfs.example.com",
    remote_url="https://github.com/user/repo.git",
  )
  @test.assert_eq(url, "https://remote-lfs.example.com")
}

///|
test "resolve_lfs_url: derived from remote url with .git suffix" {
  let url = resolve_lfs_url_from_config(
    lfs_url="",
    remote_lfs_url="",
    remote_url="https://github.com/user/repo.git",
  )
  @test.assert_eq(url, "https://github.com/user/repo.git/info/lfs")
}

///|
test "resolve_lfs_url: derived from remote url without .git suffix" {
  let url = resolve_lfs_url_from_config(
    lfs_url="",
    remote_lfs_url="",
    remote_url="https://github.com/user/repo",
  )
  @test.assert_eq(url, "https://github.com/user/repo.git/info/lfs")
}

///|
test "resolve_lfs_url: relay session url does not add .git suffix" {
  let url = resolve_lfs_url_from_config(
    lfs_url="",
    remote_lfs_url="",
    remote_url="https://relay.example.com/git/abc123",
  )
  @test.assert_eq(url, "https://relay.example.com/git/abc123/info/lfs")
}

///|
test "resolve_lfs_url: lfs.url takes priority" {
  let url = resolve_lfs_url_from_config(
    lfs_url="https://priority.example.com",
    remote_lfs_url="https://remote-lfs.example.com",
    remote_url="https://github.com/user/repo.git",
  )
  @test.assert_eq(url, "https://priority.example.com")
}

///|
test "lfs_verify_oid: correct hash" {
  // SHA-256 of empty byte sequence
  let data = b""
  @test.assert_eq(
    lfs_verify_oid(
      data, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    ),
    true,
  )
}

///|
test "lfs_verify_oid: wrong hash" {
  let data = b"hello"
  @test.assert_eq(
    lfs_verify_oid(
      data, "0000000000000000000000000000000000000000000000000000000000000000",
    ),
    false,
  )
}

///|
test "lfs_is_valid_http_url: https" {
  @test.assert_eq(lfs_is_valid_http_url("https://example.com/lfs"), true)
}

///|
test "lfs_is_valid_http_url: http" {
  @test.assert_eq(lfs_is_valid_http_url("http://example.com/lfs"), true)
}

///|
test "lfs_is_valid_http_url: file scheme rejected" {
  @test.assert_eq(lfs_is_valid_http_url("file:///etc/passwd"), false)
}

///|
test "lfs_is_valid_http_url: ssh scheme rejected" {
  @test.assert_eq(lfs_is_valid_http_url("git@github.com:user/repo.git"), false)
}

///|
fn lfs_test_setup_repo() -> @bit.TestFs raise @bit.GitError {
  let fs = @bit.TestFs::new()
  init_repo(fs, "/repo")
  fs
}

///|
fn lfs_test_index_blob(
  fs : @bit.TestFs,
  path : String,
) -> Bytes raise @bit.GitError {
  let entries = read_index_entries(fs, "/repo/.git")
  for entry in entries {
    if entry.path == path {
      return ObjectDb::load(fs, "/repo/.git").get(fs, entry.id).unwrap().data
    }
  }
  b""
}

///|
test "lfs clean: add_paths stores pointer blob and caches content" {
  let fs = lfs_test_setup_repo()
  let content = b"large binary payload\nwith multiple lines\n"
  fs.write_string("/repo/.gitattributes", "*.bin filter=lfs\n")
  fs.write_file("/repo/asset.bin", content)

  add_paths(fs, fs, "/repo", ["asset.bin"])

  let blob = lfs_test_index_blob(fs, "asset.bin")
  assert_true(is_lfs_pointer(blob))
  let ptr = parse_lfs_pointer(blob).unwrap()
  @test.assert_eq(ptr.size, content.length().to_int64())
  assert_true(lfs_verify_oid(content, ptr.oid))
  @test.assert_eq(lfs_get_cached_content(fs, "/repo/.git", ptr.oid), Some(content))
  @test.assert_eq(fs.read_file("/repo/asset.bin"), content)
}

///|
async test "lfs clean: add_paths_async stores pointer blob and caches content" {
  let fs = lfs_test_setup_repo()
  let content = b"native add path payload\n"
  fs.write_string("/repo/.gitattributes", "*.bin filter=lfs\n")
  fs.write_file("/repo/asset.bin", content)

  add_paths_async(fs, fs, "/repo", ["asset.bin"])

  let blob = lfs_test_index_blob(fs, "asset.bin")
  assert_true(is_lfs_pointer(blob))
  let ptr = parse_lfs_pointer(blob).unwrap()
  @test.assert_eq(ptr.size, content.length().to_int64())
  assert_true(lfs_verify_oid(content, ptr.oid))
  @test.assert_eq(lfs_get_cached_content(fs, "/repo/.git", ptr.oid), Some(content))
  @test.assert_eq(fs.read_file("/repo/asset.bin"), content)
}

///|
async test "lfs clean: status compares worktree content through pointer" {
  let fs = lfs_test_setup_repo()
  let content = b"same payload after restat\n"
  fs.write_string("/repo/.gitattributes", "*.bin filter=lfs\n")
  fs.write_file("/repo/asset.bin", content)
  add_paths_async(fs, fs, "/repo", ["asset.bin"])

  fs.write_file("/repo/asset.bin", content)
  let st = status(fs, "/repo")

  assert_false(st.unstaged_modified.contains("asset.bin"))
}

///|
test "lfs clean: add_paths does not re-clean existing pointer" {
  let fs = lfs_test_setup_repo()
  let pointer = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 12345\n"
  fs.write_string("/repo/.gitattributes", "*.bin filter=lfs\n")
  fs.write_file("/repo/asset.bin", pointer)

  add_paths(fs, fs, "/repo", ["asset.bin"])

  let blob = lfs_test_index_blob(fs, "asset.bin")
  @test.assert_eq(blob, pointer)
  let ptr = parse_lfs_pointer(blob).unwrap()
  @test.assert_eq(lfs_get_cached_content(fs, "/repo/.git", ptr.oid), None)
}
