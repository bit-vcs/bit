# bit agent - P2P Agent PR Huboration

A system where AI agents autonomously create, review, and merge PRs.

## Overview

`bit agent` is an orchestration layer built on top of bit's hub (PR/review) infrastructure. An agent receives a task and automates the entire flow of file editing, committing, PR creation, and pushing. It can also run as a polling daemon that automatically reviews and merges PRs created by other agents.

```
Agent A: Execute task → Create PR → push
Agent B: fetch → Verify PR → Submit review → auto-merge → push
```

## Prerequisites

- `bit` is installed
- The remote repository accepts `bit receive-pack` (bit server or git-compatible server)
- The repository has been initialized with `bit hub init`

## Setup

```bash
# Initialize the repository
mkdir my-repo && cd my-repo
bit init
bit hub init

# Start the remote server (in a separate terminal)
cd my-repo && bit receive-pack --http :8080
```

## Commands

### `bit agent run` - Task Execution

Executes a task defined in a JSON file, creates a PR, and pushes it.

```bash
bit agent run --task task.json --remote http://localhost:8080
```

#### Task JSON Format

```json
{
  "id": "fix-typo-001",
  "description": "Fix typo in README",
  "pr_title": "Fix typo in README.md",
  "pr_body": "Fixed a small typo in the introduction section.",
  "source_branch": "agent/fix-typo-001",
  "edits": [
    {
      "type": "write",
      "path": "README.md",
      "content": "# My Project\n\nThis is the corrected content.\n"
    },
    {
      "type": "delete",
      "path": "old-file.txt"
    }
  ]
}
```

| Field | Required | Description |
|---|---|---|
| `id` | yes | Unique ID for the task |
| `description` | no | Description used in the commit message |
| `pr_title` | no | PR title (default: id) |
| `pr_body` | no | PR body |
| `source_branch` | no | Source branch name (default: `agent/{id}`) |
| `edits` | no | Array of file edits |

Each element of edits:

| Field | Description |
|---|---|
| `type` | `"write"` or `"delete"` |
| `path` | File path |
| `content` | File content (only for `write`) |

### `bit agent serve` - Polling Daemon

Periodically fetches hub notes from the remote, verifies unreviewed PRs, and submits reviews. With `--auto-merge`, it automatically merges approved PRs and pushes.

```bash
bit agent serve \
  --remote http://localhost:8080 \
  --branch main \
  --validate "moon check" \
  --auto-merge \
  --interval 10000 \
  --agent-id "ci-bot"
```

| Option | Default | Description |
|---|---|---|
| `--remote <url>` | (required) | Remote repository URL |
| `--branch <name>` | `main` | Target branch |
| `--validate <cmd>` | (none) | Shell command used to validate the PR |
| `--auto-merge` | off | Automatically merge approved PRs |
| `--interval <ms>` | `5000` | Polling interval (milliseconds) |
| `--agent-id <id>` | git author | Agent identifier |

#### Daemon Operation Cycle

1. Sync notes from the remote via `hub_fetch`
2. List open PRs
3. For unreviewed PRs where the agent is not the author:
   - Run the `--validate` command
   - exit 0 → Submit review as Approved; otherwise → Submit as RequestChanges
4. If `--auto-merge` is enabled, merge approved PRs and push
5. Sync results to the remote via `hub_push`
6. Wait for `--interval` milliseconds, then return to step 1

### `bit agent status` - Status Display

Displays the list of PRs and their approval status.

```bash
bit agent status --remote http://localhost:8080
```

## Usage Example: Automatic Collaboration Between 2 Agents

```bash
# ---- Prepare the shared repository ----
mkdir shared && cd shared
bit init && bit hub init
# Create an initial commit
echo "# Project" > README.md
bit add README.md && bit commit -m "init"
# Start the server
bit receive-pack --http :8080 &

# ---- Agent A: Execute the task ----
cd /tmp && mkdir agent-a && cd agent-a
bit clone http://localhost:8080 .
bit hub init

cat > task.json << 'EOF'
{
  "id": "add-hello",
  "description": "Add hello.txt",
  "pr_title": "Add hello.txt",
  "pr_body": "Adds a greeting file",
  "source_branch": "agent-a/add-hello",
  "edits": [
    {"type": "write", "path": "hello.txt", "content": "Hello, World!\n"}
  ]
}
EOF

bit agent run --task task.json --remote http://localhost:8080 --agent-id agent-a
# => PR created: xxxx

# ---- Agent B: Review & Merge ----
cd /tmp && mkdir agent-b && cd agent-b
bit clone http://localhost:8080 .
bit hub init

# Poll once for automatic review + merge
bit agent serve \
  --remote http://localhost:8080 \
  --validate "echo ok" \
  --auto-merge \
  --agent-id agent-b \
  --interval 999999  # Stop with Ctrl+C

# ---- Verify the result ----
cd /tmp/shared
bit agent status
# => xxxx [merged] [approved] Add hello.txt (by agent-a)
```

## Architecture

```
src/x/agent/              -- pure: workflow + policy
  types.mbt               -- AgentConfig, AgentTask, FileEdit, TaskResult, ReviewResult
  workflow.mbt             -- execute_task, check_and_merge
  policy.mbt              -- evaluate_validation, should_auto_review, submit_validation_review

src/x/agent/native/       -- native: I/O adapters
  runner.mbt              -- FsWorkingTree adapter, run_task, validate_pr
  server.mbt              -- poll_once, serve (polling daemon)

src/cmd/bit/
  handlers_agent.mbt      -- CLI: bit agent run/serve/status
```

The pure layer (`src/x/agent/`) does not depend on the filesystem or network; it depends only on trait references: `&ObjectStore`, `&RefStore`, `&Clock`, `&WorkingTree`. The native layer injects the concrete implementations of these.

### Dependency Graph

```
src/x/agent/         → @bit, @lib, @hub (pure)
src/x/agent/native/  → @agent, @hub_native, @bitfs, @osfs, @bitnative, @protocol, @pack (native)
src/cmd/bit/          → @agent, @agent_native (native, handlers_agent.mbt only)
```

## Reuse of Existing Components

| Component | Purpose |
|---|---|
| `x/hub` Hub | PR creation, merging, review, approval checks |
| `x/hub/native` hub_push/fetch | Notes push/fetch |
| `x/fs` Fs | Sandboxed filesystem |
| `native` push | Branch push |
| `lib` ObjectStore/RefStore/Clock/WorkingTree | DI traits |
