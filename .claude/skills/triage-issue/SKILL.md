---
name: triage-issue
description: "Analyze and triage new issues via bit relay. Use when: processing hub.issue relay events, categorizing issues, assessing complexity, or suggesting implementation approaches."
---

# triage-issue

Analyze and triage new issues, triggered by relay hub.issue events.

## Trigger

Called when a new issue is created and synced via relay, or when relay-agent detects `hub.issue`.

## Steps

1. **Read the issue**: Parse title and body
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
# Add labels
bit issue update <id> --label "bug" --label "priority:medium"

# Add comment
bit issue comment add <id> --body "Triage: ..."
```

## Important

- Don't close issues automatically
- For bugs, try to reproduce or identify the code path
- For features, check if similar functionality exists
- Link related issues if found
