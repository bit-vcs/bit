---
name: start-work
description: "Manage implementation sessions with worktree isolation and bit issue coordination. Use when: starting non-trivial code changes, resuming previous work, entering plan mode, creating branches, or doing parallel work. Triggers on keywords: worktree, bit issue, session, parallel work, resume, continue."
---

# Worktree Session Coordination

Coordinate parallel Claude Code sessions using `bit issue` and git worktrees. Each session declares Target Files via a bit issue so other sessions can detect and avoid file conflicts.

`bit issue` works transparently from any worktree — no `GIT_DIR` workaround needed.

## Decide: New Session or Resume

```bash
# Check for existing open sessions
bit issue list --open
```

- **Open session exists for this branch** → go to [Resume Session](#resume-session)
- **No existing session** → go to [New Session](#new-session)

---

## New Session

### 1. Read the Plan

Plan files are `.gitignore`d. Read **before** entering the worktree, or via main repo absolute path.

```bash
ls -t <main-repo-path>/plans/*.md 2>/dev/null | head -1
```

### 2. Enter Worktree & Declare Scope

After worktree creation, create a bit issue. Use `bit issue list --open --label "session:<branch>"` to count existing issues and assign the next sequence number.

```bash
# Count existing issues for this session to determine next seq number
bit issue list --open --label "session:<branch-name>"
# → N issues found → next seq = N+1

bit issue create \
  --title "[session:<branch-name>#<seq>] <summary>" \
  --label "session:<branch-name>" \
  --body "$(cat <<'BODY'
## Session Info

- **branch**: <branch-name>
- **worktree**: <worktree-absolute-path>
- **seq**: <seq>

## Target Files

- path/to/file.ts (modify|create|delete)

## Plan

<plan content or omit>
BODY
)"
```

**Create before starting work** so other sessions see your scope immediately.

### 3. Check for Overlap

```bash
bit issue list --open                    # all sessions
bit issue view <other-session-id>        # check specific
```

```
overlap = |my files ∩ other files| / |my files|

- 0%:   proceed
- <50%: exclude overlapping files, record in comment
- ≥50%: ask user
```

### 4. Work

Record scope changes as they happen:

```bash
bit issue comment add <id> --body "Target added: path/to/new.ts (modify) — reason: ..."
```

### 5. Complete

Close the issue **before** removing the worktree.

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
git worktree list                # verify worktree exists
```

### 3. Continue

- **Worktree exists** → `cd` into it, continue work
- **Worktree gone** → create new worktree on same branch, issue context still valid

### 4. Clean Up Orphans

If a session's worktree is gone with no committed work:

```bash
bit issue comment add <id> --body "Orphan: worktree removed"
bit issue close <id>
```

---

## Error Handling

| Situation | Response |
|-----------|----------|
| bit command fails | Notify user, continue without coordination |
| bit not installed | Solo mode — skip coordination |
| Orphan issue | `git worktree list` to verify, exclude from overlap detection |

## Commands Reference

```bash
bit issue init                            # first-time setup
bit issue create --title "..." --label "..." --body "..."
bit issue list [--open] [--closed] [--all] [--label <name>] [--parent <id>]
bit issue view <id>
bit issue update <id> --title "..." --body "..."
bit issue close <id>
bit issue reopen <id>
bit issue comment add <id> --body "..."
bit issue comment list <id>
```
