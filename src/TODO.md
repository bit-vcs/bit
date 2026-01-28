# TODO (git)

## Testing strategy: use git as oracle

- Generate packfiles with git CLI and verify with git tools; use these outputs as fixtures.
- Prefer reproducible commands and document them alongside tests.

### Packfile oracle flow

1) Create fixtures with git
- `git pack-objects --stdout` (or `git pack-objects --stdout < objects.txt`) to produce `.pack`.
- `git index-pack` and `git verify-pack -v` to validate pack integrity.

2) Use git-generated values in tests
- `git hash-object --stdin` for blob SHA-1s.
- `git write-tree` / `git commit-tree` for tree/commit IDs and contents.

3) Cover edge cases by letting git create them
- Large objects (multi zlib stored blocks).
- Delta objects (`--delta`), thin packs, and offset deltas.
- Mixed object types and sizes around varint boundaries.

### Current limitations

- SSH/file transport uses `git-upload-pack --stateless-rpc` via ProcessManager and requires a real native backend (not provided by MemfsBackend).
- HTTP upload-pack implemented only for wasm targets.

### Fixture format

- Store small fixtures as hex strings in tests (see integration tests).
- For large fixtures, keep `.pack` files under `src/git/fixtures/` (git LFS if needed).
- Always keep the exact git commands used to generate each fixture.
