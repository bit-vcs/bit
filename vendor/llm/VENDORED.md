# Vendored `mizchi/llm@0.3.2`

Upstream: https://github.com/mizchi/llm (MIT, see `LICENSE`).

`mizchi/llm@0.3.2` is the latest published release, but it no longer compiles
on current MoonBit toolchains (`moonc v0.10.20+`), which removed method-call
syntax for `ToJson` on builtin types (`"s".to_json()` → error 4015).

This copy is listed as a member of the root `moon.work`, so it overrides the
registry package for every module that imports `mizchi/llm@0.3.2`
(`modules/bit`, `modules/bitx_rebase_ai`).

Local changes from the published 0.3.2:

- `x.to_json()` on builtin types rewritten to `ToJson::to_json(x)`.
- Dependency floors bumped to match the workspace (`mizchi/x`), and the
  `moonbitlang/async` dependency replaced by the bundled `moonbitlang/core/async`.
- Each `moon.pkg` sets `warnings = "-25-29-79"` so upstream style/deprecation
  warnings don't fail the repo's `moon check --deny-warn` lint.
- `justfile` dropped.

Drop this directory (and its `moon.work` entry) once upstream publishes a
release that builds on the current toolchain.
