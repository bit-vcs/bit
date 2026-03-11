///|
fn restore_env_var_for_upload_pack_process_wbtest(
  name : String,
  prev : String?,
) -> Unit {
  match prev {
    Some(value) => @sys.set_env_var(name, value)
    None => @sys.unset_env_var(name)
  }
}

///|
test "upload-pack process: info-refs over ssh uses native protocol (no stateless-rpc)" {
  let prev_ssh_command = @sys.get_env_var("GIT_SSH_COMMAND")
  let prev_ssh = @sys.get_env_var("GIT_SSH")
  @sys.unset_env_var("GIT_SSH_COMMAND")
  @sys.unset_env_var("GIT_SSH")
  let spec = build_upload_pack_info_refs_process_spec(
    "git@github.com:mizchi/bit-vcs.git", true,
  )
  assert_eq(spec.cmd, "ssh")
  assert_true(spec.args.length() >= 2)
  let remote_cmd = spec.args[spec.args.length() - 1]
  assert_true(remote_cmd.contains("git-upload-pack"))
  assert_false(remote_cmd.contains("--stateless-rpc"))
  assert_false(remote_cmd.contains("--advertise-refs"))
  assert_true(remote_cmd.contains("bit-vcs.git"))
  match spec.extra_env {
    Some(extra) => assert_eq(extra.get("GIT_PROTOCOL"), Some("version=2"))
    None => fail("expected GIT_PROTOCOL for prefer_v2")
  }
  restore_env_var_for_upload_pack_process_wbtest(
    "GIT_SSH_COMMAND", prev_ssh_command,
  )
  restore_env_var_for_upload_pack_process_wbtest("GIT_SSH", prev_ssh)
}

///|
test "upload-pack process: request over ssh uses native protocol (no stateless-rpc)" {
  let prev_ssh_command = @sys.get_env_var("GIT_SSH_COMMAND")
  let prev_ssh = @sys.get_env_var("GIT_SSH")
  @sys.unset_env_var("GIT_SSH_COMMAND")
  @sys.unset_env_var("GIT_SSH")
  let spec = build_upload_pack_request_process_spec(
    "git@github.com:mizchi/bit-vcs.git", true,
  )
  assert_eq(spec.cmd, "ssh")
  assert_true(spec.args.length() >= 2)
  let remote_cmd = spec.args[spec.args.length() - 1]
  assert_true(remote_cmd.contains("git-upload-pack"))
  assert_false(remote_cmd.contains("--stateless-rpc"))
  assert_true(remote_cmd.contains("bit-vcs.git"))
  match spec.extra_env {
    Some(extra) => assert_eq(extra.get("GIT_PROTOCOL"), Some("version=2"))
    None => fail("expected GIT_PROTOCOL for prefer_v2")
  }
  restore_env_var_for_upload_pack_process_wbtest(
    "GIT_SSH_COMMAND", prev_ssh_command,
  )
  restore_env_var_for_upload_pack_process_wbtest("GIT_SSH", prev_ssh)
}

///|
test "upload-pack process: ssh remote command escapes single quote in path" {
  let prev_ssh_command = @sys.get_env_var("GIT_SSH_COMMAND")
  let prev_ssh = @sys.get_env_var("GIT_SSH")
  @sys.unset_env_var("GIT_SSH_COMMAND")
  @sys.unset_env_var("GIT_SSH")
  let spec = build_upload_pack_info_refs_process_spec(
    "git@github.com:mizchi/o'hara.git", true,
  )
  assert_eq(spec.cmd, "ssh")
  assert_true(spec.args.length() >= 2)
  let remote_cmd = spec.args[spec.args.length() - 1]
  assert_eq(remote_cmd, "git-upload-pack 'mizchi/o'\\''hara.git'")
  restore_env_var_for_upload_pack_process_wbtest(
    "GIT_SSH_COMMAND", prev_ssh_command,
  )
  restore_env_var_for_upload_pack_process_wbtest("GIT_SSH", prev_ssh)
}

///|
test "upload-pack process: file transport prefers SHIM_EXEC_PATH" {
  let prev_exec_path = @sys.get_env_var("SHIM_EXEC_PATH")
  @sys.set_env_var("SHIM_EXEC_PATH", "/tmp/git-core")
  let spec = build_upload_pack_info_refs_process_spec("/tmp/repo.git", false)
  assert_eq(spec.cmd, "/tmp/git-core/git-upload-pack")
  restore_env_var_for_upload_pack_process_wbtest(
    "SHIM_EXEC_PATH", prev_exec_path,
  )
}

///|
async test "upload-pack process: run_process_with_files works with cwd override" {
  let prev_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  @sys.set_env_var("GIT_SHIM_CWD", "/tmp")
  let stdin_data = Bytes::from_array([b'h', b'i', b'\n'])
  let (code, stdout, stderr) = run_process_with_files(
    { cmd: "/bin/cat", args: [], extra_env: None },
    Some(stdin_data),
  ) catch {
    err => {
      restore_env_var_for_upload_pack_process_wbtest("GIT_SHIM_CWD", prev_cwd)
      fail("unexpected error: \{err}")
    }
  }
  assert_eq(code, 0)
  assert_eq(bytes_to_string_lossy(stdout), "hi\n")
  assert_eq(bytes_to_string_lossy(stderr), "")
  restore_env_var_for_upload_pack_process_wbtest("GIT_SHIM_CWD", prev_cwd)
}
