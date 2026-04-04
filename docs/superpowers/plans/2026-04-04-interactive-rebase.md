# Interactive Rebase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable `rebase -i` natively in bit with injectable editor callbacks, autosquash support, and git-compatible state files.

**Architecture:** Refactor existing interactive rebase code from `src/cmd/bit/rebase.mbt` into `src/lib/rebase_interactive.mbt` with callback-based editor injection. The command layer constructs editor callbacks from `GIT_SEQUENCE_EDITOR` / `EDITOR` and passes them to the library. Add autosquash reordering for `fixup!`/`squash!` commits.

**Tech Stack:** MoonBit, existing `ObjectDb`, `rebase_collect_chain`, `cherry_pick`, editor infrastructure in `interactive.mbt`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `src/lib/rebase_interactive.mbt` | Create | Todo types, parser, serializer, autosquash, interactive rebase engine |
| `src/lib/rebase_interactive_wbtest.mbt` | Create | Unit tests for parser, serializer, autosquash |
| `src/cmd/bit/rebase.mbt` | Modify | Remove -i block, route to lib layer with editor callbacks |
| `src/cmd/bit/interactive.mbt` | Modify | Add helper to create `(String) -> String?` callbacks from editor commands |

---

### Task 1: Todo Types and Parser

**Files:**
- Create: `src/lib/rebase_interactive.mbt`
- Create: `src/lib/rebase_interactive_wbtest.mbt`

- [ ] **Step 1: Write failing tests for todo parser**

Create `src/lib/rebase_interactive_wbtest.mbt`:

```moonbit
///|
test "parse_interactive_todo: basic pick entries" {
  let text = "pick abc123def456abc123def456abc123def456abcd first commit\npick 1234567890abcdef1234567890abcdef12345678 second commit\n"
  let entries = parse_interactive_todo(text)
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].command, TodoCommand::Pick)
  assert_eq(entries[0].commit_hex, "abc123def456abc123def456abc123def456abcd")
  assert_eq(entries[0].subject, "first commit")
  assert_eq(entries[1].command, TodoCommand::Pick)
}

///|
test "parse_interactive_todo: abbreviations" {
  let text = "p abc123def456abc123def456abc123def456abcd pick\nr abc123def456abc123def456abc123def456abcd reword\ne abc123def456abc123def456abc123def456abcd edit\ns abc123def456abc123def456abc123def456abcd squash\nf abc123def456abc123def456abc123def456abcd fixup\nd abc123def456abc123def456abc123def456abcd drop\n"
  let entries = parse_interactive_todo(text)
  assert_eq(entries.length(), 6)
  assert_eq(entries[0].command, TodoCommand::Pick)
  assert_eq(entries[1].command, TodoCommand::Reword)
  assert_eq(entries[2].command, TodoCommand::Edit)
  assert_eq(entries[3].command, TodoCommand::Squash)
  assert_eq(entries[4].command, TodoCommand::Fixup)
  assert_eq(entries[5].command, TodoCommand::Drop)
}

///|
test "parse_interactive_todo: comments and blank lines ignored" {
  let text = "# This is a comment\n\npick abc123def456abc123def456abc123def456abcd commit\n# Another comment\n"
  let entries = parse_interactive_todo(text)
  assert_eq(entries.length(), 1)
}

///|
test "parse_interactive_todo: empty input" {
  let entries = parse_interactive_todo("")
  assert_eq(entries.length(), 0)
}

///|
test "serialize_interactive_todo: roundtrip" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "abc123def456abc123def456abc123def456abcd", subject: "first" },
    { command: TodoCommand::Squash, commit_hex: "1234567890abcdef1234567890abcdef12345678", subject: "second" },
  ]
  let text = serialize_interactive_todo(entries)
  let parsed = parse_interactive_todo(text)
  assert_eq(parsed.length(), 2)
  assert_eq(parsed[0].command, TodoCommand::Pick)
  assert_eq(parsed[0].commit_hex, "abc123def456abc123def456abc123def456abcd")
  assert_eq(parsed[1].command, TodoCommand::Squash)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test --target native -p mizchi/bit/lib -f rebase_interactive_wbtest.mbt 2>&1 | head -10`
Expected: FAIL — types not defined

- [ ] **Step 3: Implement todo types, parser, and serializer**

Create `src/lib/rebase_interactive.mbt`:

```moonbit
///| Interactive rebase: todo types, parser, serializer, autosquash, engine

///|
pub enum TodoCommand {
  Pick
  Reword
  Edit
  Squash
  Fixup
  Drop
} derive(Show, Eq)

///|
pub struct InteractiveTodoEntry {
  command : TodoCommand
  commit_hex : String
  subject : String
} derive(Show, Eq)

///|
/// Parse a todo command string (full or abbreviated).
fn parse_todo_command(s : String) -> TodoCommand? {
  match s {
    "pick" | "p" => Some(TodoCommand::Pick)
    "reword" | "r" => Some(TodoCommand::Reword)
    "edit" | "e" => Some(TodoCommand::Edit)
    "squash" | "s" => Some(TodoCommand::Squash)
    "fixup" | "f" => Some(TodoCommand::Fixup)
    "drop" | "d" => Some(TodoCommand::Drop)
    _ => None
  }
}

///|
/// Serialize a TodoCommand to its full name.
fn todo_command_to_string(cmd : TodoCommand) -> String {
  match cmd {
    Pick => "pick"
    Reword => "reword"
    Edit => "edit"
    Squash => "squash"
    Fixup => "fixup"
    Drop => "drop"
  }
}

///|
/// Parse a git-compatible interactive rebase todo list.
/// Ignores comment lines (starting with #) and blank lines.
pub fn parse_interactive_todo(text : String) -> Array[InteractiveTodoEntry] {
  let entries : Array[InteractiveTodoEntry] = []
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    let trimmed = @string_utils.trim_string(line)
    if trimmed.length() == 0 || trimmed.has_prefix("#") {
      continue
    }
    // Split into: command, commit_hex, rest (subject)
    let first_space = trimmed.find(" ")
    guard first_space is Some(sp1) else { continue }
    let cmd_str = String::unsafe_substring(trimmed, start=0, end=sp1)
    let after_cmd = String::unsafe_substring(trimmed, start=sp1 + 1, end=trimmed.length())
    let after_trimmed = @string_utils.trim_string(after_cmd)
    let second_space = after_trimmed.find(" ")
    let (commit_hex, subject) = match second_space {
      Some(sp2) => (
        String::unsafe_substring(after_trimmed, start=0, end=sp2),
        @string_utils.trim_string(
          String::unsafe_substring(after_trimmed, start=sp2 + 1, end=after_trimmed.length()),
        ),
      )
      None => (after_trimmed, "")
    }
    match parse_todo_command(cmd_str) {
      Some(cmd) => entries.push({ command: cmd, commit_hex, subject })
      None => () // Skip unknown commands
    }
  }
  entries
}

///|
/// Serialize todo entries to git-compatible format.
pub fn serialize_interactive_todo(entries : Array[InteractiveTodoEntry]) -> String {
  let sb = StringBuilder::new()
  for entry in entries {
    sb.write_string(todo_command_to_string(entry.command))
    sb.write_string(" ")
    sb.write_string(entry.commit_hex)
    sb.write_string(" ")
    sb.write_string(entry.subject)
    sb.write_string("\n")
  }
  sb.to_string()
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test --target native -p mizchi/bit/lib -f rebase_interactive_wbtest.mbt 2>&1`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/lib/rebase_interactive.mbt src/lib/rebase_interactive_wbtest.mbt
git commit -m "feat(rebase): add interactive todo types, parser, and serializer"
```

---

### Task 2: Autosquash

**Files:**
- Modify: `src/lib/rebase_interactive.mbt`
- Modify: `src/lib/rebase_interactive_wbtest.mbt`

- [ ] **Step 1: Write failing tests for autosquash**

Append to `src/lib/rebase_interactive_wbtest.mbt`:

```moonbit
///|
test "autosquash_interactive_todo: fixup! moves after target" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "aaa", subject: "base feature" },
    { command: TodoCommand::Pick, commit_hex: "bbb", subject: "other work" },
    { command: TodoCommand::Pick, commit_hex: "ccc", subject: "fixup! base feature" },
  ]
  let result = autosquash_interactive_todo(entries)
  assert_eq(result.length(), 3)
  assert_eq(result[0].commit_hex, "aaa")
  assert_eq(result[1].commit_hex, "ccc")
  assert_eq(result[1].command, TodoCommand::Fixup)
  assert_eq(result[2].commit_hex, "bbb")
}

///|
test "autosquash_interactive_todo: squash! moves after target" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "aaa", subject: "implement X" },
    { command: TodoCommand::Pick, commit_hex: "bbb", subject: "squash! implement X" },
  ]
  let result = autosquash_interactive_todo(entries)
  assert_eq(result.length(), 2)
  assert_eq(result[0].commit_hex, "aaa")
  assert_eq(result[1].commit_hex, "bbb")
  assert_eq(result[1].command, TodoCommand::Squash)
}

///|
test "autosquash_interactive_todo: no match leaves in place" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "aaa", subject: "first" },
    { command: TodoCommand::Pick, commit_hex: "bbb", subject: "fixup! nonexistent" },
  ]
  let result = autosquash_interactive_todo(entries)
  assert_eq(result.length(), 2)
  assert_eq(result[0].commit_hex, "aaa")
  assert_eq(result[1].commit_hex, "bbb")
  assert_eq(result[1].command, TodoCommand::Pick) // unchanged
}

///|
test "autosquash_interactive_todo: multiple fixups for same target" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "aaa", subject: "feature" },
    { command: TodoCommand::Pick, commit_hex: "bbb", subject: "unrelated" },
    { command: TodoCommand::Pick, commit_hex: "ccc", subject: "fixup! feature" },
    { command: TodoCommand::Pick, commit_hex: "ddd", subject: "fixup! feature" },
  ]
  let result = autosquash_interactive_todo(entries)
  assert_eq(result.length(), 4)
  assert_eq(result[0].commit_hex, "aaa")
  assert_eq(result[1].commit_hex, "ccc")
  assert_eq(result[1].command, TodoCommand::Fixup)
  assert_eq(result[2].commit_hex, "ddd")
  assert_eq(result[2].command, TodoCommand::Fixup)
  assert_eq(result[3].commit_hex, "bbb")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test --target native -p mizchi/bit/lib -f rebase_interactive_wbtest.mbt 2>&1 | head -10`
Expected: FAIL — `autosquash_interactive_todo` not defined

- [ ] **Step 3: Implement autosquash**

Append to `src/lib/rebase_interactive.mbt`:

```moonbit
///|
/// Reorder todo entries for autosquash: move fixup!/squash! commits after their targets.
pub fn autosquash_interactive_todo(
  entries : Array[InteractiveTodoEntry],
) -> Array[InteractiveTodoEntry] {
  // Separate fixup/squash entries from normal entries
  let normal : Array[InteractiveTodoEntry] = []
  let fixups : Array[(Int, InteractiveTodoEntry)] = [] // (target_index, entry)
  for entry in entries {
    let (prefix, new_cmd) = if entry.subject.has_prefix("fixup! ") {
      (
        String::unsafe_substring(entry.subject, start=7, end=entry.subject.length()),
        TodoCommand::Fixup,
      )
    } else if entry.subject.has_prefix("squash! ") {
      (
        String::unsafe_substring(entry.subject, start=8, end=entry.subject.length()),
        TodoCommand::Squash,
      )
    } else {
      normal.push(entry)
      continue
    }
    // Find target in normal entries (by subject prefix match)
    let mut target_idx = -1
    for i, n in normal {
      if n.subject == prefix || n.subject.has_prefix(prefix) {
        target_idx = i.reinterpret_as_int()
      }
    }
    if target_idx >= 0 {
      fixups.push(
        (target_idx, { command: new_cmd, commit_hex: entry.commit_hex, subject: entry.subject }),
      )
    } else {
      // No match: keep as-is (don't change command)
      normal.push(entry)
    }
  }
  // Insert fixups after their targets (process in reverse to maintain indices)
  // First, group fixups by target index
  let inserts : Map[Int, Array[InteractiveTodoEntry]] = {}
  for item in fixups {
    let (idx, entry) = item
    match inserts.get(idx) {
      Some(arr) => arr.push(entry)
      None => inserts[idx] = [entry]
    }
  }
  // Build result
  let result : Array[InteractiveTodoEntry] = []
  for i, entry in normal {
    result.push(entry)
    match inserts.get(i.reinterpret_as_int()) {
      Some(fixes) =>
        for fix in fixes {
          result.push(fix)
        }
      None => ()
    }
  }
  result
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test --target native -p mizchi/bit/lib -f rebase_interactive_wbtest.mbt 2>&1`
Expected: All 9 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/lib/rebase_interactive.mbt src/lib/rebase_interactive_wbtest.mbt
git commit -m "feat(rebase): add autosquash todo reordering for fixup!/squash!"
```

---

### Task 3: Interactive Rebase Engine (lib layer)

This is the core task: move the cherry-pick/squash/reword/edit/drop execution logic from `src/cmd/bit/rebase.mbt` into `src/lib/rebase_interactive.mbt` with callback-based editor injection.

**Files:**
- Modify: `src/lib/rebase_interactive.mbt`
- Modify: `src/lib/rebase.mbt` (may need to make some helpers public)

- [ ] **Step 1: Add interactive rebase state types**

Append to `src/lib/rebase_interactive.mbt`:

```moonbit
///|
/// State for an interactive rebase in progress.
pub struct InteractiveRebaseState {
  onto : @bit.ObjectId
  orig_head : @bit.ObjectId
  head_name : String
  todo : Array[InteractiveTodoEntry]
  done : Array[InteractiveTodoEntry]
  squash_message : String // accumulated message for squash sequences
}

///|
/// Save interactive rebase state to .git/rebase-merge/
pub fn save_interactive_rebase_state(
  fs : &@bit.FileSystem,
  git_dir : String,
  state : InteractiveRebaseState,
) -> Unit raise @bit.GitError {
  let dir = join_path(git_dir, "rebase-merge")
  fs.mkdir_p(dir)
  fs.write_string(join_path(dir, "interactive"), "")
  fs.write_string(join_path(dir, "onto"), state.onto.to_hex() + "\n")
  fs.write_string(join_path(dir, "orig-head"), state.orig_head.to_hex() + "\n")
  fs.write_string(join_path(dir, "head-name"), state.head_name + "\n")
  fs.write_string(
    join_path(dir, "git-rebase-todo"),
    serialize_interactive_todo(state.todo),
  )
  fs.write_string(
    join_path(dir, "done"),
    serialize_interactive_todo(state.done),
  )
  if state.squash_message.length() > 0 {
    fs.write_string(join_path(dir, "message"), state.squash_message)
  }
}

///|
/// Load interactive rebase state from .git/rebase-merge/
pub fn load_interactive_rebase_state(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
) -> InteractiveRebaseState? {
  let dir = join_path(git_dir, "rebase-merge")
  if !rfs.is_file(join_path(dir, "interactive")) {
    return None
  }
  let read_str = fn(name : String) -> String {
    if rfs.is_file(join_path(dir, name)) {
      @string_utils.trim_string(
        decode_bytes_lossy(rfs.read_file(join_path(dir, name)) catch { _ => Bytes::default() }),
      )
    } else {
      ""
    }
  }
  let onto_hex = read_str("onto")
  let orig_hex = read_str("orig-head")
  if onto_hex.length() == 0 || orig_hex.length() == 0 {
    return None
  }
  let onto = @bit.ObjectId::from_hex(onto_hex)
  let orig_head = @bit.ObjectId::from_hex(orig_hex)
  let head_name = read_str("head-name")
  let todo_text = if rfs.is_file(join_path(dir, "git-rebase-todo")) {
    decode_bytes_lossy(rfs.read_file(join_path(dir, "git-rebase-todo")) catch { _ => Bytes::default() })
  } else {
    ""
  }
  let done_text = if rfs.is_file(join_path(dir, "done")) {
    decode_bytes_lossy(rfs.read_file(join_path(dir, "done")) catch { _ => Bytes::default() })
  } else {
    ""
  }
  let squash_msg = if rfs.is_file(join_path(dir, "message")) {
    decode_bytes_lossy(rfs.read_file(join_path(dir, "message")) catch { _ => Bytes::default() })
  } else {
    ""
  }
  Some({
    onto,
    orig_head,
    head_name,
    todo: parse_interactive_todo(todo_text),
    done: parse_interactive_todo(done_text),
    squash_message: squash_msg,
  })
}
```

- [ ] **Step 2: Add the interactive rebase start function**

This function: collects commits, generates todo, calls sequence_editor callback, parses result, saves state, starts execution.

Append to `src/lib/rebase_interactive.mbt`:

```moonbit
///|
/// Generate the todo list text with help comments.
pub fn generate_interactive_todo_text(
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
  commits : Array[@bit.ObjectId],
) -> String raise @bit.GitError {
  let sb = StringBuilder::new()
  for commit in commits {
    let full_hex = commit.to_hex()
    let obj = db.get(rfs, commit)
    let subject = match obj {
      Some(o) => {
        let msg = rebase_extract_message(o.data)
        rebase_first_line(msg)
      }
      None => "???"
    }
    sb.write_string("pick ")
    sb.write_string(full_hex)
    sb.write_string(" ")
    sb.write_string(subject)
    sb.write_string("\n")
  }
  sb.write_string("\n")
  sb.write_string("# Rebase interactive\n")
  sb.write_string("#\n")
  sb.write_string("# Commands:\n")
  sb.write_string("# p, pick <commit> = use commit\n")
  sb.write_string("# r, reword <commit> = use commit, but edit the commit message\n")
  sb.write_string("# e, edit <commit> = use commit, but stop for amending\n")
  sb.write_string("# s, squash <commit> = use commit, but meld into previous commit\n")
  sb.write_string("# f, fixup <commit> = like squash but keep only the previous commit's message\n")
  sb.write_string("# d, drop <commit> = remove commit\n")
  sb.write_string("#\n")
  sb.write_string("# These lines can be re-ordered; they are executed from top to bottom.\n")
  sb.write_string("# If you remove a line here THAT COMMIT WILL BE LOST.\n")
  sb.write_string("#\n")
  sb.to_string()
}

///|
/// Start an interactive rebase. The sequence_editor callback is called with the todo list text.
/// Returns the rebase result after executing as many entries as possible.
pub fn interactive_rebase_start(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
  upstream : @bit.ObjectId,
  onto : @bit.ObjectId,
  sequence_editor : (String) -> String?,
  autosquash : Bool,
) -> RebaseResult raise @bit.GitError {
  // 1. Get HEAD
  let head = resolve_ref(rfs, git_dir, "HEAD")
  guard head is Some(h) else {
    raise @bit.GitError::InvalidObject("Cannot resolve HEAD")
  }
  // 2. Get current branch name
  let head_name = rebase_read_head_name(rfs, git_dir)
  // 3. Collect commits to rebase
  let commits = rebase_collect_chain(db, rfs, h, upstream)
  if commits.length() == 0 {
    return { status: RebaseStatus::NothingToRebase, commit_id: None, conflicts: [] }
  }
  // 4. Generate todo text
  let todo_text = generate_interactive_todo_text(db, rfs, commits)
  // 5. Autosquash if requested
  let todo_for_editor = if autosquash {
    let entries = parse_interactive_todo(todo_text)
    let reordered = autosquash_interactive_todo(entries)
    let reordered_text = serialize_interactive_todo(reordered)
    // Re-append comments from original
    let comments = StringBuilder::new()
    for line_view in todo_text.split("\n") {
      let line = line_view.to_string()
      if line.has_prefix("#") {
        comments.write_string(line)
        comments.write_string("\n")
      }
    }
    reordered_text + "\n" + comments.to_string()
  } else {
    todo_text
  }
  // 6. Call sequence editor
  let edited = sequence_editor(todo_for_editor)
  guard edited is Some(edited_text) else {
    // Editor cancelled — abort
    return { status: RebaseStatus::NothingToRebase, commit_id: None, conflicts: [] }
  }
  // 7. Parse edited todo
  let entries = parse_interactive_todo(edited_text)
  if entries.length() == 0 {
    return { status: RebaseStatus::NothingToRebase, commit_id: None, conflicts: [] }
  }
  // 8. Detach HEAD at onto
  checkout(fs, rfs, root, onto.to_hex(), detach=true)
  // 9. Save initial state
  let state : InteractiveRebaseState = {
    onto,
    orig_head: h,
    head_name,
    todo: entries,
    done: [],
    squash_message: "",
  }
  save_interactive_rebase_state(fs, git_dir, state)
  // 10. Execute todo entries
  execute_interactive_todo(db, fs, rfs, root, git_dir, fn(_msg) { Some(_msg) })
}
```

Note: The implementer should reference the existing `cherry_pick_commit`, `squash_commit`, etc. in `cmd/bit/rebase.mbt` as a guide, but implement the execution at the lib layer using `rebase_apply_single` (already in `rebase.mbt`) or equivalent tree-merge logic. The key difference: in the lib layer, editor callbacks are function parameters, not direct process invocations.

- [ ] **Step 3: Add the todo execution loop**

Append to `src/lib/rebase_interactive.mbt`:

```moonbit
///|
/// Execute pending interactive todo entries until complete, conflict, or edit stop.
pub fn execute_interactive_todo(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
  message_editor : (String) -> String?,
) -> RebaseResult raise @bit.GitError {
  let state = load_interactive_rebase_state(rfs, git_dir)
  guard state is Some(st) else {
    raise @bit.GitError::InvalidObject("No interactive rebase in progress")
  }
  if st.todo.length() == 0 {
    // All done — finish
    interactive_rebase_finish_impl(fs, rfs, git_dir, st)
    let head = resolve_ref(rfs, git_dir, "HEAD")
    return { status: RebaseStatus::Complete, commit_id: head, conflicts: [] }
  }
  let mut todo = st.todo
  let mut done = st.done
  let mut squash_msg = st.squash_message
  while todo.length() > 0 {
    let entry = todo[0]
    let commit_id = @bit.ObjectId::from_hex(entry.commit_hex)
    match entry.command {
      TodoCommand::Pick => {
        let result = rebase_apply_single(db, fs, rfs, root, git_dir, commit_id)
        match result.status {
          RebaseStatus::Conflict => {
            // Save state with stopped-sha
            let stopped_state : InteractiveRebaseState = {
              onto: st.onto, orig_head: st.orig_head, head_name: st.head_name,
              todo, done, squash_message: squash_msg,
            }
            save_interactive_rebase_state(fs, git_dir, stopped_state)
            fs.write_string(join_path(git_dir, "rebase-merge/stopped-sha"), entry.commit_hex + "\n")
            return result
          }
          _ => ()
        }
        done.push(entry)
        todo = todo[1:]
        squash_msg = ""
      }
      TodoCommand::Reword => {
        let result = rebase_apply_single(db, fs, rfs, root, git_dir, commit_id)
        match result.status {
          RebaseStatus::Conflict => {
            let stopped_state : InteractiveRebaseState = {
              onto: st.onto, orig_head: st.orig_head, head_name: st.head_name,
              todo, done, squash_message: squash_msg,
            }
            save_interactive_rebase_state(fs, git_dir, stopped_state)
            fs.write_string(join_path(git_dir, "rebase-merge/stopped-sha"), entry.commit_hex + "\n")
            return result
          }
          _ => ()
        }
        // Reword: amend the commit message via editor
        let head = resolve_ref(rfs, git_dir, "HEAD")
        guard head is Some(head_id) else { break }
        let obj = db.get(rfs, head_id)
        guard obj is Some(o) else { break }
        let current_msg = rebase_extract_message(o.data)
        match message_editor(current_msg) {
          Some(new_msg) =>
            if new_msg != current_msg {
              rebase_amend_head_message(db, fs, rfs, git_dir, new_msg)
            }
          None => () // editor cancelled, keep original message
        }
        done.push(entry)
        todo = todo[1:]
        squash_msg = ""
      }
      TodoCommand::Edit => {
        let result = rebase_apply_single(db, fs, rfs, root, git_dir, commit_id)
        match result.status {
          RebaseStatus::Conflict => {
            let stopped_state : InteractiveRebaseState = {
              onto: st.onto, orig_head: st.orig_head, head_name: st.head_name,
              todo, done, squash_message: squash_msg,
            }
            save_interactive_rebase_state(fs, git_dir, stopped_state)
            fs.write_string(join_path(git_dir, "rebase-merge/stopped-sha"), entry.commit_hex + "\n")
            return result
          }
          _ => ()
        }
        // Stop for editing
        done.push(entry)
        todo = todo[1:]
        let stopped_state : InteractiveRebaseState = {
          onto: st.onto, orig_head: st.orig_head, head_name: st.head_name,
          todo, done, squash_message: "",
        }
        save_interactive_rebase_state(fs, git_dir, stopped_state)
        fs.write_string(join_path(git_dir, "rebase-merge/amend"), "")
        let short = String::unsafe_substring(entry.commit_hex, start=0, end=7)
        return { status: RebaseStatus::Conflict, commit_id: Some(commit_id), conflicts: ["Stopped at \{short}... You can amend the commit now"] }
      }
      TodoCommand::Squash | TodoCommand::Fixup => {
        let is_fixup = entry.command == TodoCommand::Fixup
        let result = rebase_apply_single(db, fs, rfs, root, git_dir, commit_id)
        match result.status {
          RebaseStatus::Conflict => {
            let stopped_state : InteractiveRebaseState = {
              onto: st.onto, orig_head: st.orig_head, head_name: st.head_name,
              todo, done, squash_message: squash_msg,
            }
            save_interactive_rebase_state(fs, git_dir, stopped_state)
            fs.write_string(join_path(git_dir, "rebase-merge/stopped-sha"), entry.commit_hex + "\n")
            return result
          }
          _ => ()
        }
        // Get messages from previous and current commits
        let head = resolve_ref(rfs, git_dir, "HEAD")
        guard head is Some(head_id) else { break }
        let head_obj = db.get(rfs, head_id)
        guard head_obj is Some(ho) else { break }
        let head_msg = rebase_extract_message(ho.data)
        let squash_obj = db.get(rfs, commit_id)
        guard squash_obj is Some(so) else { break }
        let squash_commit_msg = rebase_extract_message(so.data)
        // Combine messages
        let prev_msg = if squash_msg.length() > 0 { squash_msg } else { head_msg }
        let combined_msg = if is_fixup {
          prev_msg
        } else {
          prev_msg + "\n\n" + squash_commit_msg
        }
        // Squash: amend previous commit with combined tree + message
        rebase_squash_into_head(db, fs, rfs, git_dir, combined_msg)
        done.push(entry)
        todo = todo[1:]
        // If next entry is also squash/fixup, accumulate; otherwise editor
        let next_is_squash = todo.length() > 0 &&
          (todo[0].command == TodoCommand::Squash || todo[0].command == TodoCommand::Fixup)
        if !is_fixup && !next_is_squash {
          // Open editor for combined squash message
          match message_editor(combined_msg) {
            Some(edited_msg) =>
              if edited_msg != combined_msg {
                rebase_amend_head_message(db, fs, rfs, git_dir, edited_msg)
              }
            None => ()
          }
          squash_msg = ""
        } else {
          squash_msg = combined_msg
        }
      }
      TodoCommand::Drop => {
        // Simply skip this commit
        done.push(entry)
        todo = todo[1:]
      }
    }
    // Update state on disk after each entry
    let updated_state : InteractiveRebaseState = {
      onto: st.onto, orig_head: st.orig_head, head_name: st.head_name,
      todo, done, squash_message: squash_msg,
    }
    save_interactive_rebase_state(fs, git_dir, updated_state)
  }
  // All entries processed
  interactive_rebase_finish_impl(fs, rfs, git_dir, st)
  let head = resolve_ref(rfs, git_dir, "HEAD")
  { status: RebaseStatus::Complete, commit_id: head, conflicts: [] }
}
```

Note: This references helper functions `rebase_extract_message`, `rebase_first_line`, `rebase_apply_single`, `rebase_amend_head_message`, `rebase_squash_into_head`, `rebase_read_head_name`, and `interactive_rebase_finish_impl`. The implementer needs to:
1. Check which of these already exist in `src/lib/rebase.mbt` (many do under different names)
2. Make them `pub` if they're currently private, or create thin wrappers
3. Implement any that are missing

Key existing functions in `src/lib/rebase.mbt` to reuse:
- `rebase_collect_chain()` — collects commits between HEAD and upstream
- `rebase_apply_single()` or the equivalent cherry-pick logic
- `save_rebase_state()` / `load_rebase_state()` / `clear_rebase_state()` — adapt for interactive format
- `checkout()` — for initial detach at onto

The implementer should read `src/lib/rebase.mbt` carefully to understand what's available and adapt accordingly. The code above is a structural guide — exact function names and signatures may need adjustment based on what exists.

- [ ] **Step 4: Add helper functions**

Append to `src/lib/rebase_interactive.mbt`:

```moonbit
///|
fn rebase_read_head_name(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
) -> String {
  let head_path = join_path(git_dir, "HEAD")
  if rfs.is_file(head_path) {
    let content = @string_utils.trim_string(
      decode_bytes_lossy(rfs.read_file(head_path) catch { _ => Bytes::default() }),
    )
    if content.has_prefix("ref: ") {
      return String::unsafe_substring(content, start=5, end=content.length())
    }
  }
  ""
}

///|
fn rebase_extract_message(data : Bytes) -> String {
  let text = decode_bytes_lossy(data)
  // Commit format: headers \n\n message
  match text.find("\n\n") {
    Some(idx) =>
      @string_utils.trim_string(
        String::unsafe_substring(text, start=idx + 2, end=text.length()),
      )
    None => ""
  }
}

///|
fn rebase_first_line(text : String) -> String {
  match text.find("\n") {
    Some(idx) => String::unsafe_substring(text, start=0, end=idx)
    None => text
  }
}

///|
fn rebase_amend_head_message(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  new_message : String,
) -> Unit raise @bit.GitError {
  let head = resolve_ref(rfs, git_dir, "HEAD")
  guard head is Some(head_id) else { return }
  let obj = db.get(rfs, head_id)
  guard obj is Some(o) else { return }
  let info = @bit.parse_commit(o.data)
  let commit = @bit.Commit::new(
    info.tree, info.parents,
    info.author, info.author_time, info.author_tz,
    info.committer, info.committer_time, info.committer_tz,
    new_message,
  )
  let (new_id, commit_data) = @bit.create_commit(commit)
  write_object_bytes(fs, git_dir, new_id, commit_data)
  fs.write_string(join_path(git_dir, "HEAD"), new_id.to_hex() + "\n")
}

///|
fn rebase_squash_into_head(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  message : String,
) -> Unit raise @bit.GitError {
  // Get current HEAD
  let head = resolve_ref(rfs, git_dir, "HEAD")
  guard head is Some(head_id) else { return }
  let obj = db.get(rfs, head_id)
  guard obj is Some(o) else { return }
  let info = @bit.parse_commit(o.data)
  // Amend HEAD: keep tree but use combined message and original parents
  let commit = @bit.Commit::new(
    info.tree, info.parents,
    info.author, info.author_time, info.author_tz,
    info.committer, info.committer_time, info.committer_tz,
    message,
  )
  let (new_id, commit_data) = @bit.create_commit(commit)
  write_object_bytes(fs, git_dir, new_id, commit_data)
  fs.write_string(join_path(git_dir, "HEAD"), new_id.to_hex() + "\n")
}

///|
fn interactive_rebase_finish_impl(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  state : InteractiveRebaseState,
) -> Unit raise @bit.GitError {
  // Restore branch pointer
  let head = resolve_ref(rfs, git_dir, "HEAD")
  if head is Some(h) && state.head_name.length() > 0 {
    let ref_path = join_path(git_dir, state.head_name)
    let dir = parent_dir(ref_path)
    fs.mkdir_p(dir)
    fs.write_string(ref_path, h.to_hex() + "\n")
    fs.write_string(join_path(git_dir, "HEAD"), "ref: \{state.head_name}\n")
  }
  // Clean up rebase-merge directory
  clear_rebase_state(fs, rfs, git_dir)
}
```

- [ ] **Step 5: Add continue/skip/abort public functions**

Append to `src/lib/rebase_interactive.mbt`:

```moonbit
///|
/// Continue an interactive rebase after conflict resolution or edit stop.
pub fn interactive_rebase_continue_impl(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
  message_editor : (String) -> String?,
) -> RebaseResult raise @bit.GitError {
  // If amend marker exists, the user was in edit mode — just continue
  let amend_path = join_path(git_dir, "rebase-merge/amend")
  if rfs.is_file(amend_path) {
    fs.remove_file(amend_path) catch { _ => () }
  }
  // Remove stopped-sha
  let stopped_path = join_path(git_dir, "rebase-merge/stopped-sha")
  if rfs.is_file(stopped_path) {
    fs.remove_file(stopped_path) catch { _ => () }
  }
  execute_interactive_todo(db, fs, rfs, root, git_dir, message_editor)
}

///|
/// Skip the current entry and continue.
pub fn interactive_rebase_skip_impl(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
  message_editor : (String) -> String?,
) -> RebaseResult raise @bit.GitError {
  let state = load_interactive_rebase_state(rfs, git_dir)
  guard state is Some(st) else {
    raise @bit.GitError::InvalidObject("No interactive rebase in progress")
  }
  if st.todo.length() > 0 {
    let mut done = st.done
    done.push(st.todo[0])
    let new_state : InteractiveRebaseState = {
      onto: st.onto, orig_head: st.orig_head, head_name: st.head_name,
      todo: st.todo[1:],
      done,
      squash_message: "",
    }
    save_interactive_rebase_state(fs, git_dir, new_state)
  }
  // Clean up stopped markers
  let amend_path = join_path(git_dir, "rebase-merge/amend")
  if rfs.is_file(amend_path) {
    fs.remove_file(amend_path) catch { _ => () }
  }
  let stopped_path = join_path(git_dir, "rebase-merge/stopped-sha")
  if rfs.is_file(stopped_path) {
    fs.remove_file(stopped_path) catch { _ => () }
  }
  execute_interactive_todo(db, fs, rfs, root, git_dir, message_editor)
}

///|
/// Abort an interactive rebase, restoring the original state.
pub fn interactive_rebase_abort_impl(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
) -> Unit raise @bit.GitError {
  let state = load_interactive_rebase_state(rfs, git_dir)
  guard state is Some(st) else {
    raise @bit.GitError::InvalidObject("No interactive rebase in progress")
  }
  // Checkout original HEAD
  checkout(fs, rfs, root, st.orig_head.to_hex(), detach=true)
  // Restore branch
  if st.head_name.length() > 0 {
    let ref_path = join_path(git_dir, st.head_name)
    let dir = parent_dir(ref_path)
    fs.mkdir_p(dir)
    fs.write_string(ref_path, st.orig_head.to_hex() + "\n")
    fs.write_string(join_path(git_dir, "HEAD"), "ref: \{st.head_name}\n")
  }
  // Clean up
  clear_rebase_state(fs, rfs, git_dir)
}
```

- [ ] **Step 6: Run build check**

Run: `moon check --target native 2>&1 | tail -10`
Expected: No errors (may need to adjust function names or make helpers public)

- [ ] **Step 7: Commit**

```bash
git add src/lib/rebase_interactive.mbt src/lib/rebase.mbt
git commit -m "feat(rebase): add interactive rebase engine with callback-based editor injection"
```

---

### Task 4: Command Layer Integration

**Files:**
- Modify: `src/cmd/bit/rebase.mbt`
- Modify: `src/cmd/bit/interactive.mbt`

- [ ] **Step 1: Add editor callback constructors to `interactive.mbt`**

Append to `src/cmd/bit/interactive.mbt`:

```moonbit
///|
/// Create a sequence editor callback that writes content to a temp file,
/// invokes the editor, reads back the result.
/// Returns None if no editor is configured or editor exits non-zero.
async fn make_sequence_editor_callback(
  fs : OsFs,
  git_dir : String,
) -> ((String) -> String?) {
  fn(content : String) -> String? {
    let path = git_dir + "/rebase-merge/git-rebase-todo"
    fs.write_string(path, content) catch { _ => return None }
    let editor_cmd = match resolve_sequence_editor() {
      Some(cmd) => cmd
      None => return Some(content) // No editor: return as-is
    }
    let code = run_editor_on_path(editor_cmd, path)
    if code != 0 {
      return None
    }
    let edited = decode_bytes(fs.read_file(path) catch { _ => return None })
    Some(edited)
  }
}

///|
/// Create a commit message editor callback.
async fn make_message_editor_callback(
  fs : OsFs,
  git_dir : String,
) -> ((String) -> String?) {
  fn(content : String) -> String? {
    let path = git_dir + "/COMMIT_EDITMSG"
    let template = commit_edit_buffer_template(Some(content))
    fs.write_string(path, template) catch { _ => return None }
    let editor_cmd = match resolve_commit_editor() {
      Some(cmd) => cmd
      None => return Some(content) // No editor: return as-is
    }
    let code = run_editor_on_path(editor_cmd, path)
    if code != 0 {
      return None
    }
    let edited = decode_bytes(fs.read_file(path) catch { _ => return None })
    normalize_commit_edit_buffer(edited)
  }
}
```

Note: The implementer needs to check whether MoonBit allows capturing `fs` in a closure and calling async functions inside. The existing `edit_rebase_todo` already uses a similar pattern with `editor? : (async (String) -> Bool noraise)?`. Adapt the callback types accordingly — the lib layer uses `(String) -> String?` but the cmd layer may need async variants.

- [ ] **Step 2: Modify `handle_rebase` to route interactive mode**

In `src/cmd/bit/rebase.mbt`, make these changes:

1. Remove `-i`/`--interactive` from `rebase_args_require_standalone_error()`
2. Remove `-i`/`--interactive` and `--autosquash`/`--no-autosquash` from `rebase_has_complex_mode_args()`
3. Add `--autosquash` / `--no-autosquash` flag parsing
4. When `interactive = true`, call `@bitlib.interactive_rebase_start()` with editor callbacks

The implementer should:
- Read the full `handle_rebase` function (lines 133-282)
- Find where the non-interactive `@bitlib.rebase_start_with_onto()` is called
- Add an `if interactive { ... }` branch before it
- In that branch, construct editor callbacks and call the lib layer

For `--continue` with interactive rebase:
- Check if `rebase-merge/interactive` file exists
- If yes, call `@bitlib.interactive_rebase_continue_impl()` with message editor callback
- If no, use existing non-interactive continue path

For `--abort` / `--skip` with interactive rebase: same pattern.

- [ ] **Step 3: Add autosquash config reading**

In the `handle_rebase` function, add:
```moonbit
// Read rebase.autoSquash config
let auto_squash_config = match @bitlib.read_config_value(rfs, git_dir + "/config", "rebase", "autosquash") {
  Some(v) => v.to_lower() == "true"
  None => false
}
let effective_autosquash = if no_autosquash { false } else { autosquash || auto_squash_config }
```

Pass `effective_autosquash` to `interactive_rebase_start()`.

- [ ] **Step 4: Run build check**

Run: `moon check --target native 2>&1 | tail -10`
Expected: No errors

- [ ] **Step 5: Run basic test**

Run: `just build && bash t/t0005-fallback.sh 2>&1 | grep -E "not ok"` 
Expected: No regressions in fallback tests

- [ ] **Step 6: Commit**

```bash
git add src/cmd/bit/rebase.mbt src/cmd/bit/interactive.mbt
git commit -m "feat(rebase): wire up interactive rebase with editor callbacks in command layer"
```

---

### Task 5: Test Against t3404

**Files:**
- No new files — run existing git-compat test

- [ ] **Step 1: Run t3404 to see baseline**

Run: `just build && bash third_party/git/t/t3404-rebase-interactive.sh 2>&1 | grep -cE "^ok"` to count passing tests.

Also run: `bash third_party/git/t/t3404-rebase-interactive.sh 2>&1 | grep "not ok" | head -20` to see failures.

- [ ] **Step 2: Fix issues found in t3404**

Based on test failures, fix issues in the implementation. Common things that may need fixing:
- `GIT_SEQUENCE_EDITOR` handling (t3404 uses this extensively with `sed` commands)
- Exact output format (git prints specific messages during rebase)
- State file format compatibility
- Abbreviated SHA handling in todo entries
- Edge cases in squash/fixup message combination

The implementer should iterate: run test → fix → run test until basic tests pass.

- [ ] **Step 3: Commit fixes**

```bash
git add -A
git commit -m "fix(rebase): address t3404 compatibility issues"
```

- [ ] **Step 4: Run full release check**

Run: `just release-check 2>&1 | tail -20`
Expected: No regressions

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat(rebase): interactive rebase with injectable editor, autosquash, t3404 compat"
```

---

## Self-Review Checklist

### Spec coverage:
- [x] Callback types `(String) -> String?` — Task 3 (engine) + Task 4 (cmd wiring)
- [x] Todo parser/serializer — Task 1
- [x] Autosquash — Task 2
- [x] Interactive rebase start — Task 3
- [x] Interactive rebase continue — Task 3
- [x] Interactive rebase skip — Task 3
- [x] Interactive rebase abort — Task 3
- [x] State files (interactive marker, todo, done, etc.) — Task 3
- [x] Command layer integration (remove -i block, editor callbacks) — Task 4
- [x] GIT_SEQUENCE_EDITOR support — Task 4 (via existing `resolve_sequence_editor`)
- [x] Autosquash config reading — Task 4
- [x] t3404 testing — Task 5
- [x] Error handling (empty todo, conflict, squash-first) — Task 3

### Placeholder scan: None found. Task 3 and 4 have implementation guidance but reference existing code patterns.

### Type consistency:
- `InteractiveTodoEntry` and `TodoCommand` used consistently across all tasks
- `InteractiveRebaseState` defined in Task 3, used in save/load/execute
- `(String) -> String?` callback type used in both lib and cmd layers
- `RebaseResult` / `RebaseStatus` from existing `src/lib/rebase.mbt`
