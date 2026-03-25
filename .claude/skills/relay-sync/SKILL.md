---
name: relay-sync
description: "Synchronize bit issues and PRs across repositories via a relay server. Use when: coordinating with remote sessions, sharing issues between machines, syncing hub data across clones, or the user mentions relay, sync, remote coordination, or distributed issues."
---

# Relay Sync

Synchronize bit hub data (issues, PRs, comments) between repositories through a relay server. This enables cross-machine and cross-clone session coordination.

## When to Use

- Multiple clones of the same repo need to share issues
- Sessions on different machines need to see each other's Target Files
- Team coordination without a centralized hub (GitHub/GitLab)

## Setup

A relay URL is required. Set it via environment variable or pass directly:

```bash
export BIT_RELAY_URL=relay+http://<host>:<port>
```

Or pass `--remote <url>` to each command.

## Core Workflow

### Push local issues to relay

After creating or updating issues locally, push to share:

```bash
bit relay sync push "$BIT_RELAY_URL"
```

### Fetch remote issues from relay

Pull issues created by other sessions:

```bash
bit relay sync fetch "$BIT_RELAY_URL"
```

### Combined: sync before and after work

```bash
# Start of session: pull latest
bit relay sync fetch "$BIT_RELAY_URL"
bit issue list --open

# ... create issues, do work, close issues ...

# End of session: push changes
bit relay sync push "$BIT_RELAY_URL"
```

## Integration with start-work Skill

When using relay for cross-repo coordination, wrap the start-work protocol with sync:

```bash
# 1. Fetch before declaring scope
bit relay sync fetch "$BIT_RELAY_URL"

# 2. Follow start-work: create issue, check overlap
bit issue create --title "[session:feat/X#1] ..." --label "session:feat/X" --body "..."

# 3. Push your declaration so others can see it
bit relay sync push "$BIT_RELAY_URL"

# 4. Work...

# 5. Close and push
bit issue close <id>
bit relay sync push "$BIT_RELAY_URL"
```

## Authentication

Pass a token for authenticated relay servers:

```bash
bit relay sync push "$BIT_RELAY_URL" --auth-token "$TOKEN"
bit relay sync fetch "$BIT_RELAY_URL" --auth-token "$TOKEN"
```

## What Gets Synced

- Issues (create, update, close, reopen)
- Issue comments
- PRs and PR comments
- Labels, assignees, linked PRs

All hub data stored in `refs/notes/bit-hub` is synchronized.

## Commands Reference

```bash
bit relay sync push <relay-url> [--auth-token <token>]
bit relay sync fetch <relay-url> [--auth-token <token>]
bit relay sync clone-announce <relay-url> --url <clone-url> --repo <name>
bit relay sync clone-peers <relay-url> --repo <name>
```
