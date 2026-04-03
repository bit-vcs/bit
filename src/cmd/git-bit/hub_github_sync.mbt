///| GitHub sync subcommands for `git-bit issue sync`

///|
fn print_hub_issue_sync_usage() -> Unit {
  println("Usage: git-bit issue sync <subcommand> [<args>]")
  println("")
  println("Subcommands:")
  println("  pull --repo <owner/repo>                (pull from GitHub)")
  println(
    "  push --github --repo <owner/repo> [--apply]",
  )
  println("  status --repo <owner/repo>")
  println("  install-hook                            (install git hook)")
}

///|
async fn handle_hub_issue_sync(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    print_hub_issue_sync_usage()
    return ()
  }
  let subcmd = args[0]
  let rest = collect_args(args, 1)
  match subcmd {
    "pull" => handle_hub_issue_sync_pull(rest)
    "push" => handle_hub_issue_sync_push(rest)
    "status" => handle_hub_issue_sync_status(rest)
    "install-hook" => handle_hub_issue_sync_install_hook(rest)
    "help" | "-h" | "--help" => print_hub_issue_sync_usage()
    _ => {
      // If no recognized subcommand, treat as bidirectional sync flags
      handle_hub_issue_sync_bidirectional(args)
    }
  }
}

///|
async fn handle_hub_issue_sync_pull(
  args : Array[String],
) -> Unit raise Error {
  let mut repo : String? = None
  let mut since = ""
  let mut state = "all"
  let mut conflict = "newer-wins"
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--repo" && i + 1 < args.length() {
      i += 1
      repo = Some(args[i])
    } else if arg.has_prefix("--repo=") {
      repo = Some(
        String::unsafe_substring(arg, start=7, end=arg.length()),
      )
    } else if arg == "--since" && i + 1 < args.length() {
      i += 1
      since = args[i]
    } else if arg.has_prefix("--since=") {
      since = String::unsafe_substring(arg, start=8, end=arg.length())
    } else if arg == "--state" && i + 1 < args.length() {
      i += 1
      state = args[i]
    } else if arg.has_prefix("--state=") {
      state = String::unsafe_substring(arg, start=8, end=arg.length())
    } else if arg == "--conflict" && i + 1 < args.length() {
      i += 1
      conflict = args[i]
    } else if arg.has_prefix("--conflict=") {
      conflict = String::unsafe_substring(
        arg,
        start=11,
        end=arg.length(),
      )
    } else if arg == "-h" || arg == "--help" {
      print_hub_issue_sync_usage()
      return ()
    }
    i += 1
  }
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let fs = OsFs::new()
  let resolved_repo = resolve_github_repo(fs, git_dir, repo)
  let (objects, refs, clock) = make_hub_stores(git_dir)
  let hub = load_hub_store(objects, refs)
  print_line("Pulling issues from GitHub \{resolved_repo}...")
  let result = @hub_native.github_sync_pull_issues(
    hub, objects, refs, clock, resolved_repo, since, state, conflict,
  )
  print_line("Pull complete:")
  print_line("  Created: \{result.created}")
  print_line("  Updated: \{result.updated}")
  print_line("  Skipped: \{result.skipped}")
  if result.conflicts.length() > 0 {
    print_line("  Conflicts (manual review needed):")
    for c in result.conflicts {
      print_line("    \{c}")
    }
  }
}

///|
async fn handle_hub_issue_sync_push(
  args : Array[String],
) -> Unit raise Error {
  let mut repo : String? = None
  let mut github_flag = false
  let mut apply = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--repo" && i + 1 < args.length() {
      i += 1
      repo = Some(args[i])
    } else if arg.has_prefix("--repo=") {
      repo = Some(
        String::unsafe_substring(arg, start=7, end=arg.length()),
      )
    } else if arg == "--github" {
      github_flag = true
    } else if arg == "--apply" {
      apply = true
    } else if arg == "-h" || arg == "--help" {
      print_hub_issue_sync_usage()
      return ()
    }
    i += 1
  }
  if not(github_flag) {
    eprint_line("Error: --github flag required for push (safety measure)")
    eprint_line(
      "Usage: git-bit issue sync push --github --repo <owner/repo> [--apply]",
    )
    @sys.exit(1)
  }
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let fs = OsFs::new()
  let resolved_repo = resolve_github_repo(fs, git_dir, repo)
  let (objects, refs, clock) = make_hub_stores(git_dir)
  let hub = load_hub_store(objects, refs)
  let changes = @hub_native.github_sync_plan_push(hub, objects, resolved_repo)
  if changes.length() == 0 {
    print_line("Nothing to push to \{resolved_repo}")
    return ()
  }
  // Display plan
  print_line("Changes to push to GitHub (\{resolved_repo}):")
  print_line("")
  for change in changes {
    let prefix = if change.is_destructive { "  ! " } else { "  " }
    match change.action {
      "create" => {
        print_line("\{prefix}CREATE issue \"\{change.title}\"")
        if change.labels_change.length() > 0 {
          print_line("    labels: \{change.labels_change}")
        }
      }
      "update" => {
        print_line(
          "\{prefix}UPDATE issue #\{change.remote_number} \"\{change.title}\"",
        )
        if change.state_change.length() > 0 {
          print_line("    state: \{change.state_change}")
        }
        if change.title_change.length() > 0 {
          print_line("    title: \{change.title_change}")
        }
        if change.labels_change.length() > 0 {
          print_line("    labels: \{change.labels_change}")
        }
      }
      _ => ()
    }
  }
  print_line("")
  if not(apply) {
    print_line("Run with --apply to execute these changes.")
    return ()
  }
  // Execute
  print_line("Pushing to GitHub...")
  let result = @hub_native.github_sync_execute_push(
    hub, objects, refs, clock, resolved_repo, changes,
  )
  print_line("Push complete:")
  print_line("  Created: \{result.created}")
  print_line("  Updated: \{result.updated}")
  if result.errors.length() > 0 {
    print_line("  Errors:")
    for err in result.errors {
      print_line("    \{err}")
    }
  }
}

///|
async fn handle_hub_issue_sync_install_hook(
  _args : Array[String],
) -> Unit raise Error {
  eprint_line("git-bit issue sync install-hook: not yet implemented")
  @sys.exit(1)
}

///|
async fn handle_hub_issue_sync_bidirectional(
  _args : Array[String],
) -> Unit raise Error {
  eprint_line("git-bit issue sync: bidirectional sync not yet implemented")
  @sys.exit(1)
}

///|
async fn handle_hub_issue_sync_status(
  args : Array[String],
) -> Unit raise Error {
  let mut repo : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--repo" && i + 1 < args.length() {
      i += 1
      repo = Some(args[i])
    } else if arg.has_prefix("--repo=") {
      repo = Some(
        String::unsafe_substring(arg, start=7, end=arg.length()),
      )
    } else if arg == "-h" || arg == "--help" {
      print_hub_issue_sync_usage()
      return ()
    }
    i += 1
  }
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let fs = OsFs::new()
  let resolved_repo = resolve_github_repo(fs, git_dir, repo)
  let (objects, refs, _clock) = make_hub_stores(git_dir)
  let hub = load_hub_store(objects, refs)
  let links = hub.list_sync_links(objects, repo=resolved_repo)
  if links.length() == 0 {
    print_line("No sync links found for \{resolved_repo}")
    print_line("")
    print_line(
      "Run `git-bit issue sync pull --repo \{resolved_repo}` to pull issues from GitHub.",
    )
    return ()
  }
  print_line("Sync status for \{resolved_repo}")
  print_line("  Linked items: \{links.length()}")
  print_line("")
  // Show recent sync links (up to 20)
  let limit = if links.length() > 20 { 20 } else { links.length() }
  for idx = 0; idx < limit; idx = idx + 1 {
    let link = links[idx]
    let kind = link.local_kind()
    let num = link.remote_number()
    let local_id_short = if link.local_id().length() > 8 {
      String::unsafe_substring(link.local_id(), start=0, end=8)
    } else {
      link.local_id()
    }
    let pull_ts = link.last_pull_at()
    let push_ts = link.last_push_at()
    let pull_str = if pull_ts > 0L {
      format_timestamp_iso(pull_ts, "+0000")
    } else {
      "never"
    }
    let push_str = if push_ts > 0L {
      format_timestamp_iso(push_ts, "+0000")
    } else {
      "never"
    }
    print_line(
      "  \{kind} #\{num} <-> \{local_id_short}  pulled: \{pull_str}  pushed: \{push_str}",
    )
  }
  if links.length() > limit {
    print_line("  ... and \{links.length() - limit} more")
  }
}
