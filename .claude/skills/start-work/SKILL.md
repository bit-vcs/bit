---
name: start-work
description: "Manage implementation sessions with bit issue coordination. Use when: starting non-trivial code changes, resuming previous work, entering plan mode, creating branches, or doing parallel work. Triggers on keywords: bit issue, session, parallel work, resume, continue."
---

# Session Coordination with bit issue

Coordinate parallel coding sessions using `bit issue`. Each session declares its Target Files via an issue so other sessions can detect and avoid file conflicts.

This protocol is harness-agnostic — it works with any worktree setup, branch-based workflow, or single-repo workflow. Worktree creation and removal are the caller's responsibility.

`bit issue` works transparently from any worktree.

## Decide: New Session or Resume

```bash
bit issue list --open
```

- **Open session exists for this branch** → go to [Resume Session](#resume-session)
- **No existing session** → go to [New Session](#new-session)

---

## New Session

### 1. Read the Plan (if available)

If a plan file exists, read it before starting work. Plans may be `.gitignore`d and unavailable from worktrees — read from the main repo path if needed.

### 2. Declare Scope

Create a bit issue declaring your session and Target Files.

To assign a sequence number, count **all** issues (not just open) with the session label to avoid reuse after close/reopen cycles:

```bash
bit issue list --all --label "session:<branch-name>"
# → N issues found → next seq = N+1
```

Multiple `--label` flags are supported for categorization.

```bash
bit issue create \
  --title "[session:<branch-name>#<seq>] <summary>" \
  --label "session:<branch-name>" \
  --body "$(cat <<'BODY'
## Session Info

- **branch**: <branch-name>

## Target Files

- path/to/file.ts (modify|create|delete)

## Plan

<plan content or omit>
BODY
)"
```

**Create before starting work** so other sessions see your scope immediately.

### 3. Check for Overlap

For each open issue that is **not yours**, view it and extract Target Files from the body. Compare against your own.

```bash
bit issue list --open                    # all open sessions
bit issue view <other-session-id>        # read Target Files section
```

Calculate overlap:

```
overlap = |my files ∩ other files| / |my files|

- 0%:   proceed
- <50%: exclude overlapping files, update issue body + add comment
- ≥50%: ask user
```

When excluding files, update the issue to reflect the revised scope:

```bash
bit issue update <id> --body "<revised body with excluded files removed>"
bit issue comment add <id> --body "Excluded path/to/file.ts (owned by session X)"
```

### 4. Work

Record scope changes as they happen:

```bash
bit issue comment add <id> --body "Target added: path/to/new.ts (modify) — reason: ..."
```

### 5. Complete

Close the issue when done. Close is idempotent (safe to call on already-closed issues).

```bash
bit issue comment add <id> --body "Done: <summary>"
bit issue close <id>
```

---

## Resume Session

### 1. Find the Session

```bash
bit issue list --open --label "session:<branch-name>"
# or
bit issue list --open
```

### 2. Restore Context

```bash
bit issue view <id>              # plan + target files
bit issue comment list <id>      # scope changes + progress
```

### 3. Continue

The issue body contains the canonical Target Files and plan. Comments track scope changes and progress.

### 4. Clean Up Orphans

If a session is abandoned with no committed work:

```bash
bit issue comment add <id> --body "Orphan: session abandoned"
bit issue close <id>
```

Use `bit issue list --all` to find both open and closed sessions.

---

## Error Handling

| Situation | Response |
|-----------|----------|
| bit command fails | Notify user, continue without coordination |
| bit not installed | Solo mode — skip coordination |
| Orphan issue | Verify session is still active, exclude from overlap detection if not |

## Commands Reference

```bash
bit issue create --title "..." --label "..." [--label "..."] --body "..."
bit issue list [--open] [--closed] [--all] [--label <name>] [--parent <id>]
bit issue view <id>
bit issue update <id> [--title "..."] [--body "..."] [--label "..."]
bit issue close <id>                     # idempotent
bit issue reopen <id>                    # idempotent
bit issue comment add <id> --body "..."
bit issue comment list <id>
```
