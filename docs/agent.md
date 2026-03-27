# bit agent

## Status

This repository does not currently ship a `bit agent` top-level CLI command.
Older drafts described commands such as `bit agent run`, `bit agent serve`, and `bit agent status`, but those commands are not present in the current command dispatcher.

If you want agent-adjacent functionality today, the user-facing commands in this repository are:

- `bit pr`
- `bit issue`
- `bit relay`
- `bit ai`

## Why This Page Changed

The previous version of this document described a planned workflow and file layout that no longer matches the current tree.
Leaving those instructions in place made the docs misleading, because following them would fail on the current checkout.

## Related Notes

The repository still contains several design and proposal documents around agent systems and orchestration. Treat them as design notes, not as guaranteed-current command documentation.

- `docs/bita-agent.md`
- `docs/agent-extraction-proposal.md`
- `docs/moonix-agent-integration.md`
- `docs/orchestration-analysis.md`
- `docs/distributed-testing.md`

## Rule For Future Updates

If a real `bit agent` command is added again, this page should be rewritten from the implemented command surface in `src/cmd/bit/main.mbt` and its tests, not from older proposals.
