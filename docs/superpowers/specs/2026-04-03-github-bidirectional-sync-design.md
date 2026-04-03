# GitHub Bidirectional Sync Design

## Overview

bit issue/PR と GitHub Issues/PRs の双方向同期機能。SyncLink レコードでマッピングを管理し、`gh` CLI または直接 HTTP で GitHub API にアクセスする。

## Goals

1. Issue の双方向同期（メタデータ + コメント）
2. PR の双方向同期（メタデータ + コメント）
3. GitHub への書き込みは明示的オプション + dry-run デフォルトで安全性を確保
4. SyncLink を hub record として保存し、relay 経由で peer 間にも伝播

## Non-Goals

- Review, milestone, project board の同期
- Webhook によるリアルタイム同期
- GitHub 以外のプロバイダ対応（拡張可能にはするが初期実装は GitHub のみ）

## Design

### 1. SyncLink Record

hub record として `refs/notes/bit-hub` に保存。relay sync で peer に自然伝播。

**Issue/PR マッピング:**

```
key: hub/sync-link/{local_id}/github
kind: sync-link
```

```json
{
  "local_id": "abc12345",
  "local_kind": "issue",
  "provider": "github",
  "repo": "owner/repo",
  "remote_number": 42,
  "remote_node_id": "I_kwDOxxx",
  "last_pull_at": 1774900000,
  "last_push_at": 1774900000,
  "remote_updated_at": 1774899000
}
```

PR の場合は `local_kind: "pr"`。

**コメントマッピング:**

```
key: hub/sync-link/{local_id}/comment/{comment_id}/github
kind: sync-link
```

```json
{
  "local_id": "abc12345",
  "comment_id": "c1d2e3f4",
  "provider": "github",
  "repo": "owner/repo",
  "remote_comment_id": 123456789,
  "last_pull_at": 1774900000,
  "last_push_at": 1774900000
}
```

### 2. GitHub API Access

抽象インターフェースで `gh` CLI と直接 HTTP を統一。

**解決順序:**
1. `gh` CLI が PATH に存在 → `gh api` で REST 呼び出し
2. `GITHUB_TOKEN` 環境変数が設定済み → 直接 HTTP リクエスト (`api.github.com`)
3. どちらもない → エラー終了

**抽象化:**

```
trait GitHubClient {
  list_issues(repo, since?) -> Array[GhIssue]
  get_issue(repo, number) -> GhIssue
  create_issue(repo, title, body, labels, assignees) -> GhIssue
  update_issue(repo, number, title?, body?, state?, labels?, assignees?) -> GhIssue
  list_issue_comments(repo, number, since?) -> Array[GhComment]
  create_comment(repo, number, body) -> GhComment
  update_comment(repo, comment_id, body) -> GhComment
  delete_comment(repo, comment_id) -> Unit
  list_prs(repo, since?) -> Array[GhPullRequest]
  get_pr(repo, number) -> GhPullRequest
  create_pr(repo, title, body, head, base) -> GhPullRequest
  update_pr(repo, number, title?, body?, state?) -> GhPullRequest
  list_pr_comments(repo, number, since?) -> Array[GhComment]
}
```

**GhCli 実装:** `gh api repos/{owner}/{repo}/issues?since=...` を `@process.collect_output` で実行、JSON パース。

**HttpClient 実装:** `@http.fetch("https://api.github.com/repos/...")` で直接呼び出し、`Authorization: Bearer $GITHUB_TOKEN` ヘッダ付与。

### 3. Sync Flow

#### Pull (GitHub → bit)

1. SyncLink レコードから前回の `last_pull_at` を取得（なければ全件取得）
2. GitHub API で `since` パラメータ付きで更新された issue/PR を取得
3. SyncLink が存在しない issue/PR は新規作成（import と同等）
4. SyncLink が存在する issue/PR は競合ポリシーで解決:
   - `newer-wins` (デフォルト): `remote_updated_at` vs `bit_updated_at` の timestamp 比較
   - `github-wins`: GitHub 側を常に採用
   - `bit-wins`: bit 側を常に採用（GitHub の変更を無視）
   - `manual`: 競合をスキップして報告のみ
5. コメント同期（`--comments` オプションに従う）
6. SyncLink の `last_pull_at` を更新

#### Push (bit → GitHub)

1. SyncLink の `last_push_at` 以降に `updated_at` が更新された bit issue/PR を検出
2. SyncLink が存在しない bit issue/PR は GitHub に新規作成
3. SyncLink が存在するものは差分を計算
4. **デフォルトは dry-run**: 変更内容を表示するだけ
5. `--apply` フラグで実際に GitHub API を呼んで更新
6. 破壊的変更（state 変更、title/body 上書き、PR マージ）を色付きで警告表示
7. コメント同期（`--comments` オプションに従う）
8. SyncLink の `last_push_at` を更新

#### Bidirectional (pull → push)

`bit issue sync --github --repo owner/repo` は pull を実行してから push を実行。dry-run モードでは両方向の変更を一覧表示。

### 4. Safety Mechanisms

**`--github` オプション必須:** GitHub への書き込みを含むコマンド（push, 双方向 sync）は `--github` フラグが必須。pull は読み取りのみなので不要。

**デフォルト dry-run:** push/sync は変更内容を表示するだけ。`--apply` で実行。

**破壊的変更の表示:**

```
Changes to push to GitHub (owner/repo):

  CREATE issue #--- "New feature request"
    title: New feature request
    body: (42 chars)
    labels: [enhancement]

  UPDATE issue #42 "Fix parser bug"
    ⚠ state: open → closed
    title: Fix parser bug → Fix parser bug (updated)
    labels: [bug] → [bug, fixed]

  CREATE PR #--- "Add retry logic"
    ⚠ head: feature/retry → base: main
    title: Add retry logic

Run with --apply to execute these changes.
```

`⚠` マークで state 変更や PR 作成など破壊的操作を強調。

### 5. Conflict Policy

レコード単位で適用。フィールド単位マージはしない。

```
--conflict newer-wins    # デフォルト: updated_at timestamp 比較
--conflict github-wins   # GitHub 側を常に採用
--conflict bit-wins      # bit 側を常に採用
--conflict manual        # 競合をスキップ、レポートのみ
```

競合検出: SyncLink の `remote_updated_at` と GitHub 側の `updated_at` が異なり、かつ bit 側の `updated_at` も `last_push_at` 以降に変わっている場合。

### 6. Comment Sync Policy

```
--comments append-only   # デフォルト: 新規コメントの追加のみ
--comments full          # 追加・編集・削除すべて双方向
--comments no-delete     # 追加・編集のみ、削除しない
```

コメントマッピングは SyncLink で個別に追跡。`append-only` では SyncLink に存在しないコメントのみ同期。`full` では既存コメントの body 変更も検出して同期。

### 7. Command Interface

```bash
# Pull (GitHub → bit) — 読み取りのみ、--github 不要
bit issue sync pull --repo owner/repo
bit issue sync pull --repo owner/repo --since 2026-03-01
bit issue sync pull --repo owner/repo --conflict github-wins
bit issue sync pull --repo owner/repo --comments full

# Push (bit → GitHub) — --github 必須、デフォルト dry-run
bit issue sync push --github --repo owner/repo              # dry-run
bit issue sync push --github --repo owner/repo --apply      # 実行
bit issue sync push --github --repo owner/repo --comments full --apply

# 双方向 — --github 必須（push 含む）
bit issue sync --github --repo owner/repo                   # dry-run
bit issue sync --github --repo owner/repo --apply           # 実行

# 状態確認
bit issue sync status --repo owner/repo

# PR 同期（同じ体系）
bit pr sync pull --repo owner/repo
bit pr sync push --github --repo owner/repo --apply

# Hook 設定
bit issue sync install-hook    # git push 後に自動 sync push
```

### 8. Hook Integration

`bit issue sync install-hook` で `.git/hooks/post-push` にスクリプトを登録:

```bash
#!/bin/sh
# Auto-sync bit issues to GitHub after push
bit issue sync push --github --repo "$(git remote get-url origin | sed 's|.*github.com[:/]||;s|\.git$||')" --apply --comments append-only
```

`--apply` 付きで自動実行。dry-run は手動実行時のみ。

### 9. Import との関係

既存の `bit issue import --repo owner/repo` は SyncLink を作成しない一方向 import。sync 機能を使うと SyncLink が自動作成される。

初回 `bit issue sync pull --repo owner/repo` は実質的に import + SyncLink 作成。既に import 済みの issue は title + body の一致で SyncLink を推定作成する（`--reconcile` フラグ）。

### 10. Data Flow

```
GitHub API                          bit (refs/notes/bit-hub)
  Issues/PRs  ←── pull ──────────→  WorkItem (issue/pr)
  Comments    ←── pull/push ──────→  Comment
                                     │
                                     ├── SyncLink (mapping)
                                     │   hub/sync-link/{id}/github
                                     │
                                     └── relay sync → other peers
                                         (SyncLink も peer に伝播)
```

### 11. File Structure

```
src/x/hub/sync_link.mbt          # SyncLink 型定義、シリアライズ/パース
src/x/hub/github_types.mbt       # GhIssue, GhPullRequest, GhComment 型
src/x/hub/github_sync.mbt        # pull/push ロジック（純粋関数）
src/x/hub/native/github_api.mbt  # GitHubClient trait + gh CLI 実装
src/x/hub/native/github_http.mbt # GitHubClient HTTP 実装
src/cmd/bit/hub_github_sync.mbt  # CLI コマンドハンドラ
src/cmd/bit/hub_sync_hook.mbt    # install-hook コマンド
```
