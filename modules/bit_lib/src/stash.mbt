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
    let hex = content.trim_end(chars="\n\r ").to_owned()
    let id = @bit.ObjectId::from_hex(hex)
    return [{ id, message: "WIP on HEAD" }]
  }
  let log_content = @utf8.decode_lossy(fs.read_file(reflog_path)[:])
  let entries : Array[StashEntry] = []
  for line_view in log_content.split("\n") {
    let line = line_view.to_owned()
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
        let parts = prefix.split(" ").map(v => v.to_owned()).collect()
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
/// Push current changes to stash, like `git stash push`: an index commit
/// (I), an optional untracked-files commit (U, `include_untracked`) and the
/// worktree commit (W, parents HEAD, I[, U]) with git's messages, then a
/// hard reset to HEAD (skip-worktree entries are left alone) and, with
/// `include_untracked`, removal of the stashed untracked files.
pub async fn stash_push(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  message : String,
  author : String,
  timestamp : Int64,
  include_untracked? : Bool = false,
) -> @bit.ObjectId? raise @bit.GitError {
  let (git_dir, common_dir) = stash_git_dirs(rfs, root)
  let st = status(rfs, root)
  let untracked = if include_untracked { st.untracked } else { [] }
  if st.staged_added.length() == 0 &&
    st.staged_modified.length() == 0 &&
    st.staged_deleted.length() == 0 &&
    st.unstaged_modified.length() == 0 &&
    st.unstaged_deleted.length() == 0 &&
    untracked.length() == 0 &&
    !stash_index_differs_from_head(rfs, git_dir, common_dir) {
    return None
  }
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(head_id) else {
    raise @bit.GitError::InvalidObject("You do not have the initial commit yet")
  }
  if read_unmerged_paths(rfs, git_dir).length() > 0 {
    raise @bit.GitError::InvalidObject("could not write index")
  }
  let index_path = join_path(git_dir, "index")
  let saved_index = if rfs.is_file(index_path) {
    Some(rfs.read_file(index_path))
  } else {
    None
  }
  let index_entries = read_index_entries(rfs, git_dir)
  let skip = effective_skip_worktree_paths(rfs, root, git_dir)
  let index_tree = write_tree_from_index(fs, rfs, common_dir, index_entries)
  // W: the index with every tracked (non skip-worktree, non gitlink) path
  // re-staged from the worktree, exactly as `git add -u` would.
  // git builds W with `diff-index HEAD` (HEAD vs worktree) + update-index:
  // only paths differing from HEAD are refreshed from the worktree. A new
  // (not in HEAD) file missing on disk is not in that diff, so its index
  // version stays; HEAD paths the index dropped (`rm --cached`) but still
  // on disk come back from the worktree.
  let head_db = ObjectDb::load_lazy(rfs, common_dir)
  let head_files = collect_tree_files_from_commit(head_db, rfs, head_id)
  let tracked : Array[String] = []
  let in_index : Map[String, Bool] = Map([])
  for e in index_entries {
    in_index[e.path] = true
    if skip.contains(e.path) || is_gitlink_mode_int(e.mode) {
      continue
    }
    if !head_files.contains(e.path) &&
      @bitio.worktree_entry_meta_sync(rfs, join_path(root, e.path)) is None {
      continue
    }
    tracked.push(e.path)
  }
  for path, f in head_files {
    if !in_index.contains(path) &&
      !is_gitlink_mode_int(f.mode) &&
      @bitio.worktree_entry_meta_sync(rfs, join_path(root, path)) is Some(_) {
      tracked.push(path)
    }
  }
  let worktree_entries = if tracked.length() > 0 {
    add_paths(fs, rfs, root, tracked)
    read_index_entries(rfs, git_dir)
  } else {
    index_entries
  }
  // With -u git always records the U commit, even with an empty tree.
  let untracked_tree = if include_untracked {
    write_index_entries(fs, git_dir, [])
    if untracked.length() > 0 {
      add_paths(fs, rfs, root, untracked)
    }
    let u_entries = read_index_entries(rfs, git_dir)
    Some(write_tree_from_index(fs, rfs, common_dir, u_entries))
  } else {
    None
  }
  match saved_index {
    Some(bytes) => fs.write_file(index_path, bytes)
    None => fs.remove_file(index_path) catch { _ => () }
  }
  let worktree_tree = write_tree_from_index(
    fs, rfs, common_dir, worktree_entries,
  )
  let stash_id = stash_store_entry(
    fs,
    rfs,
    git_dir,
    head_id,
    index_tree,
    worktree_tree,
    message,
    author,
    timestamp,
    untracked_tree~,
  )
  // git runs `clean --force -d` first, then `reset --hard`: every stashed
  // untracked file goes (a HEAD path comes back with the reset, or gets the
  // skip bit outside the cone), as do empty untracked directories.
  if untracked.length() > 0 {
    let emptied : Array[String] = []
    for path in untracked {
      let abs = join_path(root, path)
      if @bitio.worktree_entry_meta_sync(rfs, abs) is Some(_) {
        fs.remove_file(abs) catch { _ => () }
        emptied.push(parent_dir(abs))
      }
    }
    tree_ops_prune_empty_dirs(fs, rfs, root, emptied)
  }
  if include_untracked {
    stash_clean_empty_dirs(fs, rfs, root, git_dir)
  }
  stash_reset_hard(fs, rfs, root, git_dir, common_dir, head_id)
  Some(stash_id)
}

///|
/// Remove every empty directory below `root` that holds no index entry
/// (skip-worktree ones included), deepest first, like `git clean -d`.
fn stash_clean_empty_dirs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
) -> Unit raise @bit.GitError {
  let tracked_dirs : Map[String, Bool] = Map([])
  for e in read_index_entries(rfs, git_dir) {
    let mut p = e.path
    while p.rev_find("/") is Some(j) {
      p = String::unsafe_substring(p, start=0, end=j)
      tracked_dirs[p] = true
    }
  }
  fn walk(rel : String) -> Bool {
    // Returns whether the directory at `rel` is empty after cleaning.
    let abs = if rel.length() == 0 { root } else { join_path(root, rel) }
    let children = rfs.readdir(abs) catch { _ => return false }
    let mut empty = true
    for name in children {
      if rel.length() == 0 && name == ".git" {
        empty = false
        continue
      }
      let child_rel = if rel.length() == 0 { name } else { rel + "/" + name }
      let child_abs = join_path(root, child_rel)
      let is_link = @bitio.worktree_entry_meta_sync(rfs, child_abs) is Some(m) &&
        m.kind is @bitio.WorktreeKindMeta::Symlink
      if !is_link && rfs.is_dir(child_abs) && !rfs.is_file(join_path(child_abs, ".git")) &&
        !rfs.is_dir(join_path(child_abs, ".git")) {
        if walk(child_rel) && !tracked_dirs.contains(child_rel) {
          fs.remove_dir(child_abs) catch { _ => empty = false }
        } else {
          empty = false
        }
      } else {
        empty = false
      }
    }
    empty
  }
  ignore(walk(""))
}

///|
/// The worktree's git dir and the common git dir (objects, refs) for
/// `root`, which may be a linked worktree whose `.git` is a file.
fn stash_git_dirs(
  rfs : &@bit.RepoFileSystem,
  root : String,
) -> (String, String) {
  let marker = join_path(root, ".git")
  let git_dir = if rfs.is_file(marker) {
    resolve_gitdir(rfs, marker)
  } else {
    marker
  }
  (git_dir, resolve_common_git_dir(rfs, git_dir))
}

///|
/// `git reset --hard HEAD` for stash: index and worktree back to HEAD,
/// removing files only the index tracked. Skip-worktree paths keep their
/// flag and are not materialized.
fn stash_reset_hard(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
  common_dir : String,
  head_id : @bit.ObjectId,
) -> Unit raise @bit.GitError {
  let db = ObjectDb::load(rfs, common_dir)
  let head_files = collect_tree_files_from_commit(db, rfs, head_id)
  let skip = effective_skip_worktree_paths(rfs, root, git_dir)
  let emptied : Array[String] = []
  let entries = read_index_entries(rfs, git_dir)
  // reset --hard re-applies the sparse patterns: out-of-cone entries get
  // the skip bit and are not materialized (their files are discarded);
  // an untracked file at such a path is left alone, as in reset --hard.
  let leave : Map[String, Bool] = Map([])
  if is_sparse_checkout_enabled(rfs, git_dir) {
    let patterns = read_sparse_patterns(rfs, git_dir)
    let indexed : Map[String, Bool] = Map([])
    for e in entries {
      indexed[e.path] = true
    }
    for path, f in head_files {
      if !is_gitlink_mode_int(f.mode) &&
        !matches_sparse_pattern(path, patterns) &&
        !skip.contains(path) {
        let abs = join_path(root, path)
        let present = @bitio.worktree_entry_meta_sync(rfs, abs) is Some(_)
        if !indexed.contains(path) && present {
          // Left alone, but the entry still gets the skip bit (git).
          leave[path] = true
          skip[path] = true
          continue
        }
        skip[path] = true
        if present {
          fs.remove_file(abs) catch { _ => () }
          emptied.push(parent_dir(abs))
        }
      }
    }
  }
  for e in entries {
    if head_files.contains(e.path) || skip.contains(e.path) {
      continue
    }
    let abs = join_path(root, e.path)
    if is_gitlink_mode_int(e.mode) {
      continue
    }
    if @bitio.worktree_entry_meta_sync(rfs, abs) is Some(_) {
      fs.remove_file(abs) catch { _ => () }
    }
    // A file already gone still lets git prune its empty parents.
    emptied.push(parent_dir(abs))
  }
  tree_ops_prune_empty_dirs(fs, rfs, root, emptied)
  let to_write : Map[String, TreeFileEntry] = Map([])
  for path, f in head_files {
    if !skip.contains(path) && !leave.contains(path) {
      to_write[path] = f
    }
  }
  write_worktree_from_files(db, fs, rfs, root, git_dir, to_write)
  let head_entries = tree_files_to_index(db, rfs, head_files)
  let keep_skip : Map[String, Bool] = Map([])
  for path, _ in skip {
    if head_files.contains(path) {
      keep_skip[path] = true
    }
  }
  write_index_entries_with_skip_worktree(fs, git_dir, head_entries, keep_skip)
}

///|
/// git's stash subject for HEAD: "<branch>: <short> <subject>", with
/// "(no branch)" on a detached HEAD and the commit's first paragraph
/// joined into one line.
fn stash_head_label(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  common_dir : String,
  head_id : @bit.ObjectId,
) -> (String, String) raise @bit.GitError {
  let branch = match read_head_ref(rfs, git_dir) {
    Branch(name) => name
    Detached(_) => "(no branch)"
  }
  let db = ObjectDb::load_lazy(rfs, common_dir)
  let msg = rebase_parse_commit_full(db, rfs, head_id).message
  let para = match msg.find("\n\n") {
    Some(i) => String::unsafe_substring(msg, start=0, end=i)
    None => msg
  }
  let words : Array[String] = []
  for line in para.split("\n") {
    let t = line.trim(chars=" \t\r").to_owned()
    if t.length() > 0 {
      words.push(t)
    }
  }
  let short = String::unsafe_substring(head_id.to_hex(), start=0, end=7)
  (branch, "\{branch}: \{short} \{words.join(" ")}")
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
  let (git_dir, _) = stash_git_dirs(rfs, root)
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
  let selected_by_path : Map[String, Array[Bool]] = Map([])
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
  let selected_overrides : Map[String, StashPatchContent] = Map([])
  let remaining_overrides : Map[String, StashPatchContent] = Map([])
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
  untracked_tree? : @bit.ObjectId? = None,
) -> @bit.ObjectId raise @bit.GitError {
  let common_dir = resolve_common_git_dir(rfs, git_dir)
  let (branch, label) = stash_head_label(rfs, git_dir, common_dir, head_id)
  // git writes the stash messages verbatim: W has no trailing newline.
  let new_commit = fn(tree, parents, msg) raise @bit.GitError {
    let commit = @bit.Commit::new(
      tree,
      parents,
      author,
      timestamp,
      "+0000",
      author,
      timestamp,
      "+0000",
      msg,
      verbatim_message=true,
    )
    let (id, data) = @bit.create_commit(commit)
    write_object_bytes(fs, common_dir, id, data)
    id
  }
  let index_commit_id = new_commit(
    index_tree,
    [head_id],
    "index on \{label}\n",
  )
  let parents = [head_id, index_commit_id]
  match untracked_tree {
    Some(tree) => parents.push(new_commit(tree, [], "untracked files on \{label}\n"))
    None => ()
  }
  let stash_msg = if message.length() > 0 {
    "On \{branch}: \{message}"
  } else {
    "WIP on \{label}"
  }
  let stash_id = new_commit(worktree_tree, parents, stash_msg)
  let stash_ref_path = common_dir + "/refs/stash"
  let old_id = if rfs.is_file(stash_ref_path) {
    let content = @utf8.decode_lossy(rfs.read_file(stash_ref_path)[:])
    let hex = content.trim_end(chars="\n\r ").to_owned()
    @bit.ObjectId::from_hex(hex) catch {
      _ => @bit.ObjectId::zero()
    }
  } else {
    @bit.ObjectId::zero()
  }
  fs.write_string(stash_ref_path, stash_id.to_hex() + "\n")
  let reflog_dir = common_dir + "/logs/refs"
  fs.mkdir_p(reflog_dir)
  let reflog_path = reflog_dir + "/stash"
  let reflog_msg = match stash_msg.find("\n") {
    Some(i) => String::unsafe_substring(stash_msg, start=0, end=i)
    None => stash_msg
  }
  let reflog_entry = "\{old_id.to_hex()} \{stash_id.to_hex()} \{author} \{timestamp} +0000\t\{reflog_msg}\n"
  let existing = if rfs.is_file(reflog_path) {
    @utf8.decode_lossy(rfs.read_file(reflog_path)[:])
  } else {
    ""
  }
  fs.write_string(reflog_path, existing + reflog_entry)
  stash_id
}

///|
fn stash_collect_patch_files(
  rfs : &@bit.RepoFileSystem,
  root : String,
  db : ObjectDb,
  head_files : Map[String, TreeFileEntry],
  index_entries : Array[IndexEntry],
) -> Array[StashPatchFile] raise @bit.GitError {
  let path_set : Map[String, Bool] = Map([])
  for path in head_files.keys() {
    path_set[path] = true
  }
  for entry in index_entries {
    path_set[entry.path] = true
  }
  let paths = path_set.keys().to_array()
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
        .map(v => v.to_owned())
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
  let path_set : Map[String, Bool] = Map([])
  for path in head_files.keys() {
    path_set[path] = true
  }
  for path in overrides.keys() {
    path_set[path] = true
  }
  let paths = path_set.keys().to_array()
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
  for path, content in overrides {
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
/// Apply stash entry (optionally dropping it), like `git stash apply|pop`
/// without `--index`: the stash's changes (base = its first parent, theirs = its tree)
/// are merged into the current index. On success the index is reset to
/// what it was except for files the stash adds, which stay staged; on
/// conflict the conflicted index is left and the entry is kept. Untracked
/// files (third parent) are restored afterwards, as in git.
pub fn stash_apply(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  index : Int,
  drop : Bool,
) -> Unit raise @bit.GitError {
  let (git_dir, common_dir) = stash_git_dirs(rfs, root)
  let entries = stash_list(rfs, common_dir)
  if index >= entries.length() {
    raise @bit.GitError::InvalidObject("No stash entry at index \{index}")
  }
  let entry = entries[index]
  let db = ObjectDb::load(rfs, common_dir)
  let stash = rebase_parse_commit_full(db, rfs, entry.id)
  if stash.parents.length() < 2 {
    raise @bit.GitError::InvalidObject(
      "'\{entry.id.to_hex()}' is not a stash-like commit",
    )
  }
  if read_unmerged_paths(rfs, git_dir).length() > 0 {
    raise @bit.GitError::InvalidObject("Cannot apply a stash in the middle of a merge")
  }
  let index_entries = read_index_entries(rfs, git_dir)
  let skip = effective_skip_worktree_paths(rfs, root, git_dir)
  let ours : Map[String, TreeFileEntry] = Map([])
  let ours_entries : Map[String, IndexEntry] = Map([])
  for e in index_entries {
    ours[e.path] = { id: e.id, mode: e.mode }
    ours_entries[e.path] = e
  }
  let base_files = collect_tree_files_from_commit(db, rfs, stash.parents[0])
  let theirs = collect_tree_files(db, rfs, stash.tree)
  // Untracked files (third parent) are restored after the merge, like
  // git's checkout-index --all: files that do not exist yet are written,
  // existing ones are reported and fail the apply (the entry is kept).
  let restore_untracked = fn() -> String? raise @bit.GitError {
    if stash.parents.length() < 3 {
      return None
    }
    let u_files = collect_tree_files_from_commit(db, rfs, stash.parents[2])
    let existing : Array[String] = []
    let to_restore : Map[String, TreeFileEntry] = Map([])
    for path, f in u_files {
      if @bitio.worktree_entry_meta_sync(rfs, join_path(root, path)) is Some(_) {
        existing.push(path)
      } else {
        to_restore[path] = f
      }
    }
    write_worktree_from_files(db, fs, rfs, root, git_dir, to_restore)
    if existing.length() == 0 {
      return None
    }
    existing.sort()
    Some(
      existing.map(p => "\{p} already exists, no checkout").join("\n") +
      "\ncould not restore untracked files from stash",
    )
  }
  // A refused merge (local changes in the way) still restores the
  // untracked files: git jumps to restore_untracked on any merge failure.
  let already_present = stash_check_local_changes(
    rfs,
    root,
    ours,
    base_files,
    theirs,
    skip,
    sparse=is_sparse_checkout_enabled(rfs, git_dir),
    touched=Some(merge_touched_paths(base_files, ours, theirs, db, rfs)),
  ) catch {
    @bit.GitError::InvalidObject(msg) => {
      let u_note = match restore_untracked() {
        Some(u) => "\n" + u
        None => ""
      }
      raise @bit.GitError::InvalidObject(msg + u_note)
    }
    e => raise e
  }
  let tw = merge_three_way(
    db,
    fs,
    rfs,
    root,
    git_dir,
    base_files,
    ours,
    theirs,
    ours_label="Updated upstream",
    theirs_label="Stashed changes",
  )
  if tw.conflicts.length() > 0 {
    merge_write_conflicted(
      db,
      fs,
      rfs,
      root,
      git_dir,
      base_files,
      ours,
      theirs,
      tw,
      overwrite=already_present,
    )
    let conflicts = tw.conflicts.copy()
    conflicts.sort()
    let u_note = match restore_untracked() {
      Some(msg) => "\n" + msg
      None => ""
    }
    raise @bit.GitError::InvalidObject(
      conflicts.map(p => "CONFLICT (content): Merge conflict in \{p}").join(
        "\n",
      ) +
      u_note +
      "\nThe stash entry is kept in case you need it again.",
    )
  }
  // Worktree: write what changed, remove what the stash deleted.
  let emptied : Array[String] = []
  for path, _ in ours {
    if !tw.merged.contains(path) && !skip.contains(path) {
      let abs = join_path(root, path)
      if @bitio.worktree_entry_meta_sync(rfs, abs) is Some(_) {
        fs.remove_file(abs) catch { _ => () }
      }
      // A file already gone still lets git prune its empty parents.
      emptied.push(parent_dir(abs))
    }
  }
  tree_ops_prune_empty_dirs(fs, rfs, root, emptied)
  let to_write : Map[String, TreeFileEntry] = Map([])
  for path, f in tw.merged {
    match ours.get(path) {
      Some(o) if o.id == f.id && o.mode == f.mode => ()
      _ => to_write[path] = f
    }
  }
  write_worktree_from_files(db, fs, rfs, root, git_dir, to_write)
  // Index: unchanged except for files new to it, which are staged.
  let new_index : Array[IndexEntry] = []
  for e in index_entries {
    new_index.push(e)
  }
  let added : Map[String, TreeFileEntry] = Map([])
  for path, f in tw.merged {
    if !ours.contains(path) {
      added[path] = f
    }
  }
  for e in tree_files_to_index(db, rfs, added) {
    new_index.push(e)
  }
  // git re-creates the index entry of every path the merge changed
  // (unstage_changes_unless_new), so those lose the skip-worktree bit.
  let kept_skip : Map[String, Bool] = Map([])
  for path, _ in skip {
    match (ours.get(path), tw.merged.get(path)) {
      (Some(o), Some(m)) if o.id == m.id && o.mode == m.mode =>
        kept_skip[path] = true
      (None, _) => kept_skip[path] = true
      _ => ()
    }
  }
  write_index_entries_with_skip_worktree(fs, git_dir, new_index, kept_skip)
  sync_skip_worktree_sidecar(fs, rfs, git_dir, kept_skip)
  match restore_untracked() {
    Some(msg) => raise @bit.GitError::InvalidObject(msg)
    None => ()
  }
  if drop {
    stash_drop_at(fs, rfs, common_dir, index)
  }
}

///|
/// git refuses to apply a stash over unstaged edits (or untracked files)
/// at paths the stash changes and the current index does not already
/// match.
fn stash_check_local_changes(
  rfs : &@bit.RepoFileSystem,
  root : String,
  ours : Map[String, TreeFileEntry],
  base_files : Map[String, TreeFileEntry],
  theirs : Map[String, TreeFileEntry],
  skip : Map[String, Bool],
  stash_note? : Bool = true,
  sparse? : Bool = false,
  touched? : Map[String, Bool]? = None,
) -> Map[String, Bool] raise @bit.GitError {
  let note = if stash_note {
    "\nThe stash entry is kept in case you need it again."
  } else {
    ""
  }
  let same = fn(a : TreeFileEntry?, b : TreeFileEntry?) {
    match (a, b) {
      (Some(x), Some(y)) => x.id == y.id && x.mode == y.mode
      (None, None) => true
      _ => false
    }
  }
  let changed : Map[String, Bool] = Map([])
  for path, _ in theirs {
    changed[path] = true
  }
  for path, _ in base_files {
    changed[path] = true
  }
  // Rename destinations the merge rewrites (theirs changed the content
  // at the old path) are in neither tree under that name.
  let renamed_dest : Map[String, Bool] = Map([])
  match touched {
    Some(t) =>
      for path, _ in t {
        if !changed.contains(path) && ours.contains(path) {
          changed[path] = true
          renamed_dest[path] = true
        }
      }
    None => ()
  }
  let dirty : Array[String] = []
  let untracked : Array[String] = []
  for path, _ in changed {
    // Only paths the merge result actually rewrites can be in the way.
    match touched {
      Some(t) if !t.contains(path) => continue
      _ => ()
    }
    if skip.contains(path) {
      continue
    }
    if !renamed_dest.contains(path) &&
      (same(base_files.get(path), theirs.get(path)) ||
      same(ours.get(path), theirs.get(path))) {
      continue
    }
    // Deleted by the stash but changed here: a modify/delete conflict that
    // leaves our file as it is, so local edits to it are not in the way.
    if !renamed_dest.contains(path) &&
      theirs.get(path) is None &&
      ours.get(path) is Some(_) &&
      !same(base_files.get(path), ours.get(path)) {
      continue
    }
    let abs = join_path(root, path)
    let on_disk : @bit.ObjectId? = match
      @bitio.worktree_entry_meta_sync(rfs, abs) {
      Some(info) =>
        match info.kind {
          @bitio.WorktreeKindMeta::Symlink =>
            @bitio.read_symlink_target_path(abs).map(fn(t) {
              @bit.hash_blob(@utf8.encode(t))
            })
          @bitio.WorktreeKindMeta::Regular =>
            Some(@bit.hash_blob(rfs.read_file(abs) catch { _ => Bytes::new(0) }))
        }
      None => None
    }
    // A mode change (exec bit, file <-> symlink) is a local change too.
    let disk_mode = match @bitio.worktree_entry_meta_sync(rfs, abs) {
      Some(info) =>
        match info.kind {
          @bitio.WorktreeKindMeta::Symlink => 0o120000
          @bitio.WorktreeKindMeta::Regular => info.mode
        }
      None => 0
    }
    match (ours.get(path), on_disk) {
      (Some(o), Some(id)) =>
        if o.id != id ||
          (o.mode != disk_mode &&
          (disk_mode == 0o100644 || disk_mode == 0o100755 || disk_mode == 0o120000)) {
          dirty.push(path)
        }
      // A missing file loses nothing when rewritten or deleted (git).
      (Some(_), None) => ()
      (None, Some(_)) => untracked.push(path)
      (None, None) => ()
    }
  }
  if dirty.length() > 0 {
    dirty.sort()
    raise @bit.GitError::InvalidObject(
      "Your local changes to the following files would be overwritten by merge:\n\t" +
      dirty.join("\n\t") +
      "\nPlease commit your changes or stash them before you merge.\nAborting" +
      note,
    )
  }
  if untracked.length() > 0 {
    // Sparse checkout: git does not refuse; the file is written over.
    if sparse {
      let present : Map[String, Bool] = Map([])
      for p in untracked {
        present[p] = true
      }
      return present
    }
    untracked.sort()
    raise @bit.GitError::InvalidObject(
      "The following untracked working tree files would be overwritten by merge:\n\t" +
      untracked.join("\n\t") +
      "\nPlease move or remove them before you merge.\nAborting" +
      note,
    )
  }
  Map([])
}

///|
/// Drop stash entry at index.
pub fn stash_drop(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  index : Int,
) -> Unit raise @bit.GitError {
  let (_, common_dir) = stash_git_dirs(rfs, root)
  stash_drop_at(fs, rfs, common_dir, index)
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
    let line = line_view.to_owned()
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
    let parts = newest.split(" ").map(v => v.to_owned()).collect()
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
  let all_paths : Map[String, Bool] = Map([])
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

///|
/// Whether the index differs from HEAD at all -- also for skip-worktree
/// entries, which status leaves out but git's stash still saves (a staged
/// file the sparse patterns then hid).
fn stash_index_differs_from_head(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  common_dir : String,
) -> Bool raise @bit.GitError {
  guard resolve_head_commit(rfs, git_dir) is Some(head) else { return false }
  let db = ObjectDb::load(rfs, common_dir)
  let head_files = collect_tree_files_from_commit(db, rfs, head)
  let entries = read_index_entries(rfs, git_dir)
  // A sparse index (directory entries) is left to status.
  if entries.iter().any(e => e.mode == 0o040000) {
    return false
  }
  if entries.length() != head_files.length() {
    return true
  }
  for e in entries {
    match head_files.get(e.path) {
      Some(f) if f.id == e.id && f.mode == e.mode => ()
      _ => return true
    }
  }
  false
}

///|
/// Paths a three-way merge result rewrites relative to `ours` (renames
/// included): changed or deleted entries, content merges and conflicts.
fn merge_touched_paths(
  base_files : Map[String, TreeFileEntry],
  ours : Map[String, TreeFileEntry],
  theirs : Map[String, TreeFileEntry],
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
) -> Map[String, Bool] {
  let fr = merge_files(base_files, ours, theirs, db, rfs)
  let out : Map[String, Bool] = Map([])
  for p, f in fr.merged {
    match ours.get(p) {
      Some(o) if o.id == f.id && o.mode == f.mode => ()
      _ => out[p] = true
    }
  }
  for c in fr.needs_content_merge {
    // A trivial resolution to our own content writes nothing.
    let ours_mode = ours.get(c.path).map(e => e.mode)
    // A binary conflict keeps our content as it is (git's result tree has
    // our blob there), so only a mode change rewrites the file.
    let ours_kept = c.ours_id == c.theirs_id ||
      c.base_id == Some(c.theirs_id) ||
      (c.base_id != Some(c.ours_id) &&
      (
        (c.base_id is Some(b) &&
        @diff3.is_binary_content(merge_get_blob_data(db, rfs, b))) ||
        @diff3.is_binary_content(merge_get_blob_data(db, rfs, c.ours_id)) ||
        @diff3.is_binary_content(merge_get_blob_data(db, rfs, c.theirs_id))
      ))
    // A regular file on one side and a symlink on the other ("distinct
    // types") is always rewritten: ours moves to <path>~<label>.
    let distinct = match (ours.get(c.path), theirs.get(c.path)) {
      (Some(o), Some(t)) => (o.mode == 0o120000) != (t.mode == 0o120000)
      _ => false
    }
    // The candidate carries the three-way merged mode (renames included).
    if distinct || !ours_kept || ours_mode != Some(c.mode) {
      out[c.path] = true
    }
  }
  for c in fr.rename_2to1 {
    out[c.path] = true
  }
  for p in fr.conflicts {
    // modify/delete with our side modified: our version is left in the
    // tree as it is, so local changes there are not in the way (git).
    if base_files.get(p) is Some(_) &&
      theirs.get(p) is None &&
      ours.get(p) is Some(o) &&
      !(fr.merged.get(p) is Some(f) && (f.id != o.id || f.mode != o.mode)) {
      continue
    }
    out[p] = true
  }
  // Deleted by the merge: neither in the result nor still pending (content
  // merges and rename/rename(2to1) are resolved later).
  let pending : Map[String, Bool] = Map([])
  for c in fr.needs_content_merge {
    pending[c.path] = true
  }
  for c in fr.rename_2to1 {
    pending[c.path] = true
  }
  for p, _ in ours {
    if !fr.merged.contains(p) && !fr.conflicts.contains(p) && !pending.contains(p) {
      out[p] = true
    }
  }
  out
}
