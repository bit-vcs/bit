# Vendored `mizchi/x@0.7.0` (patched)

Upstream: https://github.com/mizchi/x (Apache-2.0, see `LICENSE`).

`mizchi/x@0.7.0` is the latest published release, but it no longer builds on
MoonBit v0.10.21 (`moonc v0.10.21+06da1ed44`): core's `async/pipe` became
internal (`Cannot find import 'moonbitlang/core/async/pipe'`) and the core
async reader/writer, socket, fs and tls APIs changed.

This copy is the port proposed upstream in
https://github.com/mizchi/x/pull/9 (`moon.mod`, `LICENSE`, `README.md` and
`src/` of that branch). It is listed as a member of the root `moon.work`, so
it overrides the registry package for every module that imports
`mizchi/x@0.7.0`.

Drop this directory (and its `moon.work` entry) once upstream publishes a
release that builds on the current toolchain, and bump the `mizchi/x`
imports to it.
