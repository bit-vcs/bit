///|
/// Fs whitebox tests
priv struct CountingFs {
  fs : @bit.TestFs
  read_counts : Map[String, Int]
  write_counts : Map[String, Int]
}

///|
fn CountingFs::new(fs : @bit.TestFs) -> CountingFs {
  { fs, read_counts: {}, write_counts: {} }
}

///|
fn CountingFs::clear_counts(self : CountingFs) -> Unit {
  self.read_counts.clear()
  self.write_counts.clear()
}

///|
fn CountingFs::read_count(self : CountingFs, path : String) -> Int {
  match self.read_counts.get(path) {
    Some(n) => n
    None => 0
  }
}

///|
fn CountingFs::write_count(self : CountingFs, path : String) -> Int {
  match self.write_counts.get(path) {
    Some(n) => n
    None => 0
  }
}

///|
fn loose_object_path(git_dir : String, id : @bit.ObjectId) -> String {
  let hex = id.to_hex()
  git_dir +
  "/objects/" +
  String::unsafe_substring(hex, start=0, end=2) +
  "/" +
  String::unsafe_substring(hex, start=2, end=hex.length())
}

///|
impl @bit.RepoFileSystem for CountingFs with read_file(self, path) {
  let count = match self.read_counts.get(path) {
    Some(n) => n
    None => 0
  }
  self.read_counts[path] = count + 1
  self.fs.read_file(path)
}

///|
impl @bit.RepoFileSystem for CountingFs with readdir(self, path) {
  self.fs.readdir(path)
}

///|
impl @bit.RepoFileSystem for CountingFs with is_dir(self, path) {
  self.fs.is_dir(path)
}

///|
impl @bit.RepoFileSystem for CountingFs with is_file(self, path) {
  self.fs.is_file(path)
}

///|
impl @bit.FileSystem for CountingFs with mkdir_p(self, path) {
  self.fs.mkdir_p(path)
}

///|
impl @bit.FileSystem for CountingFs with write_file(self, path, data) {
  let count = match self.write_counts.get(path) {
    Some(n) => n
    None => 0
  }
  self.write_counts[path] = count + 1
  self.fs.write_file(path, data)
}

///|
impl @bit.FileSystem for CountingFs with write_string(self, path, s) {
  let count = match self.write_counts.get(path) {
    Some(n) => n
    None => 0
  }
  self.write_counts[path] = count + 1
  self.fs.write_string(path, s)
}

///|
impl @bit.FileSystem for CountingFs with remove_file(self, path) {
  self.fs.remove_file(path)
}

///|
impl @bit.FileSystem for CountingFs with remove_dir(self, path) {
  self.fs.remove_dir(path)
}

///|
test "path: normalize_path removes leading and trailing slashes" {
  assert_eq(normalize_path("/foo/bar/"), "foo/bar")
  assert_eq(normalize_path("./foo"), "foo")
  assert_eq(normalize_path("foo"), "foo")
  assert_eq(normalize_path("/"), "")
}

///|
test "path: split_path splits into components" {
  assert_eq(split_path("a/b/c"), ["a", "b", "c"])
  assert_eq(split_path("/a/b/"), ["a", "b"])
  assert_eq(split_path(""), [])
}

///|
test "path: parent_dir returns parent directory" {
  assert_eq(parent_dir("/a/b/c"), "/a/b")
  assert_eq(parent_dir("/a"), "/")
  assert_eq(parent_dir("a"), "")
}

///|
test "path: basename returns file name" {
  assert_eq(basename("/a/b/c"), "c")
  assert_eq(basename("foo"), "foo")
}

///|
test "path: split_first splits at first slash" {
  assert_eq(split_first("a/b/c"), ("a", Some("b/c")))
  assert_eq(split_first("foo"), ("foo", None))
}

///|
test "cache: blob cache with LRU eviction" {
  let cache = ObjectCache::new(100)
  let data1 = Bytes::from_array([b'a', b'b', b'c'])
  let data2 = Bytes::from_array([b'd', b'e', b'f'])
  cache.set_blob("file1", data1)
  cache.set_blob("file2", data2)
  assert_eq(cache.get_blob("file1").unwrap(), data1)
  assert_eq(cache.get_blob("file2").unwrap(), data2)
  assert_eq(cache.blob_cache.total_bytes(), 6)
}

///|
test "cache: blob eviction when over limit" {
  let cache = ObjectCache::new(10)
  let data1 = Bytes::from_array([b'a', b'b', b'c', b'd', b'e'])
  let data2 = Bytes::from_array([b'1', b'2', b'3', b'4', b'5'])
  let data3 = Bytes::from_array([b'x', b'y', b'z'])
  cache.set_blob("file1", data1)
  cache.set_blob("file2", data2)
  assert_eq(cache.blob_cache.total_bytes(), 10)
  cache.set_blob("file3", data3)
  // Two-generation LRU evicts entire cold generation at once
  // file1 and file2 were moved to cold, then evicted
  assert_true(cache.get_blob("file1") is None)
  assert_true(cache.get_blob("file2") is None)
  assert_eq(cache.get_blob("file3").unwrap(), data3)
}

///|
test "cache: path cache invalidation" {
  let cache = ObjectCache::new(1000)
  let id = @bit.ObjectId::zero()
  cache.set_path("a/b/c", Some(id))
  cache.set_path("a/b/d", Some(id))
  cache.set_path("a/x", Some(id))
  assert_true(cache.get_path("a/b/c") is Some(_))
  cache.invalidate_path("a/b")
  assert_true(cache.get_path("a/b/c") is None)
  assert_true(cache.get_path("a/b/d") is None)
  assert_true(cache.get_path("a/x") is Some(_))
}

///|
test "cache: tree cache" {
  let cache = ObjectCache::new(1000)
  let id = @bit.ObjectId::zero()
  let entries = [@bit.TreeEntry::new("100644", "file.txt", id)]
  cache.set_tree(id, entries)
  assert_true(cache.get_tree(id) is Some(_))
}

///|
test "working_layer: clear resets state" {
  let layer = WorkingLayer::new()
  layer.files["test.txt"] = Bytes::from_array([b'a'])
  layer.deleted["old.txt"] = true
  layer.dirs["dir"] = true
  layer.dirty = true
  layer.clear()
  assert_eq(layer.files.length(), 0)
  assert_eq(layer.deleted.length(), 0)
  assert_eq(layer.dirs.length(), 0)
  assert_eq(layer.dirty, false)
}

///|
test "ensure_parent_dirs creates parent directories" {
  let layer = WorkingLayer::new()
  ensure_parent_dirs(layer, "a/b/c/file.txt")
  assert_true(layer.dirs.contains("a"))
  assert_true(layer.dirs.contains("a/b"))
  assert_true(layer.dirs.contains("a/b/c"))
  assert_false(layer.dirs.contains("a/b/c/file.txt"))
}

///|
test "read_ops: sibling path cache is warmed on first lookup" {
  let fs = @bit.TestFs::new()
  @lib.init_repo(fs, "/repo")
  let bitfs = Fs::empty("/repo/.git")
  bitfs.write_file("a.txt", b"a")
  bitfs.write_file("b.txt", b"b")
  let snap = bitfs.snapshot(fs, fs, "seed", "Bench <bench@example.com>", 1000L)
  bitfs.checkout_snapshot(fs, snap.commit_id)
  assert_eq(bitfs.cache.path_cache.length(), 0)
  let _ = bitfs.read_file(fs, "a.txt")
  assert_true(bitfs.cache.get_path("a.txt") is Some(Some(_)))
  assert_true(bitfs.cache.get_path("b.txt") is Some(Some(_)))
}

///|
test "snapshot: untouched subtree objects are not loaded or rewritten" {
  let cfs = CountingFs::new(@bit.TestFs::new())
  @lib.init_repo(cfs, "/repo")

  let seed = Fs::empty("/repo/.git")
  seed.write_file("hot/a.txt", b"v1")
  seed.write_file("cold/x.txt", b"x1")
  seed.write_file("cold/y.txt", b"y1")
  let base = seed.snapshot(cfs, cfs, "seed", "Bench <bench@example.com>", 1000L)

  let db = @lib.ObjectDb::load_lazy(cfs, "/repo/.git")
  let base_tree_obj = db.get(cfs, base.tree_id)
  assert_true(base_tree_obj is Some(_))
  let root_entries = @bit.parse_tree(base_tree_obj.unwrap().data)
  let mut cold_tree_id = @bit.ObjectId::zero()
  for entry in root_entries {
    if entry.name == "cold" {
      cold_tree_id = entry.id
    }
  }
  assert_true(cold_tree_id != @bit.ObjectId::zero())
  let cold_tree_path = loose_object_path("/repo/.git", cold_tree_id)

  let bitfs = Fs::from_commit(cfs, "/repo/.git", base.commit_id)
  cfs.clear_counts()
  bitfs.write_file("hot/a.txt", b"v2")
  let _ = bitfs.snapshot(cfs, cfs, "edit", "Bench <bench@example.com>", 1001L)

  assert_eq(cfs.read_count(cold_tree_path), 0)
  assert_eq(cfs.write_count(cold_tree_path), 0)
}
