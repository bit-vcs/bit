# Package Layout (WIP)

Notes for incrementally migrating `src/` into responsibility-based packages so that only the needed functionality is imported.

## Current Split

- `mizchi/bit/remote`
  - Local/remote-helper URL resolution
  - `.git` file resolution (`resolve_gitdir`)
  - bare/worktree detection (`detect_git_dir`)
  - Shorthand parsing for `user/repo`, `user/repo:path`, `@ref`, etc.
  - Shorthand and local directory collision detection
- `mizchi/bit/refs`
  - Enumeration of loose refs / packed-refs
  - Rewriting packed-refs, cleaning up remote tracking refs
- `mizchi/bit/pack_ops`
  - Entry point for pack object collection APIs (`collect_reachable_objects`, etc.)
- `mizchi/bit/worktree`
  - Entry point for worktree operation APIs such as status/add/commit/rm/mv

A backward-compatible facade is kept in `mizchi/bit/lib`, so existing call sites continue to work as-is.

## Policy

- New implementations go into feature-specific packages first
- `lib` is kept as a thin compatibility facade
- Call sites directly import the feature package as needed

This policy makes it easier to minimize dependencies per command/binary in the future.
