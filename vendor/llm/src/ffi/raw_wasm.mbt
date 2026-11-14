///|
/// Wasm stub: run command (not supported).
fn run_command(_program : String, _args_json : String) -> String {
  abort("run_command is not supported on wasm target")
}

///|
/// Wasm stub: run shell command (not supported).
fn run_shell(_command : String, _timeout_ms : Int) -> String {
  abort("run_shell is not supported on wasm target")
}
