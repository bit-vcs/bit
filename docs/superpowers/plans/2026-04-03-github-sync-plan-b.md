# GitHub Sync Plan B: Issue 双方向 Sync

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `bit issue sync pull/push` で GitHub Issues と双方向同期を実現する

**Architecture:** pull は GitHub API → GhIssue → Issue 変換 → upsert + SyncLink 作成。push は SyncLink 参照 → 差分検出 → dry-run 表示 → --apply で GitHub API 呼び出し。ISO 8601 → Unix timestamp 変換が必要。

**Tech Stack:** MoonBit, GitHub REST API via gh CLI, Git notes

---

### Task 1: ISO 8601 タイムスタンプパーサー

**Files:**
- Create: `src/x/hub/timestamp.mbt`
- Test: `src/x/hub/hub_test.mbt`

### Task 2: GhIssue → Issue 変換関数

**Files:**
- Create: `src/x/hub/github_convert.mbt`
- Test: `src/x/hub/hub_test.mbt`

### Task 3: sync pull 実装

**Files:**
- Create: `src/x/hub/native/github_sync.mbt` (pull/push ロジック)
- Modify: `src/cmd/bit/hub_github_sync.mbt` (stub → 実装)
- Modify: `src/cmd/git-bit/hub_github_sync.mbt` (同上)

### Task 4: sync push 実装 (dry-run + --apply)

**Files:**
- Modify: `src/x/hub/native/github_sync.mbt`
- Modify: `src/cmd/bit/hub_github_sync.mbt`
- Modify: `src/cmd/git-bit/hub_github_sync.mbt`
