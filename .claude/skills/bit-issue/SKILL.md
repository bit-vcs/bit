---
name: bit-issue
description: "Manage tasks with bit issue — Git-native issue tracking without external services. Use when: creating tasks, tracking work items, organizing sub-issues, searching issues, or managing project workflow with bit."
---

# Task Management with bit issue

`bit issue` is a Git-native issue tracker. Issues are stored as Git notes (`refs/notes/bit-hub`) inside the repository — no external service required.

**Agent environments: invoke as `bit --no-git-fallback issue …`.** When any `GIT_CONFIG_*` environment variable is set (Claude Code sessions set `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_n`), the `bit` shim delegates to real git, which fails with `git: 'issue' is not a git command`. `--no-git-fallback` forces native handling. Examples below omit the flag for brevity.

## Agent Workflow (TL;DR)

1. **Session start**: `git fetch origin '+refs/notes/bit-hub:refs/notes/bit-hub'` to get the latest issues (see [Syncing issues](#syncing-issues)).
2. **Before starting work**: check the backlog — `bit issue list --open`. Pick up or create an issue for non-trivial work.
3. **Create** with a priority label and an area label (see [Label conventions](#label-conventions)).
4. **During work**: record findings with `update --body-append`, progress with `comment add`.
5. **On completion**: add a closing comment (what was done, commit hash), then `close`. Close sub-issues before their parent.
6. **Session end**: `git push origin 'refs/notes/bit-hub:refs/notes/bit-hub'` so issues reach the remote.

For session coordination (declaring target files, avoiding conflicts with parallel sessions), use the **start-work** skill. For triaging the backlog, use the **triage-issue** skill.

## Setup

```bash
bit issue init
```

Creates hub metadata and `.git/hub/policy.toml`, and offers to configure `refs/notes/bit-hub` refspecs on origin so issues travel with `git push`/`git fetch`.

**Agent gotcha**: the refspec configuration is an interactive `[y/N]` prompt, gated by TTY (`BIT_HUB_INIT_PROMPT=1` forces the prompt, `=0` suppresses it). In non-interactive sessions the prompt is skipped and **the refspecs are NOT configured** — metadata is initialized, but issues will not sync automatically. Use the explicit refspec commands below instead.

## Syncing issues

Issues live in `refs/notes/bit-hub`, which plain `git push`/`git fetch` does **not** transfer unless refspecs were configured at init. Explicit commands always work:

```bash
# Get issues from the remote (do this at session start)
git fetch origin '+refs/notes/bit-hub:refs/notes/bit-hub'

# Send issues to the remote (do this after creating/updating/closing)
git push origin 'refs/notes/bit-hub:refs/notes/bit-hub'
```

Caveat: the notes ref is a single history — if two machines update issues concurrently, the push is rejected as non-fast-forward (and a `+` fetch overwrites local-only changes). Fetch before you write, push soon after. For real multi-machine coordination use the **relay-sync** skill.

## Label conventions

Labels observed/established in this repository:

| Kind | Values | Notes |
|------|--------|-------|
| Priority | `P0` `P0.5` `P1` `P2` `P3` `P4` | `P0` = now, `P0.5` = next, `P4` = someday. Every backlog issue should carry exactly one. |
| Area | `merge` `test` `hub` `perf` `wasm` `object` `relay` `sparse` … | Free-form, lowercase, matches subsystem names. |
| Type | `bug` `edge-case` `epic` | Optional. |
| Reserved | `session:<branch>` | Session-coordination issues created by the **start-work** skill. Not backlog items — exclude them when triaging. |

When updating priority, remember `--label` **replaces** the whole set — re-pass area/type labels too.

## Core Workflow

### Create an issue

```bash
bit issue create --title "Add error handling to parser" \
  --label "bug" --label "P1" --label "parser" \
  --body "Parser panics on malformed input at line 42"
# Output:
#   issue abc12345
#   title Add error handling to parser
#   ...
```

The first line of output is `issue <id>` — extract the ID from there (e.g., `abc12345`).

Short flags: `-t` (title), `-b`/`-m` (body), `-l` (label), `-p` (parent), `-a` (assignee).

### List issues

By default, `list` shows **top-level** issues (no parent) in **all states** (open + closed). Use `--all` to include sub-issues, `--open`/`--closed` (or `--state open|closed|all`) to filter by state.

```bash
bit issue list                          # top-level issues, all states (default)
bit issue list --open                   # open top-level only (= --state open)
bit issue list --all                    # include sub-issues
bit issue list --closed --all           # closed including sub-issues
bit issue list --label "bug"            # filter by label (repeatable, AND)
bit issue list --limit 10               # cap output (-L also works)
bit issue list --format json            # JSON output (useful for parsing)
bit issue list --format json --all      # all issues as JSON
bit issue list --parent <id>            # children of a specific issue (all states)
bit issue list --parent <id> --open     # open children only
bit issue list --tree                   # parent/child tree (children indented)
```

Issues with children show a `(sub: N)` suffix; with `--all`, children show `(parent: <id>)`. `--tree` requires bit v0.44+ — older builds render it as a flat list.

### View an issue

```bash
bit issue get <id>                      # or: bit issue view <id>
bit issue comment list <id>             # read comments (not shown in get output)
```

`get` shows issue detail and its sub-issue list, but does **not** include comments inline. Use `comment list` separately.

### Update and close

```bash
bit issue update <id> --label "bug" --label "in-progress"   # or: bit issue edit <id>
bit issue update <id> --body-append "Found root cause: off-by-one in tokenizer"
bit issue comment add <id> --body "Fixed in commit abc123"
bit issue comment <id> --body "..."     # gh-style alias for comment add
bit issue close <id>                    # idempotent
bit issue reopen <id>                   # idempotent
```

**Label behavior**: `--label` **replaces** the entire label set. To add a label while keeping existing ones, include all labels:

```bash
# NG: drops existing labels
bit issue update <id> --label "in-progress"
# OK: keeps "bug" and adds "in-progress"
bit issue update <id> --label "bug" --label "in-progress"
```

**Closing convention**: add a comment stating the resolution (what changed, commit hash) before closing, so the record survives without chat context.

## Sub-issues

Break complex tasks into smaller items:

```bash
# Create parent
bit issue create --title "Refactor HTTP client" --label "epic" --label "P1"
# => abc12345

# Create sub-issues
bit issue create --title "Extract connection pool" --parent abc12345
bit issue create --title "Add retry logic" -p abc12345

# View children (all states by default)
bit issue list --parent abc12345
bit issue list --parent abc12345 --open              # open children only
bit issue list --parent abc12345 --label "bug"       # filter children by label
```

Conventions:

- Sub-issues inherit context from the parent — a short title is enough; put shared background in the parent body.
- Closing a parent does **not** auto-close children. Close each sub-issue as it completes, and close the parent only when all children are closed.
- One level of nesting is usually enough; prefer labels over deep hierarchies.

## Dependencies (blocked-by)

Record that an issue is blocked by another:

```bash
bit issue dep add <id> <blocked-by-id>      # mark <id> as blocked by <blocked-by-id>
bit issue dep list <id>                     # show blockers
bit issue dep remove <id> <blocked-by-id>   # remove dependency
```

`get` shows a `blocked-by <id>` line. Dependencies are informational only — `close` does **not** check for open blockers, and `list`/JSON output do not surface them. Check `dep list` before picking up an issue.

## Search

Search returns both open and closed issues by default.

```bash
bit issue search "parser error"                      # title/body search
bit issue search --label "bug" --open                # filtered search
bit issue search --type issue-comment "workaround"   # search comments
bit issue search "parser" --limit 5 --format json    # JSON output
```

## Cross-repo References

Link issues across local repositories using `owner/repo#id` format.

### Repository resolution

Resolution order: alias → ghq path (`~/ghq/github.com/owner/repo`) → error.

```bash
bit issue remote add myapp ~/ghq/github.com/owner/app   # register alias
bit issue remote list
bit issue remote remove myapp
```

### Link, read, create across repos

```bash
bit issue link <local-id> owner/repo#remote-id  # link remote issue to local issue
bit issue get owner/repo#issue-id               # read from another local repo
bit issue create --repo myapp --title "Fix bug" # create in remote repo (alias OK)
```

### Working set (active issues)

Track which issues you're currently working on across repos:

```bash
bit issue start #local-id                       # add local issue
bit issue start owner/repo#remote-id            # add cross-repo issue
bit issue active                                # list all active issues with status
bit issue stop owner/repo#remote-id             # remove from working set
```

### External links

```bash
bit issue create --title "Depends on upstream fix" \
  --link "https://github.com/other/repo/issues/42"
```

## GitHub Sync

Bidirectional sync between bit issues/PRs and GitHub. Requires `gh` CLI or `GITHUB_TOKEN` env var.

### Pull (GitHub → bit)

Pull is read-only — no `--github` flag needed.

```bash
bit issue sync pull --repo owner/repo                              # pull issues
bit issue sync pull --repo owner/repo --include-prs                # include PRs
bit issue sync pull --repo owner/repo --since 2026-03-01           # incremental
bit issue sync pull --repo owner/repo --conflict newer-wins        # default
bit issue sync pull --repo owner/repo --conflict github-wins       # always use GitHub
bit issue sync pull --repo owner/repo --comments full              # sync comments too
```

### Push (bit → GitHub)

Push requires `--github` flag (safety). Default is **dry-run** (shows plan only).

```bash
bit issue sync push --github --repo owner/repo                     # dry-run
bit issue sync push --github --repo owner/repo --apply             # execute
bit issue sync push --github --repo owner/repo --include-prs --apply
bit issue sync push --github --repo owner/repo --comments full --apply
```

### Bidirectional sync

Runs pull then push. Requires `--github`.

```bash
bit issue sync --github --repo owner/repo                          # pull + push dry-run
bit issue sync --github --repo owner/repo --apply                  # pull + push execute
```

### Sync status

```bash
bit issue sync status --repo owner/repo                            # show linked issues/PRs
```

### Conflict policies

```bash
--conflict newer-wins    # default: timestamp comparison
--conflict github-wins   # always use GitHub version
--conflict bit-wins      # always keep local version
--conflict manual        # skip conflicts, report only
```

### Comment sync modes

```bash
--comments append-only   # default: new comments only
--comments full          # add, edit, and delete
--comments no-delete     # add and edit, no delete
```

### Auto-sync hook

```bash
bit issue sync install-hook                                        # add post-push hook
```

This creates `.git/hooks/post-push` that auto-pushes after `git push`.

### Import (one-way, no SyncLink)

```bash
bit issue import --repo owner/repo                                 # import all issues
bit issue import --repo owner/repo --state open                    # open only
```

Note: `import` does NOT create SyncLink mappings. Use `sync pull` for tracked sync.

## Claim (optional, requires relay)

Signal to other agents/sessions that you're working on an issue:

```bash
bit issue claim <id>                    # publish claim via relay
bit issue unclaim <id>                  # release claim
bit issue claims                        # list active claims
bit issue watch                         # stream claim/unclaim events in real-time
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `bit issue init` | Setup hub metadata and refspecs (interactive; see Setup) |
| `bit issue create` | Create issue (`--title/-t`, `--body/-b`, `--label/-l`, `--parent/-p`, `--assignee/-a`, `--link`, `--repo`) |
| `bit issue list` | List top-level issues (`--open`, `--closed`, `--state`, `--all`, `--parent`, `--label`, `--limit/-L`, `--format json`) |
| `bit issue get <id>` | View issue detail (alias: `view`) |
| `bit issue update <id>` | Update issue (`--title`, `--body`, `--body-append`, `--label`, `--assignee`; alias: `edit`) |
| `bit issue close <id>` | Close issue (idempotent) |
| `bit issue reopen <id>` | Reopen issue (idempotent) |
| `bit issue comment add <id>` | Add comment (`--body`, `--reply-to`; gh-style alias: `comment <id> --body`) |
| `bit issue comment list <id>` | List comments (oldest first) |
| `bit issue dep add\|remove\|list` | Manage blocked-by dependencies (informational only) |
| `bit issue search` | Search issues (`--type`, `--state`/`--open`/`--closed`, `--author`, `--label`, `--limit`, `--format json`) |
| `bit issue import` | Import from GitHub (`--repo`, `--state`, `--limit`, `--provider`) |
| `bit issue link <issue> <target>` | Link PR or cross-repo issue (`owner/repo#id`) |
| `bit issue remote add\|list\|remove` | Manage repo aliases for cross-repo refs |
| `bit issue start <ref>` | Add issue to working set |
| `bit issue stop <ref>` | Remove issue from working set |
| `bit issue active` | List active issues across repos |
| `bit issue note` | Low-level notes access (`add`, `get`, `list`, `remove`; `--ns` for namespace) |
| `bit issue sync pull` | Pull from GitHub (`--repo`, `--since`, `--conflict`, `--comments`, `--include-prs`) |
| `bit issue sync push` | Push to GitHub (`--github`, `--repo`, `--apply`, `--comments`, `--include-prs`) |
| `bit issue sync` | Bidirectional (`--github`, `--repo`, `--apply`, `--conflict`, `--comments`) |
| `bit issue sync status` | Show sync state (`--repo`) |
| `bit issue sync install-hook` | Add post-push auto-sync hook |
| `bit issue claim <id>` | Publish claim via relay (optional) |
| `bit issue unclaim <id>` | Release claim (optional) |
| `bit issue claims` | List active claims (optional) |
| `bit issue watch` | Stream claim events in real-time (optional) |

## JSON Output Schema

`--format json` returns an array of objects:

```json
[{
  "id": "bec2b506",
  "title": "Issue title",
  "state": "open",
  "author": "name <email>",
  "created_at": 1774856949,
  "updated_at": 1774856949,
  "body": "Issue body text",
  "labels": ["bug", "P1"],
  "assignees": [],
  "linked_prs": [],
  "parent_id": null
}]
```

Timestamps are Unix epoch seconds. `parent_id` is `null` for top-level issues.

## Gotchas

- **`list` shows all states by default**: Use `--open`/`--closed` (or `--state open|closed`) to filter. Without a state filter, both open and closed issues are shown.
- **`list` hides sub-issues by default**: Use `--all` to include them. `--parent <id>` shows all states of children by default.
- **`get` does not show comments**: Use `bit issue comment list <id>` separately to read comments.
- **`search` returns all states**: Open and closed issues are both returned unless a state filter is given.
- **`update --label` replaces all labels**: Pass all desired labels every time. Omitting an existing label removes it.
- **Closing a parent does not close children**: Each sub-issue must be closed individually.
- **`close` is idempotent but messages differ**: First call prints `Closed issue #<id>`, subsequent calls print `Issue #<id> is already closed`. Both are success (exit 0).
- **`comment list` is oldest-first**: Comments are returned in chronological order (oldest first).
- **Issues don't sync on plain `git push` unless refspecs are configured**: In non-interactive sessions `bit issue init` never applies the refspecs. Use the explicit fetch/push commands in [Syncing issues](#syncing-issues).
- **`GIT_CONFIG_*` env vars break `bit issue`**: The shim delegates to real git when config-injection env vars are present. Always pass `--no-git-fallback` in agent environments (see top of this doc).
- **CLI `--help` misses some flags**: `--format json`, `--body-append`, and `--label` filtering on `list` work but are not shown in `--help`. This skill doc is the authoritative reference.
- **`dep` is informational only**: `close` does not check for open blockers.

## Data Model

- Storage: `refs/notes/bit-hub` (Git notes)
- ID format: `<8-char hex hash>` (e.g., `bec2b506`)
- States: `open`, `closed`
- Sync: `git push`/`git fetch` with `refs/notes/bit-hub` refspecs (see Syncing issues)
- Relay: optional, for real-time sync across machines (`bit relay sync push/fetch`)

## Related Skills

- **start-work** — session coordination protocol (declare target files via `session:<branch>` issues, detect conflicts with parallel sessions).
- **triage-issue** — backlog triage flow (categorize, assess complexity, assign labels).
- **relay-sync** — multi-machine issue sync via a relay server.
