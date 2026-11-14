///|
/// JS primitive: run a command with args (JSON array string), return stdout.
/// Returns "ERROR: ..." on failure.
fn run_command(program : String, args_json : String) -> String {
  js_run_command(program, args_json)
}

///|
extern "js" fn js_run_command(program : String, args_json : String) -> String =
  #|(program, argsJson) => {
  #|  try {
  #|    const { spawnSync } = require('child_process');
  #|    const args = JSON.parse(argsJson);
  #|    const result = spawnSync(program, args, { encoding: 'utf-8', maxBuffer: 50 * 1024 * 1024 });
  #|    if (result.error) { return 'ERROR: ' + (result.error.message || String(result.error)); }
  #|    if (result.status !== 0) { return 'ERROR: exit code ' + result.status + ': ' + (result.stderr || ''); }
  #|    return result.stdout || '';
  #|  } catch (e) {
  #|    return 'ERROR: ' + (e.message || String(e));
  #|  }
  #|}

///|
/// JS primitive: run a shell command, return stdout.
/// Returns "ERROR: ..." on failure.
fn run_shell(command : String, timeout_ms : Int) -> String {
  js_run_shell(command, timeout_ms)
}

///|
extern "js" fn js_run_shell(command : String, timeout_ms : Int) -> String =
  #|(command, timeoutMs) => {
  #|  try {
  #|    const { execSync } = require('child_process');
  #|    return execSync(command, { timeout: timeoutMs, encoding: 'utf-8' });
  #|  } catch (e) {
  #|    return 'ERROR: ' + (e.message || String(e));
  #|  }
  #|}
