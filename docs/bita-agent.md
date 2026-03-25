# bit agent: LLM Coding Agent System

## Overview

`src/x/agent/llm/` is an LLM-based coding agent system.
It provides file operations and command execution as tools to the LLM, enabling autonomous task completion.

## Package Structure

```
src/x/agent/llm/
  runner.mbt          # Agent execution (build_system_prompt, run_llm_agent)
  tools.mbt           # Tool definitions + ToolRegistry construction
  tool_env.mbt        # ToolEnvironment trait + NativeToolEnvironment
  loop_detect.mbt     # LoopTracker (consecutive call detection + progress heuristic)
  coord.mbt           # CoordinationBackend trait + FileCoordinationBackend
  coord_kv.mbt        # KvStore trait + KvCoordinationBackend + BitKvAdapter
  orchestrator.mbt    # AgentRunner trait + parallel task decomposition/execution
```

## Core Traits

### ToolEnvironment

Abstracts file operations and command execution for the agent.

```
read_file(path) -> String
write_file(path, content) -> Unit
remove_file(path) -> Unit
list_directory(path) -> String
list_files_recursive(path, max_depth) -> String
search_text(pattern, path, glob, max_results) -> String
run_command(command, work_dir, timeout_ms) -> String
```

Implementations:
- `NativeToolEnvironment`: via shell (`cat`, `printf`, `rg`, etc.)
- `TestToolEnvironment`: in-memory Map (for wbtest)

### CoordinationBackend

Abstracts state management between agents.

```
init_session / init_agent / write_status / write_step / write_pid
write_branch / append_event / read_status / read_all_agents
read_events_since / cleanup
```

Implementations:
- `FileCoordinationBackend`: filesystem-based (shell exec)
- `KvCoordinationBackend`: via KvStore trait (git-backed KV)

### KvStore

KV store abstraction (isolates `@kv` dependency from `coord_kv.mbt`).

```
get_string(key) / set_string(key, value) / delete(key)
list(prefix) / list_recursive(prefix) / commit(message)
```

Implementations:
- `BitKvAdapter`: wraps `@kv.Kv` (`bit_kv_store()` factory)

### AgentRunner

Abstracts agent process execution method.

```
spawn_agent(config, log_file) -> String   # handle (PID or agent_id)
wait_all(session_dir, timeout, log) -> Unit
cancel_agent(handle) -> Unit
```

Implementations:
- `ProcessAgentRunner`: background process spawn via nohup (parallel)
- `InProcessAgentRunner`: directly calls run_llm_agent (sequential)
- `Cloudflare submit mode`: submits subtasks to `POST /api/v1/jobs/submit`
  - After submission, polls `GET /api/v1/jobs/:job_id` to monitor `done|failed|cancelled`

## System Prompt

`build_system_prompt` instructs the LLM with a 5-phase workflow:

1. **Explore** - One `list_files_recursive` call + `search_text` for code exploration
2. **Plan** - Identify target files, confirm with `read_file`
3. **Implement** - Make changes with `write_file` (required)
4. **Verify** - Run tests/type checks with `run_command`
5. **Complete** - Stop tool calls, output summary

The anti-patterns section explicitly prohibits:
- Repeated `list_directory` calls on the same path
- Re-reading the same file with `read_file`
- Only exploring without calling `write_file`

`detect_project_hints(work_dir)` auto-detects MoonBit projects and
suggests `moon check --deny-warn` / `moon test` / `moon fmt`.

## Tools (7 tools)

| Tool | Description |
|------|------|
| `read_file` | Read a file. Always read before modifying |
| `write_file` | Write a file (overwrite). Required for progress |
| `list_directory` | List directory contents (shallow). Use sparingly |
| `list_files_recursive` | Recursive file listing. Use only once at the start |
| `search_text` | ripgrep search. Primary means of code discovery |
| `run_command` | Shell command execution. For verification |
| `remove_file` | Delete a file |

All tools are wrapped with `tracked_handler` and monitored by LoopTracker.

## Loop Detection

`LoopTracker` detects two types of issues:

### 1. Consecutive Call Detection

The same `(tool_name, key_arg)` called `max_repeat` times (default 3) in a row triggers a nudge message.
Handler execution is skipped, and the nudge is presented to the LLM as the tool result.

### 2. Progress Heuristic

If `write_nudge_threshold` (default 10) read-only tool calls are made without any `write_file`,
a progress nudge is returned. The counter resets on `write_file` calls.

Read-only tools: `read_file`, `list_directory`, `list_files_recursive`, `search_text`

## Orchestrator

### Task Decomposition

`plan_subtasks` asks the LLM to decompose into file-scoped subtasks:

```json
[
  {"task": "Add tests for A", "files": ["a_test.mbt"]},
  {"task": "Add tests for B", "files": ["b_test.mbt"]}
]
```

`validate_file_overlap` detects file overlaps. If overlaps exist, it falls back to a single task.

### Execution Flow

1. Plan subtasks (LLM planner)
2. Validate file overlap
3. If `exec_mode=cloudflare`: submit subtasks to the Cloudflare orchestrator and poll job status
4. Cloudflare payload includes `static_check_only=true` / `execution_backend=deno-worker`, delegating static checks to Cloudflare and execution to Deno Workers
5. Otherwise: create worktrees + coordination directory
6. Spawn agents via AgentRunner (process or in-process)
7. Monitor progress (stall detection, error pattern detection)
8. Commit changes per worktree
9. Merge branches
10. Cleanup
11. Optional: create PR

Main modes for `bit agent llm --orchestrate`:

- `--exec-mode process` (default): existing parallel process execution
- `--exec-mode in-process`: sequential execution within the bit process (self-agent mode)
- `--exec-mode cloudflare --orchestrator-url <url>`: submit to Cloudflare worker orchestrator (`cloudflare-static` / `cloudflare-static-deno` / `deno-remote` aliases)

### Monitor Decisions

- `AllDone`: all agents completed
- `CancelAgent`: 3 consecutive errors or no progress for 5 minutes -> kill + Cancelled
- `Continue`: keep polling

## Dependency Graph

```
src/x/agent/llm/
  loop_detect.mbt    -> (none)           # pure
  tool_env.mbt       -> (none)           # pure trait
  tools.mbt          -> @ffi, @llmlib    # shell + LLM
  runner.mbt         -> @ffi, @llmlib    # shell + LLM
  coord.mbt          -> @strconv         # pure coordination
  coord_kv.mbt       -> @kv, @bit, @lib  # via BitKvAdapter only
  orchestrator.mbt   -> @llmlib, @strconv
```

The dependency on `@kv`/`@bit`/`@lib` is isolated to `BitKvAdapter`.
Separating `BitKvAdapter` from `coord_kv.mbt` would make the entire package independent.

## Test Coverage

38 tests (all native-only):

- `loop_detect_wbtest.mbt`: consecutive detection, reset, key extraction, progress nudge (9 tests)
- `runner_wbtest.mbt`: prompt structure, workflow phases, anti-patterns (7 tests)
- `tools_wbtest.mbt`: tool execution, description guidance (8 tests)
- `tool_env_wbtest.mbt`: TestToolEnvironment mock (11 tests)
- `coord_wbtest.mbt`: FileCoordinationBackend (tests)
- `coord_kv_wbtest.mbt`: KvCoordinationBackend (3 tests)

## Configuration

### LlmAgentConfig

```
work_dir, task, branch_name, target_branch
provider_name, model, max_steps
auto_commit, auto_pr, pr_title, verbose
coord_dir, agent_id
env : &ToolEnvironment?     # None = NativeToolEnvironment
coord : &CoordinationBackend?  # None = FileCoordinationBackend
```

### OrchestratorConfig

```
work_dir, task, provider_name, model
max_workers, max_runtime_sec, max_tool_calls, stop_file
target_branch, auto_pr, verbose
exec_mode : process | in-process | cloudflare
orchestrator_url, orchestrator_token
```

## Future: moonix Integration

By implementing `ToolEnvironment` via moonix's `AgentRuntime`:

- Snapshot/rollback per step
- Capability-based security
- Effect log (audit trail of all external operations)
- Fork-based exploration (parallel trial of multiple approaches)

See `docs/moonix-agent-integration.md`.
