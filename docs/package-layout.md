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

Single facade package. May depend on `core/*` and `mid/*`. Used by `cmd/*` and
`x-*` as a convenience surface.

| Package           | Path       | Notes                                          |
|-------------------|------------|------------------------------------------------|
| `mizchi/bit/lib`  | `src/lib`  | High-level / backward-compatible facade        |

### x-* (extensions, gitoxide にはない bit 独自機能)

Optional features. Each `x-*` package is independent and must not depend on
other `x-*` packages, with two exceptions documented under "Shared
infrastructure" below. May depend on `core/*`, `mid/*`, and `lib`.

| Package                          | Path                      | Description                  |
|----------------------------------|---------------------------|------------------------------|
| `mizchi/bit/x-hub`               | `src/x-hub`               | Local PR / Issue metadata    |
| `mizchi/bit/x-hub/crypto`        | `src/x-hub/crypto`        | Hub signing primitives       |
| `mizchi/bit/x-hub/native`        | `src/x-hub/native`        | Hub native bindings          |
| `mizchi/bit/x-kv`                | `src/x-kv`                | Git-backed KV store          |
| `mizchi/bit/x-kv/native`         | `src/x-kv/native`         | KV native sync               |
| `mizchi/bit/x-fs`                | `src/x-fs`                | Virtual FS over commits      |
| `mizchi/bit/x-mcp`               | `src/x-mcp`               | MCP server                   |
| `mizchi/bit/x-mcp/cmd`           | `src/x-mcp/cmd`           | Standalone MCP entry point   |
| `mizchi/bit/x-hq`                | `src/x-hq`                | `ghq`-compatible repo mgr    |
| `mizchi/bit/x-rebase-ai`         | `src/x-rebase-ai`         | AI rebase helpers            |
| `mizchi/bit/x-subdir`            | `src/x-subdir`            | Subdirectory clone           |
| `mizchi/bit/x-fingerprint`       | `src/x-fingerprint`       | Workspace fingerprint        |
| `mizchi/bit/x-workspace`         | `src/x-workspace`         | Workspace flow               |
| `mizchi/bit/x-bitconfig`         | `src/x-bitconfig`         | bit-specific config          |
| `mizchi/bit/x-doc`               | `src/x-doc`               | Doc rendering                |

### cmd (binaries)

CLI entry points. May depend on any layer.

| Package                  | Path             | Notes                                  |
|--------------------------|------------------|----------------------------------------|
| `mizchi/bit/cmd/bit`     | `src/cmd/bit`    | Main `bit` CLI                         |
| `mizchi/bit/cmd/git-bit` | `src/cmd/git-bit`| `git-bit` shim CLI                     |

## Allowed dependency directions

Each layer may import from itself and lower layers only:

| From    | core | mid | high (lib) | x-*  | cmd  |
|---------|:----:|:---:|:----------:|:----:|:----:|
| core    | ✓    |     |            |      |      |
| mid     | ✓    | ✓   |            |      |      |
| high    | ✓    | ✓   | ✓          |      |      |
| x-*     | ✓    | ✓   | ✓          | (1)  |      |
| cmd     | ✓    | ✓   | ✓          | ✓    | ✓    |

(1) An `x-*` package must not import another `x-*` package, with the exception
of the shared-infrastructure packages listed below.

## Shared infrastructure (`EXT_SHARED`)

Two `x-*` packages currently sit between `mid` and `ext`. Other `x-*` packages
and `lib` are permitted to depend on them. They are tracked here so the lint
allowlist matches the docs:

| Package                     | Used by                                            |
|-----------------------------|----------------------------------------------------|
| `mizchi/bit/x-fs`           | `lib`, `x-kv`, `x-kv/native`, `x-subdir`           |
| `mizchi/bit/x-fingerprint`  | `x-workspace`                                      |

Future work: promote these into the `mid` (or `core`) layer so the `ext`
boundary becomes strictly leaf-only. The corresponding allowlist lives in
`tools/check-layers.mjs` (`EXT_SHARED`).

## Lint

Run `node tools/check-layers.mjs` to validate the dependency graph against the
rules above. CI runs the same script.

## Policy

- New low-level functionality lands directly in `core/*`.
- `lib` (high) is a thin facade. Do not put new logic into `lib`; instead, add
  it to a focused `core/*` or `mid/*` package and re-export through `lib` if
  callers need the convenience.
- `x-*` packages are independent. If two `x-*` packages need to share code,
  promote the shared piece into `mid` or `core`.
