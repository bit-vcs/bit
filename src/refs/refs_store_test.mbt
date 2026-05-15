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
  assert_eq(refs.get("refs/heads/main"), Some(id))
  assert_eq(refs.get("refs/tags/v1"), Some(id2))
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
