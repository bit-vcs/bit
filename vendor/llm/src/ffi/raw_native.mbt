///|
#borrow(command)
extern "C" fn llm_popen_ffi(command : Bytes) -> String = "llm_popen_ffi"

///|
/// Native primitive: run a command with args (JSON array string), return stdout.
/// Builds a shell command from program + args with proper escaping.
fn run_command(program : String, args_json : String) -> String {
  let args = parse_json_string_array(args_json)
  let cmd = build_shell_command(program, args)
  let cmd_bytes = mbt_string_to_utf8_bytes(cmd)
  llm_popen_ffi(cmd_bytes)
}

///|
/// Native primitive: run a shell command, return stdout.
fn run_shell(command : String, _timeout_ms : Int) -> String {
  let cmd_bytes = mbt_string_to_utf8_bytes(command)
  llm_popen_ffi(cmd_bytes)
}

///|
/// Shell-escape a string using single quotes.
fn shell_escape(s : String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('\'')
  for ch in s {
    if ch == '\'' {
      buf.write_string("'\\''")
    } else {
      buf.write_char(ch)
    }
  }
  buf.write_char('\'')
  buf.to_string()
}

///|
/// Build a shell command string from program and args with escaping.
/// Redirects stderr to stdout via 2>&1.
fn build_shell_command(program : String, args : Array[String]) -> String {
  let buf = StringBuilder::new()
  buf.write_string(shell_escape(program))
  for arg in args {
    buf.write_char(' ')
    buf.write_string(shell_escape(arg))
  }
  buf.write_string(" 2>&1")
  buf.to_string()
}

///|
/// Parse a JSON array of strings. Simple parser for ["a", "b", ...] format.
fn parse_json_string_array(json : String) -> Array[String] {
  let result : Array[String] = []
  let parsed = @json.parse(json) catch { _ => return result }
  match parsed {
    Json::Array(items) =>
      for item in items {
        match item {
          Json::String(s) => result.push(s)
          _ => ()
        }
      }
    _ => ()
  }
  result
}
