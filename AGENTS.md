# Repository Conventions

## Package layering

`src/` is organized into layers: **core → mid → high → ext → cmd**. Dependencies
flow only downward. See [`docs/package-layout.md`](docs/package-layout.md) for
the package-by-package classification.

Run `node tools/check-layers.mjs` to validate the dependency graph.
