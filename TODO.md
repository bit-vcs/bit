# moongit TODO

## 最新テスト結果サマリー (2026-02-04)

### allowlist テスト (strict モード)
- success: 4650
- broken: 4
- failed: 0
- total: 4760
- pass rate: 97.7%

strict モード:
```
SHIM_CMDS="pack-objects index-pack upload-pack receive-pack" SHIM_STRICT=1
```

allowlist coverage:
- total tests: 1031
- allowlist: 610 (59.2%)
- outside allowlist: 421

※ allowlist を拡張したため再計測が必要（詳細は `COMPAT_RESULTS.md`）。

### allowlist 外の探索的実行
- executed: 779 / 901 (86.5%)
- pass: 743
- fail: 36
- pass rate: 95.4%

高レベル要約（落ちているもの）:
- Pack / MIDX / bitmap / reuse / repack 系の差分が主要 (t53xx, t77xx)
- Partial clone / promisor / protocol v2 の端ケース (t0411, t5616, t5510)
- help/doc/porcelain 表示の差異 (t0012, t0450, t7502)
- cat-file batch/all/unordered (t1006)
- bundle sha256 list-heads (t6020)
- pager exec-path, merge --continue (t7006, t7600)
- scalar/git-shell 未実装 (t9210/t9211, t9850)

詳細: `COMPAT_RESULTS.md`

## 最優先: バイナリ破損リスク（pack/idx/bitmap/repack）

重点対象（破損/整合性の不安が最も高い）:
- pack 生成/再利用/破損耐性: t5305, t5309, t5310, t5314, t5316 (t5302/t5303 done)
- midx / rev-index / bitmap: t5319, t5325, t5326, t5327, t5332
- cruft / repack: t5329, t7700, t7703, t7704
- receive-pack の整合性: t5410, t5411

実装の優先順:
1) pack read/verify + rev-index 整合性 (t5303, t5325, t5310)
2) midx/bitmap/reuse (t5319, t5326, t5327, t5332)
3) repack/cruft (t7700, t7703, t7704, t5329)

## 次のステップ

- [ ] pack/midx/bitmap/repack の整合性修正（上記優先順）
- [ ] 破損検出の回帰テスト追加（pack->verify/fsck 相当）
- [ ] allowlist 再計測（拡張後の結果更新）
- [ ] CI: 5 shard 並列の結果を確認

## 完了した項目

### ✅ Protocol v2 filter/packfile-uris 対応 (2026-02-01)

**修正済み:**
- `src/cmd/bit/pack_objects.mbt`: `--filter` オプション対応 (blob:none, blob:limit, tree:depth)
- `src/cmd/bit/handlers_remote.mbt`: `GIT_CONFIG_OVERRIDES` 環境変数からの設定読み込み
- `src/lib/upload_pack.mbt`: filter spec のパースと適用

**テスト結果:**
- t5702-protocol-v2.sh テスト 42 (filter): パス
- t5702-protocol-v2.sh テスト 60 (packfile-uris): パス

### ✅ `-h` オプション対応

**修正済み:** `src/cmd/moongit/handlers_remote.mbt`
- `receive-pack -h` → usage を stdout に出力、exit code 129
- `upload-pack -h` → usage を stdout に出力、exit code 129

### ✅ git-shim `-c` オプション修正

**修正済み:** `tools/git-shim/bin/git`
- `git branch -c` が config オプションとして誤認識される問題を修正
- サブコマンド検出後のみ `-c` 検証を行うように変更

### ✅ CRC32 バグ修正 (2026-02-01)

**修正済み:** pack ファイルの CRC32 計算が正しく動作するよう修正

### ✅ index-pack SHA1 collision detection 対応 (2026-02-01)

**修正済み:** pack 解析時に SHA1 collision を検出して失敗するよう修正

---

## 追加タスク（メモ）

- [ ] bit mount: ファイルシステムにマウントする機能
- [ ] bit mcp: MCP 対応
- [ ] gitconfig サポート
- [ ] BIT~ 環境変数の対応
- [ ] .bitignore 対応
- [ ] .bit 対応
- [ ] bit jj: jj 相当の対応

---

## 新機能: Git-Native PR システム (src/x/collab)

**計画ファイル:** `~/.claude/plans/lexical-beaming-valley.md`

GitHub/GitLab に依存しない、Git ネイティブな Pull Request システム。
専用ブランチ `_prs` に全 PR データを Git オブジェクト（blob/tree）として保存し、標準の fetch/push で同期。

### 実装ステップ

- [ ] **Step 1: 基盤 (types.mbt, format.mbt)**
  - 型定義 (PullRequest, PrComment, PrReview, PrState, ReviewVerdict)
  - Git スタイルテキストのシリアライズ/パース

- [ ] **Step 2: PR 操作 (pr.mbt)**
  - PrSystem 構造体
  - create, get, list, close

- [ ] **Step 3: コメント・レビュー (comment.mbt, review.mbt)**
  - add_comment, list_comments
  - submit_review, is_approved

- [ ] **Step 4: マージ (merge.mbt)**
  - can_merge, merge_pr
  - 既存の src/lib/merge.mbt を活用

- [ ] **Step 5: 同期 (sync.mbt)**
  - push, fetch
  - conflict resolution

### ファイル構成

```
src/x/collab/
├── moon.pkg.json
├── types.mbt          # 型定義
├── format.mbt         # シリアライズ/デシリアライズ
├── pr.mbt             # PrSystem, create/list/show/close
├── comment.mbt        # コメント操作
├── review.mbt         # レビュー操作
├── merge.mbt          # PR マージ
├── sync.mbt           # fetch/push 同期
└── pr_test.mbt        # テスト
```

### 検証方法

```bash
moon check
moon test --target native -p mizchi/git/x/collab
```
