///| JS target entry point for git-bit

///|
async fn main_js_async() -> Unit {
  // `@env.args()` keeps `process.argv[0]`, the JavaScript runtime
  // executable, which the deprecated `@sys.get_cli_args()` dropped. The
  // dispatch below indexes from the script path, so drop it here instead
  // of shifting every index.
  let args = @env.args()[1:].to_owned()
  if args.length() >= 2 {
    match args[1] {
      "-v" | "--version" | "version" => {
        println("git-bit version 0.1.0")
        return
      }
      _ => ()
    }
  }
  println("git-bit is only available on the native target.")
}

///|
fn main {
  @async.run_async_main(main_js_async)
}
