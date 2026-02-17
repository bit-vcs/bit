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

///|
test "hooks: list_hooks_with_status merges .git/hooks and .bit/hooks" {
  let fs = OsFs::new()
  let root =
    "/tmp/bit-test-hooks-list-status-" + get_current_timestamp().to_string()
  let git_dir = root + "/.git"
  fs.mkdir_p(git_dir + "/hooks")
  fs.mkdir_p(root + "/.bit/hooks")
  fs.write_string(root + "/.bit/hooks/pre-add", "#!/bin/sh\n")
  fs.write_string(git_dir + "/hooks/post-applypatch", "#!/bin/sh\n")
  fs.write_string(git_dir + "/hooks/pre-add", "#!/bin/sh\n")
  let status = list_hooks_with_status(fs, root, git_dir, None)
  assert_eq(status, [
    "post-applypatch (enabled)",
    "pre-add (available, enabled)",
  ])
  let filtered = list_hooks_with_status(fs, root, git_dir, Some("pre"))
  assert_eq(filtered, [
    "pre-add (available, enabled)",
  ])

  fs.remove_file(root + "/.bit/hooks/pre-add") catch {
    _ => ()
  }
  fs.remove_file(git_dir + "/hooks/post-applypatch") catch {
    _ => ()
  }
  fs.remove_file(git_dir + "/hooks/pre-add") catch {
    _ => ()
  }
  fs.remove_dir(git_dir + "/hooks") catch {
    _ => ()
  }
  fs.remove_dir(git_dir) catch {
    _ => ()
  }
  fs.remove_dir(root + "/.bit") catch {
    _ => ()
  }
  fs.remove_dir(root) catch {
    _ => ()
  }
}

///|
async test "hooks: set registers available hook and approve/unapprove operate independently" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-hooks-flow-" + get_current_timestamp().to_string()
  let git_dir = root + "/.git"
  fs.mkdir_p(root)
  fs.mkdir_p(git_dir)
  let source = root + "/source-hook"
  fs.write_string(source, "#!/bin/sh\necho test\n")
  await handle_x_hooks_set(fs, root, ["pre-commit", source])
  assert_true(fs.is_file(root + "/.bit/hooks/pre-commit"))
  await handle_x_hooks_approve(fs, root, git_dir, ["pre-commit"])
  assert_true(fs.is_file(git_dir + "/hooks/pre-commit"))
  await handle_x_hooks_unapprove(git_dir, ["pre-commit"])
  assert_false(fs.is_file(git_dir + "/hooks/pre-commit"))
  await handle_x_hooks_remove(fs, root, ["pre-commit"])
  assert_false(fs.is_file(root + "/.bit/hooks/pre-commit"))

  fs.remove_file(source) catch {
    _ => ()
  }
  fs.remove_dir(git_dir) catch {
    _ => ()
  }
  fs.remove_dir(root + "/.bit") catch {
    _ => ()
  }
  fs.remove_dir(root) catch {
    _ => ()
  }
}
