///| Keeping a subdir-clone in sync with its upstream repository.
///
/// A subdir-clone records two commits in .git/info/attributes: subdir-base
/// (an upstream commit) and subdir-local (the local commit whose tree is the
/// subdirectory at subdir-base). Push replays the local commits after
/// subdir-local onto subdir-base; pull/rebase converts the upstream commits
/// after subdir-base that touch the subdirectory into local commits on top of
/// subdir-local and rebases the local work onto them.

///|
/// The local commit matching the subdirectory at subdir-base. Clones made
/// before subdir-local was recorded fall back to their root commit, which is
/// the state they were cloned at.
fn subdir_sync_point(
  fs : OsFs,
  git_dir : String,
) -> @bitcore.ObjectId raise @bitcore.GitError {
  match @bitlib.read_subdir_local(fs, git_dir) {
    Some(id) => id
    None => find_initial_subdir_commit(fs, git_dir)
  }
}

///|
/// First-parent commits after `sync_point` up to `head`, oldest first.
fn subdir_unsynced_commits(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  sync_point : @bitcore.ObjectId,
  head : @bitcore.ObjectId,
) -> Array[@bitcore.ObjectId] raise @bitcore.GitError {
  let result : Array[@bitcore.ObjectId] = []
  let mut current = head
  while current != sync_point {
    result.push(current)
    guard db.get(fs, current) is Some(obj) else {
      raise @bitcore.GitError::InvalidObject(
        "missing commit " + current.to_hex(),
      )
    }
    let info = @bitcore.parse_commit(obj.data)
    guard info.parents.length() > 0 else {
      raise @bitcore.GitError::InvalidObject(
        "HEAD is not based on the last synced upstream state; run `bit pull` first",
      )
    }
    current = info.parents[0]
  }
  result.rev_in_place()
  result
}

///|
/// Upstream commits after `base` up to `target` (first-parent) that change
/// the subdirectory, oldest first, each with its subdirectory tree.
fn subdir_upstream_changes(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  base : @bitcore.ObjectId,
  target : @bitcore.ObjectId,
  subdir_path : String,
) -> Array[(@bitcore.ObjectId, @bitcore.ObjectId)] raise @bitcore.GitError {
  let walked : Array[@bitcore.ObjectId] = []
  let mut current = target
  while current != base {
    walked.push(current)
    guard db.get(fs, current) is Some(obj) else { break }
    let info = @bitcore.parse_commit(obj.data)
    guard info.parents.length() > 0 else { break }
    current = info.parents[0]
  }
  let mut prev_tree = @bitlib.get_subdir_tree_from_commit(
    db, fs, base, subdir_path,
  )
  let changes : Array[(@bitcore.ObjectId, @bitcore.ObjectId)] = []
  for i = walked.length() - 1; i >= 0; i = i - 1 {
    let commit_id = walked[i]
    let tree = @bitlib.get_subdir_tree_from_commit(
      db, fs, commit_id, subdir_path,
    )
    match tree {
      Some(t) if prev_tree != Some(t) => {
        changes.push((commit_id, t))
        prev_tree = tree
      }
      _ => ()
    }
  }
  changes
}

///|
/// Make sure the given objects exist locally, copying them from a local
/// upstream repository or fetching them over HTTP.
async fn subdir_fetch_objects(
  fs : OsFs,
  root : String,
  git_dir : String,
  remote_url : String,
  ids : Array[@bitcore.ObjectId],
) -> Unit raise Error {
  if ids.length() == 0 {
    return
  }
  match @bitlib.resolve_local_repo_path(fs, root, remote_url) {
    Some(path) => {
      guard @bitlib.detect_git_dir(fs, path) is Some((remote_git_dir, _)) else {
        raise @bitcore.GitError::InvalidObject("Not a git repository: " + path)
      }
      let remote_db = @bitlib.ObjectDb::load_lazy(fs, remote_git_dir)
      for id in ids {
        guard remote_db.get(fs, id) is Some(obj) else {
          raise @bitcore.GitError::InvalidObject(
            "upstream is missing object " + id.to_hex(),
          )
        }
        ignore(@bitlib.write_loose_object(fs, git_dir, obj.obj_type, obj.data))
      }
    }
    None => {
      let pack = @bitnative.fetch_pack_http(remote_url, ids, true)
      let objects = @pack.parse_packfile(pack)
      @pack.write_packfile_with_index(fs, git_dir, pack, objects)
    }
  }
}

///|
/// Fetch blobs of `trees` that are not present locally (subdir-clones are
/// blob:none partial clones of the upstream repository).
async fn subdir_fetch_missing_blobs(
  fs : OsFs,
  root : String,
  git_dir : String,
  remote_url : String,
  trees : Array[@bitcore.ObjectId],
) -> Bool raise Error {
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  let seen : Map[String, Bool] = Map([])
  let missing : Array[@bitcore.ObjectId] = []
  for tree in trees {
    for blob in @bitlib.collect_tree_blobs(db, fs, tree) {
      let hex = blob.to_hex()
      if seen.contains(hex) {
        continue
      }
      seen[hex] = true
      if db.get(fs, blob) is None {
        missing.push(blob)
      }
    }
  }
  subdir_fetch_objects(fs, root, git_dir, remote_url, missing)
  missing.length() > 0
}

///|
/// "origin/main" / "refs/remotes/origin/main" / "origin" / none →
/// (remote, branch), defaulting to origin and the current branch.
fn subdir_parse_upstream(
  fs : OsFs,
  git_dir : String,
  upstream : String?,
) -> (String, String) {
  let current = get_current_branch(fs, git_dir)
  match upstream {
    None => ("origin", current)
    Some(raw) => {
      let name = if raw.has_prefix("refs/remotes/") {
        String::unsafe_substring(raw, start=13, end=raw.length())
      } else {
        raw
      }
      match name.find("/") {
        Some(idx) =>
          (
            String::unsafe_substring(name, start=0, end=idx),
            String::unsafe_substring(name, start=idx + 1, end=name.length()),
          )
        None => (name, current)
      }
    }
  }
}

///|
/// Whether `bit rebase <upstream>` in a subdir-clone means "sync with the
/// upstream repository": no argument, or a remote-tracking ref.
fn subdir_rebase_targets_upstream(
  fs : OsFs,
  git_dir : String,
  upstream : String?,
) -> Bool {
  match upstream {
    None => true
    Some(u) if u.has_prefix("refs/remotes/") => true
    Some(u) =>
      match u.find("/") {
        Some(idx) =>
          @bitlib.get_remote_url(
            fs,
            git_dir,
            String::unsafe_substring(u, start=0, end=idx),
          )
          is Some(_)
        None => false
      }
  }
}

///|
/// `bit pull` / `bit rebase [<remote>/<branch>]` in a subdir-clone: fetch,
/// turn the upstream commits that touch the subdirectory into local commits
/// on top of subdir-local, then rebase the local work onto them.
async fn handle_subdir_rebase(
  fs : OsFs,
  root : String,
  git_dir : String,
  upstream : String?,
) -> Unit raise Error {
  guard read_subdir_attributes(fs, git_dir)
    is Some((remote_url, subdir_path, base_hex)) else {
    raise @bitcore.GitError::InvalidObject("not a subdir-clone repository")
  }
  let (remote_name, branch) = subdir_parse_upstream(fs, git_dir, upstream)
  if run_git_command(["-C", root, "fetch", remote_name], cwd=None) != 0 {
    raise @bitcore.GitError::InvalidObject("fetch from \{remote_name} failed")
  }
  let tracking = "refs/remotes/\{remote_name}/\{branch}"
  let target = match @bitrepo.rev_parse(fs, git_dir, tracking) {
    Some(id) => id
    None =>
      match
        (
          upstream,
          @bitrepo.rev_parse(fs, git_dir, "refs/remotes/\{remote_name}/HEAD"),
        ) {
        (None, Some(id)) => id
        _ =>
          raise @bitcore.GitError::InvalidObject(
            "cannot resolve \{remote_name}/\{branch}",
          )
      }
  }
  let base = @bitcore.ObjectId::from_hex(base_hex) catch {
    _ => raise @bitcore.GitError::InvalidObject("invalid subdir-base")
  }
  let sync_point = subdir_sync_point(fs, git_dir)
  let changes = subdir_upstream_changes(
    @bitlib.ObjectDb::load_lazy(fs, git_dir),
    fs,
    base,
    target,
    subdir_path,
  )
  ignore(
    subdir_fetch_missing_blobs(
      fs,
      root,
      git_dir,
      remote_url,
      changes.map(change => change.1),
    ),
  )
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  let mut tip = sync_point
  for change in changes {
    let (upstream_id, tree) = change
    guard db.get(fs, upstream_id) is Some(obj) else {
      raise @bitcore.GitError::InvalidObject(
        "missing upstream commit " + upstream_id.to_hex(),
      )
    }
    tip = @bitlib.write_loose_object(
      fs,
      git_dir,
      @bitcore.ObjectType::Commit,
      @bitlib.rewrite_subdir_commit(obj.data, tree, [tip]),
    )
  }
  // Recorded before rebasing: if the rebase stops on a conflict, finishing
  // it with `bit rebase --continue` leaves HEAD on top of `tip`.
  @bitlib.update_subdir_sync_point(fs, fs, git_dir, target, tip)
  print_line(
    "Synced with \{remote_name}/\{branch}: \{changes.length()} upstream commit(s) touch \{subdir_path}",
  )
  let head = @bitlib.resolve_head_commit(fs, git_dir)
  match head {
    Some(h) if is_ancestor_commit(db, fs, tip, h) =>
      print_line("Current branch \{branch} is up to date.")
    _ => handle_rebase([tip.to_hex()])
  }
}

///|
/// Push for subdir-clone repositories: rewrite the local commits after
/// subdir-local onto subdir-base, replacing only the subdirectory.
async fn handle_subdir_push(
  fs : OsFs,
  root : String,
  git_dir : String,
  remote_url : String,
  subdir_path : String,
  base_hex : String,
  refname : String,
  _force : Bool,
) -> Unit raise Error {
  guard @bitlib.resolve_head_commit(fs, git_dir) is Some(local_head) else {
    raise @bitcore.GitError::InvalidObject("HEAD not found")
  }
  let upstream_base = @bitcore.ObjectId::from_hex(base_hex) catch {
    _ => raise @bitcore.GitError::InvalidObject("invalid subdir-base")
  }
  let sync_point = subdir_sync_point(fs, git_dir)
  let local_commits = subdir_unsynced_commits(
    @bitlib.ObjectDb::load_lazy(fs, git_dir),
    fs,
    sync_point,
    local_head,
  )
  if local_commits.length() == 0 {
    print_line("Everything up-to-date")
    return
  }
  print_line("  \{local_commits.length()} local commit(s) to push")
  // The base commit and its trees are normally local already (cloned, pushed
  // or fetched); fetch the upstream if they are not.
  if @bitlib.ObjectDb::load_lazy(fs, git_dir).get(fs, upstream_base) is None {
    ignore(run_git_command(["-C", root, "fetch", "origin"], cwd=None))
  }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  if db.get(fs, upstream_base) is None {
    raise @bitcore.GitError::InvalidObject(
      "upstream base \{base_hex} is not available locally; run `bit pull` first",
    )
  }
  let mut parent = upstream_base
  for commit_id in local_commits {
    parent = subdir_transform_commit(
      fs, db, git_dir, commit_id, parent, subdir_path,
    )
  }
  let pushed = parent
  match @bitlib.resolve_local_repo_path(fs, root, remote_url) {
    Some(path) =>
      subdir_push_local(fs, db, path, upstream_base, pushed, refname)
    None => {
      errdefer eprint_line(
        "hint: the upstream may have moved on; run `bit pull` in this subdir-clone, then push again",
      )
      let result = @bitlibnative.push_http_tree_only(
        fs, root, remote_url, pushed, upstream_base, refname,
      )
      print_line("  \{result}")
    }
  }
  @bitlib.update_subdir_sync_point(fs, fs, git_dir, pushed, local_head)
  if refname.has_prefix("refs/heads/") {
    write_ref_file(
      fs,
      git_dir,
      "refs/remotes/origin/" +
      String::unsafe_substring(refname, start=11, end=refname.length()),
      pushed,
    )
  }
  print_line(
    "  \{upstream_base.to_hex()[:7]}..\{pushed.to_hex()[:7]}  HEAD -> \{refname}",
  )
}

///|
/// Rewrite one local commit onto `upstream_parent`, putting its tree at
/// `subdir_path` and keeping its author, committer and message.
fn subdir_transform_commit(
  fs : OsFs,
  db : @bitlib.ObjectDb,
  git_dir : String,
  local_commit : @bitcore.ObjectId,
  upstream_parent : @bitcore.ObjectId,
  subdir_path : String,
) -> @bitcore.ObjectId raise @bitcore.GitError {
  guard db.get(fs, local_commit) is Some(local_obj) else {
    raise @bitcore.GitError::InvalidObject("Cannot find local commit")
  }
  guard db.get(fs, upstream_parent) is Some(upstream_obj) else {
    raise @bitcore.GitError::InvalidObject("Cannot find upstream commit")
  }
  let local_info = @bitcore.parse_commit(local_obj.data)
  let upstream_info = @bitcore.parse_commit(upstream_obj.data)
  let new_root_tree = replace_tree_at_path(
    fs,
    db,
    git_dir,
    upstream_info.tree,
    subdir_path,
    local_info.tree,
  )
  @bitlib.write_loose_object(
    fs,
    git_dir,
    @bitcore.ObjectType::Commit,
    @bitlib.rewrite_subdir_commit(local_obj.data, new_root_tree, [
      upstream_parent,
    ]),
  )
}

///|
/// Push to an upstream repository on the local filesystem: copy the new
/// objects and move the ref if it still points at `base`.
async fn subdir_push_local(
  fs : OsFs,
  db : @bitlib.ObjectDb,
  remote_path : String,
  base : @bitcore.ObjectId,
  pushed : @bitcore.ObjectId,
  refname : String,
) -> Unit raise Error {
  guard @bitlib.detect_git_dir(fs, remote_path) is Some((remote_git_dir, bare)) else {
    raise @bitcore.GitError::InvalidObject(
      "Not a git repository: " + remote_path,
    )
  }
  match @bitlib.resolve_ref(fs, remote_git_dir, refname) {
    Some(current) if current != base => {
      eprint_line(" ! [rejected]        HEAD -> \{refname} (fetch first)")
      eprint_line(
        "hint: the upstream has new commits; run `bit pull` in this subdir-clone, then push again",
      )
      raise @bitcore.GitError::InvalidObject(
        "failed to push some refs to '\{remote_path}'",
      )
    }
    _ => ()
  }
  if !bare && refname.has_prefix("refs/heads/") {
    let branch = String::unsafe_substring(
      refname,
      start=11,
      end=refname.length(),
    )
    let deny = @bitlib.read_config_value(
      fs,
      remote_git_dir + "/config",
      "receive",
      "denycurrentbranch",
    ).map(v => v.to_lower())
    let allowed = match deny {
      Some("ignore") | Some("warn") | Some("false") | Some("no") => true
      _ => false
    }
    if !allowed &&
      @bitlib.is_branch_checked_out(fs, remote_path, branch) is Some(_) {
      raise @bitcore.GitError::InvalidObject(
        "refusing to update checked out branch: \{refname}",
      )
    }
  }
  for obj in @bitlib.collect_diff_objects(db, fs, base, pushed) {
    ignore(
      @bitlib.write_loose_object(fs, remote_git_dir, obj.obj_type, obj.data),
    )
  }
  write_ref_file(fs, remote_git_dir, refname, pushed)
}

///|
/// The commit to cherry-pick in a subdir-clone. An upstream commit (one that
/// has the subdirectory) is converted into a commit of the subdirectory alone
/// so the regular three-way cherry-pick applies just its change; local commits
/// are returned as they are. None when the upstream commit leaves the
/// subdirectory untouched.
async fn subdir_cherry_pick_source(
  fs : OsFs,
  root : String,
  git_dir : String,
  remote_url : String,
  commit_id : @bitcore.ObjectId,
  subdir_path : String,
) -> @bitcore.ObjectId? raise Error {
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  guard db.get(fs, commit_id) is Some(obj) else {
    raise @bitcore.GitError::InvalidObject("Commit not found")
  }
  guard @bitlib.get_subdir_tree_from_commit(db, fs, commit_id, subdir_path)
    is Some(tree) else {
    return Some(commit_id)
  }
  let info = @bitcore.parse_commit(obj.data)
  let parent_tree = if info.parents.length() > 0 {
    @bitlib.get_subdir_tree_from_commit(db, fs, info.parents[0], subdir_path)
  } else {
    None
  }
  if parent_tree == Some(tree) {
    return None
  }
  let trees = [tree]
  match parent_tree {
    Some(t) => trees.push(t)
    None => ()
  }
  ignore(subdir_fetch_missing_blobs(fs, root, git_dir, remote_url, trees))
  let parents = match parent_tree {
    Some(t) => {
      guard db.get(fs, info.parents[0]) is Some(parent_obj) else {
        raise @bitcore.GitError::InvalidObject("missing parent commit")
      }
      [
        @bitlib.write_loose_object(
          fs,
          git_dir,
          @bitcore.ObjectType::Commit,
          @bitlib.rewrite_subdir_commit(parent_obj.data, t, []),
        ),
      ]
    }
    None => []
  }
  Some(
    @bitlib.write_loose_object(
      fs,
      git_dir,
      @bitcore.ObjectType::Commit,
      @bitlib.rewrite_subdir_commit(obj.data, tree, parents),
    ),
  )
}

///|
/// `bit pull [<remote> [<branch>]]` in a subdir-clone.
async fn handle_subdir_pull(
  fs : OsFs,
  root : String,
  git_dir : String,
  args : Array[String],
) -> Unit raise Error {
  let positional : Array[String] = []
  for arg in args {
    if !arg.has_prefix("-") {
      positional.push(arg)
    }
  }
  let upstream = match positional {
    [] => None
    [remote] => Some(remote)
    [remote, branch, ..] => Some(remote + "/" + branch)
  }
  handle_subdir_rebase(fs, root, git_dir, upstream)
}
