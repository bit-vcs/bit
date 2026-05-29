///| JS relay dispatcher (serve only)

///|
fn print_relay_js_usage() -> Unit {
  println("Usage: bit relay <subcommand> [<args>]")
  println("")
  println("Subcommands:")
  println("  serve         Serve repository via relay for remote cloning")
  println("  help          Show this help")
  println("")
  println("Run 'bit relay <subcommand> -h' for details.")
}

///|
async fn handle_relay_js(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    print_relay_js_usage()
    return
  }
  let subcmd = args[0]
  let rest = collect_args(args, 1)
  match subcmd {
    "help" | "-h" | "--help" => print_relay_js_usage()
    "serve" => handle_hub_serve(rest)
    "sync" => {
      eprint_line("bit relay sync: not supported in JS target")
      @sys.exit(1)
    }
    _ => {
      eprint_line("bit relay: unknown subcommand '\{subcmd}'")
      print_relay_js_usage()
      @sys.exit(1)
    }
  }
}
