///|
/// Process signals are not exposed by the WASM process backend.
/// This function is retained for source compatibility and always aborts.
pub fn kill(_pid : Int32, _signal : @signal.Signal) -> Unit {
  abort("process signals are not supported on wasm target")
}

///|
/// Process groups are not supported by the WASM process backend.
/// This function is retained for source compatibility and always aborts.
pub fn Process::kill_tree(_self : Process, _signal : @signal.Signal) -> Unit {
  abort("process groups are not supported on wasm target")
}

///|
/// Spawn a process through `moonbitlang/core/async/process`.
///
/// `new_process_group=true` is unsupported on WASM and aborts rather than
/// silently running without process-group isolation.
pub async fn spawn(
  group : @async.TaskGroup,
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler~ : CancellationHandler = graceful_cancel(timeout=5000),
  no_wait? : Bool,
  new_process_group~ : Bool = false,
) -> Process {
  if new_process_group {
    abort("new_process_group is not supported on wasm target")
  }
  spawn_internal(
    group,
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cwd?,
    cancel_handler~,
    no_wait?,
  )
}
