///| Pack index fixture tests (git index-pack output)

///|
/// Resolve a repo-root-relative fixture path independent of the test's working
/// directory. `moon test` does not guarantee the native test binary runs from
/// the repo root (this changed in moon 0.1.20260618, which broke the plain
/// "fixtures/..." reads), so walk up parent directories until the path exists.
fn resolve_fixture(path : String) -> String {
  let mut prefix = ""
  let mut i = 0
  while i < 32 {
    let candidate = prefix + path
    if @fs.path_exists(candidate) {
      return candidate
    }
    prefix = prefix + "../"
    i = i + 1
  }
  path
}

///|
fn read_fixture_bytes(path : String) -> Bytes raise {
  let resolved = resolve_fixture(path)
  @fs.read_file_to_bytes(resolved) catch {
    e =>
      fail("failed to read fixture: \{path} (\{@debug.render(@debug.to_repr(e))})")
  }
}

///|
fn assert_bytes_equal(actual : Bytes, expected : Bytes) -> Unit raise {
  if !Bytes::equal(actual, expected) {
    fail(
      "bytes mismatch: actual=\{actual.length()} expected=\{expected.length()}",
    )
  }
}

///|
fn assert_pack_idx_matches(pack_path : String, idx_path : String) -> Unit raise {
  let pack = read_fixture_bytes(pack_path)
  let expected = read_fixture_bytes(idx_path)
  let actual = build_pack_index(pack)
  assert_bytes_equal(actual, expected)
}

///|
test "pack index fixture: hello.pack" {
  assert_pack_idx_matches("fixtures/hello.pack", "fixtures/hello.idx")
}

///|
test "pack index fixture: oracle.pack" {
  assert_pack_idx_matches("fixtures/oracle.pack", "fixtures/oracle.idx")
}

///|
test "pack index fixture: oracle_deflate.pack" {
  assert_pack_idx_matches(
    "fixtures/oracle_deflate.pack", "fixtures/oracle_deflate.idx",
  )
}

///|
test "pack index fixture: oracle_delta.pack" {
  assert_pack_idx_matches(
    "fixtures/oracle_delta.pack", "fixtures/oracle_delta.idx",
  )
}

///|
test "pack index fixture: oracle_after_delta.pack" {
  assert_pack_idx_matches(
    "fixtures/oracle_after_delta.pack", "fixtures/oracle_after_delta.idx",
  )
}

///|
test "pack index fixture: oracle_thin_base.pack" {
  assert_pack_idx_matches(
    "fixtures/oracle_thin_base.pack", "fixtures/oracle_thin_base.idx",
  )
}
