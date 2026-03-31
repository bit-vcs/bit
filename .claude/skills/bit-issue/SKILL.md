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

### List open issues

```bash
bit issue list                          # open issues (default)
bit issue list --all                    # include sub-issues
bit issue list --closed                 # closed only
bit issue list --label "bug"            # filter by label
bit issue list --format json            # JSON output
bit issue list --tree                   # show as indented tree
```

### View an issue

```bash
bit issue get <id>                      # or: bit issue view <id>
bit issue comment list <id>             # read comments
```

### Update and close

```bash
bit issue update <id> --label "in-progress"
bit issue update <id> --body-append "Found root cause: off-by-one in tokenizer"
bit issue comment add <id> --body "Fixed in commit abc123"
bit issue close <id>                    # idempotent
```

## Sub-issues

Break complex tasks into smaller items:

```bash
# Create parent
bit issue create --title "Refactor HTTP client" --label "epic"
# => iss-abc123

# Create sub-issues
bit issue create --title "Extract connection pool" --parent iss-abc123
bit issue create --title "Add retry logic" --parent iss-abc123

# View hierarchy
bit issue list --tree
bit issue list --parent iss-abc123
```

## Search

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
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `bit issue init` | Setup hub metadata and refspecs |
| `bit issue create` | Create issue (`--title`, `--body`, `--label`, `--parent`, `--link`) |
| `bit issue list` | List issues (`--open`, `--closed`, `--all`, `--tree`, `--parent`, `--label`, `--format json`) |
| `bit issue get <id>` | View issue detail |
| `bit issue update <id>` | Update issue (`--title`, `--body`, `--body-append`, `--label`) |
| `bit issue close <id>` | Close issue (idempotent) |
| `bit issue reopen <id>` | Reopen issue (idempotent) |
| `bit issue comment add <id>` | Add comment (`--body`, `--reply-to`) |
| `bit issue comment list <id>` | List comments |
| `bit issue search` | Search issues (`--type`, `--state`, `--author`, `--label`, `--limit`) |
| `bit issue import` | Import from GitHub (`--repo`, `--state`, `--limit`, `--provider`) |
| `bit issue link <issue> <pr>` | Associate PR with issue |
| `bit issue sync pull` | Pull changes from GitHub (`--repo`, `--since`, `--dry-run`) |
| `bit issue sync push` | Push changes to GitHub (`--repo`, `--label`, `--dry-run`) |
| `bit issue sync` | Bidirectional sync (`--repo`, `--conflict`, `--dry-run`) |
| `bit issue sync status` | Show sync state (`--repo`) |
| `bit issue claim <id>` | Publish claim via relay (optional) |
| `bit issue unclaim <id>` | Release claim (optional) |
| `bit issue claims` | List active claims (optional) |

## Data Model

- Storage: `refs/notes/bit-hub` (Git notes)
- ID format: `iss-<hash>`
- States: `open`, `closed`
- Sync: automatic via `git push`/`git fetch` after `bit issue init`
- Relay: optional, for real-time sync across machines (`bit relay sync push/fetch`)
