# Package Layout

The repository is a MoonBit workspace (`moon.work`). Every module lives under
`modules/<name>/`. The main module `mizchi/bit` (under `modules/bit/`) contains
Git plumbing / porcelain organized in a layered structure inspired by
[gitoxide]'s `gix-*` plumbing / `gix` porcelain / `gitoxide` CLI split.
Non-Git extensions live in their own `mizchi/bitx_*` modules so consumers can
pick only the features they need.

[gitoxide]: https://github.com/Byron/gitoxide

## Repository layout

```
moon.work                  ← workspace manifest
modules/
  bit/                     ← main module: core / mid / high / cmd
    moon.mod.json
    src/
      types/  hash/  object/  ...  (core)
      repo/  worktree/  diff/ ...   (mid)
      lib/  vfs/  fingerprint/      (high)
      cmd/bit/  cmd/git-bit/        (cmd)
  bitx_bitconfig/          ← extension modules
  bitx_doc/
  bitx_hq/
  bitx_hub/
  bitx_kv/
  bitx_rebase_ai/
  bitx_subdir/
  bitx_workspace/
```

## Layers

```
cmd ─→ bitx_* ─→ lib (high) ─→ mid ─→ core
                bitx_* ─→ mid ─→ core      (bitx_* may bypass `lib`)
```

Dependencies must flow only in one direction. A package in a lower layer must
never import a package from a higher layer.

### core (gitoxide `gix-*` plumbing 相当)

Single-purpose, low-level packages. Each package is responsible for one Git
primitive and may only depend on other `core/*` packages it strictly needs.

| Package                       | Path                  | gitoxide analogue                  |
|-------------------------------|-----------------------|------------------------------------|
| `mizchi/bit/types`            | `modules/bit/src/types`           | (shared types)                     |
| `mizchi/bit/hash`             | `modules/bit/src/hash`            | `gix-hash`                         |
| `mizchi/bit/date_parse`       | `modules/bit/src/date_parse`      | `gix-date`                         |
| `mizchi/bit/string_utils`     | `modules/bit/src/string_utils`    | `gix-utils`, `gix-quote`           |
| `mizchi/bit/config_parse`     | `modules/bit/src/config_parse`    | `gix-config`                       |
| `mizchi/bit/object`           | `modules/bit/src/object`          | `gix-object`                       |
| `mizchi/bit/trailers`         | `modules/bit/src/trailers`        | `gix-trailers`                     |
| `mizchi/bit/ignore`           | `modules/bit/src/ignore`          | `gix-ignore` + `gix-glob`          |
| `mizchi/bit/tar`              | `modules/bit/src/tar`             | `gix-archive`                      |
| `mizchi/bit/diff_core`        | `modules/bit/src/diff_core`       | `gix-diff` (low-level)             |
| `mizchi/bit/diff3`            | `modules/bit/src/diff3`           | `gix-merge` (low-level)            |
| `mizchi/bit/apply`            | `modules/bit/src/apply`           | (patch application)                |
| `mizchi/bit/fast_import`      | `modules/bit/src/fast_import`     | (fast-import stream)               |
| `mizchi/bit/grep`             | `modules/bit/src/grep`            | (grep engine)                      |
| `mizchi/bit/io`               | `modules/bit/src/io`              | `gix-fs` (abstract)                |
| `mizchi/bit/io/native`        | `modules/bit/src/io/native`       | `gix-fs` (native bindings)         |
| `mizchi/bit/osfs`             | `modules/bit/src/osfs`            | `gix-fs` (OS-backed impl)          |
| `mizchi/bit/pack`             | `modules/bit/src/pack`            | `gix-pack`                         |
| `mizchi/bit/refs`             | `modules/bit/src/refs`            | `gix-ref`                          |
| `mizchi/bit/reftable`         | `modules/bit/src/reftable`        | (reftable backend)                 |
| `mizchi/bit/protocol`         | `modules/bit/src/protocol`        | `gix-protocol`/`gix-transport`     |
| `mizchi/bit/runtime`          | `modules/bit/src/runtime`         | (runtime helpers)                  |
| `mizchi/bit/bootstrap`        | `modules/bit/src/bootstrap`       | (bootstrap helpers)                |

### mid (gitoxide `gitoxide-core` 相当)

Operations layered on top of `core/*`. May depend on `core/*` only.

| Package                  | Path             | Notes                                |
|--------------------------|------------------|--------------------------------------|
| `mizchi/bit/repo`        | `modules/bit/src/repo`       | Repository handle / materialization  |
| `mizchi/bit/repo_ops`    | `modules/bit/src/repo_ops`   | Repository-level operations          |
| `mizchi/bit/pack_ops`    | `modules/bit/src/pack_ops`   | `collect_reachable_objects`, etc.    |
| `mizchi/bit/remote`      | `modules/bit/src/remote`     | URL / shorthand / `.git` discovery   |
| `mizchi/bit/worktree`    | `modules/bit/src/worktree`   | status / add / commit / rm / mv      |
| `mizchi/bit/diff`        | `modules/bit/src/diff`       | High-level diff / show               |

### high (gitoxide `gix` porcelain 相当)

Porcelain layer. May depend on `core/*` and `mid/*`. Used by `cmd/*` and
`x-*` as a convenience surface.

| Package                       | Path               | Notes                                              |
|-------------------------------|--------------------|----------------------------------------------------|
| `mizchi/bit/lib`              | `modules/bit/src/lib`          | High-level / backward-compatible facade            |
| `mizchi/bit/vfs`              | `modules/bit/src/vfs`          | Virtual FS over commits (used by `lib`, `x-kv`, `x-subdir`) |
| `mizchi/bit/fingerprint`      | `modules/bit/src/fingerprint`  | Workspace fingerprint (used by `x-workspace`)      |

### bitx_* (extensions, gitoxide にはない bit 独自機能)

Optional features. Each extension is its own MoonBit module under
`modules/`, so consumers can pull in only the features they need. An
extension may depend on `mizchi/bit` (core / mid / high) but must not
depend on another extension module — shared logic should be promoted into
`mid` or `core` of the main module.

| Module                       | Path                            | Description                     |
|------------------------------|---------------------------------|---------------------------------|
| `mizchi/bitx_bitconfig`      | `modules/bitx_bitconfig/src`    | bit-specific config             |
| `mizchi/bitx_doc`            | `modules/bitx_doc/src`          | Repo-stored markdown docs       |
| `mizchi/bitx_hq`             | `modules/bitx_hq/src`           | `ghq`-compatible repo manager   |
| `mizchi/bitx_hub`            | `modules/bitx_hub/src`          | Local PR / Issue metadata       |
| `mizchi/bitx_hub/crypto`     | `modules/bitx_hub/src/crypto`   | Hub signing primitives          |
| `mizchi/bitx_hub/native`     | `modules/bitx_hub/src/native`   | Hub native bindings + GitHub    |
| `mizchi/bitx_kv`             | `modules/bitx_kv/src`           | Git-backed KV store             |
| `mizchi/bitx_kv/native`      | `modules/bitx_kv/src/native`    | KV native sync                  |
| `mizchi/bitx_rebase_ai`      | `modules/bitx_rebase_ai/src`    | AI-assisted rebase helpers      |
| `mizchi/bitx_subdir`         | `modules/bitx_subdir/src`       | Subdirectory clone              |
| `mizchi/bitx_workspace`      | `modules/bitx_workspace/src`    | Workspace flow                  |

### cmd (binaries)

CLI entry points. May depend on any layer.

| Package                  | Path             | Notes                                  |
|--------------------------|------------------|----------------------------------------|
| `mizchi/bit/cmd/bit`     | `modules/bit/src/cmd/bit`    | Main `bit` CLI                         |
| `mizchi/bit/cmd/git-bit` | `modules/bit/src/cmd/git-bit`| `git-bit` shim CLI                     |

## Allowed dependency directions

Each layer may import from itself and lower layers only:

| From    | core | mid | high (lib) | bitx_* | cmd  |
|---------|:----:|:---:|:----------:|:------:|:----:|
| core    | ✓    |     |            |        |      |
| mid     | ✓    | ✓   |            |        |      |
| high    | ✓    | ✓   | ✓          |        |      |
| bitx_*  | ✓    | ✓   | ✓          | (1)    |      |
| cmd     | ✓    | ✓   | ✓          | ✓      | ✓    |

(1) A `bitx_*` module must not import another `bitx_*` module. Shared logic
should be lifted into `high`, `mid`, or `core` of the main `mizchi/bit`
module.

## Lint

Run `node tools/check-layers.mjs` to validate the dependency graph against the
rules above. CI runs the same script.

## Policy

- New low-level functionality lands directly in `core/*`.
- `lib` (high) is a thin facade. Do not put new logic into `lib`; instead, add
  it to a focused `core/*` or `mid/*` package and re-export through `lib` if
  callers need the convenience.
- `bitx_*` modules are independent. If two of them need to share code,
  promote the shared piece into `mid` or `core` of the main `mizchi/bit`
  module.

## Multi-module workspace

The main `mizchi/bit` module is kept focused on Git plumbing/porcelain. All
non-Git extensions are extracted into their own MoonBit modules under
`modules/`, so a consumer can pull in only the features they need. This
mirrors gitoxide's split between `gix-*` plumbing crates and feature-specific
crates.

The repo root has a `moon.work` file listing every workspace member. When
`moon build` resolves dependencies it picks the listed members up locally
instead of from `mooncakes.io`. The naming convention is `bitx_<feature>`
(underscore-separated, single underscore-prefixed segment per feature).

### Cross-module dependencies

`mizchi/bit` declares each `bitx_*` it consumes (via `cmd/*`) in its
`moon.mod.json` `deps`. Each `bitx_*` module declares `mizchi/bit` in its
own `deps` when it needs core types. MoonBit's workspace resolver allows
this module-level cycle because the in-package dependency graph remains
acyclic.

### How to add a new extracted module

1. Create `modules/bitx_<name>/moon.mod.json` with `"name":
   "mizchi/bitx_<name>"` and the minimum `deps` set.
2. Move the package directory under `modules/bitx_<name>/src/` with
   `git mv`.
3. Replace any self-import inside the moved package's `moon.pkg` files
   (e.g. `"mizchi/bit/x-foo"` → `"mizchi/bitx_foo"`).
4. Add the new directory to `moon.work`'s `members`.
5. For every consumer in `mizchi/bit` (typically `cmd/*`), update the
   `moon.pkg` import path and add the new module to the root
   `moon.mod.json`'s `deps`.
6. Update this document and any references in `Taskfile.pkl`.
7. Run `moon check` and `moon test --target native -p mizchi/bitx_<name>`
   to confirm the move is clean.
