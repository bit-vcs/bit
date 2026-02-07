///|
fn main {
  let args = @sys.get_cli_args()
  let (orchestrate, parsed) = parse_args(args)
  if orchestrate {
    run_orchestrator(parsed.to_orchestrator_config())
  } else {
    run_llm_agent(parsed.to_agent_config())
  }
}

///|
priv struct ParsedArgs {
  task : String
  work_dir : String
  provider : String
  model : String
  max_steps : Int
  branch : String
  target_branch : String
  auto_commit : Bool
  auto_pr : Bool
  pr_title : String
  max_workers : Int
  verbose : Bool
}

///|
fn ParsedArgs::to_agent_config(self : ParsedArgs) -> LlmAgentConfig {
  let branch = if self.branch.is_empty() {
    "agent/" + strip_trailing_whitespace(exec("date +%s"))
  } else {
    self.branch
  }
  {
    work_dir: self.work_dir,
    task: self.task,
    branch_name: branch,
    target_branch: self.target_branch,
    provider_name: self.provider,
    model: self.model,
    max_steps: self.max_steps,
    auto_commit: self.auto_commit,
    auto_pr: self.auto_pr,
    pr_title: self.pr_title,
    verbose: self.verbose,
  }
}

///|
fn ParsedArgs::to_orchestrator_config(self : ParsedArgs) -> OrchestratorConfig {
  {
    work_dir: self.work_dir,
    task: self.task,
    provider_name: self.provider,
    model: self.model,
    max_workers: self.max_workers,
    target_branch: self.target_branch,
    auto_pr: self.auto_pr,
    verbose: self.verbose,
  }
}

///|
fn strip_trailing_whitespace(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let mut end = chars.length()
  while end > 0 {
    let ch = chars[end - 1]
    if ch == '\n' || ch == '\r' || ch == ' ' || ch == '\t' {
      end = end - 1
    } else {
      break
    }
  }
  if end == chars.length() {
    s
  } else {
    let buf = StringBuilder::new()
    for j = 0; j < end; j = j + 1 {
      buf.write_char(chars[j])
    }
    buf.to_string()
  }
}

///|
fn parse_int_or(s : String, default_ : Int) -> Int {
  let json = @json.parse(s) catch { _ => return default_ }
  match json {
    Number(n, ..) => n.to_int()
    _ => default_
  }
}

///|
fn parse_args(args : Array[String]) -> (Bool, ParsedArgs) {
  let mut task = ""
  let mut work_dir = ""
  let mut provider = "openrouter"
  let mut model = ""
  let mut max_steps = 20
  let mut branch = ""
  let mut target_branch = "main"
  let mut auto_commit = true
  let mut auto_pr = false
  let mut pr_title = ""
  let mut max_workers = 3
  let mut verbose = true
  let mut orchestrate = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--orchestrate" => orchestrate = true
      "--task" => {
        i += 1
        if i < args.length() {
          task = args[i]
        }
      }
      "--work-dir" => {
        i += 1
        if i < args.length() {
          work_dir = args[i]
        }
      }
      "--provider" => {
        i += 1
        if i < args.length() {
          provider = args[i]
        }
      }
      "--model" => {
        i += 1
        if i < args.length() {
          model = args[i]
        }
      }
      "--max-steps" => {
        i += 1
        if i < args.length() {
          max_steps = parse_int_or(args[i], 20)
        }
      }
      "--max-workers" => {
        i += 1
        if i < args.length() {
          max_workers = parse_int_or(args[i], 3)
        }
      }
      "--branch" => {
        i += 1
        if i < args.length() {
          branch = args[i]
        }
      }
      "--target-branch" => {
        i += 1
        if i < args.length() {
          target_branch = args[i]
        }
      }
      "--no-commit" => auto_commit = false
      "--pr" => auto_pr = true
      "--pr-title" => {
        i += 1
        if i < args.length() {
          pr_title = args[i]
        }
      }
      "--quiet" => verbose = false
      _ => ()
    }
    i += 1
  }
  // Default work_dir from pwd
  if work_dir.is_empty() {
    work_dir = strip_trailing_whitespace(@ffi.exec_sync("pwd", 5000))
  }
  // Require task
  if task.is_empty() {
    println("Error: --task is required")
    println(
      "Usage: moon run src/x/agent/llm --target native -- --task <text> [options]",
    )
    println("")
    println("Options:")
    println("  --orchestrate          Run as orchestrator (parallel subtasks)")
    println("  --max-workers <n>      Max parallel workers (default: 3)")
    println("  --work-dir <path>      Working directory (default: cwd)")
    println("  --provider <name>      openrouter|anthropic|openai|claude_code")
    println("  --model <name>         Model name (default: provider default)")
    println("  --max-steps <n>        Max agent steps (default: 20)")
    println(
      "  --branch <name>        Git branch name (default: agent/<timestamp>)",
    )
    println("  --target-branch <name> PR target branch (default: main)")
    println("  --no-commit            Skip auto-commit")
    println("  --pr                   Create PR after commit")
    println("  --pr-title <text>      PR title")
    println("  --quiet                Suppress verbose output")
    @sys.exit(1)
  }
  let parsed : ParsedArgs = {
    task,
    work_dir,
    provider,
    model,
    max_steps,
    branch,
    target_branch,
    auto_commit,
    auto_pr,
    pr_title,
    max_workers,
    verbose,
  }
  (orchestrate, parsed)
}
