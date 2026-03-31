---
name: relay-respond
description: "Push results back to a bit relay room after completing a task. Use when: reporting CI status, submitting PR reviews, commenting on issues, or publishing agent responses via relay."
---

# relay-respond

Push a message back to a relay room. Use after completing a task triggered by a relay event.

## Usage

When you finish processing a relay event (CI fix, review, triage), publish the result:

```bash
bit relay ci push <owner/repo> --status pass --ref <ref>
bit relay review submit <owner/repo> --pr <id> --verdict approve
bit issue comment add <id> --body "Agent analysis: ..."
```

## When to use

- After fixing a CI failure → `bit relay ci push ... --status pass`
- After reviewing a PR → `bit relay review submit ... --verdict approve/reject`
- After triaging an issue → add labels, comment with analysis
- For generic responses → publish a notify message

## Relay publish command

```bash
curl -X POST "https://bit-relay.mizchi.workers.dev/api/v1/publish?room=ROOM&sender=claude-agent&topic=agent.response&id=ID" \
  -H "Content-Type: application/json" \
  -d '{"kind":"agent.response","body":"..."}'
```
