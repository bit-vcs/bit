///|
async fn remove_if_exists(path : String) -> Unit {
  try @fs.remove(path) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async fn rmdir_if_exists(path : String) -> Unit {
  try @fs.rmdir(path) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async fn rmdir_tree_if_exists(path : String) -> Unit {
  try @fs.rmdir(path, recursive=true) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async test "rename replaces existing file by default" {
  let src = "/tmp/mizchi_x_fs_rename_src.txt"
  let dst = "/tmp/mizchi_x_fs_rename_dst.txt"
  remove_if_exists(src)
  remove_if_exists(dst)

  @fs.write_file(src, "new")
  @fs.write_file(dst, "old")
  @fs.rename(src, dst)

  assert_false(@fs.exists(src))
  assert_eq(@fs.read_file(dst).text(), "new")
  @fs.remove(dst)
}

///|
async test "rename replace false keeps existing target" {
  let src = "/tmp/mizchi_x_fs_rename_no_replace_src.txt"
  let dst = "/tmp/mizchi_x_fs_rename_no_replace_dst.txt"
  remove_if_exists(src)
  remove_if_exists(dst)

  @fs.write_file(src, "new")
  @fs.write_file(dst, "old")
  let result : Result[Unit, @fs.IOError] = try
    @fs.rename(src, dst, replace=false)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  assert_true(result is Err(_))
  assert_true(@fs.exists(src))
  assert_eq(@fs.read_file(dst).text(), "old")
  @fs.remove(src)
  @fs.remove(dst)
}

///|
async test "directory next reports entry kind" {
  let dir = "/tmp/mizchi_x_fs_dir_next"
  let file = dir + "/file.txt"
  let subdir = dir + "/subdir"
  remove_if_exists(file)
  rmdir_if_exists(subdir)
  rmdir_tree_if_exists(dir)

  @fs.mkdir(dir, permission=0o755, recursive=true)
  @fs.write_file(file, "file")
  @fs.mkdir(subdir, permission=0o755, recursive=false)

  let handle = @fs.opendir(dir)
  defer handle.close()
  let mut seen_file = false
  let mut seen_subdir = false
  while handle.next(include_hidden=true) is Some(entry) {
    if entry.name == "file.txt" {
      seen_file = true
      assert_false(entry.is_dir)
    } else if entry.name == "subdir" {
      seen_subdir = true
      assert_true(entry.is_dir)
    }
  }

  assert_true(seen_file)
  assert_true(seen_subdir)
  @fs.remove(file)
  @fs.rmdir(subdir)
  @fs.rmdir(dir)
}

///|
async test "file create open append and read all" {
  let path = "/tmp/mizchi_x_fs_file_create_open.txt"
  remove_if_exists(path)
  {
    let file = @fs.create(path, sync=Full)
    defer file.close()
    file.write(b"alpha")
  }
  {
    let file = @fs.open(
      path,
      mode=WriteOnly,
      create_mode=OpenOrCreate,
      append=true,
    )
    defer file.close()
    file.write(b"-beta")
    file.sync()
  }
  {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    assert_eq(file.read_all().text(), "alpha-beta")
    assert_true(file.size() > 0L)
    assert_eq(file.kind(), Regular)
  }

  @fs.remove(path)
}

///|
async test "file random access read and write" {
  let path = "/tmp/mizchi_x_fs_random_access.txt"
  remove_if_exists(path)
  @fs.write_file(path, "abcdef", create_mode=CreateOrTruncate)
  {
    let file = @fs.open(path, mode=ReadWrite)
    defer file.close()
    file.write_at(b"34", position=2L)
    file.write_at(b"56", position=4L)
    assert_eq(file.read_exactly_at(2, position=2L), b"34")
    let buf = FixedArray::make(4, b'\x00')
    let n = file.read_at(buf, position=2L)
    assert_eq(n, 4)
  }

  assert_eq(@fs.read_file(path).text(), "ab3456")
  @fs.remove(path)
}

///|
async test "tmpdir creates unique directory" {
  let dir = @fs.tmpdir(prefix="mizchi_x_fs_tmp_")
  assert_true(@fs.exists(dir))
  assert_eq(@fs.kind(dir), Directory)
  @fs.rmdir(dir)
}

///|
async test "walk visits nested directories" {
  let root = "/tmp/mizchi_x_fs_walk"
  rmdir_tree_if_exists(root)
  @fs.mkdir(root + "/a/b", permission=0o755, recursive=true)
  @fs.write_file(root + "/root.txt", "root")
  @fs.write_file(root + "/a/child.txt", "child")
  @fs.write_file(root + "/a/b/grand.txt", "grand")

  let seen : Array[String] = []
  @fs.walk(root, max_concurrency=1, (path, files) => {
    files.sort()
    seen.push(path + ":" + files.join(","))
  })
  seen.sort()

  assert_true(seen.contains(root + ":a,root.txt"))
  assert_true(seen.contains(root + "/a:b,child.txt"))
  assert_true(seen.contains(root + "/a/b:grand.txt"))
  @fs.rmdir(root, recursive=true)
}

///|
async test "access helpers and chmod" {
  let path = "/tmp/mizchi_x_fs_access.txt"
  remove_if_exists(path)
  @fs.write_file(path, "access")

  assert_true(@fs.can_read(path))
  assert_true(@fs.can_write(path))
  @fs.chmod(path, 0o644)
  let (_s, ns) = @fs.mtime(path)
  assert_true(ns >= 0)

  @fs.remove(path)
}
