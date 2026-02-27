///|
test "fallback: need_real_git_for_autocrlf always returns false (native handling)" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-fallback-autocrlf-" +
    get_current_timestamp().to_string()
  fs.mkdir_p(root + "/.git")
  let cleanup = fn() {
    fs.remove_file(root + "/.git/config") catch {
      _ => ()
    }
    fs.remove_dir(root + "/.git") catch {
      _ => ()
    }
    fs.remove_dir(root) catch {
      _ => ()
    }
  }

  fs.write_file(
    root + "/.git/config",
    string_to_bytes("[core]\nautocrlf = true\n"),
  )
  assert_false(need_real_git_for_autocrlf(root))

  fs.write_file(
    root + "/.git/config",
    string_to_bytes("[core]\nautocrlf = input\n"),
  )
  assert_false(need_real_git_for_autocrlf(root))

  fs.write_file(
    root + "/.git/config",
    string_to_bytes("[core]\nautocrlf = false\n"),
  )
  assert_false(need_real_git_for_autocrlf(root))
  cleanup()
}

///|
test "fallback: need_real_git_for_gitattributes only triggers for filter/working-tree-encoding" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-fallback-gitattr-" +
    get_current_timestamp().to_string()
  fs.mkdir_p(root + "/.git")
  let cleanup = fn() {
    fs.remove_file(root + "/.gitattributes") catch {
      _ => ()
    }
    fs.remove_file(root + "/.git/config") catch {
      _ => ()
    }
    fs.remove_dir(root + "/.git") catch {
      _ => ()
    }
    fs.remove_dir(root) catch {
      _ => ()
    }
  }

  // text/eol attributes no longer trigger fallback (handled natively)
  fs.write_file(root + "/.gitattributes", string_to_bytes("*.txt -text\n"))
  assert_false(need_real_git_for_gitattributes(root))

  fs.write_file(root + "/.gitattributes", string_to_bytes("*.txt text\n"))
  assert_false(need_real_git_for_gitattributes(root))

  fs.write_file(root + "/.gitattributes", string_to_bytes("*.txt eol=crlf\n"))
  assert_false(need_real_git_for_gitattributes(root))

  // filter= still triggers fallback
  fs.write_file(
    root + "/.gitattributes",
    string_to_bytes("*.txt filter=foo diff=bar\n"),
  )
  assert_true(need_real_git_for_gitattributes(root))

  // working-tree-encoding= still triggers fallback
  fs.write_file(
    root + "/.gitattributes",
    string_to_bytes("*.txt working-tree-encoding=UTF-16\n"),
  )
  assert_true(need_real_git_for_gitattributes(root))

  fs.write_file(
    root + "/.gitattributes",
    string_to_bytes("# comment only\n   \n"),
  )
  assert_false(need_real_git_for_gitattributes(root))
  cleanup()
}

///|
test "fallback: need_real_git_for_filtering combines autocrlf and gitattributes" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-fallback-filtering-" +
    get_current_timestamp().to_string()
  fs.mkdir_p(root + "/.git")
  let cleanup = fn() {
    fs.remove_file(root + "/.gitattributes") catch {
      _ => ()
    }
    fs.remove_file(root + "/.git/config") catch {
      _ => ()
    }
    fs.remove_dir(root + "/.git") catch {
      _ => ()
    }
    fs.remove_dir(root) catch {
      _ => ()
    }
  }

  // neither autocrlf nor gitattributes
  fs.write_file(
    root + "/.git/config",
    string_to_bytes("[core]\nautocrlf = false\n"),
  )
  assert_false(need_real_git_for_filtering(root))

  // autocrlf=true no longer triggers (native handling)
  fs.write_file(
    root + "/.git/config",
    string_to_bytes("[core]\nautocrlf = true\n"),
  )
  assert_false(need_real_git_for_filtering(root))

  // text attribute no longer triggers (native handling)
  fs.write_file(
    root + "/.git/config",
    string_to_bytes("[core]\nautocrlf = false\n"),
  )
  fs.write_file(root + "/.gitattributes", string_to_bytes("*.txt text\n"))
  assert_false(need_real_git_for_filtering(root))

  // filter= still triggers
  fs.write_file(root + "/.gitattributes", string_to_bytes("*.txt filter=lfs\n"))
  assert_true(need_real_git_for_filtering(root))
  cleanup()
}
