# Package Layout (WIP)

`src/` を責務単位で分割し、必要な機能だけ import できる構成に段階移行するためのメモ。

## 現在の分割

- `mizchi/bit/remote`
  - ローカル/remote-helper URL の解決
  - `.git` ファイル解決 (`resolve_gitdir`)
  - bare/worktree 判定 (`detect_git_dir`)
  - `user/repo`, `user/repo:path`, `@ref` などの shorthand 解析
  - shorthand とローカルディレクトリ衝突判定
- `mizchi/bit/refs`
  - loose refs / packed-refs の列挙
  - packed-refs の書き換え、remote tracking refs の掃除
- `mizchi/bit/pack_ops`
  - pack 用 object 収集 API (`collect_reachable_objects` など) の入口
- `mizchi/bit/worktree`
  - status/add/commit/rm/mv など worktree 操作 API の入口

`mizchi/bit/lib` には後方互換の facade を残しているため、既存呼び出しはそのまま動作する。

## 方針

- 新規実装はまず機能別 package に置く
- `lib` は互換 facade として薄く保つ
- 呼び出し側は必要に応じて feature package を直接 import する

この方針により、将来的に command/binary ごとに依存を最小化しやすくする。
