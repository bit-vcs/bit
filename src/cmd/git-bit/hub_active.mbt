///|
fn hub_active_issues_path(git_dir : String) -> String {
  git_dir + "/hub/active-issues"
}

///|
/// Parse newline-separated entries, skip blank lines.
fn parse_active_issues(content : String) -> Array[String] {
  let result : Array[String] = []
  if content.length() == 0 {
    return result
  }
  for line_view in content.split("\n") {
    let trimmed = line_view.to_string().trim().to_string()
    if trimmed.length() > 0 {
      result.push(trimmed)
    }
  }
  result
}

///|
/// Join entries with newlines.
fn serialize_active_issues(entries : Array[String]) -> String {
  let buf = StringBuilder::new()
  for entry in entries {
    buf.write_string(entry)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// Add if not already present (no duplicates).
fn add_active_issue(
  entries : Array[String],
  issue_ref : String,
) -> Array[String] {
  for entry in entries {
    if entry == issue_ref {
      return entries
    }
  }
  let result = entries.copy()
  result.push(issue_ref)
  result
}

///|
/// Filter out matching entry.
fn remove_active_issue(
  entries : Array[String],
  issue_ref : String,
) -> Array[String] {
  entries.filter(fn(entry) { entry != issue_ref })
}

///|
/// Load active issues from git_dir/hub/active-issues file.
fn load_active_issues(git_dir : String) -> Array[String] {
  let fs = OsFs::new()
  let path = hub_active_issues_path(git_dir)
  if !(fs.is_file(path)) {
    return []
  }
  let bytes = fs.read_file(path) catch { _ => return [] }
  let content = @utf8.decode_lossy(bytes[:]).to_string()
  parse_active_issues(content)
}

///|
/// Save active issues to git_dir/hub/active-issues file.
fn save_active_issues(
  git_dir : String,
  entries : Array[String],
) -> Unit raise Error {
  let fs = OsFs::new()
  let path = hub_active_issues_path(git_dir)
  let dir = match path.rev_find("/") {
    Some(idx) => String::unsafe_substring(path, start=0, end=idx)
    None => "."
  }
  fs.mkdir_p(dir)
  let content = serialize_active_issues(entries)
  fs.write_string(path, content)
}

///|
async fn handle_hub_issue_start(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    eprint_line("Usage: git-bit issue start <ref>")
    @sys.exit(1)
  }
  let issue_ref = args[0]
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let entries = load_active_issues(git_dir)
  let updated = add_active_issue(entries, issue_ref)
  save_active_issues(git_dir, updated)
  print_line("Added \{issue_ref} to active issues")
}

///|
async fn handle_hub_issue_stop(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    eprint_line("Usage: git-bit issue stop <ref>")
    @sys.exit(1)
  }
  let issue_ref = args[0]
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let entries = load_active_issues(git_dir)
  let updated = remove_active_issue(entries, issue_ref)
  save_active_issues(git_dir, updated)
  print_line("Removed \{issue_ref} from active issues")
}

///|
async fn handle_hub_issue_active(_args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let entries = load_active_issues(git_dir)
  if entries.length() == 0 {
    print_line("No active issues")
    return
  }
  let home = @sys.get_env_var("HOME").unwrap_or("/")
  let aliases = load_aliases(git_dir)
  for entry in entries {
    let (repo_ref, issue_id) = parse_cross_repo_ref(entry)
    let target_git_dir = if repo_ref.length() > 0 {
      try {
        let remote_path = resolve_repo_ref_to_path(repo_ref, home, aliases~)
        resolve_hub_git_dir(remote_path)
      } catch {
        _ => {
          print_line("\{entry} (repo not found)")
          continue
        }
      }
    } else {
      git_dir
    }
    let (objects, refs, _clock) = make_hub_stores(target_git_dir)
    let hub = try {
      load_hub_store(objects, refs)
    } catch {
      _ => {
        print_line("\{entry} (hub not initialized)")
        continue
      }
    }
    match hub.get_issue(objects, issue_id) {
      Some(issue) => {
        let prefix = if repo_ref.length() > 0 { repo_ref + "#" } else { "#" }
        print_line("\{prefix}\{issue.id} [\{issue.state}] \{issue.title}")
      }
      None => print_line("\{entry} (issue not found)")
    }
  }
}
