///| Native filter command execution

///|
fn fs_error_message(err : @fs.IOError) -> String {
  match err {
    @fs.IOError::IOError(message) => message
  }
}

///|
/// Run a filter command (clean or smudge) on content via temp file + shell.
pub async fn run_filter_command(
  root : String,
  git_dir : String,
  command : String,
  content : Bytes,
) -> Bytes raise @bit.GitError {
  let temp_path = git_dir + "/bit-filter.tmp"
  @fs.write_bytes_to_file(temp_path, content) catch {
    err =>
      raise @bit.GitError::IoError(
        "filter write temp failed: \{fs_error_message(err)}",
      )
  }
  let shell_cmd = build_filter_shell_command(command)
  let proc_result = @process.run(
    "sh",
    ["-c", shell_cmd, "bit-filter", temp_path],
    inherit_env=true,
    cwd=root,
    stdout=Collect,
  ) catch {
    err => {
      @fs.remove_file(temp_path) catch {
        _ => ()
      }
      raise @bit.GitError::IoError("filter command failed: \{err}")
    }
  }
  let (code, stdout) = (proc_result.exit_code, proc_result.stdout_binary())
  @fs.remove_file(temp_path) catch {
    _ => ()
  }
  if code != 0 {
    raise @bit.GitError::IoError(
      "filter command '\{command}' failed with status \{code}",
    )
  }
  stdout
}

///|
/// Build shell command for filter execution.
/// Supports: "cmd %f" → "cmd "$1"", "cmd" → "cmd < "$1""
fn build_filter_shell_command(command : String) -> String {
  let trimmed = command.trim().to_owned()
  if trimmed.contains("%f") {
    return trimmed.replace_all(old="%f", new="\"$1\"")
  }
  // Default: pipe via stdin
  trimmed + " < \"$1\""
}
