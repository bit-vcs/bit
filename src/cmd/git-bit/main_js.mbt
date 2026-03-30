///| JS target entry point for git-bit

///|
async fn main_js_async() -> Unit {
  let args = @sys.get_cli_args()
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
