# Completed Tasks

Archive of completed tasks. Moved from TODO.md.

## Git compatibility (P0)

### Test fixes

- [x] **t6101-rev-parse-parents.sh** — `^@`, `^!`, `^-`, `..`, `...`, `^` negation (2026-03-09)
- [x] **t6002-rev-list-bisect.sh** — `--bisect` default refs (2026-03-08)
- [x] **t1350-config-hooks-path.sh** — `core.hooksPath` support (2026-03-08)
- [x] **t3300-funny-names.sh** — ls-tree C-quoting (2026-03-08)
- [x] **t6018-rev-list-glob.sh** — `--branches/--tags/--remotes/--glob/--all/--exclude` (2026-03-08)
- [x] **t1508-at-combinations.sh** — bare `@{N}`, reflog boundary, empty reflog (2026-03-08)
- [x] **t1503-rev-parse-verify.sh** — quiet flag, dot-separated dates (2026-03-08)
- [x] **t6302-for-each-ref-filter.sh** — `contents:lines=N` signature exclusion (2026-03-08)
- [x] pack-objects repack flag implementation (2026-03-02)
- [x] t1517-outside-repo added to allowlist (2026-03-02)
- [x] Unified known-breakage patches to `!BIT_PACK_OBJECTS` prereq skip approach (2026-03-02)

### pack-objects / repack

- [x] `--unpack-unreachable` implementation (2026-03-03, v0.26.3)
  - Removed `!BIT_PACK_OBJECTS` prereq skip patch for t7700 tests 20/25 (`--filter` already implemented)
  - `--unpack-unreachable=<date>` mtime check (2026-03-03)
- [x] `--help` spec-driven / regression tests / opt-in external loading / shim fallback detection

### pack-objects performance investigation

- [x] Pre-allocate capacity for result Array[Byte] — no effect (2026-03-04)
- [x] Reduce Bytes conversion cost of delta results — no effect (2026-03-04)
- [x] Eliminate zlib double compression — already had "quick upper bound" optimization
- [x] zlib C FFI — rejected (pure MoonBit has higher value)

## Relay / P2P collaboration (P1)

- [x] `bit hub serve` command and relay session clone support (2026-02-21)
- [x] P2P collaboration: bidirectional git, broadcast, work-item sync (2026-02-21)
- [x] relay invite URL with room token (2026-02-21)
- [x] signed relay publish headers (2026-02-21)
- [x] Proxied relay URL detection fix (2026-02-24, PR #16)
- [x] Enabled `bit relay serve` for JS target (2026-02-23)
- [x] SSH clone JS target: documented native-only constraint (2026-03-05)
- [x] Added SSH URL to HTTPS smart URL conversion utility (2026-03-05)
- [x] Applied to JS clone/fetch/pull/push paths (2026-03-05)

## Performance (P2)

- [x] `bit status` index-guided walk: 1860ms → 9ms (2026-02-23, PR #11)
- [x] lazy ObjectDb loading for log/commit (2026-02-22)
- [x] Replaced worktree_entry_meta with single lstat() FFI (2026-02-22)
- [x] Skip tree checkout on checkout -b for same commit (2026-02-22)
- [x] incremental MIDX and worktree stat skip (2026-02-23)
- [x] cat-file: lazy pack loading + `-t` early return (3.1x improvement, 2026-03-04)

## WASM / Cross-platform (P4)

- [x] Added WASM Component Model build (2026-02-22)
- [x] WASM Component implementation for clone/fetch/push network operations (2026-02-22)
- [x] Extracted cross-platform crypto package (2026-02-22)

## Platform / Future tasks (P5)

- [x] `~/.config/bit/bitconfig.toml` config file support (2026-02-23)
- [x] `bit hub` → `bit pr`/`bit issue`/`bit debug` reorganization (2026-02-23)
- [x] `bit hooks` management and safe execution (2026-02-17)
- [x] hook approval flow: `.bit/hooks` ↔ `.git/hooks` (2026-02-17)
- [x] `bit hub issue watch` daemon with WebSocket/poll fallback (2026-02-23)
- [x] AI command suite improvements (rebase-ai integration, 2026-02-18)
- [x] Added `x/doc` command (2026-02-20)
- [x] SSH clone: native interactive protocol implementation (2026-02-24, PR #17)
