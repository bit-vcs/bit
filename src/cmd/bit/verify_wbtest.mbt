///|
async fn verify_wbtest_generate_ssh_key(
  fs : OsFs,
  root : String,
  principal : String,
) -> (String, String) raise Error {
  let key_path = root + "/id_ed25519"
  let allowed_signers = root + "/allowed_signers"
  let (code, _, stderr) = @process.collect_output(
    "ssh-keygen",
    ["-q", "-t", "ed25519", "-N", "", "-C", principal, "-f", key_path],
    inherit_env=true,
    cwd=root,
  )
  if code != 0 {
    let stderr_text = stderr.text() catch { _ => "" }
    fail("ssh-keygen failed: \{stderr_text}")
  }
  let public_key = trim_string(decode_bytes(fs.read_file(key_path + ".pub")))
  fs.write_string(allowed_signers, principal + " " + public_key + "\n")
  (key_path, allowed_signers)
}

///|
async fn verify_wbtest_generate_timeboxed_ssh_keys(
  fs : OsFs,
  root : String,
) -> (String, String, String) raise Error {
  let valid_key_path = root + "/timeboxed_valid_ed25519"
  let invalid_key_path = root + "/timeboxed_invalid_ed25519"
  let allowed_signers = root + "/allowed_signers"
  let (valid_code, _, valid_stderr) = @process.collect_output(
    "ssh-keygen",
    [
      "-q", "-t", "ed25519", "-N", "", "-C", "timeboxed valid key", "-f", valid_key_path,
    ],
    inherit_env=true,
    cwd=root,
  )
  if valid_code != 0 {
    let stderr_text = valid_stderr.text() catch { _ => "" }
    fail("ssh-keygen failed: \{stderr_text}")
  }
  let (invalid_code, _, invalid_stderr) = @process.collect_output(
    "ssh-keygen",
    [
      "-q", "-t", "ed25519", "-N", "", "-C", "timeboxed invalid key", "-f", invalid_key_path,
    ],
    inherit_env=true,
    cwd=root,
  )
  if invalid_code != 0 {
    let stderr_text = invalid_stderr.text() catch { _ => "" }
    fail("ssh-keygen failed: \{stderr_text}")
  }
  let valid_public_key = trim_string(
    decode_bytes(fs.read_file(valid_key_path + ".pub")),
  )
  let invalid_public_key = trim_string(
    decode_bytes(fs.read_file(invalid_key_path + ".pub")),
  )
  fs.write_string(
    allowed_signers,
    "\"timeboxed valid key\" valid-after=\"20050101000000\",valid-before=\"20051231235959\" " +
    valid_public_key +
    "\"\n" +
    "\"timeboxed invalid key\" valid-after=\"20040101000000\",valid-before=\"20041231235959\" " +
    invalid_public_key +
    "\"\n",
  )
  (valid_key_path, invalid_key_path, allowed_signers)
}

///|
async test "verify: verify-commit validates ssh signatures via native ssh-keygen" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-verify-commit-ssh-" +
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
  let (signing_key, allowed_signers) = verify_wbtest_generate_ssh_key(
    fs, root, "test@example.com",
  )
  commit_wbtest_run_git(root, ["config", "gpg.format", "ssh"])
  commit_wbtest_run_git(root, ["config", "user.signingkey", signing_key])
  commit_wbtest_run_git(root, [
    "config", "gpg.ssh.allowedSignersFile", allowed_signers,
  ])

  fs.write_string(root + "/signed.txt", "signed\n")
  commit_wbtest_run_git(root, ["add", "signed.txt"])

  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", root)

  handle_commit(["-q", "-S", "-m", "signed ssh"]) catch {
    err => fail("handle_commit failed: \{err}")
  }
  handle_verify_commit(["HEAD"]) catch {
    err => fail("handle_verify_commit failed: \{err}")
  }

  cleanup_tree(fs, root)
}

///|
async test "verify: ssh verifier uses commit timestamp for key validity" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-verify-commit-ssh-verify-time-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let git_dir = root + "/.git"

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  let prev_author_date = @sys.get_env_var("GIT_AUTHOR_DATE")
  let prev_committer_date = @sys.get_env_var("GIT_COMMITTER_DATE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  defer add_test_restore_env("GIT_AUTHOR_DATE", prev_author_date)
  defer add_test_restore_env("GIT_COMMITTER_DATE", prev_committer_date)

  commit_wbtest_run_git(root, ["init", "--initial-branch=main", "-q", "."])
  commit_wbtest_run_git(root, ["config", "user.name", "Test User"])
  commit_wbtest_run_git(root, ["config", "user.email", "test@example.com"])
  let (valid_key, invalid_key, allowed_signers) = verify_wbtest_generate_timeboxed_ssh_keys(
    fs, root,
  )
  commit_wbtest_run_git(root, ["config", "gpg.format", "ssh"])
  commit_wbtest_run_git(root, [
    "config", "gpg.ssh.allowedSignersFile", allowed_signers,
  ])

  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", root)
  @sys.set_env_var("GIT_AUTHOR_DATE", "1112912001 +0000")
  @sys.set_env_var("GIT_COMMITTER_DATE", "1112912001 +0000")

  commit_wbtest_run_git(root, ["config", "user.signingkey", valid_key])
  fs.write_string(root + "/signed.txt", "valid\n")
  commit_wbtest_run_git(root, ["add", "signed.txt"])
  handle_commit(["-q", "-S", "-m", "signed valid ssh"]) catch {
    err => fail("handle_commit failed: \{err}")
  }
  let valid_commit = match @bitrepo.rev_parse(fs, git_dir, "HEAD") {
    Some(id) => id
    None => fail("expected valid commit")
  }

  commit_wbtest_run_git(root, ["config", "user.signingkey", invalid_key])
  fs.write_string(root + "/signed.txt", "invalid\n")
  commit_wbtest_run_git(root, ["add", "signed.txt"])
  handle_commit(["-q", "-S", "-m", "signed invalid ssh"]) catch {
    err => fail("handle_commit failed: \{err}")
  }
  let invalid_commit = match @bitrepo.rev_parse(fs, git_dir, "HEAD") {
    Some(id) => id
    None => fail("expected invalid commit")
  }

  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let valid_obj = match db.get(fs, valid_commit) {
    Some(obj) => obj
    None => fail("missing valid commit object")
  }
  let invalid_obj = match db.get(fs, invalid_commit) {
    Some(obj) => obj
    None => fail("missing invalid commit object")
  }
  let (valid_payload, valid_signature) = match
    signing_extract_commit_signature(valid_obj.data) {
    Some(pair) => pair
    None => fail("missing valid commit signature")
  }
  let (invalid_payload, invalid_signature) = match
    signing_extract_commit_signature(invalid_obj.data) {
    Some(pair) => pair
    None => fail("missing invalid commit signature")
  }

  let valid_verified = signing_verify_payload(
    fs, root, git_dir, valid_payload, valid_signature,
  ) catch {
    err => fail("signing_verify_payload failed: \{err}")
  }
  let invalid_verified = signing_verify_payload(
    fs, root, git_dir, invalid_payload, invalid_signature,
  ) catch {
    err => fail("signing_verify_payload failed: \{err}")
  }

  assert_true(valid_verified)
  assert_false(invalid_verified)

  cleanup_tree(fs, root)
}

///|
async test "verify: verify-tag validates ssh signatures via native ssh-keygen" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-verify-tag-ssh-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)

  grep_test_run_git(root, ["init", "-q", "repo"])
  grep_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  grep_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  let (signing_key, allowed_signers) = verify_wbtest_generate_ssh_key(
    fs, root, "test@example.com",
  )
  grep_test_run_git(repo_dir, ["config", "gpg.format", "ssh"])
  grep_test_run_git(repo_dir, ["config", "user.signingkey", signing_key])
  grep_test_run_git(repo_dir, [
    "config", "gpg.ssh.allowedSignersFile", allowed_signers,
  ])
  fs.write_string(repo_dir + "/tracked.txt", "seed\n")
  grep_test_run_git(repo_dir, ["add", "tracked.txt"])
  grep_test_run_git(repo_dir, ["commit", "-q", "-m", "initial"])

  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", repo_dir)

  handle_tag(["-s", "-m", "signed tag", "v1"]) catch {
    err => fail("handle_tag failed: \{err}")
  }
  handle_verify_tag(["v1"]) catch {
    err => fail("handle_verify_tag failed: \{err}")
  }

  cleanup_tree(fs, root)
}

///|
async test "verify: ssh verifier uses tagger timestamp for key validity" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-verify-tag-ssh-verify-time-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"
  let git_dir = repo_dir + "/.git"

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  let prev_committer_date = @sys.get_env_var("GIT_COMMITTER_DATE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  defer add_test_restore_env("GIT_COMMITTER_DATE", prev_committer_date)

  grep_test_run_git(root, ["init", "-q", "repo"])
  grep_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  grep_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  let (valid_key, invalid_key, allowed_signers) = verify_wbtest_generate_timeboxed_ssh_keys(
    fs, root,
  )
  grep_test_run_git(repo_dir, ["config", "gpg.format", "ssh"])
  grep_test_run_git(repo_dir, [
    "config", "gpg.ssh.allowedSignersFile", allowed_signers,
  ])
  fs.write_string(repo_dir + "/tracked.txt", "seed\n")
  grep_test_run_git(repo_dir, ["add", "tracked.txt"])
  grep_test_run_git(repo_dir, ["commit", "-q", "-m", "initial"])

  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", repo_dir)
  @sys.set_env_var("GIT_COMMITTER_DATE", "1112912001 +0000")

  grep_test_run_git(repo_dir, ["config", "user.signingkey", valid_key])
  handle_tag(["-s", "-m", "signed tag", "v-valid"]) catch {
    err => fail("handle_tag failed: \{err}")
  }
  let valid_tag = match @bitrepo.rev_parse(fs, git_dir, "v-valid") {
    Some(id) => id
    None => fail("expected valid tag")
  }

  grep_test_run_git(repo_dir, ["config", "user.signingkey", invalid_key])
  handle_tag(["-s", "-m", "signed tag", "v-invalid"]) catch {
    err => fail("handle_tag failed: \{err}")
  }
  let invalid_tag = match @bitrepo.rev_parse(fs, git_dir, "v-invalid") {
    Some(id) => id
    None => fail("expected invalid tag")
  }

  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let valid_obj = match db.get(fs, valid_tag) {
    Some(obj) => obj
    None => fail("missing valid tag object")
  }
  let invalid_obj = match db.get(fs, invalid_tag) {
    Some(obj) => obj
    None => fail("missing invalid tag object")
  }
  let (valid_payload, valid_signature) = match
    signing_extract_tag_signature(valid_obj.data) {
    Some(pair) => pair
    None => fail("missing valid tag signature")
  }
  let (invalid_payload, invalid_signature) = match
    signing_extract_tag_signature(invalid_obj.data) {
    Some(pair) => pair
    None => fail("missing invalid tag signature")
  }

  let valid_verified = signing_verify_payload(
    fs, repo_dir, git_dir, valid_payload, valid_signature,
  ) catch {
    err => fail("signing_verify_payload failed: \{err}")
  }
  let invalid_verified = signing_verify_payload(
    fs, repo_dir, git_dir, invalid_payload, invalid_signature,
  ) catch {
    err => fail("signing_verify_payload failed: \{err}")
  }

  assert_true(valid_verified)
  assert_false(invalid_verified)

  cleanup_tree(fs, root)
}

///|
async test "verify: verify-commit uses external openpgp verifier" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-verify-commit-gpg-" +
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

  handle_commit(["-q", "-S", "-m", "signed gpg"]) catch {
    err => fail("handle_commit failed: \{err}")
  }
  handle_verify_commit(["HEAD"]) catch {
    err => fail("handle_verify_commit failed: \{err}")
  }

  cleanup_tree(fs, root)
}

///|
async test "verify: verify-tag uses external openpgp verifier" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-verify-tag-gpg-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)

  grep_test_run_git(root, ["init", "-q", "repo"])
  grep_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  grep_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  let signer = root + "/fake-gpg.sh"
  signing_wbtest_write_fake_gpg(fs, signer)
  grep_test_run_git(repo_dir, ["config", "gpg.program", signer])
  grep_test_run_git(repo_dir, ["config", "gpg.format", "openpgp"])
  fs.write_string(repo_dir + "/tracked.txt", "seed\n")
  grep_test_run_git(repo_dir, ["add", "tracked.txt"])
  grep_test_run_git(repo_dir, ["commit", "-q", "-m", "initial"])

  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", repo_dir)

  handle_tag(["-s", "-m", "signed tag", "v1"]) catch {
    err => fail("handle_tag failed: \{err}")
  }
  handle_verify_tag(["v1"]) catch {
    err => fail("handle_verify_tag failed: \{err}")
  }

  cleanup_tree(fs, root)
}
