///|
async test "native worktree probes handle UTF-8 paths and missing entries" {
  let root = @afs.tmpdir(prefix="bit-probe-")
  defer @afs.rmdir(root, recursive=true)
  let directory = root + "/目录"
  @afs.mkdir(directory)
  let path = directory + "/文件.txt"
  @afs.write_file(path, "hello")
  guard native_lstat_meta(path) is Some(meta) else {
    fail("missing file metadata")
  }
  assert_true(meta.kind is Regular)
  assert_eq(meta.size, Some(5))
  guard native_readdir_typed(directory) is Some(entries) else {
    fail("missing directory entries")
  }
  assert_eq(entries, [("文件.txt", 8)])
  assert_true(native_lstat_meta(directory + "/missing") is None)
  assert_eq(native_readdir_typed(directory + "/missing"), None)
  assert_eq(native_try_readlink(path), None)
}

///|
async test "native worktree probes preserve symbolic link targets" {
  let root = @afs.tmpdir(prefix="bit-probe-link-")
  defer @afs.rmdir(root, recursive=true)
  let path = root + "/链接"
  @afs.symlink(target="缺失.txt", path, force_symlink=true)
  guard native_lstat_meta(path) is Some(meta) else {
    fail("missing symlink metadata")
  }
  assert_true(meta.kind is Symlink)
  assert_eq(native_try_readlink(path), Some("缺失.txt"))
  guard native_readdir_typed(root) is Some(entries) else {
    fail("missing directory entries")
  }
  assert_eq(entries, [("链接", 10)])
}
