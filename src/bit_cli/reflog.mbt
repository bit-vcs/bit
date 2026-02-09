///|
async fn handle_reflog(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let rfs : &@git.RepoFileSystem = fs
  let wfs : &@git.FileSystem = fs
  if args.length() == 0 {
    // Default to show HEAD
    show_reflog(rfs, git_dir, "HEAD")
    return
  }
  let subcmd = args[0]
  let rest : Array[String] = []
  for i in 1..<args.length() {
    rest.push(args[i])
  }
  match subcmd {
    "show" => {
      let refname = if rest.length() > 0 { rest[0] } else { "HEAD" }
      show_reflog(rfs, git_dir, refname)
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
    _ =>
      // Treat as a ref name for show
      show_reflog(rfs, git_dir, subcmd)
  }
}

///|
async fn show_reflog(
  fs : &@git.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Unit raise Error {
  let entries = @gitrepo.read_reflog(fs, git_dir, refname)
  // Show in reverse order (newest first)
  let len = entries.length()
  for i in 0..<len {
    let idx = len - 1 - i
    let entry = entries[idx]
    let short_sha = String::unsafe_substring(
      entry.new_id.to_hex(),
      start=0,
      end=7,
    )
    print_line("\{short_sha} \{refname}@{\{i}}: \{entry.message}")
  }
}

///|
