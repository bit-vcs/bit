# TODO (Active Only)

最終整理日: 2026-02-15
方針: 完了ログは一旦外し、未完了タスクのみ管理する。

## P0: Git compatibility / 計測

- [x] `t5326-multi-pack-bitmaps.sh` を解消する（2026-02-15: `SHIM_CMDS="multi-pack-index pack-objects index-pack repack" SHIM_STRICT=1` で `success 357 / failed 0`）
- [x] `t5327-multi-pack-bitmaps-rev.sh` を解消する（2026-02-15: `SHIM_CMDS="multi-pack-index pack-objects index-pack repack" SHIM_STRICT=1` で `success 314 / failed 0`）
- [x] `t5334-incremental-multi-pack-index.sh` を解消する（2026-02-15: `SHIM_CMDS="multi-pack-index pack-objects index-pack repack" SHIM_STRICT=1` で `success 16 / failed 0`）
- [ ] multi-pack-index の崩れを修正する
  - bitmap/rev 生成検証
  - `rev-list --test-bitmap`
  - incremental layer/relink
- [ ] allowlist/full の全流し再計測を実施する（長時間ジョブ）

## P1: Agent runtime

- [ ] Process agent signal handling: タイムアウト/キャンセル時のクリーンアップ改善
- [ ] Agent output capture: ProcessAgentRunner の per-agent stdout 取得

## P2: Git互換の残タスク（方針未対応）

- [ ] Git 互換を一度に全件化するため、`hash-object` で確立した方針を順次展開する
  - [ ] まずコマンド別に「storage runtime で実装不十分になりやすい領域」を洗い出す（filter / autocrlf / gitattributes / pathspec など）
  - [ ] 各コマンドで `--random` でも壊れにくいフォールバックを設計し、`real git` と `storage runtime` の振る舞い差を最小化する
  - [ ] 方針適用ごとに既存テストを回して短時間で固定し、失敗は allowlist/full で再確認する
  - [ ] フォールバックルールを横断的に共通化して、将来コマンド追加時の抜け漏れを抑制する

- [ ] `t5540-http-push-webdav.sh`
- [ ] `t9001-send-email.sh`
- [ ] `full allowlist (just git-t-allowlist-shim-strict)` を再開して完走させる
  - [ ] `2026-02-17`: 実行途中で 1時間56分でタイムアウト
  - [x] `2026-02-17`: `t1300-config.sh` の `git --config-env with missing value` を再現（`tools/git-shim/bin/git` の `resolve_real_git` 引数未設定時 `shift` バグ）
- [ ] `--help` 移植（全サブコマンドの usage テキスト）
  - [x] `show_command_help` を spec 駆動へ整理（追加時の重複実装を削減）
  - [x] help 経路の回帰テストを追加（completion 一覧 / dispatch 固有 / alias）
  - [x] 詳細ヘルプをオプトイン外部読込に対応（`BIT_HELP_FULL=1`, `BIT_HELP_TEXT_DIR`）
  - [x] shim の fallback 判定を help ターゲットベースへ変更し、グローバルオプション前置き (`--git-dir`, `-C`) でも fallback する回帰テストを追加（2026-02-16）
  - [ ] 外部 help テキスト実体の整備（必要コマンド分）

## P3: プラットフォーム/将来タスク

- [ ] Moonix integration: ToolEnvironment <-> AgentRuntime（moonix release 待ち）
- [ ] bit mount: ファイルシステムにマウントする機能
- [ ] bit mcp: MCP 対応
- [ ] gitconfig サポート
- [ ] BIT~ 環境変数の対応
- [ ] `.bitignore` 対応
- [ ] `.bit` 対応
- [ ] bit jj: jj 相当の対応
