///| GitHub sync subcommands for `bit issue sync`

///|
fn print_hub_issue_sync_usage() -> Unit {
  println("Usage: bit issue sync <subcommand> [<args>]")
  println("")
  println("Subcommands:")
  println(
    "  pull --repo <owner/repo> [--include-prs] [--comments append-only|full|no-delete]",
  )
  println(
    "  push --github --repo <owner/repo> [--apply] [--include-prs] [--comments append-only|full|no-delete]",
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
  let mut include_prs = false
  let mut comments_mode = "append-only"
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
    } else if arg == "--include-prs" {
      include_prs = true
    } else if arg == "--comments" && i + 1 < args.length() {
      i += 1
      comments_mode = args[i]
    } else if arg.has_prefix("--comments=") {
      comments_mode = String::unsafe_substring(
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
  print_line("Issues pull complete:")
  print_line("  Created: \{result.created}")
  print_line("  Updated: \{result.updated}")
  print_line("  Skipped: \{result.skipped}")
  if result.conflicts.length() > 0 {
    print_line("  Conflicts (manual review needed):")
    for c in result.conflicts {
      print_line("    \{c}")
    }
  }
  // Pull comments for synced issues
  let links = hub.list_sync_links(objects, repo=resolved_repo)
  let mut total_comments_created = 0
  let mut total_comments_updated = 0
  let mut total_comments_deleted = 0
  for link in links {
    if link.local_kind() == "issue" || link.local_kind() == "pr" {
      let cr = @hub_native.github_sync_pull_comments(
        hub,
        objects,
        refs,
        clock,
        resolved_repo,
        link.local_id(),
        link.remote_number(),
        comments_mode,
      )
      total_comments_created += cr.created()
      total_comments_updated += cr.updated()
      total_comments_deleted += cr.deleted()
      if cr.errors().length() > 0 {
        for err in cr.errors() {
          print_line("  Comment error: \{err}")
        }
      }
    }
  }
  if total_comments_created > 0 ||
    total_comments_updated > 0 ||
    total_comments_deleted > 0 {
    print_line("")
    print_line("Comments pull complete:")
    print_line("  Created: \{total_comments_created}")
    print_line("  Updated: \{total_comments_updated}")
    print_line("  Deleted: \{total_comments_deleted}")
  }
  if include_prs {
    print_line("")
    print_line("Pulling PRs from GitHub \{resolved_repo}...")
    let pr_result = @hub_native.github_sync_pull_prs(
      hub, objects, refs, clock, resolved_repo, since, state, conflict,
    )
    print_line("PRs pull complete:")
    print_line("  Created: \{pr_result.created}")
    print_line("  Updated: \{pr_result.updated}")
    print_line("  Skipped: \{pr_result.skipped}")
    if pr_result.conflicts.length() > 0 {
      print_line("  Conflicts (manual review needed):")
      for c in pr_result.conflicts {
        print_line("    \{c}")
      }
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
  let mut include_prs = false
  let mut comments_mode = "append-only"
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
    } else if arg == "--include-prs" {
      include_prs = true
    } else if arg == "--comments" && i + 1 < args.length() {
      i += 1
      comments_mode = args[i]
    } else if arg.has_prefix("--comments=") {
      comments_mode = String::unsafe_substring(
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
  if not(github_flag) {
    eprint_line("Error: --github flag required for push (safety measure)")
    eprint_line(
      "Usage: bit issue sync push --github --repo <owner/repo> [--apply]",
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
  let pr_changes = if include_prs {
    @hub_native.github_sync_plan_push_prs(hub, objects, resolved_repo)
  } else {
    []
  }
  if changes.length() == 0 && pr_changes.length() == 0 {
    print_line("Nothing to push to \{resolved_repo}")
    return ()
  }
  // Display issue plan
  if changes.length() > 0 {
    print_line("Issue changes to push to GitHub (\{resolved_repo}):")
    print_line("")
    for change in changes {
      print_push_change(change, "issue")
    }
    print_line("")
  }
  // Display PR plan
  if pr_changes.length() > 0 {
    print_line("PR changes to push to GitHub (\{resolved_repo}):")
    print_line("")
    for change in pr_changes {
      print_push_change(change, "PR")
    }
    print_line("")
  }
  if not(apply) {
    print_line("Run with --apply to execute these changes.")
    return ()
  }
  // Execute issues
  if changes.length() > 0 {
    print_line("Pushing issues to GitHub...")
    let result = @hub_native.github_sync_execute_push(
      hub, objects, refs, clock, resolved_repo, changes,
    )
    print_line("Issue push complete:")
    print_line("  Created: \{result.created}")
    print_line("  Updated: \{result.updated}")
    if result.errors.length() > 0 {
      print_line("  Errors:")
      for err in result.errors {
        print_line("    \{err}")
      }
    }
  }
  // Execute PRs
  if pr_changes.length() > 0 {
    print_line("Pushing PR updates to GitHub...")
    let pr_result = @hub_native.github_sync_execute_push_prs(
      hub, objects, refs, clock, resolved_repo, pr_changes,
    )
    print_line("PR push complete:")
    print_line("  Created: \{pr_result.created}")
    print_line("  Updated: \{pr_result.updated}")
    if pr_result.errors.length() > 0 {
      print_line("  Errors:")
      for err in pr_result.errors {
        print_line("    \{err}")
      }
    }
  }
  // Push comments for synced issues/PRs
  let links = hub.list_sync_links(objects, repo=resolved_repo)
  let mut total_comments_created = 0
  let mut total_comments_updated = 0
  for link in links {
    if link.local_kind() == "issue" || link.local_kind() == "pr" {
      let cr = @hub_native.github_sync_push_comments(
        hub,
        objects,
        refs,
        clock,
        resolved_repo,
        link.local_id(),
        link.remote_number(),
        comments_mode,
        apply,
      )
      total_comments_created += cr.created()
      total_comments_updated += cr.updated()
      if cr.errors().length() > 0 {
        for err in cr.errors() {
          print_line("  Comment error: \{err}")
        }
      }
    }
  }
  if total_comments_created > 0 || total_comments_updated > 0 {
    print_line("")
    print_line("Comments push complete:")
    print_line("  Created: \{total_comments_created}")
    print_line("  Updated: \{total_comments_updated}")
  }
}

///|
async fn print_push_change(
  change : @hub_native.SyncPushChange,
  kind : String,
) -> Unit raise Error {
  let prefix = if change.is_destructive { "  ! " } else { "  " }
  match change.action {
    "create" => {
      print_line("\{prefix}CREATE \{kind} \"\{change.title}\"")
      if change.labels_change.length() > 0 {
        print_line("    labels: \{change.labels_change}")
      }
    }
    "update" => {
      print_line(
        "\{prefix}UPDATE \{kind} #\{change.remote_number} \"\{change.title}\"",
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

///|
async fn handle_hub_issue_sync_install_hook(
  _args : Array[String],
) -> Unit raise Error {
  eprint_line("bit issue sync install-hook: not yet implemented")
  @sys.exit(1)
}

///|
async fn handle_hub_issue_sync_bidirectional(
  _args : Array[String],
) -> Unit raise Error {
  eprint_line("bit issue sync: bidirectional sync not yet implemented")
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
      "Run `bit issue sync pull --repo \{resolved_repo}` to pull issues from GitHub.",
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
