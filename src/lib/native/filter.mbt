///| Native filter command execution

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
    err => raise @bit.GitError::IoError("filter write temp failed: \{err}")
  }
  let shell_cmd = build_filter_shell_command(command)
  let (code, stdout) = @process.collect_stdout(
    "sh",
    ["-c", shell_cmd, "bit-filter", temp_path],
    inherit_env=true,
    cwd=root,
  ) catch {
    err => {
      @fs.remove_file(temp_path) catch {
        _ => ()
      }
      raise @bit.GitError::IoError("filter command failed: \{err}")
    }
  }
  @fs.remove_file(temp_path) catch {
    _ => ()
  }
  if code != 0 {
    raise @bit.GitError::IoError(
      "filter command '\{command}' failed with status \{code}",
    )
  }
  stdout.binary()
}

///|
/// Build shell command for filter execution.
/// Supports: "cmd %f" → "cmd "$1"", "cmd" → "cmd < "$1""
fn build_filter_shell_command(command : String) -> String {
  let trimmed = command.trim().to_string()
  if trimmed.contains("%f") {
    return trimmed.replace_all(old="%f", new="\"$1\"")
  }
  // Default: pipe via stdin
  trimmed + " < \"$1\""
}
