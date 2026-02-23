# bit relay ガイド

## 概要

`bit relay` は bit-relay サーバーを介したリポジトリ共有と hub メタデータ同期のためのコマンド群です。
NAT/ファイアウォール越しの git clone/fetch/push と、issue・PR などの hub メタデータの配信・取得ができます。

## セットアップ

### 1. relay サーバーの URL を取得

relay サーバーの URL を確認します。例:

```
relay+https://relay.example.com
```

URL は `relay+https://` または `relay+http://` プレフィックスを使用します。

### 2. 署名鍵の生成 (Ed25519)

relay に publish する際の送信者署名に Ed25519 鍵を使用できます。

```bash
# Ed25519 秘密鍵を生成
openssl genpkey -algorithm Ed25519 -out relay-key.pem

# 公開鍵を base64url で取得
openssl pkey -in relay-key.pem -pubout -outform DER | base64 | tr '+/' '-_' | tr -d '='
```

### 3. 環境変数の設定

```bash
# relay URL (serve/sync 共通のデフォルト)
export BIT_RELAY_URL=relay+https://relay.example.com

# 署名鍵 (オプション)
export BIT_RELAY_SIGN_PRIVATE_KEY_FILE=~/.config/bit/relay-key.pem
export BIT_RELAY_SENDER=alice
```

## リポジトリ公開 (`bit relay serve`)

ローカルリポジトリを relay 経由で公開し、リモートから clone/fetch できるようにします。

### 基本

```bash
bit relay serve relay+https://relay.example.com
```

セッションが登録され、clone URL が表示されます:

```
Session registered: abc123
Clone URL: relay+https://relay.example.com/abc123
```

他のユーザーは表示された URL で clone できます:

```bash
bit clone relay+https://relay.example.com/abc123
```

### オプション

| オプション | 説明 |
|---|---|
| `--allow-push` | リモートからの push を受け付ける (`refs/relay/incoming/` に保存) |
| `--broadcast` | push 時に feature notification をブロードキャスト |
| `--auto-fetch` | room 内の feature-broadcast を検知して自動 fetch |
| `--room <name>` | broadcast/auto-fetch 用の room 名 (デフォルト: `serve-{session_id}`) |
| `--repo <name>` | アドバタイズするリポジトリ名 |

### 例: push も許可する双方向共有

```bash
bit relay serve relay+https://relay.example.com --allow-push --broadcast --auto-fetch
```

## hub メタデータ同期 (`bit relay sync`)

issue・PR などの hub メタデータを relay サーバー経由で同期します。

### push: ローカルの hub データを relay に publish

```bash
bit relay sync push relay+https://relay.example.com
```

### fetch: relay から hub データを取得

```bash
bit relay sync fetch relay+https://relay.example.com
```

### clone-announce: clone URL を relay に登録

```bash
bit relay sync clone-announce relay+https://relay.example.com \
  --url https://github.com/user/repo.git
```

### clone-peers: relay に登録された clone URL 一覧を取得

```bash
bit relay sync clone-peers relay+https://relay.example.com
```

### 署名オプション

```bash
# 署名付き push (環境変数を使用)
BIT_RELAY_SIGN_PRIVATE_KEY_FILE=key.pem \
BIT_RELAY_SENDER=alice \
  bit relay sync push relay+https://relay.example.com

# 署名検証を強制
bit relay sync fetch relay+https://relay.example.com --require-signed
```

## ワークフロー例

### 1. チームでの issue 管理

```bash
# リーダー: issue を作成して relay に publish
bit hub issue create --title "バグ修正" --body "ログイン画面のエラー"
bit relay sync push relay+https://relay.example.com

# メンバー: relay から issue を取得
bit relay sync fetch relay+https://relay.example.com
bit hub issue list
```

### 2. PR レビュー + merge

```bash
# 開発者: PR を作成して push
bit hub pr create --title "機能追加" --source feature --target main
bit relay sync push relay+https://relay.example.com

# レビュアー: PR を取得してレビュー
bit relay sync fetch relay+https://relay.example.com
bit hub pr list
bit hub pr review 1 --approve --commit <hex>

# マージ
bit hub pr merge 1
bit relay sync push relay+https://relay.example.com
```

### 3. NAT 越しのリポジトリ共有

```bash
# ホスト側: relay 経由でリポジトリを公開
bit relay serve relay+https://relay.example.com --allow-push

# クライアント側: clone して作業
bit clone relay+https://relay.example.com/<session-id>
# ... 編集 ...
bit push
```

## 移行ガイド

以前の `bit hub serve` / `bit hub sync` は `bit relay serve` / `bit relay sync` に移動しました。
旧コマンドは引き続き動作しますが、移行メッセージが表示されます。

```bash
# 旧 (非推奨)
bit hub serve relay+https://...
bit hub sync push relay+https://...

# 新
bit relay serve relay+https://...
bit relay sync push relay+https://...
```
