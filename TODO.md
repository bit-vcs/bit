# TODO (Active Only)

最終整理日: 2026-04-05
現バージョン: v0.41.0
allowlist: 973 テスト
CI SHIM_CMDS: **108 コマンド**
e2e: **43/43 全パス**
t3404 (rebase -i): **129/132 (97.7%)**

## P0: Delegate → Native 残り

### log (特殊フラグ)

- [ ] `--parents` — 各コミットの親 OID を表示
- [ ] `--boundary` — boundary コミットのマーク
- [ ] `--full-history` / `--simplify-merges` — マージ簡略化制御
- [ ] `--ancestry-path` — 2点間の ancestry パス
- [ ] `--show-signature` — GPG 署名表示
- [ ] `--stdin` — stdin からリビジョン読み取り

### GPG 署名

- [ ] `rebase -S` / `--gpg-sign` — rebase 中のコミット署名
- [ ] `merge -S` / `--gpg-sign` — merge コミット署名
- [ ] `show --show-signature` — 署名表示

### その他

- [ ] `blame` textconv ドライバー対応
- [ ] `clone` file:// + --depth/--filter (shallow)
- [ ] `fetch --depth` / `--unshallow` (shallow fetch)
- [ ] `stash push -p` — interactive hunk 選択
- [ ] `rev-list --cherry-pick` / `--cherry-mark`

## P1: LFS

- [x] Phase 1: Read-Only — pointer 解決、batch download (v0.40.0)
- [x] Phase 1 セキュリティ — SHA-256 検証、SSRF 防止 (v0.40.1)
- [ ] Phase 2: Clean filter — `git add` で pointer 化
- [ ] Phase 3: Push — upload to LFS server
- [ ] Phase 4: bit-relay LFS 転送

## P1.5: Hub / GitHub sync

- [x] Cross-repo issue references (owner/repo#id)
- [x] GitHub sync pull (issues, PRs, comments)
- [ ] GitHub sync push — org リポジトリ対応
- [ ] `--force-remote` フラグ

## P2: パフォーマンス

- [ ] Pack bitmap 読み込み (t5310/t5326/t5333)
- [ ] Commit-graph 活用 — log/rev-list 高速化

## P2.5: Allowlist 拡大

- 現在: 973/1027 (非 t9xxx で 54 テスト未追加)
- [ ] t0008, t4124, t5300, t1400, t4056 等

## P3: 将来タスク

- [ ] WASM target カバレッジ拡大
- [ ] Moonix integration
- [ ] bit mcp 拡充

---

## 完了済み (v0.38.0 → v0.41.0)

<details>
<summary>展開</summary>

### v0.41.0 (rebase 完全 native 化 + LFS + log 強化)

**LFS Read-Only**
- Pointer 解決、batch download、checkout 統合
- SHA-256 検証、SSRF 防止、サイズ検証、パス走査防止

**Interactive Rebase (全コマンド native)**
- pick, reword, edit, squash, fixup, drop, exec, break, label, reset, merge
- --autosquash, --exec/-x, --autostash, --keep-empty, --edit-todo
- --show-current-patch, --update-refs, --root, --strategy/-X, --rebase-merges
- Editor injection: lib 層は `(String) -> String?` コールバック、cmd 層は GIT_SEQUENCE_EDITOR
- t3404: 129/132 (97.7%)

**Log 強化**
- --graph, --stat, --name-only, --name-status
- --topo-order, --date-order, --author-date-order
- pathspec フィルタ (log -- path)

**その他**
- core.hooksPath 対応
- Cross-repo issue references + GitHub sync (read-only)
- npm バージョン同期 (0.40.0)

### v0.38.0

- SHA-256 オブジェクトハッシュ基盤 (Phase 1-3)
- Commit-graph 読込・生成
- CI 安定化

</details>

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
- Perl Git.pm (t9700), svn/cvs/p4 (t9*)
