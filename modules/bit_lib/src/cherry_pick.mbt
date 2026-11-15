///| Git cherry-pick implementation

///|
pub enum CherryPickStatus {
  Success
  Conflict
  /// The change is already in HEAD (and --allow-empty was not given):
  /// nothing was committed; CHERRY_PICK_HEAD is left for --abort/--skip.
  Empty
}

///|
pub struct CherryPickResult {
  status : CherryPickStatus
  commit_id : @bit.ObjectId?
  conflicts : Array[String]
}

///|
/// Apply the change `commit_id` introduced (relative to its first parent)
/// on top of HEAD with a real three-way merge, as git does: the merge base
/// is the picked commit's parent, "ours" is HEAD and "theirs" the commit.
/// The new commit keeps the original author; `author`/`timestamp` are the
/// committer. On conflict the worktree gets conflict markers, the index
/// stages 1-3, and CHERRY_PICK_HEAD / MERGE_MSG are written.
pub fn cherry_pick(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  commit_id : @bit.ObjectId,
  author : String,
  timestamp : Int64,
  allow_empty? : Bool = false,
  no_commit? : Bool = false,
  message_suffix? : String = "",
  signoff_committer? : String = "",
) -> CherryPickResult raise @bit.GitError {
  let git_marker = join_path(root, ".git")
  let git_dir = if rfs.is_file(git_marker) {
    resolve_gitdir(rfs, git_marker)
  } else {
    git_marker
  }
  let object_git_dir = resolve_common_git_dir(rfs, git_dir)
  let db = ObjectDb::load(rfs, object_git_dir)
  let commit_obj = db.get(rfs, commit_id)
  guard commit_obj is Some(obj) else {
    raise @bit.GitError::InvalidObject("Commit not found")
  }
  if obj.obj_type != @bit.ObjectType::Commit {
    raise @bit.GitError::InvalidObject("Not a commit")
  }
  let commit_info = @bit.parse_commit(obj.data)
  let raw_message = cherry_pick_extract_message(obj.data, commit_id)
  let msg_with_suffix = if message_suffix.length() > 0 {
    let trimmed = cherry_pick_trim_trailing_newlines(raw_message)
    trimmed + "\n" + message_suffix + "\n"
  } else {
    raw_message
  }
  let message = if signoff_committer.length() > 0 {
    commit_apply_signoff(msg_with_suffix, committer=signoff_committer)
  } else {
    msg_with_suffix
  }
  let head = resolve_head_commit(rfs, git_dir)
  let base_files : Map[String, TreeFileEntry] = if commit_info.parents.length() ==
    0 {
    Map([])
  } else {
    collect_tree_files_from_commit(db, rfs, commit_info.parents[0])
  }
  let ours : Map[String, TreeFileEntry] = match head {
    Some(h) => collect_tree_files_from_commit(db, rfs, h)
    None => Map([])
  }
  let theirs = collect_tree_files(db, rfs, commit_info.tree)
  sequencer_check_local_changes(
    rfs, root, git_dir, ours, base_files, theirs, "cherry-pick",
  )
  let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
  let tw = merge_three_way(
    db,
    fs,
    rfs,
    root,
    git_dir,
    base_files,
    ours,
    theirs,
    ours_label="HEAD",
    theirs_label=short + " (" + cherry_pick_subject(message) + ")",
  )
  if tw.conflicts.length() > 0 {
    merge_write_conflicted(
      db, fs, rfs, root, git_dir, base_files, ours, theirs, tw,
    )
    if !no_commit {
      fs.write_string(
        join_path(git_dir, "CHERRY_PICK_HEAD"),
        commit_id.to_hex() + "\n",
      )
    }
    fs.write_string(join_path(git_dir, "MERGE_MSG"), message)
    let conflicts = tw.conflicts.copy()
    conflicts.sort()
    return { status: CherryPickStatus::Conflict, commit_id: None, conflicts }
  }
  write_worktree_from_files(
    db,
    fs,
    rfs,
    root,
    git_dir,
    tw.merged,
    remove_missing=true,
  )
  let entries = tree_files_to_index(db, rfs, tw.merged)
  write_index_entries(fs, git_dir, entries)
  if no_commit {
    return { status: CherryPickStatus::Success, commit_id: None, conflicts: [] }
  }
  let tree_id = write_tree_from_index(fs, rfs, git_dir, entries)
  let head_tree = match head {
    Some(h) =>
      match db.get(rfs, h) {
        Some(o) if o.obj_type == @bit.ObjectType::Commit =>
          Some(@bit.parse_commit(o.data).tree)
        _ => None
      }
    None => None
  }
  if !allow_empty && head_tree == Some(tree_id) {
    fs.write_string(
      join_path(git_dir, "CHERRY_PICK_HEAD"),
      commit_id.to_hex() + "\n",
    )
    fs.write_string(join_path(git_dir, "MERGE_MSG"), message)
    return { status: CherryPickStatus::Empty, commit_id: None, conflicts: [] }
  }
  let parents = match head {
    Some(h) => [h]
    None => []
  }
  // The original authorship is preserved; only the committer is new.
  let original = rebase_parse_commit_content(obj.data)
  let new_commit = @bit.Commit::new(
    tree_id,
    parents,
    original.author,
    original.author_time,
    original.author_tz,
    author,
    timestamp,
    "+0000",
    message,
  )
  let (new_id, new_data) = @bit.create_commit(new_commit)
  write_object_bytes(fs, object_git_dir, new_id, new_data)
  update_head_ref(fs, rfs, git_dir, new_id)
  { status: CherryPickStatus::Success, commit_id: Some(new_id), conflicts: [] }
}

///|
fn cherry_pick_subject(message : String) -> String {
  match message.find("\n") {
    Some(i) => String::unsafe_substring(message, start=0, end=i)
    None => message
  }
}

///|
fn cherry_pick_extract_message(
  data : Bytes,
  commit_id : @bit.ObjectId,
) -> String {
  let commit_text = @utf8.decode_lossy(data[:])
  let msg_start = commit_text.find("\n\n")
  match msg_start {
    Some(idx) =>
      String::unsafe_substring(
        commit_text,
        start=idx + 2,
        end=commit_text.length(),
      )
    None => "Cherry-picked from \{commit_id.to_hex()}"
  }
}

///|
fn cherry_pick_trim_trailing_newlines(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 && (chars[end - 1] == '\n' || chars[end - 1] == '\r') {
    end -= 1
  }
  let result = StringBuilder()
  for i in 0..<end {
    result.write_char(chars[i])
  }
  result.to_string()
}

///|
/// git refuses to cherry-pick / revert over local changes: the index must
/// match HEAD, and no path the operation changes (where `theirs` differs
/// from `base_files`) may have unstaged edits or be an untracked file.
/// Checked before anything is written.
fn sequencer_check_local_changes(
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
  ours : Map[String, TreeFileEntry],
  base_files : Map[String, TreeFileEntry],
  theirs : Map[String, TreeFileEntry],
  op : String,
) -> Unit raise @bit.GitError {
  let entries = read_index_entries(rfs, git_dir)
  let skip = read_skip_worktree_paths(rfs, git_dir)
  // On an unborn branch (no HEAD tree) an index already matching the
  // picked tree is fine, as in git.
  let unborn = ours.length() == 0
  let mut staged = !unborn && entries.length() != ours.length()
  if !staged {
    for e in entries {
      let matches = fn(t : TreeFileEntry?) {
        t is Some(o) && o.id == e.id && o.mode == e.mode
      }
      if !(matches(ours.get(e.path)) || (unborn && matches(theirs.get(e.path)))) {
        staged = true
        break
      }
    }
  }
  if staged {
    raise @bit.GitError::InvalidObject(
      "your local changes would be overwritten by \{op}.\nhint: commit your changes or stash them to proceed.",
    )
  }
  // Only paths the operation actually rewrites matter: theirs differs
  // from base, and HEAD does not already have theirs' version.
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
  for path in changed.keys().to_array() {
    if same(base_files.get(path), theirs.get(path)) ||
      same(ours.get(path), theirs.get(path)) {
      changed.remove(path)
    }
  }
  let dirty : Array[String] = []
  let untracked : Array[String] = []
  for path, _ in changed {
    if skip.contains(path) {
      continue
    }
    let abs = join_path(root, path)
    let meta = @bitio.worktree_entry_meta_sync(rfs, abs)
    let on_disk : @bit.ObjectId? = match meta {
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
    match (ours.get(path), on_disk) {
      (Some(o), Some(id)) => if o.id != id { dirty.push(path) }
      // A missing file loses nothing when rewritten or deleted (git).
      (Some(_), None) => ()
      // An untracked file identical to what would be written is fine.
      (None, Some(id)) =>
        if !(theirs.get(path) is Some(t) && t.id == id) {
          untracked.push(path)
        }
      (None, None) => ()
    }
  }
  if dirty.length() > 0 {
    dirty.sort()
    raise @bit.GitError::InvalidObject(
      "Your local changes to the following files would be overwritten by \{op}:\n\t" +
      dirty.join("\n\t"),
    )
  }
  if untracked.length() > 0 {
    untracked.sort()
    raise @bit.GitError::InvalidObject(
      "The following untracked working tree files would be overwritten by \{op}:\n\t" +
      untracked.join("\n\t"),
    )
  }
}

///|
/// `git revert <commit>`: undo the change `commit_id` introduced relative
/// to its parent (`mainline`, 1-based, for merges) with a three-way merge
/// (base = the commit, ours = HEAD, theirs = the parent). The commit is
/// authored and committed by `author`. On conflict REVERT_HEAD / MERGE_MSG
/// are written; an empty result is refused unless `allow_empty`.
pub fn revert(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  commit_id : @bit.ObjectId,
  author : String,
  timestamp : Int64,
  mainline? : Int? = None,
  no_commit? : Bool = false,
  allow_empty? : Bool = false,
) -> CherryPickResult raise @bit.GitError {
  let git_marker = join_path(root, ".git")
  let git_dir = if rfs.is_file(git_marker) {
    resolve_gitdir(rfs, git_marker)
  } else {
    git_marker
  }
  let object_git_dir = resolve_common_git_dir(rfs, git_dir)
  let db = ObjectDb::load(rfs, object_git_dir)
  let commit = rebase_parse_commit_full(db, rfs, commit_id)
  let parent : @bit.ObjectId? = if commit.parents.length() > 1 {
    match mainline {
      Some(m) if m >= 1 && m <= commit.parents.length() =>
        Some(commit.parents[m - 1])
      Some(_) =>
        raise @bit.GitError::InvalidObject(
          "commit \{commit_id.to_hex()} does not have parent \{mainline.unwrap()}",
        )
      None =>
        raise @bit.GitError::InvalidObject(
          "commit \{commit_id.to_hex()} is a merge but no -m option was given.",
        )
    }
  } else if mainline is Some(_) {
    raise @bit.GitError::InvalidObject(
      "mainline was specified but commit \{commit_id.to_hex()} is not a merge.",
    )
  } else if commit.parents.length() == 1 {
    Some(commit.parents[0])
  } else {
    None
  }
  let head = resolve_head_commit(rfs, git_dir)
  guard head is Some(head_id) else {
    raise @bit.GitError::InvalidObject("cannot revert a commit onto an unborn branch")
  }
  let base_files = collect_tree_files(db, rfs, commit.tree)
  let ours = collect_tree_files_from_commit(db, rfs, head_id)
  let theirs : Map[String, TreeFileEntry] = match parent {
    Some(p) => collect_tree_files_from_commit(db, rfs, p)
    None => Map([])
  }
  sequencer_check_local_changes(
    rfs, root, git_dir, ours, base_files, theirs, "revert",
  )
  let subject = cherry_pick_subject(commit.message)
  // git: reverting a revert reads `Reapply "<original subject>"`.
  let title = if subject.has_prefix("Revert \"") &&
    subject.has_suffix("\"") &&
    subject.length() > 9 {
    "Reapply " + String::unsafe_substring(subject, start=7, end=subject.length())
  } else {
    "Revert \"\{subject}\""
  }
  let message = "\{title}\n\nThis reverts commit \{commit_id.to_hex()}.\n"
  let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
  let tw = merge_three_way(
    db,
    fs,
    rfs,
    root,
    git_dir,
    base_files,
    ours,
    theirs,
    ours_label="HEAD",
    theirs_label="parent of " + short + " (" + subject + ")",
  )
  if tw.conflicts.length() > 0 {
    merge_write_conflicted(
      db, fs, rfs, root, git_dir, base_files, ours, theirs, tw,
    )
    if !no_commit {
      fs.write_string(join_path(git_dir, "REVERT_HEAD"), commit_id.to_hex() + "\n")
    }
    fs.write_string(join_path(git_dir, "MERGE_MSG"), message)
    let conflicts = tw.conflicts.copy()
    conflicts.sort()
    return { status: CherryPickStatus::Conflict, commit_id: None, conflicts }
  }
  write_worktree_from_files(
    db,
    fs,
    rfs,
    root,
    git_dir,
    tw.merged,
    remove_missing=true,
  )
  let entries = tree_files_to_index(db, rfs, tw.merged)
  write_index_entries(fs, git_dir, entries)
  if no_commit {
    return { status: CherryPickStatus::Success, commit_id: None, conflicts: [] }
  }
  let tree_id = write_tree_from_index(fs, rfs, git_dir, entries)
  let head_tree = rebase_parse_commit_full(db, rfs, head_id).tree
  if !allow_empty && head_tree == tree_id {
    // Unlike cherry-pick, git leaves no REVERT_HEAD for an empty revert.
    fs.write_string(join_path(git_dir, "MERGE_MSG"), message)
    return { status: CherryPickStatus::Empty, commit_id: None, conflicts: [] }
  }
  let new_commit = @bit.Commit::new(
    tree_id,
    [head_id],
    author,
    timestamp,
    "+0000",
    author,
    timestamp,
    "+0000",
    message,
  )
  let (new_id, new_data) = @bit.create_commit(new_commit)
  write_object_bytes(fs, object_git_dir, new_id, new_data)
  update_head_ref(fs, rfs, git_dir, new_id)
  { status: CherryPickStatus::Success, commit_id: Some(new_id), conflicts: [] }
}
