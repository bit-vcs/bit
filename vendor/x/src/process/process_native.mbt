///|
/// Best-effort: move `pid` into its own process group via
/// `setpgid(pid, pid)`. Returns 0 on success (or when the child has
/// already exec'd and set its own pgid, which is treated as soft
/// success); a non-zero errno otherwise. The race window between the
/// async spawn helper's posix_spawn and this call is the reason the
/// `new_process_group` flag on `spawn` is documented as best-effort —
/// the kernel-level fix is `POSIX_SPAWN_SETPGROUP`, which needs
/// upstream moonbitlang/core/async to thread through.
extern "C" fn process_setpgid_self_ffi(pid : Int32) -> Int32 = "mizchi_x_process_setpgid_self"

///|
/// `kill(2)` raw wrapper. Returns 0 on success, an errno otherwise.
extern "C" fn process_kill_ffi(pid : Int32, signal : Int32) -> Int32 = "mizchi_x_process_kill"

///|
/// Send a signal to `pid`. Mirrors `kill(2)` — pass a negative `pid`
/// to target the process group whose pgid equals `-pid`. Silently
/// drops the errno; use the raw FFI if you need it.
pub fn kill(pid : Int32, signal : @signal.Signal) -> Unit {
  ignore(process_kill_ffi(pid, signal.to_int()))
}

///|
/// Send a signal to every process whose pgid equals this process's
/// pid. Effective only when the spawn was set up as a process-group
/// leader — pair with `spawn(..., new_process_group=true)`. When the
/// leader-set raced and lost, the call still sends `signal` to a
/// process group containing this single pid, so direct children
/// inheriting the parent's pgid are NOT hit; the caller must fall
/// back to per-pid signalling or `pkill -P` for the subtree.
pub fn Process::kill_tree(self : Process, signal : @signal.Signal) -> Unit {
  ignore(process_kill_ffi(-self.pid, signal.to_int()))
}

///|
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
  let process = spawn_internal(
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
  // The upstream spawn API does not expose POSIX_SPAWN_SETPGROUP, so this
  // remains best-effort and absorbs the race with child exec.
  if new_process_group {
    ignore(process_setpgid_self_ffi(process.pid))
  }
  process
}
