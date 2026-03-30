///|
fn signing_repo_hash_algorithm(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> @bitobject.HashAlgorithm {
  if repo_object_format(fs, git_dir) == "sha256" {
    @bitobject.HashAlgorithm::Sha256
  } else {
    @bitobject.HashAlgorithm::Sha1
  }
}

///|
fn signing_commit_config_enabled(git_dir : String) -> Bool {
  match bit_config_get(git_dir, "commit", "gpgsign") {
    Some(value) => parse_bool_value(value).unwrap_or(false)
    None => false
  }
}

///|
fn signing_normalize_config_value(value : String) -> String {
  @bitlib.config_strip_quotes(value).trim().to_string()
}

///|
fn signing_format(git_dir : String) -> String {
  match bit_config_get(git_dir, "gpg", "format") {
    Some(value) => {
      let normalized = signing_normalize_config_value(value).to_lower()
      match normalized {
        "ssh" => "ssh"
        "x509" => "x509"
        _ => "openpgp"
      }
    }
    None => "openpgp"
  }
}

///|
fn signing_program_from_values(
  primary : String?,
  fallback : String?,
  default_program : String,
) -> String {
  match primary {
    Some(value) => {
      let normalized = signing_normalize_config_value(value)
      if normalized.length() > 0 {
        normalized
      } else {
        signing_program_from_values(None, fallback, default_program)
      }
    }
    None =>
      match fallback {
        Some(value) => {
          let normalized = signing_normalize_config_value(value)
          if normalized.length() > 0 {
            normalized
          } else {
            default_program
          }
        }
        None => default_program
      }
  }
}

///|
fn signing_program(git_dir : String, format : String) -> String {
  match format {
    "ssh" =>
      signing_program_from_values(
        bit_config_get(git_dir, "gpg", "ssh.program"),
        bit_config_get(git_dir, "gpg", "program"),
        "ssh-keygen",
      )
    "x509" =>
      signing_program_from_values(
        bit_config_get(git_dir, "gpg", "x509.program"),
        bit_config_get(git_dir, "gpg", "program"),
        "gpgsm",
      )
    _ =>
      signing_program_from_values(
        bit_config_get(git_dir, "gpg", "openpgp.program"),
        bit_config_get(git_dir, "gpg", "program"),
        "gpg",
      )
  }
}

///|
fn signing_split_program(command : String) -> (String, Array[String]) {
  let tokens = split_alias_command(command)
  if tokens.length() == 0 {
    return (command, [])
  }
  let args : Array[String] = []
  for i in 1..<tokens.length() {
    args.push(tokens[i])
  }
  (tokens[0], args)
}

///|
fn signing_key(git_dir : String, key_override : String?) -> String? {
  match key_override {
    Some(value) if value.trim().to_string().length() > 0 =>
      Some(value.trim().to_string())
    _ =>
      bit_config_get(git_dir, "user", "signingkey").map(
        signing_normalize_config_value,
      )
  }
}

///|
fn signing_lines(signature : String) -> Array[String] raise @bitcore.GitError {
  let lines : Array[String] = []
  let normalized = signature
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  for line_view in normalized.split("\n") {
    lines.push(line_view.to_string())
  }
  while lines.length() > 0 && lines[lines.length() - 1] == "" {
    ignore(lines.pop())
  }
  if lines.length() == 0 {
    raise @bitcore.GitError::InvalidObject("Empty signature")
  }
  lines
}

///|
fn signing_inject_commit_signature(
  payload : Bytes,
  signature : String,
) -> Bytes raise @bitcore.GitError {
  let lines = signing_lines(signature)
  let mut header_end = -1
  let mut i = 0
  while i + 1 < payload.length() {
    if payload[i] == b'\n' && payload[i + 1] == b'\n' {
      header_end = i
      break
    }
    i += 1
  }
  if header_end < 0 {
    raise @bitcore.GitError::InvalidObject("Malformed commit payload")
  }
  let out : Array[Byte] = []
  for b in payload[:header_end + 1] {
    out.push(b)
  }
  for b in @utf8.encode("gpgsig ") {
    out.push(b)
  }
  for b in @utf8.encode(lines[0]) {
    out.push(b)
  }
  out.push(b'\n')
  for i in 1..<lines.length() {
    out.push(b' ')
    for b in @utf8.encode(lines[i]) {
      out.push(b)
    }
    out.push(b'\n')
  }
  out.push(b'\n')
  for b in payload[header_end + 2:] {
    out.push(b)
  }
  Bytes::from_iter(out.iter())
}

///|
fn signing_append_tag_signature(
  payload : Bytes,
  signature : String,
) -> Bytes raise @bitcore.GitError {
  let lines = signing_lines(signature)
  let out : Array[Byte] = []
  for b in payload {
    out.push(b)
  }
  if payload.length() > 0 && payload[payload.length() - 1] != b'\n' {
    out.push(b'\n')
  }
  for line in lines {
    for b in @utf8.encode(line) {
      out.push(b)
    }
    out.push(b'\n')
  }
  Bytes::from_iter(out.iter())
}

///|
fn signing_try_remove_file(fs : OsFs, path : String) -> Unit {
  fs.remove_file(path) catch {
    _ => ()
  }
}

///|
async fn signing_run_stdout_signer(
  root : String,
  program : String,
  args : Array[String],
  payload : Bytes,
) -> String raise @bitcore.GitError {
  let (stdin_input, stdin_writer) = @process.write_to_process() catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "failed to start signing input pipe: \{err}",
      )
  }
  stdin_writer.write(payload) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "failed to write signing payload: \{err}",
      )
  }
  stdin_writer.close()
  let (code, stdout_data, stderr_data) = @process.collect_output(
    program,
    args,
    inherit_env=true,
    stdin=stdin_input,
    cwd=root,
  ) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "failed to run signing program '\{program}': \{err}",
      )
  }
  if code != 0 {
    let stderr = (stderr_data.text() catch { _ => "" }).trim().to_string()
    if stderr.length() > 0 {
      raise @bitcore.GitError::InvalidObject(stderr)
    }
    raise @bitcore.GitError::InvalidObject(
      "signing program '\{program}' failed with status \{code}",
    )
  }
  stdout_data.text() catch {
    _ => decode_bytes(stdout_data.binary())
  }
}

///|
async fn signing_run_ssh_signer(
  fs : OsFs,
  root : String,
  git_dir : String,
  program : String,
  base_args : Array[String],
  payload : Bytes,
  signing_key : String,
) -> String raise @bitcore.GitError {
  let temp_path = git_dir +
    "/bit-ssh-sign-" +
    get_current_timestamp().to_string()
  let sig_path = temp_path + ".sig"
  fs.write_file(temp_path, payload) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "failed to write temporary signing payload: \{err}",
      )
  }
  let args : Array[String] = []
  for arg in base_args {
    args.push(arg)
  }
  args.push("-Y")
  args.push("sign")
  args.push("-n")
  args.push("git")
  args.push("-f")
  args.push(signing_key)
  args.push(temp_path)
  let result = @process.collect_output(
    program,
    args,
    inherit_env=true,
    cwd=root,
  ) catch {
    err => {
      signing_try_remove_file(fs, temp_path)
      signing_try_remove_file(fs, sig_path)
      raise @bitcore.GitError::InvalidObject(
        "failed to run signing program '\{program}': \{err}",
      )
    }
  }
  let (code, _stdout_data, stderr_data) = result
  if code != 0 {
    let stderr = (stderr_data.text() catch { _ => "" }).trim().to_string()
    signing_try_remove_file(fs, temp_path)
    signing_try_remove_file(fs, sig_path)
    if stderr.length() > 0 {
      raise @bitcore.GitError::InvalidObject(stderr)
    }
    raise @bitcore.GitError::InvalidObject(
      "signing program '\{program}' failed with status \{code}",
    )
  }
  let signature = fs.read_file(sig_path) catch {
    _ => {
      signing_try_remove_file(fs, temp_path)
      signing_try_remove_file(fs, sig_path)
      raise @bitcore.GitError::InvalidObject(
        "ssh signing program did not produce a signature file",
      )
    }
  }
  signing_try_remove_file(fs, temp_path)
  signing_try_remove_file(fs, sig_path)
  decode_bytes(signature)
}

///|
async fn signing_sign_payload(
  fs : OsFs,
  root : String,
  git_dir : String,
  payload : Bytes,
  key_override : String?,
) -> String raise @bitcore.GitError {
  let format = signing_format(git_dir)
  let command = signing_program(git_dir, format)
  let (program, base_args) = signing_split_program(command)
  let resolved_key = signing_key(git_dir, key_override)
  match format {
    "ssh" => {
      let signing_key = match resolved_key {
        Some(value) => value
        None =>
          raise @bitcore.GitError::InvalidObject(
            "user.signingkey is required for ssh signing",
          )
      }
      signing_run_ssh_signer(
        fs, root, git_dir, program, base_args, payload, signing_key,
      )
    }
    "x509" | _ => {
      let args : Array[String] = []
      for arg in base_args {
        args.push(arg)
      }
      args.push("-bsa")
      match resolved_key {
        Some(value) => {
          args.push("-u")
          args.push(value)
        }
        None => ()
      }
      signing_run_stdout_signer(root, program, args, payload)
    }
  }
}
