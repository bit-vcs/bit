# bit home — Home Repo パターン

`bit home` は [Home Repo パターン](https://www.aihero.dev/the-home-repo-pattern) を実践するためのコマンドです。

## Home Repo パターンとは

プロジェクトが複数のリポジトリにまたがっていると、あるリポジトリで起動したエージェントには、そのリポジトリしか見えません。その結果、次のような問題が起きます。

- skill やエージェントの設定が、リポジトリごとにコピーされて散らばる。
- 複数リポジトリにまたがる機能を、全体を見ないまま計画することになる。

Home Repo パターンでは、次のものを置く専用のリポジトリ（Home Repo）を 1 つ作ります。

- AGENTS.md
- skill
- 共有ドキュメント（コーディング規約、用語集、ADR など）

AGENTS.md には、ほかのリポジトリへの**ポインタ**（ローカルの場所と clone 元）を並べます。エージェントは Home Repo で起動し、必要なリポジトリを開いて作業します。コードはそれぞれのリポジトリに置いたままで、履歴・remote・issue もリポジトリごとに残ります。

`bit home` は、このポインタを `bit-home.toml` で管理し、Home Repo と参照先のリポジトリを**1 つの仮想リポジトリ**として扱います。

- `bit home sync`: 全リポジトリを一度に clone / 更新する。
- `bit home status`: 全リポジトリの状態を一覧する。
- `bit home wt`: 機能ごとの worktree を、1 つまたは複数のリポジトリにまとめて作る。
- `bit home exec`: 全リポジトリ（または指定したもの）で同じコマンドを実行する。

リポジトリごとに `cd` して pull して回る必要はありません。

## クイックスタート

```bash
# 1. Home Repo を作る（bit-home.toml, AGENTS.md, CLAUDE.md が作られる）
bit home init ~/repos/acme/home
cd ~/repos/acme/home

# 2. 参照するリポジトリを登録する（--path は必須）
bit home add git@github.com:acme/storefront.git --path ~/repos/acme/storefront \
  --description "Next.js app" --notes "Read its AGENTS.md before changing it."
bit home add git@github.com:acme/payments-api.git --path ~/repos/acme/payments-api

# 3. モノレポの一部だけを使う場合は --subdir（sparse checkout）
bit home add git@github.com:acme/mono.git --path ~/repos/acme/mono-web --subdir apps/web

# 4. 全部まとめて clone / 更新する
bit home sync

# 5. 全体の状態を見る
bit home status
```

`bit home status` の出力例です。

```text
(home)        ~/repos/acme/home          main, up to date with origin/main, clean
storefront    ~/repos/acme/storefront    main, up to date with origin/main, clean
payments-api  ~/repos/acme/payments-api  main, behind 2 vs origin/main, clean
mono-web      ~/repos/acme/mono-web      main, up to date with origin/main, clean, sparse apps/web/
```

最後に、Home Repo 自体を commit / push してチームと共有します。

```bash
git add -A && git commit -m "Set up home repo" && git push
```

## エージェントとの連携

- **起動する場所:** エージェントは Home Repo で起動します（例: `cd ~/repos/acme/home && claude`）。
- **AGENTS.md:** 「Other Repos」セクションには、`bit home render` が `bit-home.toml` から生成したポインタが並びます。

  ```markdown
  <!-- bit-home:begin -->
  ## Other Repos
  ...
  - **storefront** (Next.js app): `~/repos/acme/storefront`. Clone from `git@github.com:acme/storefront.git` if missing. Read its AGENTS.md before changing it.
  - **mono-web**: `~/repos/acme/mono-web`. Clone from `git@github.com:acme/mono.git` if missing. Only `apps/web/` is checked out (sparse).
  <!-- bit-home:end -->
  ```

  マーカー（`bit-home:begin` / `bit-home:end`）の外は自由に編集できます。中は再生成のたびに上書きされるので、手で編集しないでください。
- **CLAUDE.md:** Claude Code は AGENTS.md ではなく CLAUDE.md を読み込みます。そのため `init` は、`@AGENTS.md` の 1 行だけの CLAUDE.md を作ります。すでに CLAUDE.md があって AGENTS.md を参照していない場合は、ヒントを表示します。
- **共有の skill やドキュメント:** Home Repo に置きます（例: `skills/<name>/SKILL.md`、`docs/coding-standards.md`）。各リポジトリに残すのは、そのリポジトリだけに当てはまる内容（固有の AGENTS.md、ビルド手順など）だけです。

## マニフェスト `bit-home.toml`

Home Repo のルートに置きます。`[[repo]]` テーブルの配列です。

```toml
[[repo]]
name = "storefront"                          # 省略すると path の末尾（.git を除く）
path = "~/repos/acme/storefront"             # 必須: clone の置き場所
url = "git@github.com:acme/storefront.git"   # clone 元（無ければ clone できない）
description = "Next.js app"                  # AGENTS.md に表示
branch = "main"                              # clone するブランチ
subdir = "apps/web"                          # このディレクトリだけ sparse checkout
notes = "Read its AGENTS.md before changing it."   # AGENTS.md のポインタ行に追記
```

| キー | 必須 | 説明 |
|---|---|---|
| `path` | ✓ | clone の場所。`~/` はホームディレクトリ、相対パスは Home Repo のルートを基準に解決する |
| `name` | | 識別名。英数字と `.` `_` `-` のみ。重複は不可 |
| `url` | | clone 元。`sync` で未 clone のリポジトリを clone するのに必要 |
| `description` | | AGENTS.md のポインタ行に表示する説明 |
| `branch` | | clone するブランチ |
| `subdir` | | このディレクトリだけを checkout する（cone モードの sparse checkout）。`..` は不可 |
| `notes` | | AGENTS.md のポインタ行に追記する注意書き |

知らないキーはエラーになるので、`subdirs` のような typo もそのまま見逃されません。ファイルは手で編集してかまいません。編集したら `bit home render` で AGENTS.md に反映します。

## コマンド

Home Repo は、カレントディレクトリから親へたどって最初に見つかった `bit-home.toml` の場所です。Home Repo の外から操作するときは、環境変数 `BIT_HOME_ROOT` で場所を指定します。

### `bit home init [<dir>]`

Home Repo を作ります（`<dir>` を省略するとカレントディレクトリ）。

- git リポジトリでなければ `init` する。
- `bit-home.toml` が無ければ、雛形を作る。
- AGENTS.md が無ければ作り、あれば「Other Repos」ブロックだけを追加または更新する。
- CLAUDE.md が無ければ、`@AGENTS.md` だけの CLAUDE.md を作る。

既存のファイルを上書きしないので、すでにあるリポジトリに対して実行しても安全です。

### `bit home add [<url>] --path <dir> [--name <n>] [--description <d>] [--branch <b>] [--subdir <d>] [--notes <text>]`

`bit-home.toml` の末尾に `[[repo]]` を追記し、AGENTS.md を再生成します。

- 既存のコメントは残ります。
- 書き込む前に、マニフェスト全体を検証します（name の重複、不正な subdir など）。

### `bit home render [--check]`

AGENTS.md の「Other Repos」ブロックを `bit-home.toml` から再生成します。

`--check` を付けると書き込まず、ブロックが古ければ exit 1 で終わります。CI に入れておけば、マニフェストを編集したのに render し忘れた変更を検出できます。

### `bit home sync [<name>...]`

名前を省略すると、Home Repo 自体と、マニフェストに登録された全リポジトリが対象です。リポジトリごとの動作は次のとおりです。

| 状態 | 動作 |
|---|---|
| 未 clone | `url` から clone する（`branch` があればそのブランチ）。`subdir` があれば続けて sparse checkout を設定する |
| clone 済み・変更なし・upstream あり | `pull --ff-only` で fast-forward する |
| clone 済み・ローカルの変更あり | `fetch` だけ行い、checkout は更新しない（commit か stash を促す）。`status` の behind は最新になる |
| upstream なし | `fetch` だけ行う。remote が 1 つも無ければ何もしない |
| fast-forward できない（分岐している） | 失敗として報告する |

`subdir` を指定したリポジトリには、毎回 sparse checkout の設定を適用します。マニフェストの `subdir` を変えれば、次の `sync` で checkout される範囲も変わります。1 つでも失敗すると、最後に exit 1 で終わります。

### `bit home status [<name>...]`

各リポジトリについて、次を 1 行ずつ表示します。

- ブランチ
- upstream との差（ahead / behind）
- ローカルの変更数
- sparse checkout の範囲

clone されていないリポジトリには `missing (run bit home sync <name>)` と表示します。

### `bit home wt add <name>[,<name>...] <feature> [--base <ref>]` / `wt list [<name>...]` / `wt remove <name>[,<name>...] <feature> [--force]`

機能ごとの worktree を、そのリポジトリの clone の中に作ります。

- `<name>` をカンマ区切りで並べると、同じ `<feature>` の worktree を複数のリポジトリにまとめて作ります（複数リポジトリにまたがる機能）。
- `--all <feature>` は、マニフェストの全リポジトリが対象です。`wt remove --all <feature>` は、その worktree があるリポジトリだけから外します。
- 一部のリポジトリで失敗しても残りは続け、最後に exit 128 で終わります。

- 場所は `<path>/.worktrees/<feature>`、ブランチ名は `<feature>`。
- ブランチが既にあれば、それを checkout する。無ければ `--base`（省略時は HEAD）から作る。
- `.worktrees/` はそのリポジトリの `.git/info/exclude` に追加するので、追跡されたファイルは変更しない。

1 つのリポジトリで、複数のエージェントが別々の worktree で並行して作業できます。

```bash
bit home wt add storefront checkout-redesign
bit home wt add storefront,payments-api checkout-redesign   # 2 リポジトリにまたがる機能
bit home wt list
bit home wt remove --all checkout-redesign
```

### `bit home exec [<name>...] [--home] [-q] -- <command> [<arg>...]` / `exec ... -c '<shell command>'`

clone 済みの各リポジトリで、そのリポジトリをカレントディレクトリにしてコマンドを実行します（1 つずつ順番に）。

- `<name>` を省略すると、マニフェストの全リポジトリが対象です。`--home` を付けると Home Repo 自体も含めます。
- `--` の後ろはそのまま実行します。`-c` には、パイプや `&&` を含むシェルのコマンド列を渡せます（`/bin/sh -c`）。
- 各リポジトリの前に `== <name> (<path>)` を表示します（`-q` で省略）。
- 環境変数 `BIT_HOME_REPO`（名前）と `BIT_HOME_REPO_PATH`（clone の絶対パス）を設定します。
- clone されていないリポジトリは飛ばします。1 つでも失敗すると、最後に失敗したリポジトリを並べて exit 1 で終わります。

```bash
bit home exec -- git log -1 --oneline
bit home exec storefront payments-api -c 'npm test 2>&1 | tail -3'
bit home exec -q -c 'git status --short | sed "s|^|$BIT_HOME_REPO: |"'
```

## 運用のヒント

- **マニフェストを正とする:** リポジトリの追加・削除は `bit-home.toml` で行い、`render` で AGENTS.md に反映します。CI で `bit home render --check` を実行すると、反映し忘れを防げます。
- **リポジトリが多いとき:** 数十を超えると AGENTS.md が長くなります。元記事では、数百規模なら領域ごとのファイル（例: `repos/billing.md`）にリポジトリの一覧を分け、AGENTS.md からはそれらのファイルを指す方法（progressive disclosure）を勧めています。v1 の `render` は 1 ブロックに全件を並べるだけなので、分割は手で行ってください。
- **チームで使う:** `path` に `~/repos/<org>/<name>` のような共通の規約を決めておくと、全員が同じ `bit-home.toml` を使えます。`add --path` にホームディレクトリ配下の絶対パスを渡しても（シェルが `~` を展開した場合など）、`~/...` の形で保存します。

## 制限事項（v1）

- `subdir` 付きのリポジトリでは、最初の clone で一度すべてを checkout し、その直後に sparse checkout で絞り込みます（clone 時から部分的に checkout するわけではありません）。
- `subdir` 付きのリポジトリでも、`wt add` で作る worktree は全体を checkout します。bit の sparse-checkout が、linked worktree にまだ対応していないためです。
- `sync` と `exec` は 1 リポジトリずつ順番に処理します（並列には実行しません）。
- 元記事にある「既存リポジトリの skill や AGENTS.md の棚卸し」は自動化していません。
