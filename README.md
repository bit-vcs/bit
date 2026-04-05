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

## Shell Completion

```bash
# bash (~/.bashrc)
eval "$(bit completion bash)"

# zsh (~/.zshrc)
eval "$(bit completion zsh)"
```

## Quick Start

```bash
bit clone https://github.com/user/repo
bit checkout -b feature
bit add .
bit commit -m "changes"
bit push origin feature
```

## Bit Extension Commands Quick Guide

### bit pr / bit issue

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
bit issue list --open             # top-level issues, with sub-issue counts
bit issue list --tree             # parent/child tree
bit issue list --all              # flat list including children
bit issue list --parent <issue-id>

# Local pull requests
bit pr create --title "Fix cache invalidation" --body "refresh status after write" \
  --head feature/cache-fix --base main
bit pr list --open
bit pr review <pr-id> --approve --commit <commit-hex>
bit pr merge <pr-id>

# Optional relay sync for PR / Issue metadata
bit relay sync push <remote-url>
bit relay sync fetch <remote-url>

# Optional links and search
bit issue link <issue-id> <pr-id>
bit pr search "cache"
bit issue search "cache"
```

### bit fingerprint

`bit fingerprint` is currently a feature set (workspace/PR workflow integration), not a standalone top-level command.

```bash
# Workspace flow uses per-node directory fingerprints
BIT_WORKSPACE_FINGERPRINT_MODE=git bit workspace flow test
BIT_WORKSPACE_FINGERPRINT_MODE=fast bit workspace flow test

# PR workflow records can carry a workspace fingerprint
bit pr workflow submit 123 \
  --task test --status success \
  --fingerprint <workspace-fingerprint> \
  --txn <txn-id>
```

### bit subdir

Use `bit subdir-clone` (or clone shorthand) to work on a repository subdirectory as an independent repo.

```bash
# Explicit command
bit subdir-clone https://github.com/user/repo src/lib mylib

# Shorthand via clone
bit clone user/repo:src/lib
bit clone user/repo@main:src/lib

# GitHub tree/blob URL is also supported
bit clone https://github.com/user/repo/tree/main/packages/core
bit clone https://github.com/user/repo/blob/main/README.md
```

Cloned subdirectories have their own `.git` directory. When placed inside another git repository, git treats them as embedded repositories (similar to submodules), and the parent repo does not commit their contents.

### bit ai

AI-assisted rebase conflict resolution (OpenRouter, default model `moonshotai/kimi-k2`).
Subcommands:
  - `rebase` (alias: `rebase-ai`)
  - `merge`
  - `commit`
  - `cherry-pick`
  - `revert`

```bash
export OPENROUTER_API_KEY=...

# Start / continue / abort / skip
bit ai rebase main
bit ai rebase --continue
bit ai rebase --abort
bit ai rebase --skip
bit ai merge --continue
bit ai merge --abort

# Options
bit ai rebase --model moonshotai/kimi-k2 --max-ai-rounds 16 main
bit ai rebase --agent-loop --agent-max-steps 24 main
bit ai merge --agent-loop --agent-max-steps 24 branch
bit ai commit --split
bit ai commit
bit ai cherry-pick abc1234
bit ai revert abc1234

# Alias (legacy)
bit rebase-ai main
```

### bit ai commit

Experimental AI-assisted commit message helper entrypoint (currently delegates to `bit commit` for compatibility).
`bit ai commit` は `rebase` と同じ AI 設定引数を受け付けます（`--model`, `--max-ai-rounds`, `--agent-loop`, `--agent-max-steps`）。

```bash
bit ai commit -m "message..."
bit ai commit
```

### bit mcp

Start the MCP server via `bit mcp` (native target).

```bash
# Start MCP server (stdio)
bit mcp

# Help
bit mcp --help
bit help mcp

# Standalone MoonBit entrypoint (equivalent server implementation)
moon run src/x/mcp/cmd --target native
```

### bit hq

`ghq`-compatible repository manager (default root: `~/bhq`).

```bash
bit hq get mizchi/git
bit hq get -u mizchi/git
bit hq get --shallow mizchi/git
bit hq list
bit hq list mizchi
bit hq root
```

## Agent Storage Runtime

`bit` core operations can run against any storage backend that implements:

- `@bit.FileSystem` (write side)
- `@bit.RepoFileSystem` (read side)

Entry point:

- `/Users/mz/ghq/github.com/mizchi/bit/src/cmd/bit/storage_runtime.mbt`
- `run_storage_command(fs, rfs, root, cmd, args)`

One in-memory implementation is `@bit.TestFs`, which can be used as agent storage:

```moonbit
let fs = @bit.TestFs::new()
let root = "/agent-repo"
run_storage_command(fs, fs, root, "init", ["-q"])
fs.write_string(root + "/note.txt", "hello")
run_storage_command(fs, fs, root, "add", ["note.txt"])
run_storage_command(fs, fs, root, "commit", ["-m", "agent snapshot"])
```

## Compatibility

bit implements 108 git commands natively with 973 git test suite tests passing. Key compatibility features:

- Git config: reads global aliases from `~/.gitconfig` (or `GIT_CONFIG_GLOBAL`).
- `core.hooksPath`: custom hook directory support.
- Generic `filter=` attributes (clean/smudge) handled natively.
- LFS pointer files resolved natively (read-only).
- `log --graph`, `--stat`, `--name-only`, `--name-status`, `--topo-order` run natively.
- `rebase -i` with all standard commands runs natively.
- Detailed standalone scope, unsupported paths, fallback points, and git/t coverage documented in [`docs/git-compatibility.md`](docs/git-compatibility.md).

### Git LFS Support

bit natively resolves LFS pointer files during clone and checkout. No `git-lfs` binary required.

- LFS pointer detection and batch download via LFS Batch API
- SHA-256 integrity verification on downloaded objects
- Local cache at `.git/lfs/objects/` (compatible with git-lfs layout)
- URL resolution: `lfs.url`, `remote.<name>.lfsurl`, or derived from remote URL

**Note:** Write support (clean filter, push) is not yet implemented. LFS repositories are read-only.

### Interactive Rebase

bit handles `rebase -i` natively with an injectable editor architecture:

- **Commands:** pick, reword, edit, squash, fixup, drop, exec, break, label, reset, merge
- **Flags:** `--autosquash`, `--exec`, `--autostash`, `--keep-empty`, `--edit-todo`, `--show-current-patch`, `--update-refs`, `--root`, `--strategy`/`-X`, `--rebase-merges`
- **Editor injection:** `GIT_SEQUENCE_EDITOR` for todo editing, `GIT_EDITOR` for commit messages
- **Programmatic API:** library layer accepts `(String) -> String?` callbacks (for CI, AI agents, MCP tools)

### Explicitly Unsupported Features

The following features are **not supported** and will produce a fatal error:

**Repository formats**
- SHA-256 repositories (`--object-format=sha256`)
- Reftable ref format (`--ref-format=reftable`)
- Incremental multi-pack-index chains

**Gitattributes**
- `working-tree-encoding=`

**Other**
- GPG signing on merge/rebase (`-S`, `--gpg-sign`)
- Grafts (`.git/info/grafts`) and replace refs (`refs/replace/`)
- Recursive clone (`--recursive`, submodule auto-init)
- Shell aliases (prefixed with `!`)

**JS target only**
- SSH transport (`ssh://`, `git@...`) in `clone` / `fetch` / `pull` / `push` (use HTTP(S) or relay URLs)

## Environment Variables

- `BIT_BENCH_GIT_DIR`: override .git path for bench_real (x/fs benchmarks).
- `BIT_PACK_CACHE_LIMIT`: max number of pack files to keep in memory (default: 2; 0 disables cache).
- `BIT_RACY_GIT`: when set, rehash even if stat matches to avoid racy-git false negatives.
- `BIT_WORKSPACE_FINGERPRINT_MODE`: workspace fingerprint mode (`git` default, `fast` optional). `git` mode follows add-all-style Git-compatible directory snapshots for flow cache decisions.

## Library Extensions

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
