///| Ignore SIGPIPE on Unix to prevent exit 141 when piped output is truncated

///|
extern "c" fn bit_ignore_sigpipe() = "bit_ignore_sigpipe"

///|
fn bit_ignore_sigpipe_safe() -> Unit {
  bit_ignore_sigpipe()
}
