# bit hub protocol v1

## 1. 目的

この文書は `bit hub` の永続化フォーマットと merge gate 契約の v1 を定義する。
対象は以下。

- Hub record の key/kind/payload 契約
- PR merge policy (`.git/hub/policy.toml`) 契約
- workflow 結果連携 (`hub pr workflow`, `workspace flow --pr`) 契約
- relay 同期時の認証・署名ポリシー入力

## 2. 永続化

- Hub record は `refs/notes/bit-hub` 配下で管理する。
- record は `HubRecord` として serialize される。
- workflow 記録は以下 key 空間を使う。
  - prefix: `hub/pr/<pr_id>/workflow/`
  - key: `hub/pr/<pr_id>/workflow/<task_hash>`
  - kind: `hub.pr.workflow`

`<task_hash>` は task 名から計算される安定ハッシュであり、同一 task は同一 key に上書きされる。

## 3. workflow payload (`hub.pr.workflow`)

payload は JSON object:

```json
{
  "pr_id": "p-123",
  "task": "test",
  "status": "success",
  "workspace_fingerprint": "...",
  "author": "ci@example.com",
  "txn_id": "flow-test-...",
  "summary": "optional"
}
```

- `status`: `pending|running|success|failed`
- `workspace_fingerprint`: 実行時の workspace 指紋（文字列）
- `txn_id`: 任意
- `summary`: 任意

`updated_at` は payload ではなく HubRecord timestamp を正とする。

## 4. merge policy v1

`bit hub init` が生成する `.git/hub/policy.toml`:

```toml
[merge]
required_approvals = 0
allow_request_changes = true
require_signed_records = false
required_workflows = []
```

`required_workflows` に task 名がある場合、`bit hub pr merge` は以下を満たす必要がある:

- 対象 PR に各 task の workflow record が存在する
- 各 task の最新 status が `success`

満たさない場合は merge を拒否する。

## 5. CLI 契約

### 5.1 workflow 記録

- `bit hub pr workflow submit <pr-id> --task <task> --status <status> [--fingerprint <v>] [--txn <id>] [--author <name>] [--summary <text>]`
- `bit hub pr workflow list <pr-id>`

### 5.2 workspace 連携

- `bit workspace flow <task> --pr <pr-id>`
  - flow 実行結果を `hub.pr.workflow` として自動記録する
  - `status`: required node が全て成功なら `success`、失敗があれば `failed`
  - `txn_id`: workspace flow transaction id

## 6. relay sync の認証・署名入力

`bit hub sync push/fetch` は以下オプションを受け付ける。

- `--auth-token <token>`
- `--signing-key <key>` (`--sign-key` も可)
- `--require-signed`
- `--allow-unsigned`

未指定時は環境変数を使う。

- `BIT_RELAY_AUTH_TOKEN`
- `BIT_COLLAB_SIGN_KEY`
- `BIT_COLLAB_REQUIRE_SIGNED`

CLI オプションが環境変数より優先される。

## 7. 互換性

- 既存 PR/Issue/Comment/Review/Note record 形式は変更しない。
- `required_workflows` 未設定（空配列）の場合、従来 merge policy と同じ動作。
