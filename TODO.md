# TODO (Active Only)

最終整理日: 2026-03-29
方針: 完了ログは一旦外し、未完了タスクのみ管理する。
現バージョン: v0.38.0
allowlist: 973 テスト
CI SHIM_CMDS: **108 コマンド** (全コマンドをCIに登録済み)
CI unit test: **1302/1302 全パス** (2026-03-29)
CI git-compat: **全10 shard SUCCESS** (2026-03-29)
CI random compat: **全5 shard SUCCESS** (2026-03-29)
e2e: **30/30 全パス** (2026-03-29)

### v0.37.0 → v0.38.0 の主な変更

- SHA-256 オブジェクトハッシュ基盤 (Phase 1-3 完了)
  - HashAlgorithm enum, SHA-256 hasher, ObjectId 可変長化
  - Pack/Index/Reftable の hash_size パラメータ化
  - index-pack/pack-objects の SHA-256 rejection 除去
  - lib 層 (index, object_db, revparse, log, rebase, receive_pack) の OID 長対応
  - E2E テスト: init sha256 → object write/read → 検証
- Commit-graph: topological generation number 計算（fsck 修正）
- CI 安定化: test_expect_failure → prereq skip 変換、タイムアウトテスト除外

## P0: SHA-256 残課題

- [ ] packfile_parse の delta 解決後 OID 計算を algo 対応に (11箇所の hash_object_content → hash_object_content_with_algo)
- [ ] commit-graph trailer を hash_size 対応に (sha1() → hash_prefix())
- [ ] SHA-256 compat テスト (t1016) — GPG2 依存、GPG 署名実装後に対応

## P0: Git compatibility

### 実装済みコマンド (108 SHIM_CMDS)

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

### スコープ外コマンド

- `filter-branch` — 非推奨 (git-filter-repo 推奨)

### スコープ外テスト

- SHA-256 compat (t1016) — GPG2 依存
- Perl Git.pm (t9700)
- GPG/SSH 署名 (t7510, t7528)
- svn/cvs/p4 (t9*)
- 常時タイムアウト (t0008, t1400, t1901, t3305, t4056, t4124, t5300, t5310, t5326, t5333, t9300)

## P0.5: 未実装機能

- [x] Bitmap ファイル書き出し
- [x] Multi-pack-index 書き出し
- [x] Commit-graph 読込・生成
- [x] SSH トランスポート
- [ ] GPG/SSH 署名 (`commit -S`, `tag -s`) — フラグ認識のみ、`--signoff` は動作
- [ ] Interactive add (`add -p` / `add -i`) — エラーで拒否するよう修正済み。実装は未着手
- [ ] Interactive rebase (`rebase -i`) — 部分実装 (pick/reword/edit/squash/fixup/drop)、スタンドアロンモード不可

## P1: Relay / P2P collaboration

- [ ] SSH clone の JS target 対応（Issue #18）

## P2: パフォーマンス

### pack-objects 高速化

ベースライン (2026-03-04): 500obj bit=1970ms vs git=101ms (19.5x)
最新計測 (2026-03-28): 500obj bit=58.5ms (delta: 61.3ms) vs git=42ms (**1.4x**) — 33.7x 高速化

## P3: WASM / クロスプラットフォーム

- [ ] WASM target 機能カバレッジ拡大
- [ ] JS target SSH clone 代替 → Issue #18

## P4: 将来タスク

- [ ] Moonix integration
- [ ] bit mcp 拡充
