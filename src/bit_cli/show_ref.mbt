///|
async fn handle_show_ref(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let git_dir = resolve_git_dir(fs, root)
  let mut heads_only = false
  let mut tags_only = false
  let mut hash_only = false
  let mut verify = false
  let mut quiet = false
  let patterns : Array[String] = []
  for arg in args {
    match arg {
      "--heads" => heads_only = true
      "--tags" => tags_only = true
      "-s" | "--hash" => hash_only = true
      "--verify" => verify = true
      "-q" | "--quiet" => quiet = true
      "--" => ()
      _ if arg.has_prefix("-") => warn_unimplemented_arg("show-ref", arg)
      _ => patterns.push(arg)
    }
  }
  if verify {
    if patterns.length() == 0 {
      @sys.exit(1)
    }
    let mut has_missing = false
    for refname in patterns {
      match @gitlib.resolve_ref(fs, git_dir, refname) {
        Some(id) =>
          if not(quiet) {
            if hash_only {
              print_line(id.to_hex())
            } else {
              print_line("\{id.to_hex()} \{refname}")
            }
          }
        None => has_missing = true
      }
    }
    if has_missing {
      @sys.exit(1)
    }
    return
  }
  let refs = @gitrepo.show_ref(fs, git_dir)
  let mut matched_count = 0
  for item in refs {
    let (refname, id) = item
    if heads_only && not(refname.has_prefix("refs/heads/")) {
      continue
    }
    if tags_only && not(refname.has_prefix("refs/tags/")) {
      continue
    }
    if patterns.length() > 0 {
      let mut matched = false
      for pattern in patterns {
        if refname == pattern || refname.has_suffix("/" + pattern) {
          matched = true
          break
        }
      }
      if not(matched) {
        continue
      }
    }
    matched_count += 1
    if not(quiet) {
      if hash_only {
        print_line(id.to_hex())
      } else {
        print_line("\{id.to_hex()} \{refname}")
      }
    }
  }
  if matched_count == 0 {
    @sys.exit(1)
  }
}

///|
