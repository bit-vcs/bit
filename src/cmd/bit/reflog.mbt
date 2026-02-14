///|
async fn handle_reflog(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let rfs : &@git.RepoFileSystem = fs
  let wfs : &@git.FileSystem = fs
  if args.length() == 0 {
    // Default to show HEAD
    show_reflog(rfs, git_dir, "HEAD", false)
    return
  }
  let subcmd = args[0]
  let rest : Array[String] = []
  for i in 1..<args.length() {
    rest.push(args[i])
  }
  match subcmd {
    "show" => {
      let (refname, no_abbrev_commit) = parse_reflog_show_args(rest)
      show_reflog(rfs, git_dir, refname, no_abbrev_commit)
    }
    "exists" => {
      if rest.length() == 0 {
        @stdio.stderr.write("usage: git reflog exists <ref>")
        @sys.exit(1)
      }
      let refname = rest[0]
      if @gitrepo.reflog_exists(rfs, git_dir, refname) {
        @sys.exit(0)
      } else {
        @sys.exit(1)
      }
    }
    "delete" => {
      if rest.length() == 0 {
        @stdio.stderr.write("usage: git reflog delete <ref>")
        @sys.exit(1)
      }
      let refname = rest[0]
      @gitrepo.delete_reflog(wfs, rfs, git_dir, refname)
    }
    "expire" =>
      // For now, just a no-op (would need to implement expiry logic)
      ()
    _ => {
      let show_args : Array[String] = []
      show_args.push(subcmd)
      show_args.append(rest)
      let (refname, no_abbrev_commit) = parse_reflog_show_args(show_args)
      // Treat as a ref name for show
      show_reflog(rfs, git_dir, refname, no_abbrev_commit)
    }
  }
}

///|
async fn show_reflog(
  fs : &@git.RepoFileSystem,
  git_dir : String,
  refname : String,
  no_abbrev_commit : Bool,
) -> Unit raise Error {
  let entries = @gitrepo.read_reflog(fs, git_dir, refname)
  // Show in reverse order (newest first)
  let len = entries.length()
  for i in 0..<len {
    let idx = len - 1 - i
    let entry = entries[idx]
    let sha = if no_abbrev_commit {
      entry.new_id.to_hex()
    } else {
      String::unsafe_substring(entry.new_id.to_hex(), start=0, end=7)
    }
    print_line("\{sha} \{refname}@{\{i}}: \{entry.message}")
  }
}

///|
fn parse_reflog_show_args(args : Array[String]) -> (String, Bool) {
  let mut refname = "HEAD"
  let mut no_abbrev_commit = false
  let mut has_refname = false
  for arg in args {
    match arg {
      "--no-abbrev-commit" => no_abbrev_commit = true
      _ if arg.has_prefix("-") => ()
      _ =>
        if not(has_refname) {
          refname = arg
          has_refname = true
        }
    }
  }
  (refname, no_abbrev_commit)
}

///|
