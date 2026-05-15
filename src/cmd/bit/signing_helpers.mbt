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
fn signing_join_signature_lines(lines : Array[String]) -> String {
  if lines.length() == 0 {
    return ""
  }
  let mut out = lines.join("\n")
  if !out.has_suffix("\n") {
    out = out + "\n"
  }
  out
}

///|
fn signing_parse_identity_timestamp_and_timezone(
  identity : String,
) -> (Int64, String) {
  let mut timestamp = 0L
  let mut timezone = "+0000"
  let mut last_space = identity.rev_find(" ")
  if last_space is Some(tz_idx) {
    let before_tz = String::unsafe_substring(identity, start=0, end=tz_idx)
    timezone = String::unsafe_substring(
      identity,
      start=tz_idx + 1,
      end=identity.length(),
    )
    last_space = before_tz.rev_find(" ")
    if last_space is Some(time_idx) {
      let time_str = String::unsafe_substring(
        before_tz,
        start=time_idx + 1,
        end=before_tz.length(),
      )
      for c in time_str {
        if c < '0' || c > '9' {
          return (0L, timezone)
        }
        let digit = c.to_int() - '0'.to_int()
        timestamp = timestamp * 10L + digit.to_int64()
      }
    }
  }
  (timestamp, timezone)
}

///|
fn signing_payload_verify_time_arg(payload : Bytes) -> String? {
  let text = decode_bytes(payload)
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    let identity = if line.has_prefix("committer ") {
      Some(String::unsafe_substring(line, start=10, end=line.length()))
    } else if line.has_prefix("tagger ") {
      Some(String::unsafe_substring(line, start=7, end=line.length()))
    } else {
      None
    }
    match identity {
      Some(rest) => {
        let (timestamp, timezone) = signing_parse_identity_timestamp_and_timezone(
          rest,
        )
        if timestamp > 0L {
          return Some(
            "-Overify-time=" +
            format_timestamp_strftime(timestamp, timezone, "%Y%m%d%H%M%S"),
          )
        }
        return None
      }
      None => ()
    }
  }
  None
}

///|
fn signing_bytes_starts_with(
  data : Bytes,
  start : Int,
  end_ : Int,
  prefix : String,
) -> Bool {
  let prefix_bytes = @utf8.encode(prefix)
  if end_ - start < prefix_bytes.length() {
    return false
  }
  for i in 0..<prefix_bytes.length() {
    if data[start + i] != prefix_bytes[i] {
      return false
    }
  }
  true
}

///|
fn signing_bytes_equals(
  data : Bytes,
  start : Int,
  end_ : Int,
  text : String,
) -> Bool {
  let text_bytes = @utf8.encode(text)
  if end_ - start != text_bytes.length() {
    return false
  }
  signing_bytes_starts_with(data, start, end_, text)
}

///|
fn signing_collect_line_ranges(data : Bytes) -> Array[(Int, Int, Bool)] {
  let lines : Array[(Int, Int, Bool)] = []
  if data.length() == 0 {
    return lines
  }
  let mut i = 0
  while i < data.length() {
    let start = i
    while i < data.length() && data[i] != b'\n' {
      i += 1
    }
    let end_ = i
    let has_newline = i < data.length() && data[i] == b'\n'
    if has_newline {
      i += 1
    }
    lines.push((start, end_, has_newline))
  }
  lines
}

///|
fn signing_copy_line_range(
  data : Bytes,
  out : Array[Byte],
  line : (Int, Int, Bool),
) -> Unit {
  for b in data[line.0:line.1] {
    out.push(b)
  }
  if line.2 {
    out.push(b'\n')
  }
}

///|
fn signing_extract_commit_signature(data : Bytes) -> (Bytes, String)? {
  let lines = signing_collect_line_ranges(data)
  let mut header_end = lines.length()
  let mut sig_start = -1
  let mut sig_end = -1
  let mut prefix_len = 0
  for i in 0..<lines.length() {
    let line = lines[i]
    if line.1 == line.0 {
      header_end = i
      break
    }
    if signing_bytes_starts_with(data, line.0, line.1, "gpgsig ") {
      sig_start = i
      prefix_len = 7
      break
    }
    if signing_bytes_starts_with(data, line.0, line.1, "gpgsig-sha256 ") {
      sig_start = i
      prefix_len = 14
      break
    }
  }
  if sig_start < 0 {
    return None
  }
  sig_end = sig_start + 1
  while sig_end < header_end {
    let line = lines[sig_end]
    if line.1 > line.0 && data[line.0] == b' ' {
      sig_end += 1
    } else {
      break
    }
  }
  let signature_lines : Array[String] = []
  let first_line = lines[sig_start]
  signature_lines.push(
    decode_bytes(
      bytes_from_array(data[first_line.0 + prefix_len:first_line.1].to_array()),
    ),
  )
  for i in (sig_start + 1)..<sig_end {
    let line = lines[i]
    signature_lines.push(
      decode_bytes(bytes_from_array(data[line.0 + 1:line.1].to_array())),
    )
  }
  let out : Array[Byte] = []
  for i in 0..<lines.length() {
    if i >= sig_start && i < sig_end {
      continue
    }
    signing_copy_line_range(data, out, lines[i])
  }
  Some(
    (
      Bytes::from_iter(out.iter()),
      signing_join_signature_lines(signature_lines),
    ),
  )
}

///|
fn signing_extract_tag_signature(data : Bytes) -> (Bytes, String)? {
  let lines = signing_collect_line_ranges(data)
  for line in lines {
    if signing_bytes_equals(
        data,
        line.0,
        line.1,
        "-----BEGIN PGP SIGNATURE-----",
      ) ||
      signing_bytes_equals(
        data,
        line.0,
        line.1,
        "-----BEGIN SSH SIGNATURE-----",
      ) {
      return Some(
        (
          bytes_from_array(data[:line.0].to_array()),
          decode_bytes(bytes_from_array(data[line.0:].to_array())),
        ),
      )
    }
  }
  None
}

///|
fn signing_detect_signature_format(
  git_dir : String,
  signature : String,
) -> String {
  if signature.contains("-----BEGIN SSH SIGNATURE-----") {
    return "ssh"
  }
  if signature.contains("-----BEGIN PGP SIGNATURE-----") {
    return "openpgp"
  }
  signing_format(git_dir)
}

///|
fn signing_resolve_config_path(root : String, value : String) -> String {
  resolve_global_path(signing_normalize_config_value(value), Some(root))
}

///|
fn signing_allowed_signers_file(root : String, git_dir : String) -> String? {
  bit_config_get(git_dir, "gpg", "ssh.allowedSignersFile").map(value => {
    signing_resolve_config_path(root, value)
  })
}

///|
fn signing_revocation_file(root : String, git_dir : String) -> String? {
  bit_config_get(git_dir, "gpg", "ssh.revocationFile").map(value => {
    signing_resolve_config_path(root, value)
  })
}

///|
async fn signing_collect_output_text(
  root : String,
  program : String,
  args : Array[String],
) -> (Int, String, String) raise @bitcore.GitError {
  let (code, stdout_data, stderr_data) = @process.collect_output(
    program,
    args,
    inherit_env=true,
    cwd=root,
  ) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "failed to run signing program '\{program}': \{err}",
      )
  }
  let stdout = stdout_data.text() catch {
    _ => decode_bytes(stdout_data.binary())
  }
  let stderr = stderr_data.text() catch {
    _ => decode_bytes(stderr_data.binary())
  }
  (code, stdout, stderr)
}

///|
async fn signing_collect_output_text_with_payload(
  root : String,
  program : String,
  args : Array[String],
  payload : Bytes,
) -> (Int, String, String) raise @bitcore.GitError {
  let (stdin_input, stdin_writer) = @process.write_to_process() catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "failed to start verify input pipe: \{err}",
      )
  }
  stdin_writer.write(payload) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "failed to write verify payload: \{err}",
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
  let stdout = stdout_data.text() catch {
    _ => decode_bytes(stdout_data.binary())
  }
  let stderr = stderr_data.text() catch {
    _ => decode_bytes(stderr_data.binary())
  }
  (code, stdout, stderr)
}

///|
async fn signing_emit_stderr_text(text : String) -> Unit raise Error {
  let normalized = text
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  for line_view in normalized.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    eprint_line(line)
  }
}

///|
async fn signing_run_detached_verifier(
  fs : OsFs,
  root : String,
  git_dir : String,
  format : String,
  payload : Bytes,
  signature : String,
) -> Bool raise @bitcore.GitError {
  let command = signing_program(git_dir, format)
  let (program, base_args) = signing_split_program(command)
  let temp_base = root +
    "/bit-verify-" +
    format +
    "-" +
    get_current_timestamp().to_string()
  let payload_path = temp_base + ".payload"
  let sig_path = temp_base + ".sig"
  fs.write_file(payload_path, payload) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "failed to write temporary verify payload: \{err}",
      )
  }
  fs.write_string(sig_path, signature) catch {
    err => {
      signing_try_remove_file(fs, payload_path)
      raise @bitcore.GitError::InvalidObject(
        "failed to write temporary signature: \{err}",
      )
    }
  }
  let args : Array[String] = []
  for arg in base_args {
    args.push(arg)
  }
  args.push("--verify")
  args.push(sig_path)
  args.push(payload_path)
  let (code, stdout, stderr) = signing_collect_output_text(root, program, args)
  signing_try_remove_file(fs, payload_path)
  signing_try_remove_file(fs, sig_path)
  signing_emit_stderr_text(stdout) catch {
    _ => ()
  }
  signing_emit_stderr_text(stderr) catch {
    _ => ()
  }
  code == 0
}

///|
async fn signing_run_ssh_verifier(
  fs : OsFs,
  root : String,
  git_dir : String,
  payload : Bytes,
  signature : String,
) -> Bool raise @bitcore.GitError {
  let allowed_signers = match signing_allowed_signers_file(root, git_dir) {
    Some(path) => path
    None =>
      raise @bitcore.GitError::InvalidObject(
        "gpg.ssh.allowedSignersFile is required for ssh verification",
      )
  }
  let command = signing_program(git_dir, "ssh")
  let (program, base_args) = signing_split_program(command)
  let temp_base = root +
    "/bit-verify-ssh-" +
    get_current_timestamp().to_string()
  let sig_path = temp_base + ".sig"
  fs.write_string(sig_path, signature) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "failed to write temporary signature: \{err}",
      )
  }
  let revocation_file = signing_revocation_file(root, git_dir)
  let verify_time_arg = signing_payload_verify_time_arg(payload)
  let find_args : Array[String] = []
  for arg in base_args {
    find_args.push(arg)
  }
  find_args.push("-Y")
  find_args.push("find-principals")
  find_args.push("-f")
  find_args.push(allowed_signers)
  find_args.push("-s")
  find_args.push(sig_path)
  match verify_time_arg {
    Some(arg) => find_args.push(arg)
    None => ()
  }
  let (find_code, find_stdout, find_stderr) = signing_collect_output_text(
    root, program, find_args,
  )
  let principals : Array[String] = []
  if find_code == 0 {
    for line_view in find_stdout.split("\n") {
      let line = trim_string(line_view.to_string())
      if line.length() > 0 {
        principals.push(line)
      }
    }
  }
  if principals.length() > 0 {
    let mut last_stdout = ""
    let mut last_stderr = ""
    for principal in principals {
      let verify_args : Array[String] = []
      for arg in base_args {
        verify_args.push(arg)
      }
      verify_args.push("-Y")
      verify_args.push("verify")
      verify_args.push("-f")
      verify_args.push(allowed_signers)
      verify_args.push("-I")
      verify_args.push(principal)
      verify_args.push("-n")
      verify_args.push("git")
      verify_args.push("-s")
      verify_args.push(sig_path)
      match verify_time_arg {
        Some(arg) => verify_args.push(arg)
        None => ()
      }
      match revocation_file {
        Some(path) => {
          verify_args.push("-r")
          verify_args.push(path)
        }
        None => ()
      }
      let (code, stdout, stderr) = signing_collect_output_text_with_payload(
        root, program, verify_args, payload,
      )
      last_stdout = stdout
      last_stderr = stderr
      if code == 0 {
        signing_try_remove_file(fs, sig_path)
        signing_emit_stderr_text(stdout) catch {
          _ => ()
        }
        signing_emit_stderr_text(stderr) catch {
          _ => ()
        }
        return true
      }
    }
    signing_try_remove_file(fs, sig_path)
    signing_emit_stderr_text(last_stdout) catch {
      _ => ()
    }
    signing_emit_stderr_text(last_stderr) catch {
      _ => ()
    }
    return false
  }
  let check_args : Array[String] = []
  for arg in base_args {
    check_args.push(arg)
  }
  check_args.push("-Y")
  check_args.push("check-novalidate")
  check_args.push("-n")
  check_args.push("git")
  check_args.push("-s")
  check_args.push(sig_path)
  match verify_time_arg {
    Some(arg) => check_args.push(arg)
    None => ()
  }
  let (_check_code, check_stdout, check_stderr) = signing_collect_output_text_with_payload(
    root, program, check_args, payload,
  )
  signing_try_remove_file(fs, sig_path)
  signing_emit_stderr_text(check_stdout) catch {
    _ => ()
  }
  signing_emit_stderr_text(find_stderr) catch {
    _ => ()
  }
  signing_emit_stderr_text(check_stderr) catch {
    _ => ()
  }
  false
}

///|
async fn signing_verify_payload(
  fs : OsFs,
  root : String,
  git_dir : String,
  payload : Bytes,
  signature : String,
) -> Bool raise @bitcore.GitError {
  let format = signing_detect_signature_format(git_dir, signature)
  match format {
    "ssh" => signing_run_ssh_verifier(fs, root, git_dir, payload, signature)
    "x509" | _ =>
      signing_run_detached_verifier(
        fs, root, git_dir, format, payload, signature,
      )
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
