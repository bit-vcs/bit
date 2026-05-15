///| Git stash implementation

///|
pub struct StashEntry {
  id : @bit.ObjectId
  message : String
}

///|
pub(all) struct StashPatchHunk {
  path : String
  display_lines : Array[String]
}

///|
priv struct StashPatchInternalHunk {
  prompt : StashPatchHunk
  old_start : Int
  lines : Array[String]
}

///|
priv struct StashPatchFile {
  path : String
  old_content : Bytes?
  new_content : Bytes?
  old_mode : Int?
  new_mode : Int?
  hunks : Array[StashPatchInternalHunk]
}

///|
priv struct StashPatchContent {
  content : Bytes?
  mode : Int
}

///|
/// List all stash entries.
pub fn stash_list(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
) -> Array[StashEntry] raise @bit.GitError {
  let stash_ref_path = git_dir + "/refs/stash"
  if !fs.is_file(stash_ref_path) {
    return []
  }
  // Read reflog for stash
  let reflog_path = git_dir + "/logs/refs/stash"
  if !fs.is_file(reflog_path) {
    // Just return the current stash
    let content = @utf8.decode_lossy(fs.read_file(stash_ref_path)[:])
    let hex = content.trim_end(chars="\n\r ").to_string()
    let id = @bit.ObjectId::from_hex(hex)
    return [{ id, message: "WIP on HEAD" }]
  }
  let log_content = @utf8.decode_lossy(fs.read_file(reflog_path)[:])
  let entries : Array[StashEntry] = []
  for line_view in log_content.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    // Format: <old-sha> <new-sha> <name> <email> <timestamp> <tz>\t<message>
    let tab_idx = line.find("\t")
    match tab_idx {
      None => continue
      Some(idx) => {
        let prefix = String::unsafe_substring(line, start=0, end=idx)
        let message = String::unsafe_substring(
          line,
          start=idx + 1,
          end=line.length(),
        )
        let parts = prefix.split(" ").map(v => v.to_string()).collect()
        if parts.length() >= 2 {
          let new_sha = parts[1]
          let id = @bit.ObjectId::from_hex(new_sha) catch { _ => continue }
          entries.push({ id, message })
        }
      }
    }
  }
  // Reverse to show newest first
  entries.rev_in_place()
  entries
}

///|
/// Push current changes to stash.
pub async fn stash_push(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  message : String,
  author : String,
  timestamp : Int64,
) -> @bit.ObjectId? raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  // Check if there are changes
  let st = status(rfs, root)
  if st.staged_added.length() == 0 &&
    st.staged_modified.length() == 0 &&
    st.staged_deleted.length() == 0 &&
    st.unstaged_modified.length() == 0 &&
    st.unstaged_deleted.length() == 0 {
    return None
  }
  // Get current HEAD
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(head_id) else {
    raise @bit.GitError::InvalidObject("HEAD not found")
  }
  // Create tree from current index
  let index_entries = read_index_entries(rfs, git_dir)
  let index_tree = write_tree_from_index(fs, rfs, git_dir, index_entries)
  // Create tree from worktree (also writes blobs to object store)
  let worktree_entries = build_worktree_index(
    fs, rfs, git_dir, root, index_entries,
  )
  let worktree_tree = write_tree_from_index(fs, rfs, git_dir, worktree_entries)
  let stash_id = stash_store_entry(
    fs, rfs, git_dir, head_id, index_tree, worktree_tree, message, author, timestamp,
  )
  // Reset worktree to HEAD
  let db = ObjectDb::load(rfs, git_dir)
  let head_files = collect_tree_files_from_commit(db, rfs, head_id)
  write_worktree_from_files(db, fs, rfs, root, git_dir, head_files)
  // Reset index to HEAD
  let head_entries = tree_files_to_index(db, rfs, head_files)
  write_index_entries(fs, git_dir, head_entries)
  Some(stash_id)
}

///|
pub async fn stash_push_patch(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  message : String,
  author : String,
  timestamp : Int64,
  select_hunk : async (StashPatchHunk, Int, Int) -> Bool,
) -> @bit.ObjectId? raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(head_id) else {
    raise @bit.GitError::InvalidObject("HEAD not found")
  }
  let db = ObjectDb::load_lazy(rfs, git_dir)
  let head_files = collect_tree_files_from_commit(db, rfs, head_id)
  let index_entries = read_index_entries(rfs, git_dir)
  let patch_files = stash_collect_patch_files(
    rfs, root, db, head_files, index_entries,
  )
  let total = patch_files
    .iter()
    .fold(init=0, fn(acc, file) { acc + file.hunks.length() })
  if total == 0 {
    return None
  }
  let selected_by_path : Map[String, Array[Bool]] = {}
  let mut selected_count = 0
  let mut hunk_index = 0
  for file in patch_files {
    let choices : Array[Bool] = []
    for hunk in file.hunks {
      let selected = select_hunk(hunk.prompt, hunk_index, total) catch {
        _ => false
      }
      choices.push(selected)
      if selected {
        selected_count += 1
      }
      hunk_index += 1
    }
    selected_by_path[file.path] = choices
  }
  if selected_count == 0 {
    return None
  }
  let selected_overrides : Map[String, StashPatchContent] = {}
  let remaining_overrides : Map[String, StashPatchContent] = {}
  for file in patch_files {
    let selected = selected_by_path[file.path]
    let selected_content = stash_patch_apply_selection(
      file.old_content,
      file.new_content,
      file.hunks,
      selected,
    )
    let remaining_choices = selected.map(fn(v) { !v })
    let remaining_content = stash_patch_apply_selection(
      file.old_content,
      file.new_content,
      file.hunks,
      remaining_choices,
    )
    let selected_mode = stash_patch_result_mode(
      file.old_mode,
      file.new_mode,
      selected,
    )
    let remaining_mode = stash_patch_result_mode(
      file.old_mode,
      file.new_mode,
      remaining_choices,
    )
    selected_overrides[file.path] = {
      content: selected_content,
      mode: selected_mode,
    }
    remaining_overrides[file.path] = {
      content: remaining_content,
      mode: remaining_mode,
    }
  }
  let selected_entries = stash_build_patch_tree_entries(
    fs, rfs, git_dir, db, head_files, selected_overrides,
  )
  let worktree_tree = write_tree_from_index(fs, rfs, git_dir, selected_entries)
  let index_tree = write_tree_from_index(fs, rfs, git_dir, index_entries)
  let stash_id = stash_store_entry(
    fs, rfs, git_dir, head_id, index_tree, worktree_tree, message, author, timestamp,
  )
  stash_write_patch_remaining_worktree(fs, rfs, root, remaining_overrides)
  Some(stash_id)
}

///|
fn stash_store_entry(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  head_id : @bit.ObjectId,
  index_tree : @bit.ObjectId,
  worktree_tree : @bit.ObjectId,
  message : String,
  author : String,
  timestamp : Int64,
) -> @bit.ObjectId raise @bit.GitError {
  let index_commit = @bit.Commit::new(
    index_tree,
    [head_id],
    author,
    timestamp,
    "+0000",
    author,
    timestamp,
    "+0000",
    "index on HEAD",
  )
  let (index_commit_id, index_commit_data) = @bit.create_commit(index_commit)
  write_object_bytes(fs, git_dir, index_commit_id, index_commit_data)
  let stash_msg = if message.length() > 0 { message } else { "WIP on HEAD" }
  let stash_commit = @bit.Commit::new(
    worktree_tree,
    [head_id, index_commit_id],
    author,
    timestamp,
    "+0000",
    author,
    timestamp,
    "+0000",
    stash_msg,
  )
  let (stash_id, stash_data) = @bit.create_commit(stash_commit)
  write_object_bytes(fs, git_dir, stash_id, stash_data)
  let stash_ref_path = git_dir + "/refs/stash"
  let old_id = if rfs.is_file(stash_ref_path) {
    let content = @utf8.decode_lossy(rfs.read_file(stash_ref_path)[:])
    let hex = content.trim_end(chars="\n\r ").to_string()
    let parsed : Result[@bit.ObjectId, Error] = try? @bit.ObjectId::from_hex(
      hex,
    )
    match parsed {
      Ok(id) => id
      Err(_) => @bit.ObjectId::zero()
    }
  } else {
    @bit.ObjectId::zero()
  }
  fs.write_string(stash_ref_path, stash_id.to_hex() + "\n")
  let reflog_dir = git_dir + "/logs/refs"
  fs.mkdir_p(reflog_dir)
  let reflog_path = reflog_dir + "/stash"
  let reflog_entry = "\{old_id.to_hex()} \{stash_id.to_hex()} \{author} \{timestamp} +0000\t\{stash_msg}\n"
  let existing = if rfs.is_file(reflog_path) {
    @utf8.decode_lossy(rfs.read_file(reflog_path)[:])
  } else {
    ""
  }
  fs.write_string(reflog_path, existing + reflog_entry)
  stash_id
}

///|
fn build_worktree_index(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  root : String,
  index_entries : Array[IndexEntry],
) -> Array[IndexEntry] raise @bit.GitError {
  let result : Array[IndexEntry] = []
  for e in index_entries {
    let abs = join_path(root, e.path)
    if rfs.is_file(abs) {
      let content = rfs.read_file(abs)
      // Write blob to object store
      let id = write_loose_object(fs, git_dir, @bit.ObjectType::Blob, content)
      result.push({
        path: e.path,
        id,
        mode: e.mode,
        size: content.length(),
        mtime_sec: 0,
        mtime_nsec: 0,
        intent_to_add: false,
        dev: 0,
        ino: 0,
        uid: 0,
        gid: 0,
      })
    }
    // Skip deleted files
  }
  result
}

///|
fn stash_collect_patch_files(
  rfs : &@bit.RepoFileSystem,
  root : String,
  db : ObjectDb,
  head_files : Map[String, TreeFileEntry],
  index_entries : Array[IndexEntry],
) -> Array[StashPatchFile] raise @bit.GitError {
  let path_set : Map[String, Bool] = {}
  for item in head_files.to_array() {
    let (path, _) = item
    path_set[path] = true
  }
  for entry in index_entries {
    path_set[entry.path] = true
  }
  let paths : Array[String] = []
  for item in path_set.to_array() {
    let (path, _) = item
    paths.push(path)
  }
  paths.sort()
  let files : Array[StashPatchFile] = []
  for path in paths {
    let old_entry = head_files.get(path)
    let old_mode = match old_entry {
      Some(info) => Some(info.mode)
      None => None
    }
    let index_mode = stash_index_mode(index_entries, path)
    if stash_is_gitlink_mode(old_mode) || stash_is_gitlink_mode(index_mode) {
      continue
    }
    let old_content = match old_entry {
      Some(info) => stash_read_tree_blob(db, rfs, info)
      None => None
    }
    let abs = join_path(root, path)
    let new_content = if rfs.is_file(abs) {
      Some(rfs.read_file(abs))
    } else {
      None
    }
    let new_mode = match new_content {
      Some(_) => Some(index_mode.unwrap_or(old_mode.unwrap_or(0o100644)))
      None => None
    }
    if stash_same_content(old_content, new_content) &&
      stash_same_mode(old_mode, new_mode) {
      continue
    }
    let hunks = stash_build_patch_hunks(path, old_content, new_content)
    if hunks.length() == 0 {
      continue
    }
    files.push({ path, old_content, new_content, old_mode, new_mode, hunks })
  }
  files
}

///|
fn stash_index_mode(entries : Array[IndexEntry], path : String) -> Int? {
  for entry in entries {
    if entry.path == path {
      return Some(entry.mode)
    }
  }
  None
}

///|
fn stash_is_gitlink_mode(mode : Int?) -> Bool {
  match mode {
    Some(m) => is_gitlink_mode_int(m)
    None => false
  }
}

///|
fn stash_read_tree_blob(
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
  info : TreeFileEntry,
) -> Bytes? raise @bit.GitError {
  if is_gitlink_mode_int(info.mode) {
    return None
  }
  let obj = db.get(rfs, info.id)
  match obj {
    Some(o) if o.obj_type == @bit.ObjectType::Blob => Some(o.data)
    _ => None
  }
}

///|
fn stash_same_mode(left : Int?, right : Int?) -> Bool {
  match (left, right) {
    (None, None) => true
    (Some(a), Some(b)) => a == b
    _ => false
  }
}

///|
fn stash_same_content(left : Bytes?, right : Bytes?) -> Bool {
  match (left, right) {
    (None, None) => true
    (Some(a), Some(b)) => stash_bytes_equal(a, b)
    _ => false
  }
}

///|
fn stash_bytes_equal(left : Bytes, right : Bytes) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if left[i] != right[i] {
      return false
    }
  }
  true
}

///|
fn stash_build_patch_hunks(
  path : String,
  old_content : Bytes?,
  new_content : Bytes?,
) -> Array[StashPatchInternalHunk] {
  let lines : Array[String] = []
  @diff_core.unified_hunks(lines, old_content, new_content)
  let hunks : Array[StashPatchInternalHunk] = []
  let display_header = stash_patch_display_header(
    path, old_content, new_content,
  )
  let mut current_header = ""
  let mut current_old_start = 0
  let mut current_lines : Array[String] = []
  for line in lines {
    if line.has_prefix("@@ ") {
      if current_header.length() > 0 {
        stash_push_internal_hunk(
          hunks, path, display_header, current_header, current_old_start, current_lines,
        )
        current_lines = []
      }
      current_header = line
      match stash_parse_hunk_header(line) {
        Some((os, _, _, _)) => current_old_start = os
        None => current_old_start = 0
      }
    } else if current_header.length() > 0 {
      current_lines.push(line)
    }
  }
  if current_header.length() > 0 {
    stash_push_internal_hunk(
      hunks, path, display_header, current_header, current_old_start, current_lines,
    )
  }
  hunks
}

///|
fn stash_patch_display_header(
  path : String,
  old_content : Bytes?,
  new_content : Bytes?,
) -> Array[String] {
  let lines = ["diff --git a/\{path} b/\{path}"]
  match old_content {
    Some(_) => lines.push("--- a/\{path}")
    None => lines.push("--- /dev/null")
  }
  match new_content {
    Some(_) => lines.push("+++ b/\{path}")
    None => lines.push("+++ /dev/null")
  }
  lines
}

///|
fn stash_push_internal_hunk(
  hunks : Array[StashPatchInternalHunk],
  path : String,
  display_header : Array[String],
  header : String,
  old_start : Int,
  lines : Array[String],
) -> Unit {
  let display_lines = display_header.copy()
  display_lines.push(header)
  for line in lines {
    display_lines.push(line)
  }
  hunks.push({ prompt: { path, display_lines }, old_start, lines })
}

///|
fn stash_parse_hunk_header(line : String) -> (Int, Int, Int, Int)? {
  if !line.has_prefix("@@ ") {
    return None
  }
  let content = String::unsafe_substring(line, start=3, end=line.length())
  match content.find(" @@") {
    None => None
    Some(end) => {
      let range_part = String::unsafe_substring(content, start=0, end~)
      let parts : Array[String] = range_part
        .split(" ")
        .map(v => v.to_string())
        .collect()
      if parts.length() < 2 {
        return None
      }
      let old_part = parts[0]
      let new_part = parts[1]
      if old_part.length() == 0 || new_part.length() == 0 {
        return None
      }
      let (old_start, old_count) = stash_parse_hunk_range(
        String::unsafe_substring(old_part, start=1, end=old_part.length()),
      )
      let (new_start, new_count) = stash_parse_hunk_range(
        String::unsafe_substring(new_part, start=1, end=new_part.length()),
      )
      Some((old_start, old_count, new_start, new_count))
    }
  }
}

///|
fn stash_parse_hunk_range(s : String) -> (Int, Int) {
  match s.find(",") {
    Some(idx) => {
      let start_str = String::unsafe_substring(s, start=0, end=idx)
      let count_str = String::unsafe_substring(s, start=idx + 1, end=s.length())
      let start = @string.parse_int(start_str) catch { _ => 1 }
      let count = @string.parse_int(count_str) catch { _ => 1 }
      (start, count)
    }
    None => {
      let start = @string.parse_int(s) catch { _ => 1 }
      (start, 1)
    }
  }
}

///|
fn stash_patch_apply_selection(
  old_content : Bytes?,
  new_content : Bytes?,
  hunks : Array[StashPatchInternalHunk],
  selected : Array[Bool],
) -> Bytes? {
  let mut selected_count = 0
  for v in selected {
    if v {
      selected_count += 1
    }
  }
  if selected_count == 0 {
    return old_content
  }
  if new_content is None && selected_count == hunks.length() {
    return None
  }
  let old_lines = match old_content {
    Some(data) => @diff_core.split_lines(data)
    None => []
  }
  let result_lines : Array[String] = []
  let mut line_idx = 0
  for i in 0..<hunks.length() {
    if i >= selected.length() || !selected[i] {
      continue
    }
    let hunk = hunks[i]
    let old_start_index = if hunk.old_start > 0 {
      hunk.old_start - 1
    } else {
      0
    }
    while line_idx < old_start_index && line_idx < old_lines.length() {
      result_lines.push(old_lines[line_idx])
      line_idx += 1
    }
    for line in hunk.lines {
      if line.has_prefix("\\") {
        continue
      } else if line.has_prefix("+") {
        result_lines.push(
          String::unsafe_substring(line, start=1, end=line.length()),
        )
      } else if line.has_prefix("-") {
        if line_idx < old_lines.length() {
          line_idx += 1
        }
      } else if line.has_prefix(" ") {
        if line_idx < old_lines.length() {
          result_lines.push(old_lines[line_idx])
        } else {
          result_lines.push(
            String::unsafe_substring(line, start=1, end=line.length()),
          )
        }
        line_idx += 1
      }
    }
  }
  while line_idx < old_lines.length() {
    result_lines.push(old_lines[line_idx])
    line_idx += 1
  }
  let trailing_newline = match new_content {
    Some(data) => data.length() > 0 && data[data.length() - 1] == b'\n'
    None =>
      match old_content {
        Some(data) => data.length() > 0 && data[data.length() - 1] == b'\n'
        None => true
      }
  }
  Some(stash_join_lines(result_lines, trailing_newline))
}

///|
fn stash_join_lines(lines : Array[String], trailing_newline : Bool) -> Bytes {
  let text = if lines.length() == 0 {
    ""
  } else {
    let joined = lines.join("\n")
    if trailing_newline {
      joined + "\n"
    } else {
      joined
    }
  }
  @utf8.encode(text)
}

///|
fn stash_patch_result_mode(
  old_mode : Int?,
  new_mode : Int?,
  selected : Array[Bool],
) -> Int {
  let mut selected_count = 0
  for v in selected {
    if v {
      selected_count += 1
    }
  }
  if selected_count > 0 {
    new_mode.unwrap_or(old_mode.unwrap_or(0o100644))
  } else {
    old_mode.unwrap_or(new_mode.unwrap_or(0o100644))
  }
}

///|
fn stash_build_patch_tree_entries(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  db : ObjectDb,
  head_files : Map[String, TreeFileEntry],
  overrides : Map[String, StashPatchContent],
) -> Array[IndexEntry] raise @bit.GitError {
  let path_set : Map[String, Bool] = {}
  for item in head_files.to_array() {
    let (path, _) = item
    path_set[path] = true
  }
  for item in overrides.to_array() {
    let (path, _) = item
    path_set[path] = true
  }
  let paths : Array[String] = []
  for item in path_set.to_array() {
    let (path, _) = item
    paths.push(path)
  }
  paths.sort()
  let entries : Array[IndexEntry] = []
  for path in paths {
    match overrides.get(path) {
      Some(patch_content) =>
        match patch_content.content {
          Some(content) => {
            let id = write_loose_object(
              fs,
              git_dir,
              @bit.ObjectType::Blob,
              content,
            )
            entries.push(
              IndexEntry::new(path, id, patch_content.mode, content.length()),
            )
          }
          None => ()
        }
      None =>
        match head_files.get(path) {
          Some(info) =>
            entries.push(stash_index_entry_from_tree(db, rfs, path, info))
          None => ()
        }
    }
  }
  entries
}

///|
fn stash_index_entry_from_tree(
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
  path : String,
  info : TreeFileEntry,
) -> IndexEntry raise @bit.GitError {
  if is_gitlink_mode_int(info.mode) {
    return IndexEntry::new(path, info.id, info.mode, 0)
  }
  let obj = db.get(rfs, info.id)
  let size = match obj {
    Some(o) if o.obj_type == @bit.ObjectType::Blob => o.data.length()
    _ => 0
  }
  IndexEntry::new(path, info.id, info.mode, size)
}

///|
fn stash_write_patch_remaining_worktree(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  overrides : Map[String, StashPatchContent],
) -> Unit raise @bit.GitError {
  for item in overrides.to_array() {
    let (path, content) = item
    let abs = join_path(root, path)
    match content.content {
      Some(bytes) => {
        match abs.rev_find("/") {
          Some(idx) => {
            let dir = String::unsafe_substring(abs, start=0, end=idx)
            fs.mkdir_p(dir)
          }
          None => ()
        }
        fs.write_file(abs, bytes)
      }
      None => if rfs.is_file(abs) { fs.remove_file(abs) }
    }
  }
}

///|
/// Apply stash entry (optionally dropping it).
pub fn stash_apply(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  index : Int,
  drop : Bool,
) -> Unit raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  let entries = stash_list(rfs, git_dir)
  if index >= entries.length() {
    raise @bit.GitError::InvalidObject("No stash entry at index \{index}")
  }
  let entry = entries[index]
  // Get stash commit
  let db = ObjectDb::load(rfs, git_dir)
  let obj = db.get(rfs, entry.id)
  guard obj is Some(stash_obj) else {
    raise @bit.GitError::InvalidObject("Stash object not found")
  }
  if stash_obj.obj_type != @bit.ObjectType::Commit {
    raise @bit.GitError::InvalidObject("Invalid stash entry")
  }
  let commit_info = @bit.parse_commit(stash_obj.data)
  // Apply worktree state from stash
  let stash_files = collect_tree_files(db, rfs, commit_info.tree)
  write_worktree_from_files(
    db,
    fs,
    rfs,
    root,
    git_dir,
    stash_files,
    remove_missing=false,
  )
  // Also update index from first parent's second parent (index commit) if exists
  if commit_info.parents.length() >= 2 {
    let index_commit_id = commit_info.parents[1]
    let index_obj = db.get(rfs, index_commit_id)
    match index_obj {
      Some(idx_obj) if idx_obj.obj_type == @bit.ObjectType::Commit => {
        let idx_info = @bit.parse_commit(idx_obj.data)
        let idx_files = collect_tree_files(db, rfs, idx_info.tree)
        let idx_entries = tree_files_to_index(db, rfs, idx_files)
        write_index_entries(fs, git_dir, idx_entries)
      }
      _ => ()
    }
  }
  if drop {
    stash_drop_at(fs, rfs, git_dir, index)
  }
}

///|
/// Drop stash entry at index.
pub fn stash_drop(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  index : Int,
) -> Unit raise @bit.GitError {
  let git_dir = join_path(root, ".git")
  stash_drop_at(fs, rfs, git_dir, index)
}

///|
fn stash_drop_at(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  index : Int,
) -> Unit raise @bit.GitError {
  let entries = stash_list(rfs, git_dir)
  if index >= entries.length() {
    raise @bit.GitError::InvalidObject("No stash entry at index \{index}")
  }
  // Rebuild reflog without the entry
  let reflog_path = git_dir + "/logs/refs/stash"
  if !rfs.is_file(reflog_path) {
    // Only one entry, just remove refs/stash
    let stash_ref = git_dir + "/refs/stash"
    fs.remove_file(stash_ref)
    return ()
  }
  let log_content = @utf8.decode_lossy(rfs.read_file(reflog_path)[:])
  let lines : Array[String] = []
  for line_view in log_content.split("\n") {
    let line = line_view.to_string()
    if line.length() > 0 {
      lines.push(line)
    }
  }
  // Reverse to get newest first, then remove at index
  lines.rev_in_place()
  if index < lines.length() {
    let _ = lines.remove(index)
  }
  if lines.length() == 0 {
    // No more entries
    fs.remove_file(reflog_path)
    fs.remove_file(git_dir + "/refs/stash")
  } else {
    // Reverse back and write
    lines.rev_in_place()
    let new_content = lines
      .iter()
      .fold(init="", (acc, line) => acc + line + "\n")
    fs.write_string(reflog_path, new_content)
    // Update refs/stash to newest entry (last line has newest)
    let newest = lines[lines.length() - 1]
    let parts = newest.split(" ").map(v => v.to_string()).collect()
    if parts.length() >= 2 {
      let new_id = parts[1]
      fs.write_string(git_dir + "/refs/stash", new_id + "\n")
    }
  }
}

///|
/// Collect sorted union of paths from two tree file maps.
pub fn stash_collect_paths(
  parent_files : Map[String, TreeFileEntry],
  stash_files : Map[String, TreeFileEntry],
) -> Array[String] {
  let all_paths : Map[String, Bool] = {}
  for key, _ in parent_files {
    all_paths[key] = true
  }
  for key, _ in stash_files {
    all_paths[key] = true
  }
  let paths : Array[String] = []
  for key, _ in all_paths {
    paths.push(key)
  }
  paths.sort()
  paths
}

///|
/// Convert Int mode to String representation.
pub fn stash_mode_str(mode : Int) -> String {
  @string_utils.mode_to_string(mode)
}
