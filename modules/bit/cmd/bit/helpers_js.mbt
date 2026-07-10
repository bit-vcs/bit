///| JS-specific helper functions

///|
extern "js" fn js_console_error(s : String) -> Unit =
  #| (s) => { process.stderr.write(s + '\n'); }

///|
async fn print_line(s : String) -> Unit {
  println(s)
}

///|
async fn eprint_line(s : String) -> Unit {
  js_console_error(s)
}
