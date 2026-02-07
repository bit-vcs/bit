///|
priv struct WorkerTask {
  task : String
  work_dir : String
  branch : String
}

///|
pub(all) struct OrchestratorConfig {
  work_dir : String
  task : String
  provider_name : String
  model : String
  max_workers : Int
  target_branch : String
  auto_pr : Bool
  verbose : Bool
}

///|
fn extract_json_array(text : String) -> Array[String] {
  // Try parsing entire text as JSON
  let json = @json.parse(text) catch {
    _ => {
      // Extract JSON array substring [...]
      let chars : Array[Char] = []
      for ch in text {
        chars.push(ch)
      }
      let mut start = -1
      let mut end_ = -1
      for i = 0; i < chars.length(); i = i + 1 {
        if chars[i] == '[' && start < 0 {
          start = i
        }
        if chars[i] == ']' {
          end_ = i
        }
      }
      if start < 0 || end_ < 0 {
        return []
      }
      let buf = StringBuilder::new()
      for i = start; i <= end_; i = i + 1 {
        buf.write_char(chars[i])
      }
      @json.parse(buf.to_string()) catch {
        _ => return []
      }
    }
  }
  match json {
    Array(items) => {
      let tasks : Array[String] = []
      for item in items {
        match item {
          String(s) => tasks.push(s)
          _ => ()
        }
      }
      tasks
    }
    _ => []
  }
}

///|
fn plan_subtasks(
  config : OrchestratorConfig,
  log : (String) -> Unit,
) -> Array[String] {
  let file_listing = exec(
    "find " +
    shell_escape(config.work_dir) +
    " -maxdepth 3 -not -path '*/.*' -type f | head -200",
  )
  let system_prompt =
    #|You are a task planner for a coding project.
    #|Break down the given task into independent subtasks that can be executed in parallel by coding agents.
    #|Each subtask must be independent (no file overlap between subtasks) and focused on a specific module or area.
    #|Respond with ONLY a JSON array of task description strings. No other text.
    #|Example: ["Add tests for module A", "Add tests for module B"]
  let provider = create_provider(
    config.provider_name,
    config.model,
    system_prompt,
  )
  let user_msg = "Project files:\n" +
    file_listing +
    "\n\nTask: " +
    config.task +
    "\n\nPlan " +
    config.max_workers.to_string() +
    " or fewer subtasks."
  let messages : Array[@llmlib.Message] = [@llmlib.Message::user(user_msg)]
  let response = @llmlib.collect_text(provider.inner, messages)
  if config.verbose {
    log("[planner] LLM response:\n" + response)
  }
  let tasks = extract_json_array(response)
  if tasks.is_empty() {
    [config.task]
  } else {
    tasks
  }
}

///|
pub fn run_orchestrator(
  config : OrchestratorConfig,
  on_output~ : (String) -> Unit,
) -> Unit {
  let verbose = config.verbose
  let wd = config.work_dir
  let log = fn(s : String) { on_output(s + "\n") }
  // Step 1: Plan subtasks
  if verbose {
    log("[orchestrator] Planning subtasks...")
  }
  let subtasks = plan_subtasks(config, log)
  if verbose {
    log(
      "[orchestrator] Planned " + subtasks.length().to_string() + " subtasks:",
    )
    for i, task in subtasks {
      log("  " + (i + 1).to_string() + ". " + task)
    }
  }
  // If only 1 subtask, run directly
  if subtasks.length() == 1 {
    if verbose {
      log("[orchestrator] Single subtask, running directly...")
    }
    let agent_config : LlmAgentConfig = {
      work_dir: wd,
      task: subtasks[0],
      branch_name: "agent/" + strip_trailing_whitespace(exec("date +%s")),
      target_branch: config.target_branch,
      provider_name: config.provider_name,
      model: config.model,
      max_steps: 20,
      auto_commit: true,
      auto_pr: config.auto_pr,
      pr_title: "",
      verbose: config.verbose,
    }
    run_llm_agent(agent_config, on_output~)
    return
  }
  // Step 2: Create worktrees for isolation
  let ts = strip_trailing_whitespace(exec("date +%s"))
  let workers : Array[WorkerTask] = []
  for i, task in subtasks {
    let branch = "agent/" + ts + "-" + i.to_string()
    let wt_dir = "/tmp/bit-agent-" + ts + "-" + i.to_string()
    ignore(
      exec(
        "git -C " +
        shell_escape(wd) +
        " worktree add " +
        shell_escape(wt_dir) +
        " -b " +
        shell_escape(branch) +
        " 2>&1",
      ),
    )
    workers.push({ task, work_dir: wt_dir, branch })
    if verbose {
      log("[orchestrator] Worktree: " + wt_dir + " -> " + branch)
    }
  }
  // Step 3: Run agents sequentially in each worktree
  if verbose {
    log(
      "\n[orchestrator] Running " +
      workers.length().to_string() +
      " agents sequentially...",
    )
  }
  for i, w in workers {
    if verbose {
      log(
        "\n--- [subtask " +
        (i + 1).to_string() +
        "/" +
        workers.length().to_string() +
        "] " +
        w.task +
        " ---",
      )
    }
    let agent_config : LlmAgentConfig = {
      work_dir: w.work_dir,
      task: w.task,
      branch_name: w.branch,
      target_branch: config.target_branch,
      provider_name: config.provider_name,
      model: config.model,
      max_steps: 20,
      auto_commit: false,
      auto_pr: false,
      pr_title: "",
      verbose: config.verbose,
    }
    run_llm_agent(agent_config, on_output~)
    // Commit changes in this worktree
    let changes = exec(
      "cd " +
      shell_escape(w.work_dir) +
      " && git status --porcelain 2>/dev/null",
    )
    if not(changes.is_empty()) {
      ignore(exec("cd " + shell_escape(w.work_dir) + " && git add -A"))
      ignore(
        exec(
          "cd " +
          shell_escape(w.work_dir) +
          " && git commit -m " +
          shell_escape("agent: " + w.task),
        ),
      )
      if verbose {
        log("[orchestrator] Committed on " + w.branch)
      }
    } else if verbose {
      log("[orchestrator] No changes on " + w.branch)
    }
  }
  // Step 4: Merge all branches
  let merge_branch = "agent/combined-" + ts
  ignore(
    exec(
      "cd " +
      shell_escape(wd) +
      " && git checkout -b " +
      shell_escape(merge_branch),
    ),
  )
  for w in workers {
    let result = exec(
      "cd " +
      shell_escape(wd) +
      " && git merge --no-edit " +
      shell_escape(w.branch) +
      " 2>&1",
    )
    if verbose {
      log("[orchestrator] Merge " + w.branch + ": " + result)
    }
  }
  // Step 5: Cleanup worktrees
  for w in workers {
    ignore(
      exec(
        "git -C " +
        shell_escape(wd) +
        " worktree remove --force " +
        shell_escape(w.work_dir) +
        " 2>/dev/null",
      ),
    )
    ignore(
      exec(
        "git -C " +
        shell_escape(wd) +
        " branch -d " +
        shell_escape(w.branch) +
        " 2>/dev/null",
      ),
    )
  }
  if verbose {
    log("[orchestrator] Cleaned up worktrees")
  }
  // Step 6: PR
  if config.auto_pr {
    ignore(
      exec_with_timeout(
        "cd " +
        shell_escape(wd) +
        " && git push -u origin " +
        shell_escape(merge_branch),
        60000,
      ),
    )
    let result = exec_with_timeout(
      "cd " +
      shell_escape(wd) +
      " && gh pr create --title " +
      shell_escape("agent: " + config.task) +
      " --body 'Created by bit orchestrator' --base " +
      shell_escape(config.target_branch),
      60000,
    )
    log("[pr] " + result)
  }
  log("\n[orchestrator] Done. Branch: " + merge_branch)
}
