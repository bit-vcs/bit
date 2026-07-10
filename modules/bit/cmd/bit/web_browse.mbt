///| git web--browse - open URL in a web browser

///|
async fn handle_web_browse(args : Array[String]) -> Unit raise Error {
  let mut browser_cmd : String? = None
  let urls : Array[String] = []
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git web--browse [--browser=<browser>] <url>...",
          summary="Open one or more URLs in a web browser.",
        )
        return
      }
      _ if arg.has_prefix("--browser=") =>
        browser_cmd = Some(
          String::unsafe_substring(arg, start=10, end=arg.length()),
        )
      "-b" => ()
      _ if arg.has_prefix("-") => warn_unimplemented_arg("web--browse", arg)
      _ => urls.push(arg)
    }
  }
  if urls.length() == 0 {
    eprint_line("usage: git web--browse [--browser=<browser>] <url>...")
    @sys.exit(1)
  }
  let browser = match browser_cmd {
    Some(b) => b
    None => web_browse_detect_browser()
  }
  for url in urls {
    let code = @process.run(
      browser,
      [url],
      inherit_env=true,
      stdin=@stdio.stdin,
      stdout=@stdio.stdout,
      stderr=@stdio.stderr,
    )
    if code != 0 {
      eprint_line("fatal: failed to open '\{url}' with '\{browser}'")
      @sys.exit(1)
    }
  }
}

///|
fn web_browse_detect_browser() -> String {
  // Check GIT_BROWSER env var first
  match @sys.get_env_var("GIT_BROWSER") {
    Some(b) => if b.length() > 0 { return b }
    None => ()
  }
  // Check BROWSER env var
  match @sys.get_env_var("BROWSER") {
    Some(b) => if b.length() > 0 { return b }
    None => ()
  }
  // Detect platform by checking for macOS-specific path
  // macOS has /usr/bin/open, Linux uses xdg-open
  let fs = OsFs::new()
  if fs.is_file("/usr/bin/open") {
    "open"
  } else {
    "xdg-open"
  }
}
