///| git ls-remote - list references in a remote repository

///|
async fn handle_ls_remote(args : Array[String]) -> Unit raise Error {
  let mut show_heads = false
  let mut show_tags = false
  let mut show_refs_only = false
  let mut quiet = false
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--heads" | "-h" => show_heads = true
      "--tags" | "-t" => show_tags = true
      "--refs" => show_refs_only = true
      "--quiet" | "-q" => quiet = true
      "--help" => {
        show_simple_command_help(
          "git ls-remote [--heads] [--tags] [--refs] [-q] <repository> [<refs>...]",
          summary="List references in a remote repository.",
        )
        return
      }
      "--symref" | "--get-url" | "--sort" =>
        // silently skip unsupported flags that take no arg
        ()
      "--upload-pack" | "-u" | "--server-option" | "-o" => {
        // skip flags with value
        i += 2
        continue
      }
      _ if arg.has_prefix("--upload-pack=") ||
        arg.has_prefix("--server-option=") ||
        arg.has_prefix("--sort=") => ()
      _ if arg.has_prefix("-") => warn_unimplemented_arg("ls-remote", arg)
      _ => positional.push(arg)
    }
    i += 1
  }
  // Determine remote URL
  let remote_url = if positional.length() > 0 {
    let repo_arg = positional[0]
    // If it looks like a URL, use directly
    if repo_arg.has_prefix("http://") ||
      repo_arg.has_prefix("https://") ||
      repo_arg.has_prefix("git://") ||
      repo_arg.has_prefix("ssh://") ||
      repo_arg.contains(":") {
      repo_arg
    } else {
      // Treat as remote name, look up URL from config
      ls_remote_resolve_name(repo_arg)
    }
  } else {
    // Default to "origin"
    ls_remote_resolve_name("origin")
  }
  // Pattern args for filtering
  let patterns : Array[String] = []
  for j in 1..<positional.length() {
    patterns.push(positional[j])
  }
  // Discover refs from remote
  let (refs, _caps, _version, _symrefs) = @bitnative.discover_upload_refs_http(
    remote_url, true,
  )
  // Filter and print
  if quiet {
    return
  }
  for pair in refs {
    let (oid, refname) = pair
    // Apply filters
    if show_heads && !(refname.has_prefix("refs/heads/")) {
      continue
    }
    if show_tags && !(refname.has_prefix("refs/tags/")) {
      continue
    }
    if show_refs_only {
      // --refs: exclude HEAD and peeled refs
      if refname == "HEAD" || refname.has_suffix("^{}") {
        continue
      }
    }
    // Apply pattern matching
    if patterns.length() > 0 {
      let mut matched = false
      for pattern in patterns {
        if ls_remote_match_pattern(refname, pattern) {
          matched = true
          break
        }
      }
      if !(matched) {
        continue
      }
    }
    print_line("\{oid.to_hex()}\t\{refname}")
  }
}

///|
async fn ls_remote_resolve_name(name : String) -> String raise Error {
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let root = get_work_root()
  let git_dir = resolve_git_dir(rfs, root)
  let (remotes, _) = @bitlib.read_repo_config(fs, git_dir)
  match remotes.get(name) {
    Some(config) =>
      if config.urls.length() > 0 {
        config.urls[0]
      } else {
        eprint_line("fatal: Remote '\{name}' has no URL configured")
        @sys.exit(1)
        "" // unreachable
      }
    None => {
      eprint_line("fatal: '\{name}' does not appear to be a git repository")
      @sys.exit(1)
      "" // unreachable
    }
  }
}

///|
fn ls_remote_match_pattern(refname : String, pattern : String) -> Bool {
  // Simple glob matching: pattern with * at end matches prefix
  if pattern.has_suffix("*") {
    let prefix = String::unsafe_substring(
      pattern,
      start=0,
      end=pattern.length() - 1,
    )
    refname.has_prefix(prefix)
  } else {
    // Exact match or suffix match (like git)
    refname == pattern ||
    refname.has_suffix("/" + pattern) ||
    refname == "refs/" + pattern ||
    refname == "refs/heads/" + pattern ||
    refname == "refs/tags/" + pattern
  }
}
