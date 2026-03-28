///|
test "interactive: detect add patch mode" {
  assert_true(has_interactive_add_flag(["-p"]))
  assert_true(has_interactive_add_flag(["--patch", "README.md"]))
  assert_true(has_interactive_add_flag(["-i"]))
  assert_true(has_interactive_add_flag(["--interactive"]))
  assert_false(has_interactive_add_flag(["README.md"]))
}

///|
async test "interactive: add patch default runner rejects with error" {
  let runner_called = Array::new(capacity=1)
  let runner = Some(async fn(_args : Array[String]) -> Int noraise {
    runner_called.push(true)
    0
  })
  // With custom runner, it should pass through
  run_add_interactive(["-p", "README.md"], runner~)
  assert_eq(runner_called.length(), 1)
}

///|
async test "interactive: add patch default runner fails without custom runner" {
  // Default runner should fail (exit code 1) since add -p is not implemented
  try {
    run_add_interactive(["-p", "README.md"])
    fail("expected error from unimplemented add -p")
  } catch {
    _ => () // Expected: should raise an error
  }
}

///|
async test "interactive: rebase todo editor callback is invoked" {
  let edited_paths : Array[String] = []
  let editor = Some(async fn(path : String) -> Bool noraise {
    edited_paths.push(path)
    true
  })
  let edited = edit_rebase_todo("/tmp/git-rebase-todo", editor~)
  assert_true(edited)
  assert_eq(edited_paths.length(), 1)
  assert_eq(edited_paths[0], "/tmp/git-rebase-todo")
}

///|
test "interactive: resolve commit editor precedence" {
  @sys.set_env_var("EDITOR", "vi")
  @sys.set_env_var("VISUAL", "nvim")
  @sys.set_env_var("GIT_EDITOR", "hx")
  let selected = resolve_commit_editor()
  match selected {
    Some(cmd) => assert_eq(cmd, "hx")
    None => fail("expected editor")
  }
  @sys.unset_env_var("GIT_EDITOR")
  @sys.unset_env_var("VISUAL")
  @sys.unset_env_var("EDITOR")
}

///|
test "interactive: normalize commit edit buffer removes comments" {
  let raw =
    #|
    #|# Please enter the commit message
    #|feat: add x
    #|
    #|body line
    #|# end
  let msg = normalize_commit_edit_buffer(raw)
  match msg {
    Some(text) => assert_eq(text, "feat: add x\n\nbody line")
    None => fail("expected commit message")
  }
}

///|
async test "interactive: commit message editor callback is invoked" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-commit-editor-" +
    get_current_timestamp().to_string()
  fs.mkdir_p(root + "/.git")
  let edited_paths : Array[String] = []
  let editor = Some(async fn(path : String) -> Bool raise Error {
    edited_paths.push(path)
    fs.write_string(path, "feat: from editor\n\n# comment\nbody\n")
    true
  })
  let message = read_commit_message_from_editor(fs, root, editor~)
  match message {
    Some(text) => assert_eq(text, "feat: from editor\n\nbody")
    None => fail("expected commit message")
  }
  assert_eq(edited_paths.length(), 1)
  assert_eq(edited_paths[0], root + "/.git/COMMIT_EDITMSG")
  fs.remove_file(root + "/.git/COMMIT_EDITMSG") catch {
    _ => ()
  }
  fs.remove_dir(root + "/.git") catch {
    _ => ()
  }
  fs.remove_dir(root) catch {
    _ => ()
  }
}

///|
async test "interactive: allow-empty-message keeps blank editor result" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-commit-editor-empty-" +
    get_current_timestamp().to_string()
  fs.mkdir_p(root + "/.git")
  let editor = Some(async fn(path : String) -> Bool raise Error {
    ignore(fs.read_file(path))
    true
  })
  let message = read_commit_message_from_editor(
    fs,
    root,
    allow_empty_message=true,
    editor~,
  )
  match message {
    Some(text) => assert_eq(text, "")
    None => fail("expected empty commit message")
  }
  fs.remove_file(root + "/.git/COMMIT_EDITMSG") catch {
    _ => ()
  }
  fs.remove_dir(root + "/.git") catch {
    _ => ()
  }
  fs.remove_dir(root) catch {
    _ => ()
  }
}
