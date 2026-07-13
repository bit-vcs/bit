///|
/// Core of `git history fixup <commit>` (git 2.55, EXPERIMENTAL): fold the
/// currently staged changes into an earlier commit and replay its descendants.
///
/// The heavy lifting is an in-core three-way *tree* merge (no worktree needed),
/// built on the same content-merge machinery as `merge()` in merge.mbt.

///|
pub(all) enum HistoryEmptyAction {
  Drop
  Keep
  Abort
} derive(Eq)

///|
pub(all) struct HistoryRefUpdate {
  refname : String
  old_id : @bit.ObjectId
  new_id : @bit.ObjectId
} derive(Eq)

///|
pub(all) struct HistoryFixupResult {
  updates : Array[HistoryRefUpdate]
  /// The rewritten target commit (None if the target was dropped as empty).
  rewritten : @bit.ObjectId?
}

///|
/// In-core three-way merge of three trees. Returns the merged tree id and
/// whether the merge was clean. On conflict the returned tree id is the zero
/// id; callers treat a non-clean result as an abort condition.
fn history_merge_three_trees(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  base_tree : @bit.ObjectId,
  ours_tree : @bit.ObjectId,
  theirs_tree : @bit.ObjectId,
) -> (@bit.ObjectId, Bool) raise @bit.GitError {
  let base = collect_tree_files(db, rfs, base_tree)
  let ours = collect_tree_files(db, rfs, ours_tree)
  let theirs = collect_tree_files(db, rfs, theirs_tree)
  let result = merge_files(base, ours, theirs, db, rfs)
  let merged = result.merged
  let mut clean = result.conflicts.length() == 0
  // Rename/rename(2to1) resolution is worktree-coupled; treat it conservatively
  // as a conflict here (it does not arise for the staged-change fixup merge).
  if result.rename_2to1.length() > 0 {
    clean = false
  }
  for candidate in result.needs_content_merge {
    let base_content = match candidate.base_id {
      Some(id) => merge_get_blob_text(db, rfs, id)
      None => ""
    }
    let ours_content = merge_get_blob_text(db, rfs, candidate.ours_id)
    let theirs_content = merge_get_blob_text(db, rfs, candidate.theirs_id)
    let ours_data = merge_get_blob_data(db, rfs, candidate.ours_id)
    let theirs_data = merge_get_blob_data(db, rfs, candidate.theirs_id)
    if @diff3.is_binary_content(ours_data) || @diff3.is_binary_content(theirs_data) {
      clean = false
      continue
    }
    let cm = @diff3.content_merge(
      base_content,
      ours_content,
      theirs_content,
      @diff3.ContentMergeOptions::default(),
    )
    if cm.has_conflicts {
      clean = false
    } else {
      let (blob_id, compressed) = @bit.create_blob(@utf8.encode(cm.content))
      write_object_bytes(fs, git_dir, blob_id, compressed)
      merged[candidate.path] = { id: blob_id, mode: candidate.mode }
    }
  }
  if !(clean) {
    return (@bit.ObjectId::zero(), false)
  }
  let entries : Array[IndexEntry] = []
  for path, e in merged {
    entries.push({
      path,
      id: e.id,
      mode: e.mode,
      size: 0,
      mtime_sec: 0,
      mtime_nsec: 0,
      intent_to_add: false,
      dev: 0,
      ino: 0,
      uid: 0,
      gid: 0,
    })
  }
  let tree_oid = write_tree_from_entries(fs, rfs, git_dir, entries, Some(db))
  (tree_oid, true)
}

///|
fn history_commit_tree(
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
  commit_id : @bit.ObjectId,
) -> @bit.ObjectId raise @bit.GitError {
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) && o.obj_type == @bit.ObjectType::Commit else {
    raise @bit.GitError::InvalidObject("not a commit \{commit_id.to_hex()}")
  }
  @bit.parse_commit(o.data).tree
}

///|
/// Orchestrate `history fixup`: fold `index_tree` (the staged tree) into
/// `target_id`, then replay every descendant of `target_id` that is reachable
/// from the selected tips. Objects are written but no refs are touched; the
/// caller applies (or prints) the returned ref updates.
///
/// `tips` is the list of `(refname, commit)` refs to consider updating (e.g.
/// all branches + HEAD, or just HEAD). Only tips that have `target_id` as an
/// ancestor are rewritten.
pub fn history_fixup(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  target_id : @bit.ObjectId,
  index_tree : @bit.ObjectId,
  head_id : @bit.ObjectId,
  tips : Array[HistoryRefUpdate],
  empty : HistoryEmptyAction,
  reedit_message : String?,
) -> HistoryFixupResult raise @bit.GitError {
  let head_tree = history_commit_tree(db, rfs, head_id)
  let target = rebase_parse_commit_full(db, rfs, target_id)
  // Fold staged changes into the target: base=HEAD tree, ours=target tree,
  // theirs=index tree.
  let (merged_tree, clean) = history_merge_three_trees(
    db, fs, rfs, git_dir, head_tree, target.tree, index_tree,
  )
  if !(clean) {
    raise @bit.GitError::InvalidObject("fixup would produce conflicts; aborting")
  }

  // rewrite_map: original commit hex -> rewritten commit id.
  let rewrite_map : Map[String, @bit.ObjectId] = {}
  let mut rewritten_target : @bit.ObjectId? = None
  let target_empty = history_commit_is_empty(db, rfs, target.parents, merged_tree)
  if target_empty {
    match empty {
      Abort =>
        raise @bit.GitError::InvalidObject(
          "fixup makes commit \{target_id.to_hex()} empty",
        )
      Drop =>
        match target.parents.get(0) {
          None =>
            raise @bit.GitError::InvalidObject(
              "cannot drop root commit \{target_id.to_hex()}: it has no parent to replay onto",
            )
          Some(parent) => rewrite_map[target_id.to_hex()] = parent
        }
      Keep => {
        let id = history_write_commit(
          db, fs, git_dir, merged_tree, target.parents, target, reedit_message,
        )
        rewritten_target = Some(id)
        rewrite_map[target_id.to_hex()] = id
      }
    }
  } else {
    let id = history_write_commit(
      db, fs, git_dir, merged_tree, target.parents, target, reedit_message,
    )
    rewritten_target = Some(id)
    rewrite_map[target_id.to_hex()] = id
  }

  // Collect descendants of target reachable from the tips (linear chains only;
  // merges are rejected by the caller). Each chain is walked tip -> target.
  let descendants : Array[@bit.ObjectId] = []
  let seen : Map[String, Bool] = {}
  for tip in tips {
    if !(merge_base_is_ancestor(db, rfs, target_id, tip.new_id)) {
      continue
    }
    // Walk from tip down to target collecting the chain (child-first).
    let chain : Array[@bit.ObjectId] = []
    let mut cur = tip.new_id
    let mut reached = false
    while true {
      if cur == target_id {
        reached = true
        break
      }
      let info = rebase_parse_commit_full(db, rfs, cur)
      chain.push(cur)
      match info.parents.get(0) {
        None => break
        Some(p) => cur = p
      }
    }
    if !(reached) {
      continue
    }
    // Record in parent-first order, de-duplicating shared prefixes.
    for k = chain.length() - 1; k >= 0; k = k - 1 {
      let c = chain[k]
      if !(seen.contains(c.to_hex())) {
        seen[c.to_hex()] = true
        descendants.push(c)
      }
    }
  }

  // Replay each descendant onto its rewritten parent.
  for c in descendants {
    let info = rebase_parse_commit_full(db, rfs, c)
    let orig_parent = info.parents[0]
    let new_parent = rewrite_map
      .get(orig_parent.to_hex())
      .unwrap_or(orig_parent)
    let new_parent_tree = history_commit_tree(db, rfs, new_parent)
    let orig_parent_tree = history_commit_tree(db, rfs, orig_parent)
    let (replayed_tree, ok) = history_merge_three_trees(
      db, fs, rfs, git_dir, orig_parent_tree, new_parent_tree, info.tree,
    )
    if !(ok) {
      raise @bit.GitError::InvalidObject(
        "fixup would produce conflicts while replaying \{c.to_hex()}",
      )
    }
    let becomes_empty = replayed_tree == new_parent_tree
    if becomes_empty && empty is Drop {
      rewrite_map[c.to_hex()] = new_parent
      continue
    }
    if becomes_empty && empty is Abort {
      raise @bit.GitError::InvalidObject(
        "fixup makes replayed commit \{c.to_hex()} empty",
      )
    }
    let new_commit = @bit.Commit::new(
      replayed_tree,
      [new_parent],
      info.author,
      info.author_time,
      info.author_tz,
      info.committer,
      info.commit_time,
      info.committer_tz,
      info.message,
    )
    let (new_id, compressed) = @bit.create_commit(new_commit)
    write_object_bytes(fs, git_dir, new_id, compressed)
    rewrite_map[c.to_hex()] = new_id
  }

  // Build ref updates for tips whose commit was rewritten.
  let updates : Array[HistoryRefUpdate] = []
  for tip in tips {
    match rewrite_map.get(tip.new_id.to_hex()) {
      Some(rewritten) =>
        if rewritten != tip.new_id {
          updates.push({
            refname: tip.refname,
            old_id: tip.new_id,
            new_id: rewritten,
          })
        }
      None => ()
    }
  }
  { updates, rewritten: rewritten_target }
}

///|
fn history_write_commit(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  git_dir : String,
  tree : @bit.ObjectId,
  parents : Array[@bit.ObjectId],
  info : RebaseCommitInfo,
  reedit_message : String?,
) -> @bit.ObjectId raise @bit.GitError {
  ignore(db)
  let message = reedit_message.unwrap_or(info.message)
  let new_commit = @bit.Commit::new(
    tree,
    parents,
    info.author,
    info.author_time,
    info.author_tz,
    info.committer,
    info.commit_time,
    info.committer_tz,
    message,
  )
  let (new_id, compressed) = @bit.create_commit(new_commit)
  write_object_bytes(fs, git_dir, new_id, compressed)
  new_id
}

///|
/// True when `tree` is identical to `commit`'s (first) parent's tree, i.e. the
/// commit would introduce no changes.
fn history_commit_is_empty(
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
  parents : Array[@bit.ObjectId],
  tree : @bit.ObjectId,
) -> Bool raise @bit.GitError {
  match parents.get(0) {
    None => {
      // Root commit: "empty" means its tree is the empty tree.
      let (empty_tree, _) = @bit.create_tree([])
      tree == empty_tree
    }
    Some(parent) => {
      let pobj = db.get(rfs, parent)
      guard pobj is Some(o) && o.obj_type == @bit.ObjectType::Commit else {
        return false
      }
      @bit.parse_commit(o.data).tree == tree
    }
  }
}
