///|
test "hooks: is_valid_hook_name validates simple names" {
  assert_true(is_valid_hook_name("pre-add"))
  assert_true(is_valid_hook_name("post-add"))
  assert_true(is_valid_hook_name("hook_name"))
  assert_false(is_valid_hook_name(""))
  assert_false(is_valid_hook_name("."))
  assert_false(is_valid_hook_name(".."))
  assert_false(is_valid_hook_name("path/to/name"))
  assert_false(is_valid_hook_name("path\\to\\name"))
  assert_false(is_valid_hook_name("with space"))
}

///|
test "hooks: list_hooks sorts and filters installed hooks" {
  let fs = OsFs::new()
  let root =
    "/tmp/bit-test-hooks-list-" + get_current_timestamp().to_string()
  let git_dir = root + "/.git"
  fs.mkdir_p(git_dir + "/hooks")
  fs.write_string(git_dir + "/hooks/pre-add", "#!/bin/sh\n")
  fs.write_string(git_dir + "/hooks/post-add", "#!/bin/sh\n")
  fs.write_string(git_dir + "/hooks/pre-commit", "#!/bin/sh\n")
  let all = list_hooks(fs, git_dir, None)
  assert_eq(all, ["post-add", "pre-add", "pre-commit"])
  let filtered = list_hooks(fs, git_dir, Some("pre"))
  assert_eq(filtered, ["pre-add", "pre-commit"])

  fs.remove_file(git_dir + "/hooks/pre-add") catch {
    _ => ()
  }
  fs.remove_file(git_dir + "/hooks/post-add") catch {
    _ => ()
  }
  fs.remove_file(git_dir + "/hooks/pre-commit") catch {
    _ => ()
  }
  fs.remove_dir(git_dir + "/hooks") catch {
    _ => ()
  }
  fs.remove_dir(git_dir) catch {
    _ => ()
  }
  fs.remove_dir(root) catch {
    _ => ()
  }
}
