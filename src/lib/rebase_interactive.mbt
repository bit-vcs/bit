///| Interactive rebase: todo types, parser, serializer, autosquash, engine

// ============================================================================
// Types
// ============================================================================

///|
pub enum TodoCommand {
  Pick
  Reword
  Edit
  Squash
  Fixup
  Drop
  Exec
  Break
} derive(Show, Eq)

///|
pub struct InteractiveTodoEntry {
  command : TodoCommand
  commit_hex : String
  subject : String
} derive(Show, Eq)

///|
fn parse_todo_command(s : String) -> TodoCommand? {
  match s {
    "pick" | "p" => Some(TodoCommand::Pick)
    "reword" | "r" => Some(TodoCommand::Reword)
    "edit" | "e" => Some(TodoCommand::Edit)
    "squash" | "s" => Some(TodoCommand::Squash)
    "fixup" | "f" => Some(TodoCommand::Fixup)
    "drop" | "d" => Some(TodoCommand::Drop)
    "exec" | "x" => Some(TodoCommand::Exec)
    "break" | "b" => Some(TodoCommand::Break)
    _ => None
  }
}

///|
fn todo_command_to_string(cmd : TodoCommand) -> String {
  match cmd {
    Pick => "pick"
    Reword => "reword"
    Edit => "edit"
    Squash => "squash"
    Fixup => "fixup"
    Drop => "drop"
    Exec => "exec"
    Break => "break"
  }
}

///|
pub fn parse_interactive_todo(text : String) -> Array[InteractiveTodoEntry] {
  let entries : Array[InteractiveTodoEntry] = []
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    let trimmed = @string_utils.trim_string(line)
    if trimmed.length() == 0 || trimmed.has_prefix("#") {
      continue
    }
    let first_space = trimmed.find(" ")
    guard first_space is Some(sp1) else { continue }
    let cmd_str = String::unsafe_substring(trimmed, start=0, end=sp1)
    let after_cmd = String::unsafe_substring(
      trimmed,
      start=sp1 + 1,
      end=trimmed.length(),
    )
    let after_trimmed = @string_utils.trim_string(after_cmd)
    let second_space = after_trimmed.find(" ")
    let (commit_hex, subject) = match second_space {
      Some(sp2) =>
        (
          String::unsafe_substring(after_trimmed, start=0, end=sp2),
          @string_utils.trim_string(
            String::unsafe_substring(
              after_trimmed,
              start=sp2 + 1,
              end=after_trimmed.length(),
            ),
          ),
        )
      None => (after_trimmed, "")
    }
    match parse_todo_command(cmd_str) {
      Some(TodoCommand::Exec) =>
        // exec: rest of line is the command, no commit_hex
        entries.push({ command: TodoCommand::Exec, commit_hex: "", subject: after_trimmed })
      Some(TodoCommand::Break) =>
        // break: no arguments
        entries.push({ command: TodoCommand::Break, commit_hex: "", subject: "" })
      Some(cmd) => entries.push({ command: cmd, commit_hex, subject })
      None => ()
    }
  }
  entries
}

///|
pub fn serialize_interactive_todo(
  entries : Array[InteractiveTodoEntry],
) -> String {
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

///|
/// Reorder todo entries for autosquash: move fixup!/squash! commits after their targets.
pub fn autosquash_interactive_todo(
  entries : Array[InteractiveTodoEntry],
) -> Array[InteractiveTodoEntry] {
  let normal : Array[InteractiveTodoEntry] = []
  let fixups : Array[(Int, InteractiveTodoEntry)] = []
  for entry in entries {
    let (prefix, new_cmd) = if entry.subject.has_prefix("fixup! ") {
      (
        String::unsafe_substring(
          entry.subject,
          start=7,
          end=entry.subject.length(),
        ),
        TodoCommand::Fixup,
      )
    } else if entry.subject.has_prefix("squash! ") {
      (
        String::unsafe_substring(
          entry.subject,
          start=8,
          end=entry.subject.length(),
        ),
        TodoCommand::Squash,
      )
    } else {
      normal.push(entry)
      continue
    }
    let mut target_idx = -1
    for i, n in normal {
      if n.subject == prefix || n.subject.has_prefix(prefix) {
        target_idx = i
      }
    }
    if target_idx >= 0 {
      fixups.push(
        (
          target_idx,
          {
            command: new_cmd,
            commit_hex: entry.commit_hex,
            subject: entry.subject,
          },
        ),
      )
    } else {
      normal.push(entry)
    }
  }
  let inserts : Map[Int, Array[InteractiveTodoEntry]] = {}
  for item in fixups {
    let (idx, entry) = item
    match inserts.get(idx) {
      Some(arr) => arr.push(entry)
      None => inserts[idx] = [entry]
    }
  }
  let result : Array[InteractiveTodoEntry] = []
  for i, entry in normal {
    result.push(entry)
    match inserts.get(i) {
      Some(fixes) =>
        for fix in fixes {
          result.push(fix)
        }
      None => ()
    }
  }
  result
}

// ============================================================================
// Interactive Rebase State
// ============================================================================

///|
pub struct InteractiveRebaseState {
  onto : @bit.ObjectId
  orig_head : @bit.ObjectId
  head_name : String // branch name or "" for detached
  todo : Array[InteractiveTodoEntry]
  done : Array[InteractiveTodoEntry]
  amend : Bool // true when stopped for edit (next continue should amend)
  squash_msg : String // accumulated squash message
}

///|
pub fn save_interactive_rebase_state(
  fs : &@bit.FileSystem,
  git_dir : String,
  state : InteractiveRebaseState,
) -> Unit raise @bit.GitError {
  let rebase_dir = join_path(git_dir, "rebase-merge")
  fs.mkdir_p(rebase_dir)
  // Mark as interactive rebase
  fs.write_string(join_path(rebase_dir, "interactive"), "")
  fs.write_string(join_path(rebase_dir, "onto"), state.onto.to_hex() + "\n")
  fs.write_string(
    join_path(rebase_dir, "orig-head"),
    state.orig_head.to_hex() + "\n",
  )
  fs.write_string(join_path(rebase_dir, "head-name"), state.head_name + "\n")
  // Write todo file
  let todo_text = serialize_interactive_todo(state.todo)
  fs.write_string(join_path(rebase_dir, "git-rebase-todo"), todo_text)
  // Write done file
  let done_text = serialize_interactive_todo(state.done)
  fs.write_string(join_path(rebase_dir, "done"), done_text)
  // Write amend marker
  if state.amend {
    fs.write_string(join_path(rebase_dir, "amend"), "")
  } else {
    fs.remove_file(join_path(rebase_dir, "amend")) catch {
      _ => ()
    }
  }
  // Write squash message if non-empty
  if state.squash_msg.length() > 0 {
    fs.write_string(join_path(rebase_dir, "message-squash"), state.squash_msg)
  } else {
    fs.remove_file(join_path(rebase_dir, "message-squash")) catch {
      _ => ()
    }
  }
}

///|
pub fn load_interactive_rebase_state(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
) -> InteractiveRebaseState? raise @bit.GitError {
  let rebase_dir = join_path(git_dir, "rebase-merge")
  if !rfs.is_dir(rebase_dir) {
    return None
  }
  // Check for interactive marker
  if !rfs.is_file(join_path(rebase_dir, "interactive")) {
    return None
  }
  let onto_hex = read_file_trimmed(rfs, join_path(rebase_dir, "onto"))
  let orig_head_hex = read_file_trimmed(rfs, join_path(rebase_dir, "orig-head"))
  let head_name = read_file_trimmed(rfs, join_path(rebase_dir, "head-name"))
  let todo_text = interactive_read_file_or_empty(
    rfs,
    join_path(rebase_dir, "git-rebase-todo"),
  )
  let done_text = interactive_read_file_or_empty(
    rfs,
    join_path(rebase_dir, "done"),
  )
  let amend = rfs.is_file(join_path(rebase_dir, "amend"))
  let squash_msg = interactive_read_file_or_empty(
    rfs,
    join_path(rebase_dir, "message-squash"),
  )
  Some({
    onto: @bit.ObjectId::from_hex(onto_hex),
    orig_head: @bit.ObjectId::from_hex(orig_head_hex),
    head_name,
    todo: parse_interactive_todo(todo_text),
    done: parse_interactive_todo(done_text),
    amend,
    squash_msg,
  })
}

///|
fn interactive_read_file_or_empty(
  rfs : &@bit.RepoFileSystem,
  path : String,
) -> String {
  if !rfs.is_file(path) {
    return ""
  }
  @utf8.decode_lossy((rfs.read_file(path) catch { _ => Bytes::default() })[:])
}

// ============================================================================
// Interactive Rebase: generate todo text
// ============================================================================

///|
pub fn generate_interactive_todo_text(
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
  commits : Array[@bit.ObjectId],
) -> String raise @bit.GitError {
  let sb = StringBuilder::new()
  for commit in commits {
    let hex = commit.to_hex()
    let short = String::unsafe_substring(hex, start=0, end=7)
    let obj = db.get(rfs, commit)
    let subject = match obj {
      Some(o) => {
        let info = rebase_parse_commit_content(o.data)
        interactive_first_line(info.message)
      }
      None => "???"
    }
    sb.write_string("pick ")
    sb.write_string(short)
    sb.write_string(" ")
    sb.write_string(subject)
    sb.write_string("\n")
  }
  sb.write_string("\n")
  sb.write_string("# Rebase commands:\n")
  sb.write_string("# p, pick   <commit> = use commit\n")
  sb.write_string(
    "# r, reword <commit> = use commit, but edit the commit message\n",
  )
  sb.write_string("# e, edit   <commit> = use commit, but stop for amending\n")
  sb.write_string(
    "# s, squash <commit> = use commit, but meld into previous commit\n",
  )
  sb.write_string(
    "# f, fixup  <commit> = like squash, but discard this commit's log message\n",
  )
  sb.write_string("# d, drop   <commit> = remove commit\n")
  sb.write_string("#\n")
  sb.write_string("# If you remove a line here THAT COMMIT WILL BE LOST.\n")
  sb.write_string("#\n")
  sb.to_string()
}

///|
fn interactive_first_line(s : String) -> String {
  match s.find("\n") {
    Some(idx) =>
      @string_utils.trim_string(String::unsafe_substring(s, start=0, end=idx))
    None => @string_utils.trim_string(s)
  }
}

// ============================================================================
// Interactive Rebase: start
// ============================================================================

///|
/// Start an interactive rebase. The sequence_editor callback is invoked with
/// the generated todo text and should return `Some(edited_text)` to proceed
/// or `None` to abort.
pub async fn interactive_rebase_start(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  upstream : @bit.ObjectId,
  onto : @bit.ObjectId,
  sequence_editor : async (String) -> String?,
  message_editor : async (String) -> String?,
  autosquash? : Bool = false,
  exec_runner? : (async (String) -> Int)? = None,
) -> InteractiveRebaseResult raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  if is_rebase_in_progress(rfs, git_dir) {
    raise @bit.GitError::InvalidObject(
      "A rebase is already in progress. Use --continue, --abort, or --skip.",
    )
  }
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(h) else {
    raise @bit.GitError::InvalidObject("Cannot resolve HEAD")
  }
  let db = ObjectDb::load(rfs, git_dir)
  // Collect commits to rebase
  let commits = rebase_collect_chain(db, rfs, h, upstream)
  if commits.length() == 0 {
    return { status: IRBComplete, commit_id: Some(h), message: "" }
  }
  // Save head name before detaching
  let head_name = match read_head_ref(rfs, git_dir) {
    HeadRef::Branch(name) => "refs/heads/" + name
    HeadRef::Detached(_) => ""
  }
  // Generate todo text
  let todo_text = generate_interactive_todo_text(db, rfs, commits)
  // Call sequence editor
  let edited = sequence_editor(todo_text) catch { _ => None }
  guard edited is Some(edited_text) else {
    return { status: IRBAborted, commit_id: None, message: "rebase aborted" }
  }
  // Parse edited todo
  let mut entries = parse_interactive_todo(edited_text)
  if entries.length() == 0 {
    return {
      status: IRBAborted,
      commit_id: None,
      message: "nothing to do (empty todo list)",
    }
  }
  // Autosquash if requested
  if autosquash {
    entries = autosquash_interactive_todo(entries)
  }
  // Resolve short hex to full hex in entries
  let resolved_entries = interactive_resolve_entries(rfs, git_dir, entries)
  // Detach HEAD at onto
  ignore(checkout(fs, rfs, root, onto.to_hex(), detach=true))
  // Save state
  let state : InteractiveRebaseState = {
    onto,
    orig_head: h,
    head_name,
    todo: resolved_entries,
    done: [],
    amend: false,
    squash_msg: "",
  }
  save_interactive_rebase_state(fs, git_dir, state)
  // Execute the todo
  execute_interactive_todo(fs, rfs, root, state, message_editor, exec_runner~)
}

///|
fn interactive_resolve_entries(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  entries : Array[InteractiveTodoEntry],
) -> Array[InteractiveTodoEntry] raise @bit.GitError {
  let result : Array[InteractiveTodoEntry] = []
  for entry in entries {
    let hex = entry.commit_hex
    // Try to resolve short hex to full hex via rev_parse
    let resolved = if hex.length() < 40 {
      let id = rev_parse(rfs, git_dir, hex)
      guard id is Some(resolved_id) else {
        raise @bit.GitError::InvalidObject("Cannot resolve commit: " + hex)
      }
      resolved_id.to_hex()
    } else {
      hex
    }
    result.push({
      command: entry.command,
      commit_hex: resolved,
      subject: entry.subject,
    })
  }
  result
}

// ============================================================================
// Interactive Rebase: result type
// ============================================================================

///|
pub enum InteractiveRebaseStatus {
  IRBComplete
  IRBConflict
  IRBStopped // stopped for edit
  IRBAborted
}

///|
pub struct InteractiveRebaseResult {
  status : InteractiveRebaseStatus
  commit_id : @bit.ObjectId?
  message : String
}

// ============================================================================
// Interactive Rebase: execute todo loop
// ============================================================================

///|
pub async fn execute_interactive_todo(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  state : InteractiveRebaseState,
  message_editor : async (String) -> String?,
  exec_runner? : (async (String) -> Int)? = None,
) -> InteractiveRebaseResult raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let db = ObjectDb::load(rfs, git_dir)
  if state.todo.length() == 0 {
    // All done
    return interactive_rebase_finish(fs, rfs, root, state)
  }
  let entry = state.todo[0]
  let commit_id = @bit.ObjectId::from_hex(entry.commit_hex)
  match entry.command {
    Pick => {
      let result = interactive_cherry_pick(fs, rfs, root, db, commit_id)
      match result.status {
        IRBConflict => {
          let new_state = interactive_move_to_done(state)
          save_interactive_rebase_state(fs, git_dir, new_state)
          return result
        }
        _ => {
          let new_state = interactive_move_to_done(state)
          save_interactive_rebase_state(fs, git_dir, new_state)
          execute_interactive_todo(fs, rfs, root, new_state, message_editor, exec_runner~)
        }
      }
    }
    Reword => {
      let result = interactive_cherry_pick(fs, rfs, root, db, commit_id)
      match result.status {
        IRBConflict => {
          let new_state = interactive_move_to_done(state)
          save_interactive_rebase_state(fs, git_dir, new_state)
          return result
        }
        _ => {
          // Get original message and let editor modify it
          let info = rebase_parse_commit_full(db, rfs, commit_id)
          let edited_msg = message_editor(info.message) catch { _ => None }
          let msg = match edited_msg {
            Some(m) => m
            None => info.message
          }
          // Amend HEAD commit with new message
          interactive_amend_head_message(fs, rfs, root, db, msg)
          let new_state = interactive_move_to_done(state)
          save_interactive_rebase_state(fs, git_dir, new_state)
          execute_interactive_todo(fs, rfs, root, new_state, message_editor, exec_runner~)
        }
      }
    }
    Edit => {
      let result = interactive_cherry_pick(fs, rfs, root, db, commit_id)
      match result.status {
        IRBConflict => {
          let new_state = interactive_move_to_done(state)
          save_interactive_rebase_state(fs, git_dir, new_state)
          return result
        }
        _ => {
          // Stop for user editing
          let new_state : InteractiveRebaseState = {
            ..interactive_move_to_done(state),
            amend: true,
          }
          save_interactive_rebase_state(fs, git_dir, new_state)
          let head = resolve_head_commit(rfs, git_dir)
          {
            status: IRBStopped,
            commit_id: head,
            message: "Stopped at " +
            String::unsafe_substring(
              entry.commit_hex,
              start=0,
              end=if entry.commit_hex.length() > 7 {
                7
              } else {
                entry.commit_hex.length()
              },
            ) +
            "... " +
            entry.subject,
          }
        }
      }
    }
    Squash => {
      let result = interactive_squash_into_head(
        fs,
        rfs,
        root,
        db,
        commit_id,
        state.squash_msg,
        false,
        message_editor,
      )
      match result.status {
        IRBConflict => {
          let new_state = interactive_move_to_done(state)
          save_interactive_rebase_state(fs, git_dir, new_state)
          return result
        }
        _ => {
          let new_state : InteractiveRebaseState = {
            ..interactive_move_to_done(state),
            squash_msg: result.message,
          }
          save_interactive_rebase_state(fs, git_dir, new_state)
          execute_interactive_todo(fs, rfs, root, new_state, message_editor, exec_runner~)
        }
      }
    }
    Fixup => {
      let result = interactive_squash_into_head(
        fs,
        rfs,
        root,
        db,
        commit_id,
        state.squash_msg,
        true,
        message_editor,
      )
      match result.status {
        IRBConflict => {
          let new_state = interactive_move_to_done(state)
          save_interactive_rebase_state(fs, git_dir, new_state)
          return result
        }
        _ => {
          let new_state : InteractiveRebaseState = {
            ..interactive_move_to_done(state),
            squash_msg: result.message,
          }
          save_interactive_rebase_state(fs, git_dir, new_state)
          execute_interactive_todo(fs, rfs, root, new_state, message_editor, exec_runner~)
        }
      }
    }
    Drop => {
      // Simply skip this commit
      let new_state = interactive_move_to_done(state)
      save_interactive_rebase_state(fs, git_dir, new_state)
      execute_interactive_todo(fs, rfs, root, new_state, message_editor, exec_runner~)
    }
    Exec => {
      let cmd = entry.subject
      let new_state = interactive_move_to_done(state)
      save_interactive_rebase_state(fs, git_dir, new_state)
      let code = match exec_runner {
        Some(runner) => runner(cmd) catch { _ => 1 }
        None => 0 // No runner: skip exec commands silently
      }
      if code != 0 {
        // exec failed — stop and let user fix
        {
          status: IRBStopped,
          commit_id: resolve_head_commit(rfs, git_dir),
          message: "Execution failed: \{cmd} (exit code \{code})\nYou can fix the problem, and then run \"git rebase --continue\".",
        }
      } else {
        execute_interactive_todo(fs, rfs, root, new_state, message_editor, exec_runner~)
      }
    }
    Break => {
      let new_state = interactive_move_to_done(state)
      save_interactive_rebase_state(fs, git_dir, new_state)
      {
        status: IRBStopped,
        commit_id: resolve_head_commit(rfs, git_dir),
        message: "Stopped at break point.\nYou can run \"git rebase --continue\" to resume.",
      }
    }
  }
}

///|
fn interactive_move_to_done(
  state : InteractiveRebaseState,
) -> InteractiveRebaseState {
  let new_done = state.done.copy()
  if state.todo.length() > 0 {
    new_done.push(state.todo[0])
  }
  let new_todo = []
  for i = 1; i < state.todo.length(); i = i + 1 {
    new_todo.push(state.todo[i])
  }
  {
    onto: state.onto,
    orig_head: state.orig_head,
    head_name: state.head_name,
    todo: new_todo,
    done: new_done,
    amend: false,
    squash_msg: state.squash_msg,
  }
}

// ============================================================================
// Interactive Rebase: cherry-pick a single commit
// ============================================================================

///|
fn interactive_cherry_pick(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  db : ObjectDb,
  commit_id : @bit.ObjectId,
) -> InteractiveRebaseResult raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let info = rebase_parse_commit_full(db, rfs, commit_id)
  let parent_id = if info.parents.length() > 0 {
    info.parents[0]
  } else {
    raise @bit.GitError::InvalidObject("Cannot cherry-pick root commit")
  }
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(base_id) else {
    raise @bit.GitError::InvalidObject("No HEAD commit")
  }
  let base_map = rebase_tree_map(db, rfs, base_id)
  let parent_map = rebase_tree_map(db, rfs, parent_id)
  let commit_map = rebase_tree_map_from_tree(db, rfs, info.tree)
  let changes = rebase_diff_maps(parent_map, commit_map)
  // Check if already applied
  if rebase_changes_already_applied(db, rfs, base_map, parent_map, changes) {
    return {
      status: IRBComplete,
      commit_id: Some(base_id),
      message: "already applied",
    }
  }
  // Apply changes with conflict detection
  let conflicts = rebase_apply_changes_with_conflicts(
    db, rfs, fs, root, base_map, parent_map, changes,
  )
  if conflicts.length() > 0 {
    // Write partial worktree (skip conflicting files)
    rebase_write_worktree_except(
      fs, db, rfs, root, git_dir, base_map, conflicts,
    )
    let entries = rebase_map_to_index(db, rfs, base_map)
    write_index_entries(fs, git_dir, entries)
    return {
      status: IRBConflict,
      commit_id: Some(commit_id),
      message: "CONFLICT: resolve conflicts then run 'git rebase --continue'",
    }
  }
  // Create new commit
  let new_tree = rebase_write_tree_from_map(fs, git_dir, base_map)
  let new_commit = @bit.Commit::new(
    new_tree,
    [base_id],
    info.author,
    info.author_time,
    info.author_tz,
    info.committer,
    info.commit_time,
    info.committer_tz,
    info.message,
  )
  let (new_id, compressed) = @bit.create_commit(new_commit)
  rebase_write_object(fs, git_dir, new_id, compressed)
  rebase_update_head(fs, rfs, git_dir, new_id)
  // Update worktree + index
  rebase_write_worktree(fs, db, rfs, root, git_dir, base_map)
  let entries = rebase_map_to_index(db, rfs, base_map)
  write_index_entries(fs, git_dir, entries)
  { status: IRBComplete, commit_id: Some(new_id), message: "" }
}

// ============================================================================
// Interactive Rebase: amend HEAD message
// ============================================================================

///|
fn interactive_amend_head_message(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  db : ObjectDb,
  new_message : String,
) -> Unit raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(head_id) else {
    raise @bit.GitError::InvalidObject("No HEAD commit")
  }
  let info = rebase_parse_commit_full(db, rfs, head_id)
  let new_commit = @bit.Commit::new(
    info.tree,
    info.parents,
    info.author,
    info.author_time,
    info.author_tz,
    info.committer,
    info.commit_time,
    info.committer_tz,
    new_message,
  )
  let (new_id, compressed) = @bit.create_commit(new_commit)
  rebase_write_object(fs, git_dir, new_id, compressed)
  rebase_update_head(fs, rfs, git_dir, new_id)
}

// ============================================================================
// Interactive Rebase: squash into HEAD
// ============================================================================

///|
async fn interactive_squash_into_head(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  db : ObjectDb,
  commit_id : @bit.ObjectId,
  prev_squash_msg : String,
  fixup : Bool,
  message_editor : async (String) -> String?,
) -> InteractiveRebaseResult raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let info = rebase_parse_commit_full(db, rfs, commit_id)
  let parent_id = if info.parents.length() > 0 {
    info.parents[0]
  } else {
    raise @bit.GitError::InvalidObject("Cannot squash root commit")
  }
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(head_id) else {
    raise @bit.GitError::InvalidObject("No HEAD commit")
  }
  let head_info = rebase_parse_commit_full(db, rfs, head_id)
  // Apply the commit's changes on top of HEAD
  let base_map = rebase_tree_map(db, rfs, head_id)
  let parent_map = rebase_tree_map(db, rfs, parent_id)
  let commit_map = rebase_tree_map_from_tree(db, rfs, info.tree)
  let changes = rebase_diff_maps(parent_map, commit_map)
  let conflicts = rebase_apply_changes_with_conflicts(
    db, rfs, fs, root, base_map, parent_map, changes,
  )
  if conflicts.length() > 0 {
    rebase_write_worktree_except(
      fs, db, rfs, root, git_dir, base_map, conflicts,
    )
    let entries = rebase_map_to_index(db, rfs, base_map)
    write_index_entries(fs, git_dir, entries)
    return {
      status: IRBConflict,
      commit_id: Some(commit_id),
      message: "CONFLICT during squash",
    }
  }
  // Build combined message
  let head_msg = if prev_squash_msg.length() > 0 {
    prev_squash_msg
  } else {
    head_info.message
  }
  let combined_msg = if fixup {
    head_msg
  } else {
    head_msg + "\n\n" + info.message
  }
  // For squash (not fixup), let user edit the combined message
  let final_msg = if fixup {
    combined_msg
  } else {
    let edited_squash_msg = message_editor(combined_msg) catch { _ => None }
    match edited_squash_msg {
      Some(edited) => edited
      None => combined_msg
    }
  }
  // Create new commit replacing HEAD with squashed tree
  let new_tree = rebase_write_tree_from_map(fs, git_dir, base_map)
  let new_commit = @bit.Commit::new(
    new_tree,
    head_info.parents,
    head_info.author,
    head_info.author_time,
    head_info.author_tz,
    head_info.committer,
    head_info.commit_time,
    head_info.committer_tz,
    final_msg,
  )
  let (new_id, compressed) = @bit.create_commit(new_commit)
  rebase_write_object(fs, git_dir, new_id, compressed)
  rebase_update_head(fs, rfs, git_dir, new_id)
  // Update worktree + index
  rebase_write_worktree(fs, db, rfs, root, git_dir, base_map)
  let entries = rebase_map_to_index(db, rfs, base_map)
  write_index_entries(fs, git_dir, entries)
  { status: IRBComplete, commit_id: Some(new_id), message: final_msg }
}

// ============================================================================
// Interactive Rebase: continue / skip / abort
// ============================================================================

///|
pub async fn interactive_rebase_continue_impl(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  message_editor : async (String) -> String?,
  exec_runner? : (async (String) -> Int)? = None,
) -> InteractiveRebaseResult raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let state = load_interactive_rebase_state(rfs, git_dir)
  guard state is Some(s) else {
    raise @bit.GitError::InvalidObject("No interactive rebase in progress")
  }
  if s.amend {
    // Continuing after an "edit" stop: create commit from current worktree
    let db = ObjectDb::load(rfs, git_dir)
    let head = resolve_head_commit(rfs, git_dir)
    guard head is Some(head_id) else {
      raise @bit.GitError::InvalidObject("No HEAD commit")
    }
    let head_info = rebase_parse_commit_full(db, rfs, head_id)
    // Build tree from current index
    let entries = read_index_entries(rfs, git_dir)
    let new_tree = write_tree_from_entries(fs, rfs, git_dir, entries, None)
    // If tree changed, amend the commit
    if new_tree != head_info.tree {
      let new_commit = @bit.Commit::new(
        new_tree,
        head_info.parents,
        head_info.author,
        head_info.author_time,
        head_info.author_tz,
        head_info.committer,
        head_info.commit_time,
        head_info.committer_tz,
        head_info.message,
      )
      let (new_id, compressed) = @bit.create_commit(new_commit)
      rebase_write_object(fs, git_dir, new_id, compressed)
      rebase_update_head(fs, rfs, git_dir, new_id)
    }
    // Clear amend flag and continue
    let new_state : InteractiveRebaseState = { ..s, amend: false }
    save_interactive_rebase_state(fs, git_dir, new_state)
    return execute_interactive_todo(fs, rfs, root, new_state, message_editor, exec_runner~)
  }
  // Continuing after a conflict: commit the resolved changes
  let db = ObjectDb::load(rfs, git_dir)
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(parent_id) else {
    raise @bit.GitError::InvalidObject("No HEAD commit")
  }
  // Build tree from current index (user resolved conflicts)
  let entries = read_index_entries(rfs, git_dir)
  let new_tree = write_tree_from_entries(fs, rfs, git_dir, entries, None)
  // Get info from the last done entry (the conflicting commit)
  if s.done.length() > 0 {
    let last_done = s.done[s.done.length() - 1]
    let commit_id = @bit.ObjectId::from_hex(last_done.commit_hex)
    let info = rebase_parse_commit_full(db, rfs, commit_id)
    let new_commit = @bit.Commit::new(
      new_tree,
      [parent_id],
      info.author,
      info.author_time,
      info.author_tz,
      info.committer,
      info.commit_time,
      info.committer_tz,
      info.message,
    )
    let (new_id, compressed) = @bit.create_commit(new_commit)
    rebase_write_object(fs, git_dir, new_id, compressed)
    rebase_update_head(fs, rfs, git_dir, new_id)
  }
  // Continue with remaining todo
  save_interactive_rebase_state(fs, git_dir, s)
  execute_interactive_todo(fs, rfs, root, s, message_editor, exec_runner~)
}

///|
pub async fn interactive_rebase_skip_impl(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  message_editor : async (String) -> String?,
  exec_runner? : (async (String) -> Int)? = None,
) -> InteractiveRebaseResult raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let state = load_interactive_rebase_state(rfs, git_dir)
  guard state is Some(s) else {
    raise @bit.GitError::InvalidObject("No interactive rebase in progress")
  }
  // Reset worktree to current HEAD
  let db = ObjectDb::load(rfs, git_dir)
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(h) else {
    raise @bit.GitError::InvalidObject("No HEAD commit")
  }
  let tree_map = rebase_tree_map(db, rfs, h)
  rebase_write_worktree(fs, db, rfs, root, git_dir, tree_map)
  let entries = rebase_map_to_index(db, rfs, tree_map)
  write_index_entries(fs, git_dir, entries)
  // Clear amend flag if set
  let new_state : InteractiveRebaseState = { ..s, amend: false }
  save_interactive_rebase_state(fs, git_dir, new_state)
  execute_interactive_todo(fs, rfs, root, new_state, message_editor, exec_runner~)
}

///|
pub fn interactive_rebase_abort_impl(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
) -> Unit raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let state = load_interactive_rebase_state(rfs, git_dir)
  guard state is Some(s) else {
    raise @bit.GitError::InvalidObject("No interactive rebase in progress")
  }
  // Restore original HEAD
  let head_path = join_path(git_dir, "HEAD")
  if s.head_name.length() > 0 {
    fs.write_string(head_path, "ref: " + s.head_name + "\n")
    let ref_path = join_path(git_dir, s.head_name)
    let dir = parent_dir(ref_path)
    if dir.length() > 0 {
      fs.mkdir_p(dir)
    }
    fs.write_string(ref_path, s.orig_head.to_hex() + "\n")
  } else {
    fs.write_string(head_path, s.orig_head.to_hex() + "\n")
  }
  // Restore worktree to original HEAD
  let db = ObjectDb::load(rfs, git_dir)
  let tree_map = rebase_tree_map(db, rfs, s.orig_head)
  rebase_write_worktree(fs, db, rfs, root, git_dir, tree_map) catch {
    _ => ()
  }
  let entries = rebase_map_to_index(db, rfs, tree_map) catch { _ => [] }
  write_index_entries(fs, git_dir, entries) catch {
    _ => ()
  }
  // Clear rebase state
  clear_rebase_state(fs, rfs, git_dir)
}

// ============================================================================
// Interactive Rebase: finish (restore branch, clean up)
// ============================================================================

///|
fn interactive_rebase_finish(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  state : InteractiveRebaseState,
) -> InteractiveRebaseResult raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let db = ObjectDb::load(rfs, git_dir)
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(final_id) else {
    raise @bit.GitError::InvalidObject("No HEAD after rebase")
  }
  // Update worktree + index to final state
  let final_map = rebase_tree_map(db, rfs, final_id)
  rebase_write_worktree(fs, db, rfs, root, git_dir, final_map)
  let entries = rebase_map_to_index(db, rfs, final_map)
  write_index_entries(fs, git_dir, entries)
  // Restore branch ref if applicable
  if state.head_name.length() > 0 {
    let head_path = join_path(git_dir, "HEAD")
    fs.write_string(head_path, "ref: " + state.head_name + "\n")
    let ref_path = join_path(git_dir, state.head_name)
    let dir = parent_dir(ref_path)
    if dir.length() > 0 {
      fs.mkdir_p(dir)
    }
    fs.write_string(ref_path, final_id.to_hex() + "\n")
  }
  // Clean up rebase state
  clear_rebase_state(fs, rfs, git_dir)
  {
    status: IRBComplete,
    commit_id: Some(final_id),
    message: "Successfully rebased.",
  }
}

///|
/// Check if an interactive rebase is in progress.
pub fn is_interactive_rebase_in_progress(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
) -> Bool {
  let rebase_dir = join_path(git_dir, "rebase-merge")
  rfs.is_dir(rebase_dir) && rfs.is_file(join_path(rebase_dir, "interactive"))
}
