///| SIGPIPE is not relevant on JS/WASM targets

///|
pub fn bit_ignore_sigpipe_safe() -> Unit {
  // No-op: SIGPIPE only exists on Unix
}
