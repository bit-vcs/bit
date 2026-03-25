---
name: start-work
description: "Start implementation work with worktree isolation and bit issue coordination. Use when beginning non-trivial code changes: after plan mode, creating branches, implementing features, fixing bugs, or refactoring. Also use when the user mentions worktree, bit issue, session coordination, or parallel work."
---

# Overview

Coordinate parallel Claude Code sessions using `bit issue` and git worktrees. Each session declares its Target Files via a bit issue so other sessions can detect and avoid file conflicts.

Since all worktrees share the same `.git` directory, `bit issue` commands work transparently from any worktree — no `GIT_DIR` workaround needed (bit >= 0.35.2).

## Session Lifecycle

```
  EnterWorktree → bit issue create (Target Files) → work → bit issue close → ExitWorktree
```

## 1. Read the Plan File

Plan files are `.gitignore`d and not shared across worktrees. Read the plan **before** entering the worktree, or use the main repo's absolute path.

```bash
ls -t <main-repo-path>/plans/*.md 2>/dev/null | head -1
```

If no plan file exists (minor work), omit the Plan section from the issue body.

## 2. Enter Worktree & Create Issue

After worktree creation, create a bit issue declaring your scope.

### Create a session issue

```bash
bit issue create \
  --title "[session:<branch-name>] <summary>" \
  --label "session:<branch-name>" \
  --body "$(cat <<'BODY'
## Session Info

- **branch**: <branch-name>
- **worktree**: <worktree-absolute-path>

## Target Files

- path/to/file.ts (modify|create|delete)
- path/to/other.ts (modify)

## Plan

<plan content if available>
BODY
)"
```

**Create the issue before starting work** so other sessions can see your scope immediately.

## 3. Cross-Session Awareness

Check for overlapping Target Files at these points:

1. **After issue create** — race condition mitigation
2. **On scope change** — when modifying files not in original Target Files
3. **Before close** — final check

```bash
bit issue list --open --label "session:<branch-name>"  # your session
bit issue list --open                                   # all sessions
bit issue view <id>                                     # check specific session
```

### Overlap Detection

```
overlap = |my Target Files ∩ other Target Files| / |my Target Files|

- 0%:   proceed
- <50%: exclude overlapping files, record in comment
- ≥50%: ask user
```

### Dynamic Updates

```bash
# Record scope changes
bit issue comment add <id> --body "Target Files added: path/to/new.ts (modify) - reason: ..."
```

## 4. Completion

Close the issue **before** removing the worktree.

```bash
bit issue comment add <id> --body "Done: <summary of changes>"
bit issue close <id>
# Then ExitWorktree / remove worktree
```

## 5. Error Handling

| Situation | Response |
|-----------|----------|
| bit command fails | Notify user, continue without coordination |
| bit not installed | Solo mode — skip coordination |
| Orphan issue (worktree gone) | `git worktree list` to verify, exclude from overlap detection |

## Key Commands Reference

```bash
bit issue init                          # Initialize hub store (first time)
bit issue create --title "..." --label "..." --body "..."
bit issue list [--open] [--closed] [--all] [--label <name>] [--parent <id>]
bit issue view <id>
bit issue update <id> --title "..." --body "..."
bit issue close <id>
bit issue reopen <id>
bit issue comment add <id> --body "..."
bit issue comment list <id>
bit issue search <query>
```
