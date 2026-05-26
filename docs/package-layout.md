# Package Layout

`mizchi/bit` is a single MoonBit module (`moon.mod.json`), but its packages are
organized into a layered structure inspired by [gitoxide]'s `gix-*` plumbing /
`gix` porcelain / `gitoxide` CLI split.

[gitoxide]: https://github.com/Byron/gitoxide

## Layers

```
cmd ─→ x-* ─→ lib (high) ─→ mid ─→ core
              x-* ─→ mid ─→ core           (x-* may bypass `lib`)
```

Dependencies must flow only in one direction. A package in a lower layer must
never import a package from a higher layer.

### core (gitoxide `gix-*` plumbing 相当)

Single-purpose, low-level packages. Each package is responsible for one Git
primitive and may only depend on other `core/*` packages it strictly needs.

| Package                       | Path                  | gitoxide analogue                  |
|-------------------------------|-----------------------|------------------------------------|
| `mizchi/bit/types`            | `src/types`           | (shared types)                     |
| `mizchi/bit/hash`             | `src/hash`            | `gix-hash`                         |
| `mizchi/bit/date_parse`       | `src/date_parse`      | `gix-date`                         |
| `mizchi/bit/string_utils`     | `src/string_utils`    | `gix-utils`, `gix-quote`           |
| `mizchi/bit/config_parse`     | `src/config_parse`    | `gix-config`                       |
| `mizchi/bit/object`           | `src/object`          | `gix-object`                       |
| `mizchi/bit/trailers`         | `src/trailers`        | `gix-trailers`                     |
| `mizchi/bit/ignore`           | `src/ignore`          | `gix-ignore` + `gix-glob`          |
| `mizchi/bit/tar`              | `src/tar`             | `gix-archive`                      |
| `mizchi/bit/diff_core`        | `src/diff_core`       | `gix-diff` (low-level)             |
| `mizchi/bit/diff3`            | `src/diff3`           | `gix-merge` (low-level)            |
| `mizchi/bit/apply`            | `src/apply`           | (patch application)                |
| `mizchi/bit/fast_import`      | `src/fast_import`     | (fast-import stream)               |
| `mizchi/bit/grep`             | `src/grep`            | (grep engine)                      |
| `mizchi/bit/io`               | `src/io`              | `gix-fs` (abstract)                |
| `mizchi/bit/io/native`        | `src/io/native`       | `gix-fs` (native bindings)         |
| `mizchi/bit/osfs`             | `src/osfs`            | `gix-fs` (OS-backed impl)          |
| `mizchi/bit/pack`             | `src/pack`            | `gix-pack`                         |
| `mizchi/bit/refs`             | `src/refs`            | `gix-ref`                          |
| `mizchi/bit/reftable`         | `src/reftable`        | (reftable backend)                 |
| `mizchi/bit/protocol`         | `src/protocol`        | `gix-protocol`/`gix-transport`     |
| `mizchi/bit/runtime`          | `src/runtime`         | (runtime helpers)                  |
| `mizchi/bit/bootstrap`        | `src/bootstrap`       | (bootstrap helpers)                |

### mid (gitoxide `gitoxide-core` 相当)

Operations layered on top of `core/*`. May depend on `core/*` only.

| Package                  | Path             | Notes                                |
|--------------------------|------------------|--------------------------------------|
| `mizchi/bit/repo`        | `src/repo`       | Repository handle / materialization  |
| `mizchi/bit/repo_ops`    | `src/repo_ops`   | Repository-level operations          |
| `mizchi/bit/pack_ops`    | `src/pack_ops`   | `collect_reachable_objects`, etc.    |
| `mizchi/bit/remote`      | `src/remote`     | URL / shorthand / `.git` discovery   |
| `mizchi/bit/worktree`    | `src/worktree`   | status / add / commit / rm / mv      |
| `mizchi/bit/diff`        | `src/diff`       | High-level diff / show               |

### high (gitoxide `gix` porcelain 相当)

Porcelain layer. May depend on `core/*` and `mid/*`. Used by `cmd/*` and
`x-*` as a convenience surface.

| Package                       | Path               | Notes                                              |
|-------------------------------|--------------------|----------------------------------------------------|
| `mizchi/bit/lib`              | `src/lib`          | High-level / backward-compatible facade            |
| `mizchi/bit/vfs`              | `src/vfs`          | Virtual FS over commits (used by `lib`, `x-kv`, `x-subdir`) |
| `mizchi/bit/fingerprint`      | `src/fingerprint`  | Workspace fingerprint (used by `x-workspace`)      |

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
| `mizchi/bit/cmd/bit`     | `src/cmd/bit`    | Main `bit` CLI                         |
| `mizchi/bit/cmd/git-bit` | `src/cmd/git-bit`| `git-bit` shim CLI                     |

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
