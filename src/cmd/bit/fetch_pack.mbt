///| git fetch-pack - low-level pack fetching

///|
async fn handle_fetch_pack(args : Array[String]) -> Unit raise Error {
  let mut thin = false
  let mut all = false
  let mut stdin = false
  let mut quiet = false
  let mut keep = false
  let mut no_progress = false
  let mut verbose = false
  let mut depth : Int? = None
  let mut upload_pack : String? = None
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--thin" => thin = true
      "--no-thin" => thin = false
      "--all" => all = true
      "--stdin" => stdin = true
      "-q" | "--quiet" => quiet = true
      "-k" | "--keep" => keep = true
      "--no-progress" => no_progress = true
      "-v" | "--verbose" => verbose = true
      "--include-tag" => ()
      "--stateless-rpc" => ()
      "--lock-pack" => ()
      "--cloning" => ()
      "--check-self-contained-and-connected" => ()
      "-h" | "--help" => {
        show_simple_command_help(
          "git fetch-pack [--all] [--stdin] [--quiet] [--keep] [--thin] [--upload-pack=<path>] [--depth=<n>] <url> [<ref>...]",
          summary="Receive missing objects from another repository.",
        )
        return
      }
      _ if arg.has_prefix("--depth=") =>
        depth = Some(@string.parse_int(arg[8:].to_string()) catch { _ => 0 })
      _ if arg.has_prefix("--upload-pack=") =>
        upload_pack = Some(arg[14:].to_string())
      _ if arg.has_prefix("--exec=") => upload_pack = Some(arg[7:].to_string())
      _ if arg.has_prefix("--filter=") => ()
      _ if arg.has_prefix("--server-option=") => ()
      _ if arg.has_prefix("--negotiation-tip=") => ()
      _ if arg == "--" => ()
      _ if !arg.has_prefix("-") => positional.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("fetch-pack", arg)
      _ => ()
    }
    i += 1
  }
  // Read refs from stdin if --stdin
  if stdin {
    let input = decode_bytes(read_all_stdin())
    for line_view in input.split("\n") {
      let line = trim_string(line_view.to_string())
      if line.length() > 0 {
        positional.push(line)
      }
    }
  }
  if positional.length() == 0 {
    eprint_line("fatal: no matching remote head")
    @sys.exit(1)
    return
  }
  let url = positional[0]
  let refs : Array[String] = []
  for j = 1; j < positional.length(); j = j + 1 {
    refs.push(positional[j])
  }
  // Delegate to existing fetch infrastructure
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  // Build fetch args to delegate
  let fetch_args : Array[String] = []
  if quiet {
    fetch_args.push("--quiet")
  }
  if no_progress {
    fetch_args.push("--no-progress")
  }
  fetch_args.push(url)
  for r in refs {
    fetch_args.push(r)
  }
  // Use handle_fetch as the backend
  handle_fetch(fetch_args)
  ignore(thin)
  ignore(all)
  ignore(keep)
  ignore(verbose)
  ignore(depth)
  ignore(upload_pack)
  ignore(git_dir)
}

///|
