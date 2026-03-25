# Sub-Issues

bit hub の Issue は親子関係（sub-issue）をサポートしている。
大きなタスクを小さな単位に分解し、進捗を追跡できる。

## 作成

`--parent` (`-p`) で親 Issue の ID を指定する。

```bash
# 親 Issue を作成
bit issue create --title "認証リファクタリング"

# sub-issue を作成
bit issue create --title "トークン検証の修正" --parent <parent-id>
bit issue create --title "セッション管理の改善" -p <parent-id>
```

`--parent=<id>` 形式も使える。

## 一覧

デフォルトでは top-level（親を持たない）Issue のみ表示される。

```bash
# top-level のみ（デフォルト）
bit issue list

# 全 Issue（sub-issue 含む）
bit issue list --all

# 特定の親の sub-issue のみ
bit issue list --parent <parent-id>
```

`--state open` / `--state closed` と組み合わせ可能。

## 詳細表示

`bit issue get` は親情報と sub-issue の一覧を自動的に表示する。

```bash
bit issue get <id>
```

出力例:

```
id iss-abc123
title 認証リファクタリング
state open
...
sub-issues:
  #iss-def456 [open] トークン検証の修正
  #iss-ghi789 [closed] セッション管理の改善
```

子 Issue の場合は親情報が表示される:

```
id iss-def456
title トークン検証の修正
state open
parent iss-abc123
...
parent: #iss-abc123 認証リファクタリング
```

## データモデル

- Issue に `parent_id : String?` フィールドが追加されている
- シリアライズ形式: `parent <id>` ヘッダ行（parent_id がある場合のみ出力）
- 既存の Issue（parent なし）との後方互換性あり
- close / reopen / update 操作で parent_id は保持される
- 子の自動 close（親 close 時）はスコープ外

## 制限事項

- 深さ制限の強制なし（多段ネスト可能だが推奨しない）
- reparenting（親の変更）は未対応
- tree 表示モードは未実装
