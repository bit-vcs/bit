# Repository Conventions

## Package layering

`src/` is organized into layers: **core → mid → high → ext → cmd**. Dependencies
flow only downward. See [`docs/package-layout.md`](docs/package-layout.md) for
the package-by-package classification.

Run `node tools/check-layers.mjs` to validate the dependency graph.

## MoonBit toolchain

CI, the dev shell (`nix develop`) and the nix build all use the flake's
`moonbit` package, pinned through `moonbit-overlay` in `flake.lock`
(`.github/actions/setup-moonbit` installs it with Nix). Claude Code web
sessions can't evaluate the flake, so the SessionStart hook
[`.claude/hooks/session-start.sh`](.claude/hooks/session-start.sh) reads the
same version from the locked `moonbit-overlay` revision and installs that
release with the official installer. To move to a newer MoonBit, run
`nix flake update moonbit-overlay`.

## Native builds

`moon test --target native` runs its test drivers through the bundled
`tcc -run`, which can crash in some environments. `MOONBIT_NEW_NATIVE=1`
selects moonc's newer native backend, which routes native builds through the
system `cc`/`clang` driver instead — slower to compile, but stable. That flag
only takes effect from toolchain `0.1.20260629` onward (it is inert on older
releases such as `0.1.20260608`).

`MOONBIT_NEW_NATIVE=1` is set in
[`.claude/settings.json`](.claude/settings.json), and the toolchain the
SessionStart hook installs from `flake.lock` is newer than that, so Claude
Code web sessions get a working native backend automatically (if the pin
can't be resolved, the hook falls back to upgrading a too-old toolchain to the
latest release). `moon build --target
native --release` (the `bit.exe` binary) already uses `cc`, so it is
unaffected.

On toolchain `0.10.13` the debug build of `modules/bit` (`moon build --target
native modules/bit`, and `moon test` on `cmd/bit`) makes moonc's link-core pass
overflow the default 8 MiB stack and abort with an ICE (`Error: Stack
overflow`). Run `ulimit -s unlimited` first; the release build is unaffected.
