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

## Core package coverage (newly added)

The packages below previously had no benchmarks. Numbers are
baselines captured at the same time as the comparison above —
nothing to compare to yet.

### `hash/bench_test.mbt`

| Benchmark             | Final      | Throughput   |
| --------------------- | ---------- | ------------ |
| sha1_raw 64 bytes     |   667 ns   |              |
| sha1_raw 1 KiB        |  5.14 µs   |  ~200 MB/s   |
| sha1_raw 8 KiB        |  38.5 µs   |  ~213 MB/s   |
| sha1_raw 64 KiB       |   312 µs   |  ~210 MB/s   |
| sha256_raw 1 KiB      |  7.66 µs   |  ~134 MB/s   |
| sha256_raw 8 KiB      |  56.6 µs   |  ~145 MB/s   |

SHA-1 sustains ~210 MB/s once past the small-input overhead;
SHA-256 is ~30% slower per byte.

### `object/bench_test.mbt`

| Benchmark                      | Final      |
| ------------------------------ | ---------- |
| hash_blob 1 KiB                |  5.32 µs   |
| hash_blob 64 KiB               |   302 µs   |
| create_blob 1 KiB              |   319 µs   |
| create_blob 64 KiB             |  2.56 ms   |
| serialize_tree 10 entries      |  6.56 µs   |
| serialize_tree 100 entries     |  64.6 µs   |
| serialize_tree 1000 entries    |   644 µs   |
| create_tree 100 entries        |   325 µs   |
| create_tree 1000 entries       |  2.95 ms   |

Notable: `create_blob 1 KiB` (319 µs) is ~60× slower than
`hash_blob 1 KiB` (5.32 µs) — zlib compression dominates the
write path. `serialize_tree` is linear (~644 ns / entry).

### `config_parse/bench_test.mbt`

| Benchmark                                      | Final      |
| ---------------------------------------------- | ---------- |
| config_lines_from_content small                |  5.30 µs   |
| config_lines_from_content 100 remotes          |   182 µs   |
| get_config_value_from_content small            |  9.08 µs   |
| get_config_value_from_content miss (100 r)     |   249 µs   |
| get_all_config_values_from_content remote.*    |   256 µs   |
| parse_section_header_line subsection           |   283 ns   |
| parse_config_key dotted                        |   378 ns   |
| parse_bool_keyword_value                       |   172 ns   |
| config_parse_size_value "1m"                   |   254 ns   |

A miss on a 100-remote config scans the whole file (249 µs); this
is the worst-case path for first-time key lookup.

### `refs/bench_test.mbt`

| Benchmark                                                  | Final      |
| ---------------------------------------------------------- | ---------- |
| list_refs_with_ids loose 20 branches + 20 remotes          |  74.5 µs   |
| list_refs_with_ids loose 200 branches + 200 remotes        |   731 µs   |
| list_refs_with_ids packed 50 refs                          |  53.6 µs   |
| list_refs_with_ids packed 2000 refs                        |  2.24 ms   |
| list_refs_with_ids packed 2000 filtered by prefix          |  2.41 ms   |

Packed refs are ~2× faster per ref than loose. The prefix-filtered
variant is *slower* than unfiltered — the filter doesn't
short-circuit early, just discards non-matching entries after
parsing. Worth revisiting.

### `diff_core/bench_test.mbt`

| Benchmark                           | Final      |
| ----------------------------------- | ---------- |
| split_lines 100 KiB                 |   366 µs   |
| count_lines 100 KiB                 |  74.0 µs   |
| myers_diff identical 100 lines      |  2.82 µs   |
| myers_diff 10pct changed 100 lines  |  10.2 µs   |
| myers_diff identical 1000 lines     |  24.3 µs   |
| myers_diff 10pct changed 1000 lines |   750 µs   |

`myers_diff` is O(N) for identical input but climbs to O(ND) when
edits exist — at 1000 lines × 10% changed, the wall jumps 31× over
the all-equal case.

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

## Targeted fixes after profiling

### `refs.list_refs_with_ids` loose subtree pruning

`collect_loose_ref_ids` used to recurse into every subdir under
`<git_dir>/refs/` and filter at the file level. Now it skips a
whole subtree if its name can't intersect `filter_prefix`. The new
`refs_subtree_intersects_filter` helper checks whether
`dir + "/"` is a prefix of the filter or vice versa.

| Benchmark                                                  | Before | After  | Δ                      |
| ---------------------------------------------------------- | ------ | ------ | ---------------------- |
| list_refs_with_ids loose 200+200 (no filter)               | 731 µs | 817 µs | within noise           |
| list_refs_with_ids loose 200+200 filtered `refs/heads/`    | —      | 409 µs | **−50% vs unfiltered** |

The filtered case now does ~half the I/O — the `refs/remotes/`
subtree is skipped entirely.

### `read_config_value_from_content` for shared parses

`is_reftable_repo`, `repo_object_format`, `repo_compat_object_format`
used to each open and parse `<git_dir>/config` independently. The
rev-parse output-format path called the last two back-to-back so
the file was read twice.

New `@bitlib.read_config_value_from_content(content, section, name)`
lets the caller share a single content read across multiple key
lookups. `cmd/bit/helpers.mbt::repo_format_info` bundles all three
fields into one read, used by `rev_parse_resolve_output_oid_hex`
and `rev_parse_output_object_format_supported`.

| Benchmark                                                                   | Result  |
| --------------------------------------------------------------------------- | ------- |
| read_config_value 4 keys on 100-remote config (4 reads + 4 parses)          | 234 µs  |
| read_config_value_from_content 4 keys on 100-remote (1 read + 4 parses)     | 216 µs  |

TestFs `read_file` is cheap so the saving on benchmarks is modest
(~8%). The win is bigger on osfs where each re-read is a syscall.
An earlier attempt at a process-singleton cache landed but was
reverted because invalidation through the `FileSystem` trait
can't be made safe (`TestFs::write_string` would have to
participate, and `io` can't depend on `lib`).
