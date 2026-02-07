///| CLI handlers for bit agent subcommand

///|
fn agent_bytes_to_string(bytes : Bytes) -> String {
  let result = StringBuilder::new()
  for i in 0..<bytes.length() {
    result.write_char(bytes[i].to_int().unsafe_to_char())
  }
  result.to_string()
}

///|
fn print_agent_usage() -> Unit {
  println("Usage: bit agent <subcommand> [<args>]")
  println("")
  println("Subcommands:")
  println("  serve   Start polling daemon for PR review/merge")
  println("  run     Execute a task from JSON file")
  println("  status  Show open PRs and agent status")
  println("  help    Show this help")
  println("")
  println("Options:")
  println("  --remote <url>       Remote repository URL")
  println("  --branch <branch>    Target branch (default: main)")
  println("  --validate <cmd>     Validation command to run")
  println("  --auto-merge         Auto-merge approved PRs")
  println(
    "  --interval <ms>      Poll interval in milliseconds (default: 5000)",
  )
  println("  --agent-id <id>      Agent identifier (default: author string)")
}

///|
async fn handle_agent(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    print_agent_usage()
    return
  }
  let subcmd = args[0]
  let rest = collect_args(args, 1)
  match subcmd {
    "serve" => handle_agent_serve(rest)
    "run" => handle_agent_run(rest)
    "status" => handle_agent_status(rest)
    "help" | "-h" | "--help" => print_agent_usage()
    _ => {
      println("Unknown agent subcommand: \{subcmd}")
      print_agent_usage()
    }
  }
}

///|
fn parse_agent_config(args : Array[String]) -> @agent.AgentConfig {
  let mut remote_url = ""
  let mut target_branch = "main"
  let mut validation_cmd = ""
  let mut auto_merge = false
  let mut poll_interval_ms = 5000
  let mut agent_id = get_author_string()
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--remote" => {
        i = i + 1
        if i < args.length() {
          remote_url = args[i]
        }
      }
      "--branch" => {
        i = i + 1
        if i < args.length() {
          target_branch = args[i]
        }
      }
      "--validate" => {
        i = i + 1
        if i < args.length() {
          validation_cmd = args[i]
        }
      }
      "--auto-merge" => auto_merge = true
      "--interval" => {
        i = i + 1
        if i < args.length() {
          poll_interval_ms = @strconv.parse_int(args[i]) catch { _ => 5000 }
        }
      }
      "--agent-id" => {
        i = i + 1
        if i < args.length() {
          agent_id = args[i]
        }
      }
      _ => ()
    }
    i = i + 1
  }
  @agent.AgentConfig::new(
    agent_id,
    remote_url,
    target_branch~,
    validation_cmd~,
    auto_merge~,
    poll_interval_ms~,
  )
}

///|
async fn handle_agent_serve(args : Array[String]) -> Unit raise Error {
  let config = parse_agent_config(args)
  if config.remote_url == "" {
    println("Error: --remote <url> is required")
    return
  }
  let root = get_work_root()
  let git_dir = root + "/.git"
  println(
    "Starting agent daemon (id=\{config.agent_id}, remote=\{config.remote_url}, branch=\{config.target_branch})",
  )
  @agent_native.serve(config, git_dir)
}

///|
async fn handle_agent_run(args : Array[String]) -> Unit raise Error {
  let config = parse_agent_config(args)
  if config.remote_url == "" {
    println("Error: --remote <url> is required")
    return
  }
  // Find --task argument
  let mut task_file = ""
  let mut i = 0
  while i < args.length() {
    if args[i] == "--task" && i + 1 < args.length() {
      task_file = args[i + 1]
      i = i + 2
    } else {
      i = i + 1
    }
  }
  if task_file == "" {
    println("Error: --task <json-file> is required")
    return
  }
  // Read task file
  let osfs = OsFs::new()
  let task_bytes = (osfs : &@git.RepoFileSystem).read_file(task_file)
  let task_json = @json.parse(agent_bytes_to_string(task_bytes)) catch {
    err => {
      println("Error: invalid JSON in task file: \{err}")
      return
    }
  }
  let task = parse_agent_task(task_json) catch {
    err => {
      println("Error: invalid task format: \{err}")
      return
    }
  }
  let root = get_work_root()
  let git_dir = root + "/.git"
  let result = @agent_native.run_task(task, config, git_dir)
  match result {
    @agent.TaskResult::PrCreated(pr_id) => println("PR created: \{pr_id}")
    @agent.TaskResult::PrMerged(pr_id) => println("PR merged: \{pr_id}")
    @agent.TaskResult::PrRejected(pr_id, reason) =>
      println("PR rejected: \{pr_id} (\{reason})")
    @agent.TaskResult::ValidationFailed(output) =>
      println("Validation failed: \{output}")
    @agent.TaskResult::Error(msg) => println("Error: \{msg}")
  }
}

///|
fn parse_agent_task(json : Json) -> @agent.AgentTask raise @git.GitError {
  guard json is Object(obj) else {
    raise @git.GitError::InvalidObject("expected JSON object")
  }
  let id = match obj.get("id") {
    Some(String(s)) => s
    _ => raise @git.GitError::InvalidObject("missing 'id' field")
  }
  let description = match obj.get("description") {
    Some(String(s)) => s
    _ => ""
  }
  let pr_title = match obj.get("pr_title") {
    Some(String(s)) => s
    _ => id
  }
  let pr_body = match obj.get("pr_body") {
    Some(String(s)) => s
    _ => ""
  }
  let source_branch = match obj.get("source_branch") {
    Some(String(s)) => s
    _ => "agent/" + id
  }
  let edits : Array[@agent.FileEdit] = []
  match obj.get("edits") {
    Some(Array(arr)) =>
      for item in arr {
        guard item is Object(edit_obj) else { continue }
        match edit_obj.get("type") {
          Some(String("write")) => {
            let path = match edit_obj.get("path") {
              Some(String(s)) => s
              _ => continue
            }
            let content = match edit_obj.get("content") {
              Some(String(s)) =>
                Bytes::from_array(
                  s.to_array().map(fn(c) { c.to_int().to_byte() }),
                )
              _ => continue
            }
            edits.push(@agent.FileEdit::Write(path, content))
          }
          Some(String("delete")) => {
            let path = match edit_obj.get("path") {
              Some(String(s)) => s
              _ => continue
            }
            edits.push(@agent.FileEdit::Delete(path))
          }
          _ => continue
        }
      }
    _ => ()
  }
  @agent.AgentTask::new(
    id, description, edits, pr_title, pr_body, source_branch,
  )
}

///|
async fn handle_agent_status(args : Array[String]) -> Unit raise Error {
  let config = parse_agent_config(args)
  let root = get_work_root()
  let git_dir = root + "/.git"
  let (objects, refs, _clock) = make_collab_stores(git_dir)
  // Fetch if remote specified
  if config.remote_url != "" {
    let osfs = OsFs::new()
    let fs : &@git.FileSystem = osfs
    let rfs : &@git.RepoFileSystem = osfs
    let collab = @collab.Collab::load(objects, refs) catch {
      _ => @collab.Collab::init(objects, refs)
    }
    ignore(
      @collab_native.collab_fetch(collab, fs, rfs, git_dir, config.remote_url),
    ) catch {
      _ => ()
    }
  }
  let collab = @collab.Collab::load(objects, refs) catch {
    _ => {
      println("No collab metadata found. Run 'bit collab init' first.")
      return
    }
  }
  let prs = collab.list_prs(objects)
  if prs.length() == 0 {
    println("No pull requests found.")
    return
  }
  for pr in prs {
    let approved = if collab.is_approved(objects, pr.id()) {
      " [approved]"
    } else {
      ""
    }
    let state = match pr.state() {
      Open => "open"
      Merged => "merged"
      Closed => "closed"
    }
    println(
      "\{pr.id()} [\{state}]\{approved} \{pr.title()} (by \{pr.author()})",
    )
  }
}
