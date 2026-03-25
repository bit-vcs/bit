# Distributed Testing Guide

This document is an operational guide for verifying bit's agent/orchestrator/Hub components
as a distributed system, including failure modes.

## 1. Test Layers

1. Pure logic (fast)
- Purpose: Detect regressions in decision logic
- Target: `src/x/agent/llm/*_wbtest.mbt`, `src/x/agent/agent_test.mbt`
- Examples: Stall detection, consecutive error detection, subtask conflict detection

2. Coordination/State (medium)
- Purpose: Verify read/write consistency of the coordination dir
- Target: `src/x/agent/llm/coord_wbtest.mbt`
- Examples: Sequential numbering of event appends, status/step round-trip

3. Hub/Sync contract (medium)
- Purpose: Verify PR/Issue/Review representation and sync contracts
- Target: `src/x/hub/*_test.mbt`, `src/x/hub/*_wbtest.mbt`, `src/x/hub/native/*_wbtest.mbt`

4. End-to-end simulation (heavy)
- Purpose: End-to-end connectivity of the agent loop including mock providers
- Target: `src/x/agent/llm/agent_e2e_wbtest.mbt`

## 2. Key Invariants

1. Coordination events are append-only and never overwrite existing events
2. File write-scopes must not conflict within the same subtask set
3. Agent state transitions maintain `pending -> running -> (done|failed|cancelled)`
4. Consecutive errors or prolonged stalls trigger a transition to `cancel`
5. Hub serialize/deserialize round-trips must not lose semantic information

## 3. Execution Commands

```bash
# Run distributed-system-focused verification
just test-distributed

# Additionally, run full regression
just test
just check
```

## 4. Minimal Fault Injection Set

1. Inject consecutive error events and verify the cancel decision
2. Set step time to an old value and verify stall detection
3. Duplicate file scopes and verify the planner's single-task fallback
4. Feed empty/corrupted payloads into hub sync and verify error paths

## 5. Operational Rules

1. When adding a new orchestrator feature, always add at least one failure-case test simultaneously
2. Bug fixes must follow the "reproduction test (Red) -> fix (Green)" pattern
3. E2E tests that depend on Cloudflare/external LLMs are isolated in a separate job; local testing is primarily mock-based
