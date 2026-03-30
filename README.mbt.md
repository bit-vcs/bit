# bit

Git implementation in [MoonBit](https://docs.moonbitlang.com) with practical compatibility extensions and a built-in local GitHub-like collaboration layer.

> **Warning**: This is an experimental implementation. Do not use in production. Data corruption may occur in worst case scenarios. Always keep backups of important repositories.

## Install

**Supported platforms**: Linux x64, macOS arm64/x64

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/mizchi/bit-vcs/main/install.sh | bash

# Or install via MoonBit toolchain
moon install mizchi/bit/cmd/bit
```

## Subdirectory Clone

Clone subdirectories directly from GitHub:

```bash
# Using @user/repo/path shorthand
bit clone mizchi/bit-vcs:src/x/fs

# Or paste GitHub browser URL
bit clone https://github.com/user/repo/tree/main/packages/core

# Single file download
bit clone https://github.com/user/repo/blob/main/README.md
```

Cloned subdirectories have their own `.git` directory. When placed inside another git repository, git automatically treats them as embedded repositories (like submodules) - the parent repo won't commit their contents.

## Standard Git Commands

```bash
bit clone https://github.com/user/repo
bit checkout -b feature
bit add .
bit commit -m "changes"
bit push origin feature
```

## Local Collaboration (`bit issue` / `bit pr`)

`bit issue` and `bit pr` give you a local GitHub-like workflow backed by repository data.
Use them to track work, discuss changes, and merge branches without depending on GitHub/GitLab.
When you want to share metadata across machines or teammates, sync it separately with `bit relay sync`.

```bash
# Initialize PR / Issue metadata once per repository
# `bit pr init` / `bit issue init` ask before creating `.git/hub/policy.toml`
# and before adding `refs/notes/bit-hub` sync settings to `remote.origin.*`.
bit pr init

# Force prompts on/off when scripting
BIT_HUB_INIT_PROMPT=1 bit issue init
BIT_HUB_INIT_PROMPT=0 bit pr init

# Local issues
bit issue create --title "Cache invalidation bug" --body "status view stays stale"
bit issue list --open

# Local pull requests
bit pr create --title "Fix cache invalidation" --body "refresh status after write" \
  --head feature/cache-fix --base main
bit pr list --open
bit pr review <pr-id> --approve --commit <commit-hex>
bit pr merge <pr-id>

# Optional relay sync for PR / Issue metadata
bit relay sync push <remote-url>
bit relay sync fetch <remote-url>
```

## Compatibility

- Hash algorithm: SHA-1 only.
- SHA-256 repositories and `--object-format=sha256` are not supported.
- Git config: reads global aliases from `~/.gitconfig` (or `GIT_CONFIG_GLOBAL`) only.
- Shell aliases (prefixed with `!`) are not supported.

### Implemented Commands (108)

```
init add diff diff-files diff-index ls-files tag branch checkout switch
commit log show reflog reset update-ref update-index status merge rebase
clone push fetch pull mv notes stash rm submodule worktree config show-ref
for-each-ref rev-parse symbolic-ref cherry-pick remote cat-file hash-object
ls-tree write-tree commit-tree receive-pack upload-pack pack-objects
index-pack format-patch describe gc clean sparse-checkout restore blame
grep shell rev-list bisect diff-tree read-tree fsck am apply bundle cherry
revert prune pack-refs mktree shortlog verify-pack unpack-objects
maintenance range-diff show-branch repack multi-pack-index pack-redundant
send-pack request-pull merge-base var stripspace ls-remote fmt-merge-msg
patch-id count-objects name-rev update-server-info check-ref-format mktag
interpret-trailers column merge-tree merge-file fast-import fast-export
verify-tag fetch-pack credential difftool rerere mailinfo archive
check-attr check-ignore show-index get-tar-commit-id verify-commit annotate
```

### Git-Compat Test Results

Validated against upstream git test suite (`third_party/git/t/`) via the shim layer. 908 test files in allowlist.

| Test | Result | Notes |
|------|--------|-------|
| t1300-config | 485/485 | |
| t1450-fsck | 95/95 | |
| t3200-branch | 167/167 | |
| t3206-range-diff | 48/48 | |
| t3500-cherry | 4/4 | |
| t3501-revert-cherry-pick | 21/21 | |
| t3507-cherry-pick-conflict | 44/44 | |
| t4100-apply-stat | 19/19 | all 41 apply tests pass |
| t4150-am | 87/87 | all 11 am tests pass |
| t4201-shortlog | 32/32 | |
| t5300-pack-object | 52/52 | |
| t5304-prune | 32/32 | |
| t5510-fetch | 215/215 | |
| t5607-clone-bundle | 16/16 | all 7 bundle tests pass |
| t6020-bundle-misc | 37/37 | |
| t6101-rev-parse-parents | 38/38 | |
| t6300-for-each-ref | 427/428 | 1 fail: SSH signature |
| t6302-for-each-ref-filter | 62/62 | |
| t7003-filter-branch | 48/48 | |
| t7700-repack | 25/47 | see below |
| t7900-maintenance | 72/72 | |

### Standalone Test Coverage

Standalone coverage is validated with `git_cmd` in `t/test-lib-e2e.sh`, which runs `bit --no-git-fallback ...` (no real-git dependency in these tests). 30/30 pass.

Current standalone integration coverage (`t/t0001-*.sh` to `t/t0024-*.sh`) includes:

- repository lifecycle and core porcelain: `init`, `status`, `add`, `commit`, `branch`, `checkout`/`switch`, `reset`, `log`, `tag`
- transport-style workflows in standalone mode: `clone`, `fetch`, `pull`, `push`, `bundle`
- plumbing used by normal flows: `hash-object`, `cat-file`, `ls-files`, `ls-tree`, `write-tree`, `update-ref`, `fsck`
- feature flows: local collaboration (`pr`, `issue`, `debug`, `relay`), `ai` (`rebase`, `merge`, `cherry-pick`, `revert`, `commit`; `rebase-ai` is alias), `mcp`, `hq`

### Explicitly Unsupported In Standalone Mode

The following are intentionally rejected with explicit standalone-mode errors (covered by `t/t0005-fallback.sh` and command-level checks):

- signed commit modes (`commit -S`, `commit --gpg-sign`)
- interactive rebase (`rebase -i`)
- reftable-specific paths (`clone --ref-format=reftable`, `update-ref` on reftable repo)
- cloning from local bundle file (`clone <bundle-file>`)
- SHA-256 object-format compatibility paths (`hash-object -w` with `compatObjectFormat=sha256`, `write-tree` on non-sha1 repo)
- `cat-file --batch-all-objects` with `%(objectsize:disk)`
- unsupported option sets for `index-pack` and `pack-objects`

### Where Git Fallback Exists

- Main `bit` command dispatch in `src/cmd/bit/main.mbt` does not auto-delegate unknown commands to system git.
- Git fallback/delegation is implemented in the shim layer `tools/git-shim/bin/git`.
  - The shim delegates to `SHIM_REAL_GIT` by default.
  - CI `git-compat` (`.github/workflows/ci.yml`) runs upstream `git/t` via this shim (`SHIM_REAL_GIT`, `SHIM_MOON`, `SHIM_CMDS`).

### Unimplemented Features

The following features are not yet implemented. Flags listed here are parsed and silently ignored or produce a warning.

#### Fundamentally Missing

| Feature | Description |
|---------|-------------|
| SHA-256 | `--object-format=sha256` repositories not supported |
| Reftable | `--ref-format=reftable` backend not supported |
| Bitmap writing | `pack-objects --write-bitmap-index` does not generate `.bitmap` files |
| Multi-pack-index writing | `repack --write-midx` is a no-op |
| Commit-graph | No commit-graph generation or reading |
| SSH transport | Only HTTPS remotes; `git@host:repo` URLs not supported |
| GPG signing | `commit -S`, `tag -s`, signature verification |
| Interactive add | `add -p` / `add -i` delegate to real git when available |
| Interactive rebase | `rebase -i` rejected in standalone mode |
| Sparse index | Sparse index format not fully supported |
| Custom merge drivers | `.gitattributes` merge drivers not supported |

#### Porcelain Commands - Missing Options

| Command | Missing |
|---------|---------|
| `add` | `-p` (patch), `-i` (interactive) - delegates to git |
| `checkout` | `--patch`, `--ours`, `--theirs`, `--merge` |
| `commit` | `-S` (GPG sign), `--fixup`, `--squash` |
| `diff` | `-O` (orderfile), `--word-diff`, `--color-words` |
| `log` | `--graph` rendering (text output only) |
| `merge` | Octopus merge (3+ heads), custom merge strategies |
| `rebase` | `-i` (interactive), `--root`, `--autosquash` |
| `stash` | `create`, `store` (low-level plumbing) |
| `clean` | `-X` (remove only ignored files, needs gitignore parser) |
| `mv` | `--dry-run`, `--verbose`, `--sparse` |

#### Plumbing Commands - Missing Options

| Command | Missing |
|---------|---------|
| `pack-objects` | `--write-bitmap-index` (bitmap generation), `tree:N` filter (N>0) |
| `repack` | `--write-midx` (MIDX generation), bitmap auto-creation in bare repos |
| `unpack-objects` | `-r` (recover), `--strict` |
| `apply` | `--reject` (rejection file generation) |
| `clone` | `--filter` (partial clone) |
| `update-ref` | `--stdin` transaction status output |

#### repack Test Coverage (t7700: 25/47)

Passing: basic `-a`/`-d`/`-q`/`-l`/`-n`, `--keep-pack`, `--filter` (basic), `--geometric`, `--unpack-unreachable`, `--keep-unreachable`, server info update, `.keep` file handling, incremental repack.

Not passing:

| Category | Tests | Reason |
|----------|-------|--------|
| `--write-midx` | 9 | MIDX generation not implemented |
| `--filter` (advanced) | 5 | Requires `test-tool find-pack` |
| Alternate ODB | 4 | Alternate object detection edge cases |
| Bitmap writing | 2 | `.bitmap` file generation not implemented |
| `GIT_TRACE2_EVENT` | 1 | git internal tracing, not applicable |
| Pending objects | 1 | `--path-walk` + fsck output format |

## Environment Variables

- `BIT_BENCH_GIT_DIR`: override .git path for bench_real (x/fs benchmarks).
- `BIT_PACK_CACHE_LIMIT`: max number of pack files to keep in memory (default: 2; 0 disables cache).
- `BIT_RACY_GIT`: when set, rehash even if stat matches to avoid racy-git false negatives.

## Extensions

### Fs - Virtual Filesystem

Mount any commit as a filesystem with lazy blob loading:

```moonbit
let fs = Fs::from_commit(fs, ".git", commit_id)
let files = fs.readdir(fs, "src")
let content = fs.read_file(fs, "src/main.mbt")
```

### Kv - Distributed KV Store

Git-backed key-value store with Gossip protocol sync:

```moonbit
let db = Kv::init(fs, fs, git_dir, node_id)
db.set(fs, fs, "users/alice/profile", value, ts)
db.sync_with_peer(fs, fs, peer_url)
```

### PR / Issue Metadata (`Hub` library)

The CLI uses the `Hub` library internally. Pull requests and issues are stored as Git objects:

```moonbit
let hub = Hub::init(fs, fs, git_dir)
let pr = hub.create_pr(fs, fs, "Fix bug", "...",
  source_branch, target_branch, author, ts)
```

## License

Apache-2.0
