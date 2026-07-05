# Repository Conventions

## Package layering

`src/` is organized into layers: **core → mid → high → ext → cmd**. Dependencies
flow only downward. See [`docs/package-layout.md`](docs/package-layout.md) for
the package-by-package classification.

Run `node tools/check-layers.mjs` to validate the dependency graph.

## Native builds

`moon test --target native` runs its test drivers through the bundled
`tcc -run`, which can crash in some environments. `MOONBIT_NEW_NATIVE=1`
selects moonc's newer native backend, which routes native builds through the
system `cc`/`clang` driver instead — slower to compile, but stable. That flag
only takes effect from toolchain `0.1.20260629` onward (it is inert on older
releases such as `0.1.20260608`).

`MOONBIT_NEW_NATIVE=1` is set in
[`.claude/settings.json`](.claude/settings.json), and the SessionStart hook
[`.claude/hooks/session-start.sh`](.claude/hooks/session-start.sh) upgrades the
toolchain to the latest release when it is older than that, so Claude Code web
sessions get a working native backend automatically. `moon build --target
native --release` (the `bit.exe` binary) already uses `cc`, so it is
unaffected.
