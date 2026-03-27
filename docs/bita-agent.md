# bit agent: historical design note

## Status

This document used to describe an LLM coding agent implementation under `src/x/agent/llm/`.
That path does not exist in the current checkout, and the repository does not currently ship a `bit agent` top-level CLI command.

Because of that, the old version of this page was misleading as implementation documentation.

## What Is True Today

- There is no current `src/x/agent/llm/` directory in this repository.
- There is no current `bit agent` command in `src/cmd/bit/main.mbt`.
- Agent/orchestration work in this repository is currently represented by design notes, not by a user-facing shipped command surface.

## What This Page Represents

Treat the older `bit agent` material as historical design intent for an extracted or future agent system.
If that work returns, the command documentation should be rebuilt from the implemented code and tests, not from stale design text.

## Related Documents

- `docs/agent.md`
- `docs/agent-extraction-proposal.md`
- `docs/moonix-agent-integration.md`
- `docs/orchestration-analysis.md`
- `docs/distributed-testing.md`
