///|
test "refs/store: list refs merges loose and packed" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/refs/heads")
  let id = @bit.hash_blob(@utf8.encode("hello"))
  fs.write_string("/repo/.git/refs/heads/main", id.to_hex() + "\n")
  let id2 = @bit.hash_blob(@utf8.encode("world"))
  fs.write_string(
    "/repo/.git/packed-refs",
    "# pack-refs with: peeled fully-peeled\n\{id2.to_hex()} refs/tags/v1\n",
  )
  let refs = list_refs_with_ids(fs, "/repo/.git", None)
  @test.assert_eq(refs.get("refs/heads/main"), Some(id))
  @test.assert_eq(refs.get("refs/tags/v1"), Some(id2))
}

///|
test "refs/store: remove remote refs drops refs and logs trees" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/refs/remotes/origin")
  fs.write_string("/repo/.git/refs/remotes/origin/main", "dummy")
  fs.mkdir_p("/repo/.git/logs/refs/remotes/origin")
  fs.write_string("/repo/.git/logs/refs/remotes/origin/main", "dummy")
  remove_remote_refs(fs, fs, "/repo/.git", "origin")
  assert_false(fs.is_dir("/repo/.git/refs/remotes/origin"))
  assert_false(fs.is_dir("/repo/.git/logs/refs/remotes/origin"))
}

///|
test "refs/store: serialize_packed_refs_entries sorts, dedupes, and keeps peel lines" {
  // Unsorted input with a duplicate refname (old value first, new value last)
  // and a peeled tag: the canonical form must be sorted, last-wins, with
  // git's exact header.
  let entries = parse_packed_refs_text(
    "# pack-refs with: peeled fully-peeled sorted \n" +
    "1111111111111111111111111111111111111111 refs/tags/v1\n" +
    "^2222222222222222222222222222222222222222\n" +
    "3333333333333333333333333333333333333333 refs/notes/bit-hub\n" +
    "4444444444444444444444444444444444444444 refs/heads/main\n" +
    "5555555555555555555555555555555555555555 refs/notes/bit-hub\n",
  )
  let out = serialize_packed_refs_entries(entries)
  @test.assert_eq(
    out,
    "# pack-refs with: peeled fully-peeled sorted \n" +
    "4444444444444444444444444444444444444444 refs/heads/main\n" +
    "5555555555555555555555555555555555555555 refs/notes/bit-hub\n" +
    "1111111111111111111111111111111111111111 refs/tags/v1\n" +
    "^2222222222222222222222222222222222222222\n",
  )
}

///|
test "refs/store: parse_packed_refs_text attaches peel lines and skips header" {
  let entries = parse_packed_refs_text(
    "# pack-refs with: peeled fully-peeled sorted \n" +
    "1111111111111111111111111111111111111111 refs/tags/v1\n" +
    "^2222222222222222222222222222222222222222\n" +
    "4444444444444444444444444444444444444444 refs/heads/main\n",
  )
  @test.assert_eq(entries.length(), 2)
  @test.assert_eq(entries[0].refname, "refs/tags/v1")
  @test.assert_eq(
    entries[0].peeled,
    Some("2222222222222222222222222222222222222222"),
  )
  @test.assert_eq(entries[1].refname, "refs/heads/main")
  @test.assert_eq(entries[1].peeled, None)
}
