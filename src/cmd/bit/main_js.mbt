///| JS target main entry point

///|
/// bit version tag (update this and moon.mod.json together when releasing)
let bit_version_tag : String = "2.47.0 (bit v0.35.0)"

///|
async fn main_js_async() -> Unit {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    show_help_js()
    return
  }
  let mut i = 1
  while i < args.length() {
    match args[i] {
      "-v" | "--version" | "version" => {
        println("git version \{bit_version_tag}")
        return
      }
      "-h" | "--help" => {
        show_help_js()
        return
      }
      _ if !(args[i].has_prefix("-")) => break
      _ => ()
    }
    i += 1
  }
  if i < args.length() {
    let cmd = args[i]
    let rest = collect_args(args, i + 1)
    match cmd {
      "help" => show_help_js()
      "version" => println("git version \{bit_version_tag}")
      "relay" =>
        handle_relay_js(rest) catch {
          err => {
            eprint_line("relay error: \{err}")
            @sys.exit(1)
          }
        }
      "clone" | "fetch" | "pull" | "push" => {
        eprint_line(
          "fatal: '\{cmd}' is not available on JS target (no native network/SSH support).",
        )
        eprint_line(
          "hint: Use relay clone instead: bit clone relay+https://relay.example.com/<session>",
        )
        eprint_line(
          "hint: Or use the native binary: moon run src/cmd/bit -- \{cmd} <url>",
        )
        @sys.exit(1)
      }
      _ => {
        eprint_line("bit: '\{cmd}' is not supported in JS target")
        @sys.exit(1)
      }
    }
  } else {
    show_help_js()
  }
}

///|
fn main {
  @async.run_async_main(main_js_async)
}

///|
fn show_help_js() -> Unit {
  let help =
    #|usage: bit [-v | --version] [-h | --help]
    #|           <command> [<args>]
    #|
    #|bit is a Git implementation in MoonBit (JS target).
    #|
    #|Available commands:
    #|  relay serve    Serve repository via relay
    #|
    #|See https://github.com/bit-vcs/bit for more information.
  println(help)
}
