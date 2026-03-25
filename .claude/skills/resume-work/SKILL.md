---
name: resume-work
description: "Resume a previously started work session. Use when returning to an existing worktree, recovering from a crashed session, or picking up where another session left off. Also use when the user says 'resume', 'continue', or 'pick up where I left off'."
---

# Overview

Restore context from a previous session by reading its bit issue and worktree state.

## 1. Find the Session

```bash
# List open session issues
bit issue list --open --label "session:<branch-name>"

# Or find all open sessions
bit issue list --open
```

## 2. Restore Context

```bash
# Read the session issue to recover plan and target files
bit issue view <id>

# Check what was done so far
bit issue comment list <id>

# Verify worktree still exists
git worktree list
```

## 3. Resume Work

If the worktree exists, `cd` into it and continue. The issue body contains:
- Original plan
- Target Files
- Comments with scope changes

If the worktree is gone (orphan issue):
1. Create a new worktree on the same branch
2. The issue context is still valid — continue from where it left off

## 4. Detect Stale Sessions

```bash
# List all open sessions
bit issue list --open

# For each, check if worktree still exists
git worktree list
```

If a session's worktree is gone and no work was committed, close the orphan issue:

```bash
bit issue comment add <id> --body "Orphan: worktree removed without completion"
bit issue close <id>
```
