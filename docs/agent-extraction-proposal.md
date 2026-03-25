# Agent System Extraction Proposal

## Framing the Questions

1. Should the agent layer be extracted into a separate repository?
2. Should we provide a shell emulation environment on moonix for agents to work in?

## Current Dependency Graph

```
src/x/agent/llm/          mizchi/llm (external)
  coord.mbt                  @ffi.exec_sync (shell)
  orchestrator.mbt           @json
  runner.mbt                 @strconv
  tools.mbt
  ← dependency on git layer: ZERO

src/x/agent/               mizchi/bit (main repo)
  types.mbt                  @bit.ObjectId (type only)
  workflow.mbt               &@lib.ObjectStore (trait)
  policy.mbt                 &@lib.RefStore (trait)
                             &@lib.Clock (trait)
                             &@lib.WorkingTree (trait)
                             @hub.Hub
  ← dependency on git layer: trait references only, no implementation dependency

src/x/agent/native/        mizchi/bit (main repo)
  runner.mbt                 @bit.*, @lib.ObjectDb
  server.mbt                 @pack, @protocol, @bitnative
  ← dependency on git layer: TIGHT (native adapter)
```

## Conclusion: Should be extracted, but the extraction granularity matters

### agent/llm can be extracted immediately

`src/x/agent/llm/` has zero dependency on the git layer. Its dependencies are only `mizchi/llm` (external LLM library) and shell commands. This can stand on its own as an independent package.

The problem is that **tools.mbt does everything via raw shell**:

```moonbit
// Current tools.mbt — direct manipulation via shell_escape + exec
fn(input) {
  let path = resolve_path(work_dir, json_get_str(input, "path"))
  exec("cat " + shell_escape(path))
}
```

This results in:
- Security risk (large command injection surface area)
- Untestable (requires an actual filesystem)
- Environment-dependent (command differences between macOS/Linux)
- Non-replayable (execution is irreversible)

### agent/core can be extracted after the hub protocol is finalized

`workflow.mbt` and `policy.mbt` in `src/x/agent/` use the git layer via traits. Their dependencies are:

- `@bit.ObjectId` — type only
- `&@lib.ObjectStore` / `&@lib.RefStore` / `&@lib.WorkingTree` / `&@lib.Clock` — trait references
- `@hub.Hub` — hub API

Once the hub protocol stabilizes, this can be extracted along with the trait definitions.

### Unresolved Items in the Hub Protocol

| Item | Impact | Priority |
|------|--------|----------|
| Vector clock merge semantics | Correctness of distributed sync | CRITICAL |
| Note commit timestamp (currently fixed at 0L) | Causality tracking | CRITICAL |
| PR source_commit post-merge semantics | Post-merge state management | HIGH |
| Tombstone compaction policy | Storage bloat | MEDIUM |
| Close vs Rejected distinction | Workflow design | LOW |

## Should moonix be the agent execution environment: YES

### What moonix provides

```
AgentRuntime
  ├── GitBackedFs (virtual FS with snapshot/rollback)
  ├── CapabilitySet (FsRead, FsWrite, NetConnect... ACL)
  ├── EffectLog (audit log for irreversible operations)
  ├── POSIX context (fd, env, cwd)
  ├── MCP client/server (tool invocation protocol)
  └── A2A protocol (agent-to-agent communication)
```

### Current agent/llm vs. Agent on moonix

| Aspect | Current (direct shell) | On moonix |
|--------|----------------------|-----------|
| File operations | `exec("cat ...")` | `runtime.fs.read_file(path)` |
| Writing | `exec("printf ... > ...")` | `runtime.fs.write_file(path, data)` |
| Snapshots | git worktree + manual commit | `runtime.snapshot("checkpoint")` |
| Rollback | Not possible (only worktree deletion) | `runtime.rollback(commit_id)` |
| Permission control | None | Capability-based ACL |
| Audit log | None | EffectLog (records all external operations) |
| Testing | Requires real FS | Unit-testable with MemFs |
| Parallel agents | worktree isolation | Fork to branch |
| Security | Shell injection risk | Sandbox mode |

### Using moonix fundamentally changes orchestration

Current model:

```
Orchestrator (process)
  ├── nohup bit agent llm ... &   ← OS process spawn
  ├── coordination dir polling     ← filesystem polling
  └── git merge                    ← shell command
```

moonix model:

```
Orchestrator (in-process)
  ├── runtime_0 = AgentRuntime::sandbox()
  │     runtime_0.fs = GitBackedFs (agent-0's workspace)
  ├── runtime_1 = AgentRuntime::sandbox()
  │     runtime_1.fs = GitBackedFs (agent-1's workspace)
  ├── Run LLM agent loop in each runtime
  │     tool_call("write_file", ...) → runtime.fs.write_file(...)
  │     tool_call("read_file", ...)  → runtime.fs.read_file(...)
  │     tool_call("run_command", ...) → runtime.effect_log.record(...)
  ├── Automatic snapshot per step
  │     runtime.snapshot("step-3")
  ├── Rollback on error
  │     runtime.rollback(last_good_snapshot)
  └── merge: 3-way merge between GitBackedFs instances
```

Benefits:
- **No OS process spawn required** — parallel execution in-process
- **No coordination dir required** — directly reference runtime state
- **Built-in snapshot/rollback** — safe trial-and-error for agents
- **Fork for exploration** — branch and compare multiple approaches
- **EffectLog** — complete audit trail of external API calls
- **Capability** — restrict permissions per agent

### On shell emulation

The moonix shell parser is complete, but the **execution engine is disabled pending xsh**.

Two options:

**A. Wait for shell emulation**
- `run_command` tool completes entirely within moonix
- Agents run `moon test` and `rg` in the virtual shell
- Full sandbox

**B. Move forward with host delegation for shell**
- `run_command` delegates to the host shell, gated by capabilities
- Recorded in EffectLog (ProcessSpawn effect)
- moonix FS operations + snapshot/rollback are still used
- Shell emulation can be swapped in later

Recommendation: **B**. Waiting for shell emulation completion would block agent development. Host delegation + EffectLog provides sufficient auditing.

## Proposed Architecture

### Package Structure

```
mizchi/bit                    # git-compatible implementation (unchanged)
  src/
  src/x/hub/              # hub protocol
  src/x/kv/                  # KV store + gossip

mizchi/moonix                 # virtual execution environment (unchanged)
  src/runtime/
  src/gitfs/
  src/capability/
  src/effect/
  src/ai/                    # MCP, A2A types

mizchi/bit-agent (NEW)        # agent system
  src/
    core/                    # AgentConfig, AgentTask, TaskResult
    llm/                     # LLM providers, agent loop
    tools/                   # MCP-compatible tool definitions
    orchestrator/            # parallel orchestration
    coord/                   # coordination protocol
  dependencies:
    mizchi/moonix            # execution environment (AgentRuntime, GitBackedFs)
    mizchi/llm               # LLM provider
    mizchi/bit               # (optional) native git adapter
    mizchi/bit/x/hub      # (optional) PR/review integration
```

### Tool Definition Changes

Current (`shell_escape + exec`):
```moonbit
registry.register("read_file", ..., fn(input) {
  exec("cat " + shell_escape(path))
})
```

On moonix:
```moonbit
registry.register("read_file", ..., fn(input) {
  let bytes = runtime.fs.read_file(path)  // raise FsError
  @encoding.bytes_to_string(bytes)
})
```

### Coordination Changes

Current (filesystem polling):
```moonbit
coord_write_status(dir, agent_id, Running)
// → printf 'running' > /tmp/.../agents/agent-0/status
```

On moonix (direct in-memory reference):
```moonbit
// orchestrator directly holds each runtime's state
agents[i].status = Running
agents[i].step = runtime.current_step()
agents[i].snapshot = runtime.fs.head()
```

The coordination dir becomes unnecessary, and the migration path to KV becomes clear:
- Local: in-memory Map
- Distributed: KV gossip

## Migration Steps

### Phase 0: Finalize the hub protocol
- Specify vector clock merge semantics
- Resolve the note timestamp issue
- Document the contract in `docs/hub-protocol.md`

### Phase 1: Add agent tool adapter to moonix
- MCP-compatible tool definitions in `mizchi/moonix/src/ai/tools/`
- `read_file`, `write_file`, `list_directory` → `runtime.fs.*`
- `run_command` → host delegation + EffectLog
- `search_text` → host delegation (rg) or in-memory grep

### Phase 2: Create the bit-agent repository
- Move `src/x/agent/llm/`
- Replace tools.mbt with moonix adapter
- Change runner.mbt's shell exec to go through `AgentRuntime`
- Rewrite orchestrator for in-process parallelism

### Phase 3: Make coordination KV-compatible
- In-memory coordination (local)
- KV gossip coordination (distributed)
- Hub integration (PR/review)

## Summary

| Decision | Conclusion | Reason |
|----------|-----------|--------|
| Extract agent to a separate repo? | YES | llm layer has zero git dependency; core layer uses only traits |
| Run on moonix? | YES | Sandbox, snapshot/rollback, EffectLog, capability |
| Wait for shell emulation? | NO | Move forward with host delegation |
| Finalize hub first? | YES | Agent workflow/policy depends on hub |
| When to extract? | Phase 0 (hub) → Phase 1 (moonix tools) → Phase 2 (extract) |
