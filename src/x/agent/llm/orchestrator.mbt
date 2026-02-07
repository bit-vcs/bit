///|
priv struct WorkerTask {
  task : String
  work_dir : String
  branch : String
  agent_id : String
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
  let json = @json.parse(text) catch {
    _ => {
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
/// Find the bit binary path for spawning sub-agents
fn find_bit_binary() -> String {
  let env = @ffi.get_env("BIT_PATH")
  if not(env.is_empty()) {
    return env
  }
  let which = strip_trailing_whitespace(exec("which bit 2>/dev/null"))
  if not(which.is_empty()) {
    return which
  }
  "bit"
}

///|
/// Monitor decision
priv enum MonitorDecision {
  Continue
  CancelAgent(id~ : String, reason~ : String)
  AllDone
}

///|
/// Evaluate progress of all agents and decide next action
fn evaluate_progress(
  snapshots : Array[AgentSnapshot],
  session_dir : String,
  now : Int64,
  _log : (String) -> Unit,
) -> MonitorDecision {
  let mut all_done = true
  for s in snapshots {
    match s.status {
      Running | Pending => {
        all_done = false
        // Check for excessive errors (3+ consecutive error events)
        let events = coord_read_events_since(session_dir, s.agent_id, 0)
        let mut consecutive_errors = 0
        for ev in events {
          if ev.contains("\"type\":\"error\"") {
            consecutive_errors += 1
          } else {
            consecutive_errors = 0
          }
        }
        if consecutive_errors >= 3 {
          return CancelAgent(
            id=s.agent_id,
            reason="3+ consecutive errors detected",
          )
        }
        // Check for stall: no progress for 5 minutes
        if s.step > 0 && s.last_step_time > 0L && now - s.last_step_time > 300L {
          return CancelAgent(
            id=s.agent_id,
            reason="stalled: no progress for 5 minutes",
          )
        }
      }
      _ => ()
    }
  }
  if all_done {
    return AllDone
  }
  Continue
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
  // If only 1 subtask, run directly (no need for parallel overhead)
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
      coord_dir: "",
      agent_id: "",
      env: None,
      coord: None,
    }
    run_llm_agent(agent_config, on_output~)
    return
  }
  // Step 2: Setup coordination directory + worktrees
  let ts = strip_trailing_whitespace(exec("date +%s"))
  let session_dir = coord_init("/tmp", ts)
  if verbose {
    log("[orchestrator] Coordination dir: " + session_dir)
  }
  let workers : Array[WorkerTask] = []
  for i, task in subtasks {
    let agent_id = "agent-" + i.to_string()
    let branch = "agent/" + ts + "-" + i.to_string()
    let wt_dir = "/tmp/bit-agent-" + ts + "-" + i.to_string()
    coord_init_agent(session_dir, agent_id)
    coord_write_status(session_dir, agent_id, Pending)
    coord_write_branch(session_dir, agent_id, branch)
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
    workers.push({ task, work_dir: wt_dir, branch, agent_id })
    if verbose {
      log("[orchestrator] Worktree: " + wt_dir + " -> " + branch)
    }
  }
  // Step 3: Spawn agents as background processes
  let bit = find_bit_binary()
  if verbose {
    log(
      "\n[orchestrator] Spawning " +
      workers.length().to_string() +
      " agents in parallel...",
    )
    log("[orchestrator] Using binary: " + bit)
  }
  for w in workers {
    let log_file = session_dir + "/agents/" + w.agent_id + "/log.txt"
    let cmd = "nohup " +
      shell_escape(bit) +
      " agent llm" +
      " --task " +
      shell_escape(w.task) +
      " --work-dir " +
      shell_escape(w.work_dir) +
      " --branch " +
      shell_escape(w.branch) +
      " --provider " +
      shell_escape(config.provider_name) +
      (if config.model.is_empty() {
        ""
      } else {
        " --model " + shell_escape(config.model)
      }) +
      " --coord-dir " +
      shell_escape(session_dir) +
      " --agent-id " +
      shell_escape(w.agent_id) +
      " --no-commit" +
      " > " +
      shell_escape(log_file) +
      " 2>&1 & echo $!"
    let pid_str = strip_trailing_whitespace(exec(cmd))
    let pid = @strconv.parse_int(pid_str) catch { _ => 0 }
    coord_write_pid(session_dir, w.agent_id, pid)
    if verbose {
      log(
        "[orchestrator] Spawned " +
        w.agent_id +
        " (PID " +
        pid.to_string() +
        "): " +
        w.task,
      )
    }
  }
  // Step 4: Monitor loop - poll coordination directory
  if verbose {
    log("\n[orchestrator] Monitoring agents...")
  }
  let mut iteration = 0
  let max_iterations = 600 // 600 * 2s = 20 minutes max
  while iteration < max_iterations {
    ignore(exec("sleep 2"))
    iteration += 1
    let snapshots = coord_read_all_agents(session_dir)
    let now_str = strip_trailing_whitespace(exec("date +%s"))
    let now = (@strconv.parse_int(now_str) catch { _ => 0 }).to_int64()
    let decision = evaluate_progress(snapshots, session_dir, now, log)
    match decision {
      AllDone => {
        if verbose {
          log("[orchestrator] All agents completed.")
        }
        break
      }
      CancelAgent(id~, reason~) => {
        if verbose {
          log("[orchestrator] Cancelling " + id + ": " + reason)
        }
        // Find and kill the agent
        for s in snapshots {
          if s.agent_id == id && s.pid > 0 {
            ignore(exec("kill " + s.pid.to_string() + " 2>/dev/null"))
            coord_write_status(session_dir, id, Cancelled)
          }
        }
      }
      Continue =>
        if verbose && iteration % 5 == 0 {
          // Log progress every 10 seconds
          for s in snapshots {
            let elapsed = if s.last_step_time > 0L && now > s.last_step_time {
              " elapsed=" + (now - s.last_step_time).to_string() + "s"
            } else {
              ""
            }
            log(
              "  " +
              s.agent_id +
              ": " +
              s.status.to_string() +
              " step=" +
              s.step.to_string() +
              elapsed,
            )
          }
        }
    }
  }
  if iteration >= max_iterations {
    log("[orchestrator] Timeout reached, killing remaining agents...")
    let snapshots = coord_read_all_agents(session_dir)
    for s in snapshots {
      if s.status == Running && s.pid > 0 {
        ignore(exec("kill " + s.pid.to_string() + " 2>/dev/null"))
        coord_write_status(session_dir, s.agent_id, Cancelled)
      }
    }
  }
  // Step 5: Commit changes in each completed worktree
  for w in workers {
    let status = coord_read_status(session_dir, w.agent_id)
    if status != Done && status != Running {
      if verbose {
        log(
          "[orchestrator] Skipping " +
          w.agent_id +
          " (status: " +
          status.to_string() +
          ")",
        )
      }
      continue
    }
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
  // Step 6: Merge all branches
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
    let status = coord_read_status(session_dir, w.agent_id)
    if status != Done && status != Running {
      continue
    }
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
  // Step 7: Cleanup worktrees + coordination dir
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
  coord_cleanup(session_dir)
  if verbose {
    log("[orchestrator] Cleaned up worktrees and coordination dir")
  }
  // Step 8: PR
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
