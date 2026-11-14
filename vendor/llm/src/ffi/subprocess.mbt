///|
/// Execute a command synchronously and return stdout.
pub fn exec_sync(command : String, timeout_ms : Int) -> String {
  run_shell(command, timeout_ms)
}

///|
/// Execute a command with streaming output (line by line).
/// Uses run_command for synchronous execution, then splits output by lines.
pub fn exec_stream(
  command : String,
  args_json : String,
  on_line : (String) -> Unit,
  on_done : () -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  let result = run_command(command, args_json)
  if result.has_prefix("ERROR:") {
    on_error(result)
    return
  }
  let lines = split_lines(result)
  for line in lines {
    if !line.trim(chars=" \t\r\n").to_owned().is_empty() {
      on_line(line)
    }
  }
  on_done()
}
