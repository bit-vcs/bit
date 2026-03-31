---
name: bit-issue
description: "Manage tasks with bit issue — Git-native issue tracking without external services. Use when: creating tasks, tracking work items, organizing sub-issues, searching issues, or managing project workflow with bit."
---

# Task Management with bit issue

`bit issue` is a Git-native issue tracker. Issues are stored as Git notes (`refs/notes/bit-hub`) inside the repository — no external service required.

## Setup

```bash
bit issue init
```

This configures `refs/notes/bit-hub` refspecs on origin so issues travel with `git push`/`git fetch`.

## Core Workflow

### Create an issue

```bash
bit issue create --title "Add error handling to parser" \
  --label "bug" --label "priority:high" \
  --body "Parser panics on malformed input at line 42"
```

### List issues

By default, `list` shows **top-level** issues (no parent) in **all states** (open + closed). Use `--all` to include sub-issues, `--state` to filter by state.

```bash
bit issue list                          # top-level issues, all states (default)
bit issue list --state open             # open top-level only
bit issue list --all                    # include sub-issues
bit issue list --state closed --all     # closed including sub-issues
bit issue list --label "bug"            # filter by label
bit issue list --format json            # JSON output (useful for parsing)
bit issue list --format json --all      # all issues as JSON
bit issue list --parent <id>            # children of a specific issue (all states)
bit issue list --parent <id> --state open  # open children only
```

### View an issue

```bash
bit issue get <id>                      # or: bit issue view <id>
bit issue comment list <id>             # read comments (not shown in get output)
```

Note: `get` shows issue detail and sub-issue list, but does **not** include comments inline. Use `comment list` separately.

### Update and close

```bash
bit issue update <id> --label "in-progress"       # or: bit issue edit <id>
bit issue update <id> --body-append "Found root cause: off-by-one in tokenizer"
bit issue comment add <id> --body "Fixed in commit abc123"
bit issue close <id>                    # idempotent
```

## Sub-issues

Break complex tasks into smaller items:

```bash
# Create parent
bit issue create --title "Refactor HTTP client" --label "epic"
# => abc12345

# Create sub-issues
bit issue create --title "Extract connection pool" --parent abc12345
bit issue create --title "Add retry logic" --parent abc12345

# View hierarchy
bit issue list --tree
bit issue list --parent abc12345
```

## Search

Search returns both open and closed issues by default.

```bash
bit issue search "parser error"                     # title/body search
bit issue search --label "bug" --state open          # filtered search
bit issue search --type issue-comment "workaround"   # search comments
```

## Import from GitHub

```bash
bit issue import --repo owner/repo                  # import all issues
bit issue import --repo owner/repo --state open     # open only
```

## Cross-repo References

```bash
bit issue create --title "Depends on upstream fix" \
  --link "https://github.com/other/repo/issues/42"
```

## GitHub Sync

Bidirectional sync between bit issues and GitHub Issues.

### Pull (GitHub → bit)

```bash
bit issue sync pull --repo owner/repo                   # fetch changes
bit issue sync pull --repo owner/repo --dry-run         # preview only
bit issue sync pull --repo owner/repo --since 2026-03-01
```

### Push (bit → GitHub)

```bash
bit issue sync push --repo owner/repo                   # push changes
bit issue sync push --repo owner/repo --dry-run         # preview only
bit issue sync push --repo owner/repo --label "bug"     # filter by label
```

Note: `session:*` labeled issues are excluded from push (local-only).

### Bidirectional sync

```bash
bit issue sync --repo owner/repo                        # pull then push
bit issue sync status --repo owner/repo                 # show sync state
```

### Conflict policy

```bash
bit issue sync --repo owner/repo --conflict github-wins   # default
bit issue sync --repo owner/repo --conflict bit-wins
bit issue sync --repo owner/repo --conflict newer-wins
bit issue sync --repo owner/repo --conflict manual         # skip conflicts
```

### Import with mapping

```bash
bit issue import --repo owner/repo                      # creates mapping records
```

Import automatically creates mapping records (bit id ↔ GitHub number) so subsequent `sync pull/push` can track changes.

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
| `bit issue init` | Setup hub metadata and refspecs |
| `bit issue create` | Create issue (`--title`, `--body`, `--label`, `--parent`, `--link`) |
| `bit issue list` | List top-level issues (`--state`, `--all`, `--parent`, `--label`, `--format json`) |
| `bit issue get <id>` | View issue detail (alias: `view`) |
| `bit issue update <id>` | Update issue (`--title`, `--body`, `--body-append`, `--label`; alias: `edit`) |
| `bit issue close <id>` | Close issue (idempotent) |
| `bit issue reopen <id>` | Reopen issue (idempotent) |
| `bit issue comment add <id>` | Add comment (`--body`, `--reply-to`) |
| `bit issue comment list <id>` | List comments |
| `bit issue search` | Search issues (`--type`, `--state`, `--author`, `--label`, `--limit`) |
| `bit issue import` | Import from GitHub (`--repo`, `--state`, `--limit`, `--provider`) |
| `bit issue link <issue> <pr>` | Associate PR with issue |
| `bit issue note` | Low-level notes access (`add`, `get`, `list`, `remove`; `--ns` for namespace) |
| `bit issue sync pull` | Pull changes from GitHub (`--repo`, `--since`, `--dry-run`) |
| `bit issue sync push` | Push changes to GitHub (`--repo`, `--label`, `--dry-run`) |
| `bit issue sync` | Bidirectional sync (`--repo`, `--conflict`, `--dry-run`) |
| `bit issue sync status` | Show sync state (`--repo`) |
| `bit issue claim <id>` | Publish claim via relay (optional) |
| `bit issue unclaim <id>` | Release claim (optional) |
| `bit issue claims` | List active claims (optional) |
| `bit issue watch` | Stream claim events in real-time (optional) |

## Gotchas

- **`list` shows all states by default**: Use `--state open` or `--state closed` to filter. Without `--state`, both open and closed issues are shown.
- **`list` hides sub-issues by default**: Use `--all` to include them. `--parent <id>` shows all states of children by default.
- **`get` does not show comments**: Use `bit issue comment list <id>` separately to read comments.
- **`search` returns all states**: Open and closed issues are both returned unless `--state` is specified.
- **`--tree` is unreliable**: The flag is accepted but currently renders a flat list without indentation. Use `--parent <id>` for reliable sub-issue listing.
- **CLI `--help` is incomplete**: Some flags (`--all`, `--body-append`, `--format`, `--parent`) work but are not shown in `--help` output. This skill doc is the authoritative reference.

## Data Model

- Storage: `refs/notes/bit-hub` (Git notes)
- ID format: `<8-char hex hash>` (e.g., `bec2b506`)
- States: `open`, `closed`
- Sync: automatic via `git push`/`git fetch` after `bit issue init`
- Relay: optional, for real-time sync across machines (`bit relay sync push/fetch`)
