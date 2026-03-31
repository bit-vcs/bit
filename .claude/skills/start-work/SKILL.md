---
name: start-work
description: "Manage implementation sessions with bit issue coordination. Use when: starting non-trivial code changes, resuming previous work, entering plan mode, creating branches, or doing parallel work. Triggers on keywords: bit issue, session, parallel work, resume, continue."
---

# Session Coordination with bit issue

Coordinate coding sessions using `bit issue`. Each session declares its Target Files via an issue so other sessions can detect and avoid file conflicts.

This protocol works with any workflow — single-repo, worktrees, or branches.

## Decide: New Session or Resume

```bash
bit issue list --open
```

- **Open session exists for this branch** → [Resume Session](#resume-session)
- **No existing session** → [New Session](#new-session)

---

## New Session

### 1. Read the Plan (if available)

If a plan file exists, read it first. Plans may be `.gitignore`d — read from the main repo path if needed.

### 2. Declare Scope

Create a bit issue declaring your session and Target Files. Use the current branch name for the session label.

To assign a sequence number, count **all** issues (not just open) with the session label:

```bash
bit issue list --all --label "session:<branch-name>"
# → N issues found → next seq = N+1
```

```bash
bit issue create \
  --title "[session:<branch-name>#<seq>] <summary>" \
  --label "session:<branch-name>" \
  --body "$(cat <<'BODY'
## Target Files

- path/to/file.mbt (modify|create|delete)

## Plan

<plan content or omit>
BODY
)"
```

**Create before starting work** so other sessions see your scope immediately.

### 3. Check for Overlap

For each open session issue **other than yours**, check Target Files:

```bash
bit issue list --open                    # all open sessions
bit issue get <other-session-id>         # read Target Files
```

Overlap rules (only `modify` and `delete` count — `create` is conflict-free):

| Situation | Action |
|-----------|--------|
| No overlap | Proceed |
| Some files overlap, others remain | Exclude overlapping files, update issue |
| All files overlap | Ask user whether to proceed or abort |

When excluding files:

```bash
bit issue update <id> --body "<revised body>"
bit issue comment add <id> --body "Excluded path/to/file.mbt (owned by session X)"
```

### 4. Work

Record scope changes as they happen:

```bash
bit issue comment add <id> --body "Target added: path/to/new.mbt (modify) — reason: ..."
```

### 5. Complete

```bash
bit issue comment add <id> --body "Done: <summary>"
bit issue close <id>
```

---

## Resume Session

```bash
bit issue list --open --label "session:<branch-name>"
bit issue get <id>                       # plan + target files
bit issue comment list <id>              # scope changes + progress
```

Continue working. The issue body has the canonical Target Files; comments track changes.

### Clean Up Orphans

If a session is abandoned with no committed work:

```bash
bit issue comment add <id> --body "Orphan: session abandoned"
bit issue close <id>
```

---

## Cross-machine Sync (optional)

When coordinating across machines, wrap with relay sync:

```bash
bit relay sync fetch "$BIT_RELAY_URL"    # pull before declaring scope
# ... create session issue ...
bit relay sync push "$BIT_RELAY_URL"     # push so others see it
```

Or use claims for lightweight coordination:

```bash
bit issue claim <id>                     # signal you're working on this
bit issue claims                         # check who's working on what
```

---

## Error Handling

| Situation | Response |
|-----------|----------|
| bit command fails | Notify user, continue without coordination |
| bit not installed | Solo mode — skip coordination |
| Orphan issue | Verify session is still active, exclude from overlap |

## Commands Reference

```bash
bit issue create --title "..." --label "..." [--label "..."] --body "..."
bit issue list [--open] [--closed] [--all] [--label <name>] [--parent <id>]
bit issue get <id>
bit issue update <id> [--title "..."] [--body "..."] [--label "..."]
bit issue close <id>                     # idempotent
bit issue reopen <id>                    # idempotent
bit issue comment add <id> --body "..."
bit issue comment list <id>
```
