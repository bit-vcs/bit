# Pure Implementation Plan (gitoxide-style modularization)

## Purpose

- Make all modules except CLI **run purely across all targets (js/wasm/wasm-gc/native)**.
- Narrow dependency boundaries to **minimal interfaces**, adopting a gitoxide-style modular structure.
- `bit/x/fs` **aims to be target-agnostic** (do not assume native-only even if it currently appears so).

---

## Assumptions (reflecting the bitfs plan)

- `bit/x/fs` targets being **target-agnostic** as a Git-optimized FS.
- In Moonix, adapters will be provided to conform `RepoFileSystem` / `FileSystem`.
- WASI / native dependencies are confined to the adapter side; bitfs prioritizes Git compatibility.

---

## Target Architecture (gitoxide-style)

### Pure Core (no IO)

- `bit/core/object` : parse/serialize for blob/tree/commit/tag
- `bit/core/pack` : packfile read/write and delta
- `bit/core/refs` : ref resolution, packed-refs
- `bit/core/revwalk` : DAG walk
- `bit/core/index` : index read/write
- `bit/core/protocol` : upload-pack / receive-pack messages

### Minimal Interfaces (lib boundary)

Design so that core depends only on the following.

```
ObjectStore:
  get(id) -> GitObject?
  put(obj_type, bytes) -> ObjectId
  has(id) -> Bool

RefStore:
  resolve(ref_name) -> ObjectId?
  update(ref_name, id) -> Unit
  list(prefix) -> Array[String]

Clock:
  now() -> Int64

Random:
  short() -> String

Transport:
  fetch(remote, wants) -> Pack
  push(remote, updates) -> Result
```

Note: Worktree / OS / HTTP / process are not placed in core.

---

## Adapters (CLI / runtime-specific)

Following the bitfs plan, runtime-dependent implementations are confined to adapters.

- `bit/adapters/bitfs_native` : ObjectStore/RefStore implementation (as needed)
- `bit/adapters/transport_http_native`
- `bit/adapters/transport_process_native`
- `bit/adapters/clock_native`
- `bit/adapters/random_native`

The CLI (`cmd/bit`) assembles these and injects them into core.

---

## Dependency Graph (target)

```
core (pure)
  ↑
lib (pure: traits + algorithms)
  ↑
x/hub (pure) / x/kv (pure)
  ↑
adapters/bitfs_native (native-only)
  ↑
cmd/bit (native-only)
```

`bit/x/fs` remains pure / target-agnostic as much as possible.

---

## Concrete Migration Steps

### Step 1: Abstract the lib API boundary

- Add **trait/record definitions** to `src/lib` (`ObjectStore`, `RefStore`, `Transport`, `Clock`, `Random`).
- Add `EnvProvider` to make environment variable / current directory retrieval **injectable**.
- Remove native imports from `src/lib/moon.pkg`:
  - `moonbitlang/async/process`
  - `moonbitlang/x/sys`
  - `moonbitlang/core/env`
  - `moonbitlang/async/http`
  - `moonbitlang/async/fs` to be removed after abstracting `worktree` / `gitignore`
- Move native-specific implementations to `src/lib/native`.

### Step 2: Make `x/hub` pure

- Make `HubStore` depend only on `ObjectStore + RefStore + Clock`.
- Have the notes backend operate via refs/objects.

### Step 2.5: Abstract async/fs dependencies in `worktree` / `gitignore`

- Move `worktree_probe` and `list_working_files` to the target-dependent layer.
- Confine OS-dependent aspects like cache/mtime to the adapter side.

### Step 3: Make `x/kv` pure

- Remove `x/fs` dependency; generate commits using only `ObjectStore + TreeBuilder`.
- Implement sync/merge as pure tree operations.

### Step 4: Split transport into pure/impure

- Consolidate protocol (pack format / msg) as pure.
- http/process become adapters.

---

## Priority

1. Abstracting the lib boundary (minimal interface definitions)
2. Making x/hub pure
3. Making x/kv pure
4. Separating transport

---

## Risks and Considerations

- Code depending on `bit/x/fs` **must not be placed on the pure side**.
- `ObjectStore` responsibilities are **limited to minimal Git object read/write**.
- Additional IO requirements are **confined to adapters**.

---

## Verification Strategy

- core: Run existing tests on JS/wasm
- adapter: native tests only
- CLI: e2e on native only

---

## Notes

This plan is designed to align with the policy in `../mizchi/moonix/docs/bitfs.md`.
