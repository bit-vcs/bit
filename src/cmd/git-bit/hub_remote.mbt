///|
/// Parse "owner/repo#issue-id" or "#issue-id" or bare "issue-id".
/// Returns (repo_ref, issue_id) where repo_ref is "" for local refs.
fn parse_cross_repo_ref(input : String) -> (String, String) {
  match input.find("#") {
    Some(idx) => {
      let repo_ref = String::unsafe_substring(input, start=0, end=idx)
      let issue_id = String::unsafe_substring(
        input,
        start=idx + 1,
        end=input.length(),
      )
      (repo_ref, issue_id)
    }
    None => ("", input)
  }
}

///|
/// Resolve "owner/repo" or named alias to local filesystem path.
/// Resolution order: alias map → ghq path → error
fn resolve_repo_ref_to_path(
  repo_ref : String,
  home : String,
  aliases? : Map[String, String] = {},
) -> String raise Error {
  // 1. Check alias map
  match aliases.get(repo_ref) {
    Some(path) => return path
    None => ()
  }
  // 2. Try ghq path (owner/repo format)
  if repo_ref.find("/") is Some(_) {
    let ghq_path = home + "/ghq/github.com/" + repo_ref
    return ghq_path
  }
  // 3. Error
  raise @bitcore.GitError::InvalidObject(
    "Cannot resolve repo ref '\{repo_ref}': not an alias and not in owner/repo format",
  )
}

///|
fn hub_remotes_path(git_dir : String) -> String {
  git_dir + "/hub/remotes"
}

///|
/// Serialize alias entries to TSV format: "name\tpath\n" per line.
fn serialize_alias_entries(entries : Array[(String, String)]) -> String {
  let buf = StringBuilder::new()
  for entry in entries {
    let (name, path) = entry
    buf.write_string(name)
    buf.write_char('\t')
    buf.write_string(path)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// Parse alias entries from text format. Ignores blank lines and lines starting with #.
fn parse_alias_entries(content : String) -> Array[(String, String)] {
  let result : Array[(String, String)] = []
  if content.length() == 0 {
    return result
  }
  for line_view in content.split("\n") {
    let trimmed = line_view.to_string().trim().to_string()
    if trimmed.length() == 0 || trimmed.has_prefix("#") {
      continue
    }
    // Split on first tab
    match trimmed.find("\t") {
      Some(idx) => {
        let a = String::unsafe_substring(trimmed, start=0, end=idx)
        let p = String::unsafe_substring(
            trimmed,
            start=idx + 1,
            end=trimmed.length(),
          )
          .trim()
          .to_string()
        if a.length() > 0 && p.length() > 0 {
          result.push((a, p))
        }
      }
      None => () // skip lines without space separator
    }
  }
  result
}

///|
/// Load aliases from git_dir/hub/remotes file.
fn load_aliases(git_dir : String) -> Map[String, String] {
  let fs = OsFs::new()
  let path = hub_remotes_path(git_dir)
  if !fs.is_file(path) {
    return {}
  }
  let bytes = fs.read_file(path) catch { _ => return {} }
  let content = @utf8.decode_lossy(bytes[:]).to_string()
  let entries = parse_alias_entries(content)
  let map : Map[String, String] = {}
  for entry in entries {
    let (name, path) = entry
    map[name] = path
  }
  map
}

///|
/// Save aliases to git_dir/hub/remotes file.
fn save_aliases(
  git_dir : String,
  aliases : Map[String, String],
) -> Unit raise Error {
  let fs = OsFs::new()
  let path = hub_remotes_path(git_dir)
  let dir = match path.rev_find("/") {
    Some(idx) => String::unsafe_substring(path, start=0, end=idx)
    None => "."
  }
  fs.mkdir_p(dir)
  let entries : Array[(String, String)] = []
  aliases.each(fn(k, v) { entries.push((k, v)) })
  // Sort for deterministic output
  entries.sort_by(fn(a, b) { a.0.compare(b.0) })
  let content = serialize_alias_entries(entries)
  fs.write_string(path, content)
}

///|
async fn handle_hub_issue_remote(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    println("Usage: git-bit issue remote <subcommand>")
    println("")
    println("Subcommands:")
    println("  add <alias> <path>    Add a remote alias")
    println("  list                  List remote aliases")
    println("  remove <alias>        Remove a remote alias")
    return
  }
  let subcmd = args[0]
  let rest = collect_args(args, 1)
  match subcmd {
    "add" => handle_hub_issue_remote_add(rest)
    "list" | "ls" => handle_hub_issue_remote_list(rest)
    "remove" | "rm" => handle_hub_issue_remote_remove(rest)
    _ => {
      eprint_line("git-bit issue remote: unknown subcommand '\{subcmd}'")
      @sys.exit(1)
    }
  }
}

///|
async fn handle_hub_issue_remote_add(args : Array[String]) -> Unit raise Error {
  if args.length() < 2 {
    eprint_line("Usage: git-bit issue remote add <alias> <owner/repo-or-path>")
    @sys.exit(1)
  }
  let name = args[0]
  let target = args[1]
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let aliases = load_aliases(git_dir)
  // Resolve target: if it looks like owner/repo, resolve to ghq path
  let home = @sys.get_env_var("HOME").unwrap_or("/")
  let resolved_path = if target.has_prefix("/") {
    target
  } else {
    resolve_repo_ref_to_path(target, home) catch {
      _ => target
    }
  }
  aliases[name] = resolved_path
  save_aliases(git_dir, aliases)
  print_line("Added remote alias '\{name}' -> \{resolved_path}")
}

///|
async fn handle_hub_issue_remote_list(
  _args : Array[String],
) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let aliases = load_aliases(git_dir)
  if aliases.length() == 0 {
    print_line("No remote aliases configured.")
    return
  }
  let entries : Array[(String, String)] = []
  aliases.each(fn(k, v) { entries.push((k, v)) })
  entries.sort_by(fn(a, b) { a.0.compare(b.0) })
  for entry in entries {
    let (name, path) = entry
    print_line("\{name}\t\{path}")
  }
}

///|
async fn handle_hub_issue_remote_remove(
  args : Array[String],
) -> Unit raise Error {
  if args.length() < 1 {
    eprint_line("Usage: git-bit issue remote remove <alias>")
    @sys.exit(1)
  }
  let name = args[0]
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let aliases = load_aliases(git_dir)
  match aliases.get(name) {
    Some(_) => {
      aliases.remove(name)
      save_aliases(git_dir, aliases)
      print_line("Removed remote alias '\{name}'")
    }
    None => {
      eprint_line("git-bit issue remote: alias '\{name}' not found")
      @sys.exit(1)
    }
  }
}
