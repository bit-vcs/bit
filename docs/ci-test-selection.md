# CI test selection (affected-only runs)

CI runtime was dominated by running everything on every PR: all 43 workspace
modules' native tests, 7 cmd-shard jobs, and 10 git-compat shards that each
build real git from source and run the full ~900-test allowlist. Since v0.45.0
CI only runs what a change can affect; the full matrix is reserved for the
pre-release check.

## How selection works

`tools/select-affected-tests.mjs` computes the test set for a diff:

1. **Changed files** come from `git diff --name-only <base>...HEAD`
   (PRs: the PR base; main pushes: the previous tip).
2. **Moon targets** — the changed files' modules are expanded through the
   reverse dependency closure of the workspace graph (parsed from `moon.work`
   + each module's `moon.mod`), so a change to `bit_diff_core` also re-tests
   `bit_diff` and the CLI. `modules/bit` in the closure enables the cmd-shard
   jobs.
3. **git-compat suites** — changed paths map to suites through
   `tools/flaker-affected-rules.mjs`:
   - module-level rules (`modules/bit_pack/** → t53*` etc.); foundational
     modules (bit_core, bit_object, IO, …) map to the full suite;
   - file-level rules carve command areas out of the two kitchen-sink
     packages (`modules/bit/cmd/bit/*.mbt`, `modules/bit_lib/src/*.mbt`);
   - `bitx_*` modules map to no git suites (bit-specific features).
4. **Safety nets** — infrastructure changes (`moon.work`, `Taskfile.pkl`,
   `.github/**`, `third_party/**`, the selector itself, …) and any
   `modules/**` file that no rule knows about escalate to a **full run**.
   An incomplete map over-tests; it never under-tests.

The map is additive: a file selects the union of every rule it matches.
`tools/flaker-affected-rules.toml` (used by flaker) is generated from the
`.mjs` — regenerate with:

```bash
node tools/flaker-affected-rules.mjs > tools/flaker-affected-rules.toml
```

## In CI

`.github/workflows/ci.yml` starts with a `select` job; the other jobs consume
its outputs:

| Job | Gate |
|---|---|
| `test` (module native + js/wasm) | affected moon targets only; js/wasm steps keyed by module |
| `cmd-native-test` (7 shards) | only when `modules/bit` is in the closure |
| `distributed-test` | only for `bitx_hub` / `bitx_kv` changes |
| `nix-build` | any module change |
| `git-compat` (10 shards) | selected suites only; shards with no tests skip before building git |

The per-shard pass-count regression floor only applies to full runs — an
absolute baseline is meaningless for a subset.

## Full runs (pre-release check)

The full matrix runs when:

- **`workflow_dispatch`** — trigger CI manually from the Actions tab before
  cutting a release; or
- a **`v*` tag** is pushed (backstop so a release never ships untested).

Release procedure: run the dispatch full check on main, confirm green, then
tag.

## Local usage

```bash
pkf run test:affected               # show what CI would run for your branch
node tools/select-affected-tests.mjs --changed modules/bit_diff/src/myers.mbt
node tools/select-affected-tests.mjs --base origin/main --json
```

## Maintaining the map

- New module → add a rule in `tools/flaker-affected-rules.mjs` (or accept
  that its changes trigger full runs via the safety net), regenerate the
  toml, and extend `tools/select-affected-tests.test.mjs`.
- New `cmd/bit` or `bit_lib` file → covered by existing globs where the name
  matches (`merge*.mbt`, …); otherwise the safety net escalates to full until
  a rule is added.
- Rules tests: `node --test tools/flaker-affected-rules.test.mjs tools/select-affected-tests.test.mjs`.
