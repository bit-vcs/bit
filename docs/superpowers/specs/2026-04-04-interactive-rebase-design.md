# Interactive Rebase (`rebase -i`) — Design Spec

## Goal

Enable bit to natively execute `rebase -i` without delegating to real git. The editor interaction is injectable: library layer accepts a callback `(String) -> String?`, command layer wraps `GIT_SEQUENCE_EDITOR` / `$EDITOR` invocation as the callback. Pass basic t3404 tests as the compatibility target.

## Approach

Refactor existing `interactive_rebase_start/continue` code from `src/cmd/bit/rebase.mbt` into `src/lib/rebase_interactive.mbt`, replacing direct editor invocation with callback parameters. Enable `-i` and `--autosquash` flags in the command handler.

## Architecture

```
cmd/bit/rebase.mbt (command layer)
  ├─ make_sequence_editor() → callback wrapping GIT_SEQUENCE_EDITOR / EDITOR / vi
  ├─ make_message_editor() → callback wrapping GIT_EDITOR / core.editor / EDITOR / vi
  └─ calls lib layer functions with callbacks

lib/rebase_interactive.mbt (library layer)
  ├─ interactive_rebase_start(sequence_editor_cb, ...) → generate todo → call editor → parse → execute
  ├─ interactive_rebase_continue(message_editor_cb, ...) → resume next todo entry
  ├─ interactive_rebase_skip(...) → skip current, continue
  ├─ interactive_rebase_abort(...) → restore orig-head, cleanup
  ├─ autosquash_todo(entries) → reorder fixup!/squash! commits
  └─ parse_todo_list / serialize_todo_list
```

## Components

### 1. Callback Types

```
type RebaseSequenceEditor = (String) -> String?
type RebaseMessageEditor = (String) -> String?
```

- Input: text content to edit
- Output: `Some(edited_text)` = proceed, `None` = cancel (abort rebase)
- Sequence editor: edits the full todo list at rebase start
- Message editor: edits commit messages for reword/squash

### 2. Todo Parser / Serializer

```
pub enum TodoCommand { Pick; Reword; Edit; Squash; Fixup; Drop }

pub struct TodoEntry {
  command : TodoCommand
  commit_id : ObjectId
  subject : String
}

pub fn parse_todo_list(text : String) -> Array[TodoEntry]
pub fn serialize_todo_list(entries : Array[TodoEntry]) -> String
```

Format (git-compatible):
```
pick <40-char-sha> <subject line>
reword <40-char-sha> <subject line>
squash <40-char-sha> <subject line>
# Lines starting with # are comments (ignored)
```

- Single-character abbreviations: `p`, `r`, `e`, `s`, `f`, `d`
- Blank lines and comment lines ignored
- Unknown commands produce parse error

### 3. Autosquash

```
pub fn autosquash_todo(entries : Array[TodoEntry]) -> Array[TodoEntry]
```

- `fixup! <target-subject>`: move after matching commit, change command to Fixup
- `squash! <target-subject>`: move after matching commit, change command to Squash
- Matching: entry's subject matches `<target-subject>` (prefix match)
- No match found: leave entry in place
- Config: `rebase.autoSquash = true` enables autosquash by default (without `--autosquash` flag)

### 4. Interactive Rebase Engine

#### Start

```
pub fn interactive_rebase_start(
  fs, rfs, root, git_dir,
  upstream : ObjectId,
  onto : ObjectId,
  sequence_editor : (String) -> String?,
  autosquash : Bool,
) -> RebaseResult raise GitError
```

Flow:
1. Compute merge base between HEAD and upstream
2. Collect commit chain (HEAD → merge base, reverse to oldest-first)
3. Generate todo list (`pick <sha> <subject>` per commit)
4. If autosquash: apply `autosquash_todo()` reordering
5. Call `sequence_editor(todo_text)` — if `None`, abort
6. Parse returned todo list
7. Save state to `.git/rebase-merge/` (onto, orig-head, head-name, todo, interactive marker)
8. Execute entries sequentially until complete or conflict

#### Continue

```
pub fn interactive_rebase_continue(
  fs, rfs, root, git_dir,
  message_editor : (String) -> String?,
) -> RebaseResult raise GitError
```

Flow:
1. Load state from `.git/rebase-merge/`
2. Complete current entry (create commit from worktree state)
3. For reword: call `message_editor(original_message)`, use result
4. For squash: combine messages, call `message_editor(combined)`, use result
5. For fixup: keep previous message (no editor)
6. Move entry from todo → done
7. Execute next entries until complete or conflict

#### Skip / Abort

```
pub fn interactive_rebase_skip(fs, rfs, root, git_dir) -> RebaseResult raise GitError
pub fn interactive_rebase_abort(fs, rfs, root, git_dir) -> Unit raise GitError
```

Skip: move current todo entry to done without committing, continue.
Abort: restore orig-head, restore branch pointer, remove `.git/rebase-merge/`.

### 5. State Files (`.git/rebase-merge/`)

| File | Purpose | Notes |
|------|---------|-------|
| `interactive` | Marker file (empty) | Indicates interactive rebase in progress |
| `onto` | Target commit OID | 40-char hex + newline |
| `orig-head` | Original HEAD before rebase | 40-char hex + newline |
| `head-name` | Branch ref or empty | e.g., `refs/heads/main` |
| `git-rebase-todo` | Remaining todo entries | `pick <sha> <subject>` per line |
| `done` | Completed entries | Same format as todo |
| `stopped-sha` | Current commit when stopped | Present during conflict/edit |
| `amend` | Marker for edit stop | Empty file, present when `edit` command stops |
| `message` | Accumulated squash message | Multi-line text for squash/fixup sequences |
| `author-script` | Author info preservation | `GIT_AUTHOR_NAME='...'` shell format |

State file format follows git conventions for interoperability (a `git rebase --continue` could potentially resume a bit-started rebase and vice versa).

### 6. Command Layer Integration

In `src/cmd/bit/rebase.mbt`:

**Editor callback construction:**
```
fn make_sequence_editor() -> (String) -> String?
  // Priority: GIT_SEQUENCE_EDITOR env → sequence.editor config → GIT_EDITOR env → core.editor config → EDITOR env → vi
  // Writes text to temp file, invokes editor, reads result
  // Returns None if editor exits non-zero

fn make_message_editor() -> (String) -> String?
  // Priority: GIT_EDITOR env → core.editor config → EDITOR env → vi
  // Same temp-file mechanism
```

**Flag changes:**
- Remove `-i` / `--interactive` from `rebase_args_require_standalone_error()`
- Remove `-i` / `--interactive` and `--autosquash` from `rebase_has_complex_mode_args()`
- Add interactive mode routing in `handle_rebase()`: when `interactive = true`, call lib layer `interactive_rebase_start` with editor callbacks

**Autosquash config:**
- Read `rebase.autoSquash` from git config
- If true and `--no-autosquash` not passed, enable autosquash
- `--autosquash` flag explicitly enables regardless of config

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Editor returns `None` | Abort rebase, clean up state files |
| Todo list empty after editing | "Nothing to do" message, abort |
| Unknown command in todo | Parse error with line number, abort |
| Conflict during apply | Save state, print conflict message, exit 1 |
| squash/fixup as first entry | "Cannot squash without a previous pick" error, abort |
| Missing commit in todo | "Could not find commit <sha>" error, abort |
| Edit command | Stop after applying, print "Stopped at <sha>... amend and continue" |

## Testing

### Unit Tests (`src/lib/rebase_interactive_wbtest.mbt`)
- Todo parser: valid entries, comments, blank lines, abbreviations, unknown commands
- Todo serializer: roundtrip with parser
- Autosquash: fixup! reordering, squash! reordering, no-match passthrough, multiple fixups

### Git Compat (t3404-rebase-interactive.sh)
Target: pass tests exercising pick, reword, squash, fixup, drop, edit, autosquash, GIT_SEQUENCE_EDITOR. Tests requiring exec, label, merge, update-ref will remain delegated or skipped.

## File Summary

| File | Action | Purpose |
|------|--------|---------|
| `src/lib/rebase_interactive.mbt` | Create | Todo types, parser, serializer, autosquash, rebase engine |
| `src/lib/rebase_interactive_wbtest.mbt` | Create | Unit tests for parser, serializer, autosquash |
| `src/cmd/bit/rebase.mbt` | Modify | Remove -i block, add interactive routing, editor callbacks |
| `src/lib/rebase.mbt` | Modify | Extract shared utilities if needed |

## Out of Scope

- `exec` / `break` commands
- `label` / `reset` / `merge` / `update-ref` commands
- `--rebase-merges`
- `--strategy` / `-X` (merge strategy options)
- `--root` rebase
- `--update-refs`
- `--keep-empty` / `--no-keep-empty` (use git default behavior)
