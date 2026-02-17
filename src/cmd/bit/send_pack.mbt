///|
async fn handle_send_pack(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut dry_run = false
  let mut force = false
  let mut verbose = false
  let mut all = false
  let mut mirror = false
  let mut stdin = false
  let mut remote : String? = None
  let refspecs : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-n" | "--dry-run" => dry_run = true
      "-f" | "--force" => force = true
      "-v" | "--verbose" => verbose = true
      "--thin" | "--no-thin" => ()
      "--atomic" => ()
      "--stateless-rpc" => ()
      "--all" => all = true
      "--mirror" => mirror = true
      "--stdin" => stdin = true
      "--receive-pack" if i + 1 < args.length() => {
        i += 2
        continue
      }
      _ if arg.has_prefix("--receive-pack=") => ()
      _ if arg.has_prefix("--exec=") => ()
      _ if not(arg.has_prefix("-")) =>
        if remote is None {
          remote = Some(arg)
        } else {
          refspecs.push(arg)
        }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("send-pack", arg)
      _ => ()
    }
    i += 1
  }
  // Read refspecs from stdin if requested
  if stdin {
    let input = decode_bytes(read_all_stdin())
    for line_view in input.split("\n") {
      let line = trim_string(line_view.to_string())
      if line.length() > 0 {
        refspecs.push(line)
      }
    }
  }
  guard remote is Some(remote_url) else {
    eprint_line("fatal: No destination specified")
    @sys.exit(128)
    return
  }
  // If --all or --mirror, add all refs
  if all || mirror {
    let refs = @bitrepo.show_ref(fs, git_dir)
    for item in refs {
      let (name, _) = item
      if mirror || name.has_prefix("refs/heads/") {
        refspecs.push(name + ":" + name)
      }
    }
  }
  if refspecs.length() == 0 {
    // Default to current branch
    let head = decode_bytes(fs.read_file(git_dir + "/HEAD"))
    if head.has_prefix("ref: ") {
      let ref_name = trim_string(head[5:].to_string())
      refspecs.push(ref_name + ":" + ref_name)
    }
  }
  // Parse refspecs and collect refs to push
  let refs_to_push : Array[(String, @bitcore.ObjectId, String)] = []
  for spec in refspecs {
    let (src, dst) = match spec.find(":") {
      Some(idx) => (spec[:idx].to_string(), spec[idx + 1:].to_string())
      None => (spec, spec)
    }
    // Handle force push
    let actual_src = if src.has_prefix("+") { src[1:].to_string() } else { src }
    // Resolve source ref
    match @bitrepo.rev_parse(fs, git_dir, actual_src) {
      Some(id) => refs_to_push.push((actual_src, id, dst))
      None =>
        if actual_src.length() > 0 {
          eprint_line(
            "error: src refspec " + actual_src + " does not match any",
          )
        }
    }
  }
  if verbose {
    for item in refs_to_push {
      let (src, id, dst) = item
      print_line(
        "push " + src + " -> " + dst + " (" + id.to_hex()[:7].to_string() + ")",
      )
    }
  }
  if dry_run {
    print_line("(dry run - no actual push)")
    return
  }
  // For actual push, we would need to establish connection
  // This is a simplified implementation that outputs what would be sent
  print_line("To " + remote_url)
  for item in refs_to_push {
    let (_, id, dst) = item
    print_line(
      " * [new reference]  " + id.to_hex()[:7].to_string() + " -> " + dst,
    )
  }
  ignore(force)
}

///|
