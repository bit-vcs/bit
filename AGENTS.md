# Repository Conventions

## Package layering

`src/` is organized into layers: **core → mid → high → ext → cmd**. Dependencies
flow only downward. See [`docs/package-layout.md`](docs/package-layout.md) for
the package-by-package classification.

Run `node tools/check-layers.mjs` to validate the dependency graph.

## Native builds

`moon test --target native` runs its test drivers through the bundled
`tcc -run`, which can crash in some environments. Set `MOON_CC=cc` (or any
real `cc`/`clang` driver) to compile and run native tests with the system C
compiler instead — slower to compile, but stable. `MOONBIT_NEW_NATIVE=1`
selects moonc's newer native backend, which likewise requires a real
C compiler/linker driver.

Both are set in [`.claude/settings.json`](.claude/settings.json) so Claude
Code sessions pick them up automatically. `moon build --target native
--release` (the `bit.exe` binary) already uses `cc`, so it is unaffected.
