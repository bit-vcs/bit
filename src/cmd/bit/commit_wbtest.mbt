///|
async fn commit_wbtest_run_git(
  cwd : String,
  args : Array[String],
) -> Unit raise Error {
  let full_args : Array[String] = ["-c", "protocol.file.allow=always"]
  for arg in args {
    full_args.push(arg)
  }
  let (code, _, _) = @process.collect_output(
    "git",
    full_args[:],
    inherit_env=true,
    cwd~,
  )
  assert_eq(code, 0)
}

///|
async fn commit_wbtest_git_stderr(
  cwd : String,
  args : Array[String],
) -> (Int, String) raise Error {
  let full_args : Array[String] = ["-c", "protocol.file.allow=always"]
  for arg in args {
    full_args.push(arg)
  }
  let (code, _, stderr) = @process.collect_output(
    "git",
    full_args[:],
    inherit_env=true,
    cwd~,
  )
  let text = stderr.text() catch { _ => "" }
  (code, text)
}

///|
async fn signing_wbtest_write_fake_gpg(
  fs : OsFs,
  path : String,
) -> Unit raise Error {
  fs.write_string(
    path,
    "#!/bin/sh\n" +
    "if [ \"${1:-}\" = \"--verify\" ]; then\n" +
    "  sig=\"${2:-}\"\n" +
    "  if [ -f \"$sig\" ] && grep -q 'BEGIN PGP SIGNATURE' \"$sig\"; then\n" +
    "    echo 'gpg: Good signature from \"Test User <test@example.com>\"' >&2\n" +
    "    exit 0\n" +
    "  fi\n" +
    "  echo 'gpg: BAD signature' >&2\n" +
    "  exit 1\n" +
    "fi\n" +
    "cat >/dev/null\n" +
    "printf '%s\\n' \\\n" +
    "  '-----BEGIN PGP SIGNATURE-----' \\\n" +
    "  'abc123' \\\n" +
    "  '-----END PGP SIGNATURE-----'\n",
  )
  let chmod_code = @process.run("chmod", ["+x", path], inherit_env=true)
  assert_eq(chmod_code, 0)
}

///|
async fn signing_wbtest_write_fake_ssh_keygen(
  fs : OsFs,
  path : String,
) -> Unit raise Error {
  fs.write_string(
    path,
    "#!/bin/sh\n" +
    "last=''\n" +
    "for arg in \"$@\"; do\n" +
    "  last=\"$arg\"\n" +
    "done\n" +
    "printf '%s\\n' \\\n" +
    "  '-----BEGIN SSH SIGNATURE-----' \\\n" +
    "  'sshabc' \\\n" +
    "  '-----END SSH SIGNATURE-----' > \"${last}.sig\"\n",
  )
  let chmod_code = @process.run("chmod", ["+x", path], inherit_env=true)
  assert_eq(chmod_code, 0)
}

///|
fn commit_wbtest_find_entry(
  entries : Array[@bitlib.IndexEntry],
  path : String,
) -> @bitlib.IndexEntry {
  for entry in entries {
    if entry.path == path {
      return entry
    }
  }
  panic()
}

///|
test "commit: signing options are handled in standalone mode" {
  assert_false(commit_args_require_standalone_error(["-S", "-m", "msg"]))
  assert_false(
    commit_args_require_standalone_error(["-S/path/to/key", "-m", "msg"]),
  )
  assert_false(
    commit_args_require_standalone_error(["--gpg-sign", "-m", "msg"]),
  )
  assert_false(
    commit_args_require_standalone_error(["--gpg-sign=KEY", "-m", "msg"]),
  )
}

///|
test "commit: no-edit prefers SQUASH_MSG and appends MERGE_MSG comments" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string("/repo/.git/SQUASH_MSG", "squash body\n")
  fs.write_string("/repo/.git/MERGE_MSG", "\n# Conflicts:\n#\tfile\n")
  let msg = resolve_no_edit_commit_message(fs, "/repo", "/repo/.git", false)
  assert_eq(msg, Some("squash body\n\n# Conflicts:\n#\tfile\n"))
}

///|
test "commit: no-edit prefers MERGE_MSG when MERGE_HEAD exists" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string(
    "/repo/.git/MERGE_HEAD", "1111111111111111111111111111111111111111\n",
  )
  fs.write_string("/repo/.git/SQUASH_MSG", "squash body\n")
  fs.write_string("/repo/.git/MERGE_MSG", "merge body\n")
  let msg = resolve_no_edit_commit_message(fs, "/repo", "/repo/.git", false)
  assert_eq(msg, Some("merge body\n"))
}

///|
test "commit: read MERGE_HEAD supports multiple parents" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string(
    "/repo/.git/MERGE_HEAD", "1111111111111111111111111111111111111111\n2222222222222222222222222222222222222222\n",
  )
  let merge_heads = read_merge_head_ids(fs, "/repo/.git")
  assert_eq(merge_heads.length(), 2)
  assert_eq(merge_heads[0].to_hex(), "1111111111111111111111111111111111111111")
  assert_eq(merge_heads[1].to_hex(), "2222222222222222222222222222222222222222")
}

///|
test "commit: storage runtime routing handles normal and -a mode" {
  assert_true(commit_should_use_storage_runtime(["-m", "msg"]))
  assert_true(commit_should_use_storage_runtime(["--no-verify", "-m", "msg"]))
  assert_true(commit_should_use_storage_runtime(["-am", "msg"]))

  assert_false(commit_should_use_storage_runtime(["--amend", "-m", "msg"]))
  assert_false(commit_should_use_storage_runtime(["-F", "MSG_FILE"]))
}

///|
test "commit: cleanup mode validation honors verbatim" {
  assert_eq(commit_normalize_cleanup_mode("verbatim"), Some("verbatim"))
  assert_eq(commit_normalize_cleanup_mode("non-existent"), None)
  assert_eq(commit_prepare_message_for_validation("\n", "verbatim"), "\n")
  assert_eq(commit_prepare_message_for_validation("\n", "default"), "")
}

///|
async test "commit: pathspec staging updates submodule gitlink entry" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-commit-submodule-pathspec-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let sub_dir = root + "/sub"
  let super_dir = root + "/super"

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "sub"])
  commit_wbtest_run_git(sub_dir, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(sub_dir, ["config", "user.email", "test@example.com"])
  fs.write_string(sub_dir + "/a", "a\n")
  commit_wbtest_run_git(sub_dir, ["add", "a"])
  commit_wbtest_run_git(sub_dir, ["commit", "-q", "-m", "initial"])

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "super"])
  commit_wbtest_run_git(super_dir, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(super_dir, ["config", "user.email", "test@example.com"])

  let prev_allow_protocol = @sys.get_env_var("GIT_ALLOW_PROTOCOL")
  @sys.set_env_var("GIT_ALLOW_PROTOCOL", "file")
  commit_wbtest_run_git(super_dir, ["submodule", "add", "./../sub", "submodule"])
  commit_wbtest_run_git(super_dir, ["commit", "-qam", "initial"])
  match prev_allow_protocol {
    Some(value) => @sys.set_env_var("GIT_ALLOW_PROTOCOL", value)
    None => @sys.unset_env_var("GIT_ALLOW_PROTOCOL")
  }

  commit_wbtest_run_git(super_dir + "/submodule", [
    "config", "user.name", "Test User",
  ])
  commit_wbtest_run_git(super_dir + "/submodule", [
    "config", "user.email", "test@example.com",
  ])
  fs.write_string(super_dir + "/submodule/b", "b\n")
  commit_wbtest_run_git(super_dir + "/submodule", ["add", "b"])
  commit_wbtest_run_git(super_dir + "/submodule", [
    "commit", "-q", "-m", "second",
  ])

  let sub_git_dir = @bitlib.detect_git_dir(fs, super_dir + "/submodule")
    .map(pair => pair.0)
    .unwrap()
  let sub_head = @bitlib.resolve_head_commit(fs, sub_git_dir).unwrap()
  let before_entries = @bitlib.read_index_entries(fs, super_dir + "/.git")
  let before_submodule = commit_wbtest_find_entry(before_entries, "submodule")
  assert_true(before_submodule.id != sub_head)

  commit_handle_pathspec_staging(
    fs,
    fs,
    super_dir,
    super_dir + "/.git",
    ["submodule"],
    false,
    false,
  )

  let after_entries = @bitlib.read_index_entries(fs, super_dir + "/.git")
  let after_submodule = commit_wbtest_find_entry(after_entries, "submodule")
  assert_eq(after_submodule.id, sub_head)

  cleanup_tree(fs, root)
}

///|
async test "commit: amend preserves distinct author and committer dates" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-commit-author-date-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  let prev_author_name = @sys.get_env_var("GIT_AUTHOR_NAME")
  let prev_author_email = @sys.get_env_var("GIT_AUTHOR_EMAIL")
  let prev_committer_name = @sys.get_env_var("GIT_COMMITTER_NAME")
  let prev_committer_email = @sys.get_env_var("GIT_COMMITTER_EMAIL")
  let prev_author_date = @sys.get_env_var("GIT_AUTHOR_DATE")
  let prev_committer_date = @sys.get_env_var("GIT_COMMITTER_DATE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  defer add_test_restore_env("GIT_AUTHOR_NAME", prev_author_name)
  defer add_test_restore_env("GIT_AUTHOR_EMAIL", prev_author_email)
  defer add_test_restore_env("GIT_COMMITTER_NAME", prev_committer_name)
  defer add_test_restore_env("GIT_COMMITTER_EMAIL", prev_committer_email)
  defer add_test_restore_env("GIT_AUTHOR_DATE", prev_author_date)
  defer add_test_restore_env("GIT_COMMITTER_DATE", prev_committer_date)

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "."])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])
  fs.write_string(root + "/a.txt", "before\n")
  commit_wbtest_run_git(root, ["add", "a.txt"])
  commit_wbtest_run_git(root, ["commit", "-q", "-m", "initial"])

  fs.write_string(root + "/a.txt", "after\n")
  commit_wbtest_run_git(root, ["add", "a.txt"])

  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", root)
  @sys.set_env_var("GIT_AUTHOR_NAME", "Author User")
  @sys.set_env_var("GIT_AUTHOR_EMAIL", "author@example.com")
  @sys.set_env_var("GIT_COMMITTER_NAME", "Committer User")
  @sys.set_env_var("GIT_COMMITTER_EMAIL", "committer@example.com")
  @sys.set_env_var("GIT_AUTHOR_DATE", "1112911993 -0700")
  @sys.set_env_var("GIT_COMMITTER_DATE", "1112912001 +0900")

  @sys.set_env_var("GIT_SHIM_PWD", root)
  handle_commit(["-q", "--amend", "-m", "rewritten"]) catch {
    err => fail("handle_commit failed: \{err}")
  }

  let git_dir = root + "/.git"
  let head = @bitlib.resolve_head_commit(fs, git_dir).unwrap()
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  let commit_obj = db.get(fs, head).unwrap()
  let commit_text = @utf8.decode_lossy(commit_obj.data[:]).to_string()
  assert_true(
    commit_text.contains(
      "author Author User <author@example.com> 1112911993 -0700",
    ),
  )
  assert_true(
    commit_text.contains(
      "committer Committer User <committer@example.com> 1112912001 +0900",
    ),
  )

  cleanup_tree(fs, root)
}

///|
async test "commit: merge state commit records MERGE_HEAD as second parent" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-commit-merge-heads-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "."])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])

  fs.write_string(root + "/file", "base\n")
  commit_wbtest_run_git(root, ["add", "file"])
  commit_wbtest_run_git(root, ["commit", "-q", "-m", "I"])

  commit_wbtest_run_git(root, ["switch", "-q", "-c", "side"])
  fs.write_string(root + "/file", "side\n")
  commit_wbtest_run_git(root, ["commit", "-q", "-am", "side"])

  commit_wbtest_run_git(root, ["switch", "-q", "main"])
  fs.write_string(root + "/file", "main\n")
  commit_wbtest_run_git(root, ["commit", "-q", "-am", "main"])

  let (conflict_code, _) = commit_wbtest_git_stderr(root, [
    "merge", "-m", "merge", "side",
  ])
  assert_true(conflict_code != 0)
  let merge_head = decode_bytes(fs.read_file(root + "/.git/MERGE_HEAD"))
    |> trim_string

  fs.write_string(root + "/file", "main\nside\n")
  commit_wbtest_run_git(root, ["add", "file"])

  @sys.set_env_var("GIT_SHIM_PWD", root)
  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  handle_commit(["-q", "-a", "-m", "merge"]) catch {
    err => fail("handle_commit failed: \{err}")
  }

  let git_dir = root + "/.git"
  let head = @bitlib.resolve_head_commit(fs, git_dir).unwrap()
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  let commit_obj = db.get(fs, head).unwrap()
  let info = @bitcore.parse_commit(commit_obj.data)
  assert_eq(info.parents.length(), 2)
  assert_eq(info.parents[1].to_hex(), merge_head)
  assert_false(fs.is_file(root + "/.git/MERGE_HEAD"))

  cleanup_tree(fs, root)
}

///|
async test "commit: -S stores gpgsig header via configured signing program" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-commit-gpg-sign-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "."])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])
  let signer = root + "/fake-gpg.sh"
  signing_wbtest_write_fake_gpg(fs, signer)
  commit_wbtest_run_git(root, ["config", "gpg.program", signer])
  commit_wbtest_run_git(root, ["config", "gpg.format", "openpgp"])

  fs.write_string(root + "/signed.txt", "signed\n")
  commit_wbtest_run_git(root, ["add", "signed.txt"])

  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", root)

  handle_commit(["-q", "-S", "-m", "signed"]) catch {
    err => fail("handle_commit failed: \{err}")
  }

  let git_dir = root + "/.git"
  let head = @bitlib.resolve_head_commit(fs, git_dir).unwrap()
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  let commit_obj = db.get(fs, head).unwrap()
  let commit_text = @utf8.decode_lossy(commit_obj.data[:]).to_string()
  assert_true(
    commit_text.contains(
      "gpgsig -----BEGIN PGP SIGNATURE-----\n abc123\n -----END PGP SIGNATURE-----\n",
    ),
  )

  cleanup_tree(fs, root)
}

///|
async test "commit: -S stores ssh signature header via ssh signing format" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-commit-ssh-sign-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "."])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])
  let signer = root + "/fake-ssh-keygen.sh"
  signing_wbtest_write_fake_ssh_keygen(fs, signer)
  commit_wbtest_run_git(root, ["config", "gpg.program", signer])
  commit_wbtest_run_git(root, ["config", "gpg.format", "ssh"])
  fs.write_string(root + "/fake_ed25519", "not-a-real-key\n")
  commit_wbtest_run_git(root, [
    "config",
    "user.signingkey",
    root + "/fake_ed25519",
  ])

  fs.write_string(root + "/signed-ssh.txt", "signed ssh\n")
  commit_wbtest_run_git(root, ["add", "signed-ssh.txt"])

  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", root)

  handle_commit(["-q", "-S", "-m", "signed ssh"]) catch {
    err => fail("handle_commit failed: \{err}")
  }

  let git_dir = root + "/.git"
  let head = @bitlib.resolve_head_commit(fs, git_dir).unwrap()
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  let commit_obj = db.get(fs, head).unwrap()
  let commit_text = @utf8.decode_lossy(commit_obj.data[:]).to_string()
  assert_true(
    commit_text.contains(
      "gpgsig -----BEGIN SSH SIGNATURE-----\n sshabc\n -----END SSH SIGNATURE-----\n",
    ),
  )

  cleanup_tree(fs, root)
}
