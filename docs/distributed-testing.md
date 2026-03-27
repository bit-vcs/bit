# Distributed Testing Guide

This document is an operational guide for verifying bit's current distributed and coordination-oriented components as a system, including failure modes.

The current checkout does not contain `src/x/agent/*`.
Older agent/orchestrator notes still exist in `docs/`, but this guide is scoped to components that are actually present today.

## 1. Test Layers

1. Pure logic (fast)
- Purpose: Detect regressions in pure coordination and serialization logic
- Target: `src/x/hub/*_test.mbt`, `src/x/kv/*_test.mbt`, `src/x/rebase-ai/*_wbtest.mbt`
- Examples: Hub record round-trips, issue/PR state transitions, KV merge behavior, rebase-ai parser logic

2. Coordination/State (medium)
- Purpose: Verify read/write consistency across relay, native sync, and repo-backed state
- Target: `src/x/hub/native/*_wbtest.mbt`, `src/x/kv/native/*_wbtest.mbt`, `src/x/mcp/*_wbtest.mbt`
- Examples: relay fetch/push behavior, sync conflict handling, MCP server I/O behavior

3. Hub/Sync contract (medium)
- Purpose: Verify PR/Issue/Review representation and sync contracts
- Target: `src/x/hub/*_test.mbt`, `src/x/hub/*_wbtest.mbt`, `src/x/hub/native/*_wbtest.mbt`

4. End-to-end simulation (heavy)
- Purpose: End-to-end connectivity of repository collaboration and relay-oriented flows
- Target: shell tests under `t/`, relay-oriented tests, and focused native package suites

## 2. Key Invariants

1. Hub records serialize/deserialize without semantic loss
2. Relay sync must be idempotent and must not corrupt existing metadata
3. KV merge and gossip state must converge for equivalent histories
4. Rebase-ai and other coordination helpers must fail predictably on malformed input
5. Native wrappers must preserve protocol-level expectations across retries and partial failures

## 3. Execution Commands

```bash
# Run distributed-system-focused verification
just test-distributed

# Additionally, run full regression
just test
just check
```

Current `just test-distributed` runs:

- `mizchi/bit/x/mcp`
- `mizchi/bit/x/rebase-ai`
- `mizchi/bit/x/hub`
- `mizchi/bit/x/hub/native`
- `mizchi/bit/x/kv`

## 4. Minimal Fault Injection Set

1. Feed empty/corrupted payloads into hub sync and verify error paths
2. Replay duplicate relay records and verify idempotent merge behavior
3. Inject conflicting KV histories and verify merge convergence
4. Exercise malformed or partial rebase-ai inputs and verify bounded failures

## 5. Operational Rules

1. When adding a new distributed or coordination feature, always add at least one failure-case test simultaneously
2. Bug fixes must follow the "reproduction test (Red) -> fix (Green)" pattern
3. E2E tests that depend on external services should stay isolated; local verification should remain primarily mock-based or repo-local
