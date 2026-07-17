---
name: triage-issue
description: "Analyze and triage issues — categorize, assess complexity, suggest approach. Use when: reviewing new issues, prioritizing backlog, or processing hub.issue relay events."
---

# triage-issue

Analyze and triage issues.

## Trigger

- User asks to triage issues
- `bit issue list --open` shows untriaged issues
- Relay event: `hub.issue` (optional, requires relay)

## Steps

1. **Read the issue**: `bit issue get <id>` (skip `session:<branch>` labeled issues — they are session-coordination records, not backlog)
2. **Categorize**: Determine type (bug, feature, question, improvement, docs)
3. **Assess complexity**: Estimate as small/medium/large based on:
   - Number of files likely affected
   - Whether it requires new architecture
   - Test coverage implications
4. **Suggest labels**: Follow the label conventions in the **bit-issue** skill — one priority (`P0`, `P0.5`, `P1`, `P2`, `P3`, `P4`) + area (`merge`, `test`, `hub`, `perf`, `wasm`, `object`, `relay`, `sparse`, …) + optional type (`bug`, `edge-case`, `epic`)
5. **Propose approach**: Brief implementation plan if applicable
6. **Update issue**: Add labels and comment with analysis

## Output format

```
## Triage: <issue-title>

**Type**: bug | feature | question | improvement
**Complexity**: small | medium | large
**Labels**: P1, merge, bug
**Area**: modules/bit_core, modules/bit/cmd/bit, modules/bitx_hub, etc.

## Analysis
Brief description of what needs to be done.

## Suggested approach
1. Step 1
2. Step 2
3. Step 3
```

## Commands

```bash
# --label replaces the whole set: pass priority + area + type together
bit issue update <id> --label "P1" --label "merge" --label "bug"
bit issue comment add <id> --body "Triage: ..."
```

## Important

- Don't close issues automatically
- For bugs, try to reproduce or identify the code path
- For features, check if similar functionality exists
- Link related issues if found
