# Cross-Repo Issue References + Working Set

## Overview

bit-issue にクロスリポジトリ参照とワーキングセット機能を追加する。
同一PCローカル内の複数リポジトリ間で issue をリンク・参照・直接操作できるようにする。

## Goals

1. 別リポジトリの issue をリンクとして紐付ける（データ同期なし、ポインタのみ）
2. 同一PCローカル内なら別リポの issue を直接読み書きできる
3. 作業中の issue をワーキングセットとして記録・一覧表示できる

## Non-Goals

- クロスリポジトリ間の issue データ同期（notes の fetch/push）
- リモートPC間のリンク解決（relay 経由の同期は既存機能のまま）

## Design

### 1. Repository Resolution

**標準形式**: `owner/repo#issue-id`（例: `bit-vcs/bit#082e0cda`）

**エイリアス**: 短縮名でリポジトリを参照可能。

**解決順序**:
1. `.git/hub/remotes` に登録されたエイリアス
2. `~/ghq/github.com/{owner}/{repo}` への自動解決
3. エラー

**エイリアス保存先**: `.git/hub/remotes`（TSV形式: `alias\tpath`）

### 2. Cross-Repo Issue Links

issue のメタデータに `linked_issues` フィールドを追加する。

```json
{
  "title": "implement feature X",
  "body": "...",
  "labels": [],
  "assignees": [],
  "parent_id": null,
  "linked_issues": ["bit-vcs/other-repo#a1b2c3d4"]
}
```

- リンクはポインタのみ。相手リポの issue データは同期しない。
- 表示時にリンク先リポのパスを解決し、read-only で情報を取得して表示する。
- リンク先リポが存在しない場合は ID のみ表示（エラーにしない）。

### 3. Working Set (Active Issues)

作業中の issue を `.git/hub/active-issues` に記録する。

**ファイル形式**: 1行1エントリ

```
#local-id
owner/repo#remote-id
alias#remote-id
```

- ローカル issue は `#id` 形式
- クロスリポ issue は `owner/repo#id` または `alias#id` 形式
- 表示時に各リポジトリから最新情報を read-only で取得

### 4. Direct Remote Repo Operations

同一PCローカル内のリポジトリに対して直接操作できる。

- **読み取り**: 相手リポの `.git` から直接 `refs/notes/bit-hub` を読む
- **書き込み**: 相手リポの `refs/notes/bit-hub` に直接書き込む
- Git のローカルアクセスのみ。relay 不要。

### 5. New Commands

```
# Repository alias management
bit issue remote add <alias> <path>     # Register alias
bit issue remote list                    # List aliases
bit issue remote remove <alias>          # Remove alias

# Cross-repo issue links
bit issue link <local-id> <owner/repo#id>    # Add link to issue
bit issue unlink <local-id> <owner/repo#id>  # Remove link

# Working set
bit issue start <ref>                    # Add to working set
bit issue stop <ref>                     # Remove from working set
bit issue active                         # List active issues

# Remote repo operations
bit issue create --repo <owner/repo> -t "title"  # Create in remote repo
bit issue get <owner/repo#id>                     # Read from remote repo
```

### 6. Merge Strategy

- **コメント・変更履歴**: append-only（ID による重複排除）
- **メタデータ（title, status, labels）**: last-write-wins（timestamp）
- リンクの追加・削除もメタデータ扱い（last-write-wins）

### 7. Relay Relationship

- ローカル同士: Git 直接アクセス（relay 不要）
- 別PC間: 従来通り relay 経由（既存機能に変更なし）
- リンク情報は relay sync 時に hub record の一部として自然に同期される
