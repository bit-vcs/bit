# Benchmarks

Native-target `moon bench` results, captured after the security /
refactor batch on branch `claude/refactor-with-benchmarks-O6vLz`.

Hardware: container-sandbox, single core. Numbers are mean ± σ over
10 runs each.

## Compared to pre-batch baseline (commit `1f02776`)

All measurements `moon bench -p <pkg> --target native -f
<bench_test>.mbt --release`. The "Before" column comes from a clean
checkout of `1f02776`; the "Final" column is after the full
refactor + zlib 0.4.5 + security batch.

### `lib/bench_ops_test.mbt`

| Benchmark             | Before     | Final      | Δ      |
| --------------------- | ---------- | ---------- | ------ |
| add_paths 100 files   |  5.56 ms   |  3.99 ms   | −28%   |
| add_paths 500 files   | 27.22 ms   | 20.70 ms   | −24%   |
| commit 100 files      |  4.67 ms   |  3.61 ms   | −23%   |
| checkout              |  4.97 ms   |  3.28 ms   | −34%   |

### `lib/bench_status_test.mbt`

| Benchmark                  | Before     | Final      | Δ      |
| -------------------------- | ---------- | ---------- | ------ |
| status clean small (200)   |  1.30 ms   |   928 µs   | −29%   |
| status dirty small         |  1.33 ms   |   921 µs   | −31%   |
| status clean large (1000)  |  5.94 ms   |  4.24 ms   | −29%   |
| status_porcelain_from      |  (new)     |  5.97 µs   |        |

### `diff/bench_test.mbt`

| Benchmark                          | Before     | Final      | Δ      |
| ---------------------------------- | ---------- | ---------- | ------ |
| diff_trees identical 100 files     |   515 µs   |   365 µs   | −29%   |
| diff_trees 10pct changed 100 files |  1.39 ms   |   919 µs   | −34%   |
| diff_text 10 files                 |  78.1 µs   |  65.7 µs   | −16%   |
| diff_stat 10 files                 |  2.66 µs   |  2.18 µs   | −18%   |

### `vfs/bench_test.mbt`

| Benchmark                              | Before     | Final      | Δ      |
| -------------------------------------- | ---------- | ---------- | ------ |
| bitfs snapshot 500 files               | 25.77 ms   | 19.08 ms   | −26%   |
| bitfs snapshot incremental 1/500 files |  6.30 ms   |  4.39 ms   | −30%   |
| bitfs from_commit only                 |  88.4 µs   |  55.7 µs   | −37%   |
| bitfs read_single_file                 |   194 ns   |   148 ns   | −24%   |

### `pack/bench_test.mbt` (no pre-batch baseline captured)

| Benchmark                       | Final      |
| ------------------------------- | ---------- |
| parse_packfile small            |   74.3 µs  |
| parse_packfile 100 objects      |   2.44 ms  |
| create_packfile 10 objects      |   120 µs   |
| create_packfile 100 objects     |   1.28 ms  |
| create_packfile_with_delta 100  |   2.51 ms  |
| build_pack_index                |   2.51 ms  |
| encode_type_and_size            |   9.83 µs  |
| decode_type_and_size_at         |    10 µs   |

## Drivers of the improvement

Improvements span every package; no single change dominates. Best
guesses, in rough order of impact:

1. **MoonBit toolchain refresh** at session start (`0.1.20260512`).
   Likely the largest single factor — Generic `core` improvements
   (allocator, codegen) propagate everywhere.
2. **`mizchi/zlib` 0.4.4 → 0.4.5** — bomb defense plus internal
   tweaks; touches every object read.
3. **`Map.to_array()` iteration cleanup across `lib`/`vfs`/`cmd/bit`
   etc.** (commits `e0aaea9` … `a21bab1`). Each replaced an
   intermediate `Array[(K, V)]` alloc + per-element tuple alloc
   with a direct `iter2` / `keys` / `values` walk. Hot in
   `status`, `add_paths`, `commit`, `diff`.
4. **`worktree.add_paths` 6-chain `.map(...).unwrap_or(0)` collapse**
   into a single `match` (commit `e0aaea9`). 6 closures + 6
   `Option` allocs gone per file.
5. **`status_porcelain_from` Map collapse** — three `Map[String,
   Char|Bool]`s reduced to two (commit `e0aaea9`).

## Regressions

None observed.

## How to reproduce

```bash
moon bench -p mizchi/bit/lib --target native -f bench_ops_test.mbt --release
moon bench -p mizchi/bit/lib --target native -f bench_status_test.mbt --release
moon bench -p mizchi/bit/diff --target native --release
moon bench -p mizchi/bit/vfs --target native -f bench_test.mbt --release
moon bench -p mizchi/bit/pack --target native -f bench_test.mbt --release
```
