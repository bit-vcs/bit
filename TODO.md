# TODO (Active Only)

最終整理日: 2026-04-05
方針: 完了ログは一旦外し、未完了タスクのみ管理する。
現バージョン: v0.40.3
allowlist: 973 テスト
CI SHIM_CMDS: **108 コマンド** (全コマンドをCIに登録済み)
e2e: **43/43 全パス** (2026-04-05)
t3404 (rebase -i): **129/132 (97.7%)**

### v0.38.0 → v0.40.3 の主な変更

- LFS Read-Only: pointer 解決 + batch download + SHA-256 検証 + SSRF 防止
- Interactive Rebase: pick/reword/edit/squash/fixup/drop/exec/break + autosquash + --exec
- core.hooksPath: git config からフックパス解決
- log --graph / --stat: native 実行に移行
- Cross-repo issue references + GitHub sync (read-only)
- セキュリティ修正: LFS SHA-256 検証、URL scheme 検証、パス走査防止

## P0: Git compatibility — delegate → native 移行

### 高優先度・低コスト

- [ ] `log --name-only` / `--name-status` — diff ファイル名/ステータス表示
- [ ] `log --topo-order` / `--date-order` / `--author-date-order` — コミットソート順

### 高優先度・中コスト

- [ ] `rebase --rebase-merges` — マージコミット保持 rebase (label/reset/merge コマンド)

### 中優先度

- [ ] `stash push -p` — interactive hunk 選択
- [ ] t3404 残り 3 件 — FAKE_LINES テストインフラ互換性

## P0.5: 未実装機能

- [x] Bitmap ファイル書き出し
- [x] Multi-pack-index 書き出し
- [x] Commit-graph 読込・生成
- [x] SSH トランスポート
- [x] GPG/SSH 署名 (`commit -S`, `tag -s`)
- [x] Interactive add (`add -p` / `add -i`)
- [x] Interactive rebase (`rebase -i`) — native 実装 (v0.40.2)
- [x] LFS Read-Only (v0.40.0)
- [x] core.hooksPath (v0.40.3)
- [x] log --graph / --stat (v0.40.3)

## P1: LFS

- [x] Phase 1: Read-Only — pointer 解決、batch download、checkout 統合
- [x] Phase 1 セキュリティ — SHA-256 検証、SSRF 防止、サイズ検証
- [ ] Phase 2: Clean filter — `git add` で pointer 化
- [ ] Phase 3: Push — upload to LFS server
- [ ] Phase 4: bit-relay LFS 転送 — P2P で LFS オブジェクト共有

## P1.5: Hub / GitHub sync

- [x] Cross-repo issue references (owner/repo#id)
- [x] GitHub sync pull (issues, PRs, comments)
- [x] Write safety gate (BIT_GITHUB_SYNC_WRITE=1)
- [ ] GitHub sync push の安定化 — owner check の org 対応
- [ ] `--force-remote` フラグ実装（エラーメッセージで言及済み）

## P2: パフォーマンス

### pack-objects 高速化

ベースライン (2026-03-04): 500obj bit=1970ms vs git=101ms (19.5x)
最新計測 (2026-03-28): 500obj bit=58.5ms (delta: 61.3ms) vs git=42ms (**1.4x**) — 33.7x 高速化

### 未実装の最適化

- [ ] Pack bitmap 読み込み (t5310/t5326/t5333) — clone/fetch 高速化
- [ ] Commit-graph 活用 — log/rev-list 高速化

## P2.5: Allowlist 拡大

- 現在: 973/1027 (非 t9xxx で 54 テスト未追加)
- [ ] t0008 (check-ignore) — 基本機能
- [ ] t4124 (apply whitespace) — apply の whitespace ルール
- [ ] t5300 (pack-object) — pack 関連
- [ ] t5310/t5326/t5333 (bitmap) — bitmap 実装後
- [ ] t1400 (update-ref) — FIFO デッドロック問題
- [ ] t4056 (diff order) — `-O orderfile` 未実装

## P3: WASM / クロスプラットフォーム

- [ ] WASM target 機能カバレッジ拡大

## P4: 将来タスク

- [ ] Moonix integration
- [ ] bit mcp 拡充
- [ ] GPG 署名 on merge/rebase

## 実装済みコマンド (108 SHIM_CMDS)

```
init add diff diff-files diff-index ls-files tag branch checkout switch
commit log show reflog reset update-ref update-index status merge rebase
clone push fetch pull mv notes stash rm submodule worktree config show-ref
for-each-ref rev-parse symbolic-ref cherry-pick remote cat-file hash-object
ls-tree write-tree commit-tree receive-pack upload-pack pack-objects
index-pack format-patch describe gc clean sparse-checkout restore blame
grep shell rev-list bisect diff-tree read-tree fsck am apply bundle cherry
revert prune pack-refs mktree shortlog verify-pack unpack-objects
maintenance range-diff show-branch repack multi-pack-index pack-redundant
send-pack request-pull merge-base var stripspace ls-remote fmt-merge-msg
patch-id count-objects name-rev update-server-info check-ref-format mktag
interpret-trailers column merge-tree merge-file fast-import fast-export
verify-tag fetch-pack difftool rerere mailinfo archive check-attr
check-ignore show-index get-tar-commit-id verify-commit annotate
```

### スコープ外

- `filter-branch` — 非推奨 (git-filter-repo 推奨)
- Perl Git.pm (t9700)
- svn/cvs/p4 (t9*)
