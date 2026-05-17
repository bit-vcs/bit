# TODO (Active Only)

最終整理日: 2026-05-17
現バージョン: v0.41.0
allowlist: 908 テスト
known-breakage パッチ: 10 (audit pass 完了、残は機能 gap / 個別 test rewrite)
CI SHIM_CMDS: **108 コマンド**
e2e: **43/43 全パス**
t3404 (rebase -i): **129/132 (97.7%)**

## P0: Delegate → Native 残り

### log (特殊フラグ)

- [x] `--parents` — 各コミットの親 OID を表示
- [x] `--boundary` — boundary コミットのマーク
- [x] `--full-history` / `--simplify-merges` — マージ簡略化制御
- [x] `--ancestry-path` — 2点間の ancestry パス
- [x] `--show-signature` — GPG 署名表示
- [x] `--stdin` — stdin からリビジョン読み取り

### GPG 署名

- [x] `rebase -S` / `--gpg-sign` — rebase 中のコミット署名
- [x] `merge -S` / `--gpg-sign` — merge コミット署名
- [x] `show --show-signature` — 署名表示

### その他

- [x] `blame` textconv ドライバー対応
- [x] `clone` file:// + --depth/--filter (shallow)
- [x] `fetch --depth` / `--unshallow` (shallow fetch)
- [x] `stash push -p` — interactive hunk 選択
- [x] `rev-list --cherry-pick` / `--cherry-mark`

## P1: LFS

- [x] Phase 1: Read-Only — pointer 解決、batch download (v0.40.0)
- [x] Phase 1 セキュリティ — SHA-256 検証、SSRF 防止 (v0.40.1)
- [x] Phase 2: Clean filter — `git add` で pointer 化
- [x] Phase 3: Push — upload to LFS server
- [x] Phase 4: bit-relay LFS 転送

## P1.5: Hub / GitHub sync

- [x] Cross-repo issue references (owner/repo#id)
- [x] GitHub sync pull (issues, PRs, comments)
- [x] GitHub sync push — org リポジトリ対応
- [x] `--force-remote` フラグ

## P2: パフォーマンス

- [x] Pack bitmap 読み込み (t5310/t5326/t5333)
- [x] Commit-graph 活用 — log/rev-list 高速化

## P2.5: Allowlist 拡大

- 現在: 908
- [x] t0008-ignores.sh
- [x] t1400-update-ref.sh — per-test timeout を `max(weight×3, 120s)` に変更して enroll
- [x] t1901-repo-structure.sh
- [x] t3305-notes-fanout.sh
- [x] t4124-apply-ws-rule.sh — known-breakage patch 不要
- [x] t5300-pack-object.sh
- [x] t5310-pack-bitmaps.sh
- [x] t5326-multi-pack-bitmaps.sh
- [x] t5333-pseudo-merge-bitmaps.sh
- [x] t9300-fast-import.sh — known-breakage patch 不要 (t9301-9306 と同列)
- 残候補 in-scope: なし (未収録 120 件は svn/cvs/p4/perl/scalar 系 = スコープ外)

## P2.6: Known-breakage パッチ精査 — audit pass 完了

- 削除済: 18 → 10
  - [x] **case 1a (#54)**: t5610-clone-detached / t9350-fast-export / t5505-remote / t5801-remote-helpers
    — 純 relaxation (BIT prereq なし) → upstream `test_expect_failure` で支障なし
  - [x] **case 1b (#56)**: t1410-reflog / t2405-worktree-submodule / t3600-rm
    — BIT prereq 付きだが upstream は `test_expect_failure`、bit 側 skip を外しても TODO 扱い
  - [x] **case 1c (#58)**: t5572-pull-submodule
    — `lib-submodule-update.sh` 内の 2 件、再分類で case 1 判明
- 残 10 パッチ = 機能 gap または rewrite 系。 audit 範囲外:
  - **case 2 — bit 機能 gap を masking (6)**:
    - t7502 / t7600 — commit / merge の SIGTERM 時 lock cleanup 未実装
    - t0411 / t5616 / t7703 — pack-objects の promisor remote 対応 (lazy-fetch / REF_DELTA / geometric repack)
    - t7527 — builtin fsmonitor--daemon の submodule 統合
    → patch 削除には機能実装が先
  - **case 3 — test 書き換え (4)**: t1006-cat-file (rest+whitespace) / t5300-pack-object (8 件 success→failure) / t5540-http-push-webdav (skip 追加) / t9902-completion (contrib/completion 修正含む)
    → 個別評価

## P3: 将来タスク

- [ ] WASM target カバレッジ拡大
  - [x] diff3 wbtest (23/23 pass) / repo materialize wbtest (2/2 pass) — wasm CI 入り
  - [x] grep pattern + search wbtest (28/28 pass) — wasm CI 入り
  - [ ] fingerprint / x-workspace の wbtest は `async/process` 依存で wasm 不可能、native のみ維持
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
