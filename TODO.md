# TODO (Active Only)

最終整理日: 2026-03-27
方針: 完了ログは一旦外し、未完了タスクのみ管理する。
現バージョン: v0.36.0
allowlist: 906 テスト（重複除去済み）
CI SHIM_CMDS: **108 コマンド** (全コマンドをCIに登録済み)
CI unit test: **1637/1637 全パス** (2026-03-16)
e2e: **30/30 全パス** (2026-03-16)

### v0.31.0 → v0.36.0 の主な変更

- SHA-256 オブジェクトハッシュ対応 (dual SHA-1/SHA-256)
- Octopus merge (multi-head merge) 実装
- Commit-graph reader (ObjectDb 統合)
- Relay watch / CI status / review / presence コマンド
- Sub-issue 対応 (bit-hub)
- Merge engine: rename detection, file/directory conflict detection
- cat-file :N:path 対応

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

### lib 抽出済み (libgit API)

| ファイル | pub 関数 | 内容 |
|----------|---------|------|
| config_parse.mbt | 14 | config ファイル解析・値取得・型変換 |
| date_parse.mbt | 10 | approxidate (relative/human/ISO8601) |
| commit_helpers.mbt | 5 | メッセージ整形・trailer・signoff |
| fsck.mbt | 4 | connectivity check・object 列挙 |
| bisect.mbt | 4 | 候補計算・祖先マーク |
| apply.mbt | 6 | パッチパース・rename 表示 |
| rev_list_helpers.mbt | 5 | glob・range・ページネーション |
| diff_tree_helpers.mbt | 2 | hex 省略・フィルタ |
| stash.mbt (+2) | 2 | パス収集・mode 変換 |

### 横断カテゴリ別 未対応サマリ

| カテゴリ | テスト数 | 合計失敗数 | 主要テスト |
|----------|----------|------------|------------|
| **Merge engine** | 5 | 56 | t6416, t6422, t6423, t6424, t6426 |
| **Sparse/Index** | 5 | 44 | t1092(14), t7002(14), t3903(13), t1091(1), t3705(2) |
| **Reftable/Refs** | 3 | 42 | t1460(25), t0610(14), t1463(3) |
| **Object/Hash** | 3 | 110 | t1451(62), t1006(31), t1007(17) |

### スコープ外テスト

- SHA-256 compat (t1016), Perl Git.pm (t9700)
- GPG/SSH 署名 (t7510, t7528), Reftable (t0610, t1460)
- svn/cvs/p4 (t9*)

## P0.5: 未実装機能

- [x] Bitmap ファイル書き出し (`pack-objects --write-bitmap-index`) — EWAH 圧縮、type bitmap、per-tip reachable bitmap、SHA-1 trailer
- [ ] Multi-pack-index 書き出し (`repack --write-midx`) — `ignore(write_midx)` でスタブ
- [x] Commit-graph 読込 (実装済み)
- [ ] Commit-graph 生成 (書き出し)
- [x] SSH トランスポート — ネイティブ `ssh` コマンドに委譲で動作。in-process SSH は未実装
- [ ] GPG/SSH 署名 (`commit -S`, `tag -s`) — フラグ認識のみ、`--signoff` は動作
- [ ] Interactive add (`add -p` / `add -i`) — エラーで拒否するよう修正済み。実装は未着手
- [ ] Interactive rebase (`rebase -i`) — 部分実装 (pick/reword/edit/squash/fixup/drop)、スタンドアロンモード不可

## P1: Relay / P2P collaboration

- [ ] SSH clone の JS target 対応（Issue #18）

## P2: パフォーマンス

### pack-objects 高速化

ベースライン (2026-03-04): 500obj bit=1970ms vs git=101ms (19.5x)

- [x] スライディングウィンドウ (--window) — 実装済み (window=10, configurable)
- [x] build_delta ブロックインデックス再利用 — 実装済み (DeltaWindowEntry にキャッシュ)
- [x] find_best_match 候補数制限緩和 — 32 → 128 に拡大、4バイトprefix check、early-exit閾値 4x に引き上げ
- [ ] delta出力バッファ事前確保 — 実装済み (capacity=target_len/2+32)
- [ ] pack-objects ベンチマーク再計測（最新ベースライン未取得）

## P3: WASM / クロスプラットフォーム

- [ ] WASM target 機能カバレッジ拡大
- [ ] JS target SSH clone 代替 → Issue #18

## P4: 将来タスク

- [ ] Moonix integration
- [ ] bit mcp 拡充
