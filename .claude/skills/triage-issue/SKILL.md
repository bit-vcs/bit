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

1. **Read the issue**: `bit issue get <id>`
2. **Categorize**: Determine type (bug, feature, question, improvement, docs)
3. **Assess complexity**: Estimate as small/medium/large based on:
   - Number of files likely affected
   - Whether it requires new architecture
   - Test coverage implications
4. **Suggest labels**: Based on category and affected area
5. **Propose approach**: Brief implementation plan if applicable
6. **Update issue**: Add labels and comment with analysis

## Output format

```
## Triage: <issue-title>

**Type**: bug | feature | question | improvement
**Complexity**: small | medium | large
**Labels**: label1, label2
**Area**: src/cmd/bit, src/lib, src/pack, etc.

## Analysis
Brief description of what needs to be done.

## Suggested approach
1. Step 1
2. Step 2
3. Step 3
```

## Commands

```bash
bit issue update <id> --label "bug" --label "priority:medium"
bit issue comment add <id> --body "Triage: ..."
```

## Important

- Don't close issues automatically
- For bugs, try to reproduce or identify the code path
- For features, check if similar functionality exists
- Link related issues if found
