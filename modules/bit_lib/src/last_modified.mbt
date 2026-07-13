///|
/// Core of `git last-modified` (git 2.55): attribute each final-state path to
/// the commit that last modified it. Pure logic over `ObjectDb` +
/// `RepoFileSystem`; the CLI wrapper handles argument parsing and output.

///|
pub(all) struct LmPath {
  path : String
}

///|
pub(all) struct LmResult {
  oid : @bit.ObjectId
  path : String
  boundary : Bool
}

///|
pub(all) struct LmCommit {
  id : @bit.ObjectId
  tree : @bit.ObjectId
  parents : Array[@bit.ObjectId]
  timestamp : Int64
}

///|
/// Parse the committer timestamp (unix seconds) from a raw commit object.
pub fn last_modified_committer_ts(data : Bytes) -> Int64 {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("committer ") {
      // "committer Name <email> <ts> <tz>"
      let parts = line.split(" ")
      let toks : Array[String] = []
      for p in parts {
        toks.push(p.to_owned())
      }
      // timestamp is the second-to-last token.
      if toks.length() >= 2 {
        let ts_str = toks[toks.length() - 2]
        return @strconv.parse_int64(ts_str) catch { _ => 0L }
      }
    }
  }
  0L
}

///|
/// Does any pathspec reach strictly into the subtree at `path` (i.e. name
/// something below it)? Such a subtree must be descended even at the depth
/// limit, so pathspecs like `a/file` or `a/*` can be found.
fn last_modified_reaches_into(path : String, pathspecs : Array[String]) -> Bool {
  for spec in pathspecs {
    if spec.has_prefix(path + "/") {
      return true
    }
  }
  false
}

///|
/// Collect the entries of `tree_id` honoring last-modified's depth model.
/// `max_depth < 0` = unlimited (`-r`); `0` (default) = top-level only; a tree
/// reached at exactly `max_depth` is emitted as a tree leaf; trees above it are
/// descended and only shown when `show_trees`. A subtree named by a pathspec is
/// always descended so the named paths can be reached.
pub fn last_modified_collect_entries(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  tree_id : @bit.ObjectId,
  prefix : String,
  depth : Int,
  max_depth : Int,
  show_trees : Bool,
  pathspecs : Array[String],
  out : Array[LmPath],
) -> Unit raise @bit.GitError {
  let obj = db.get(fs, tree_id)
  guard obj is Some(tree_obj) else {
    raise @bit.GitError::InvalidObject("Missing tree object")
  }
  let entries = @bit.parse_tree(tree_obj.data)
  for entry in entries {
    let path = if prefix.length() == 0 {
      entry.name
    } else {
      prefix + "/" + entry.name
    }
    let is_tree = entry.mode == "40000" || entry.mode == "040000"
    if is_tree {
      let pathspec_descend = last_modified_reaches_into(path, pathspecs)
      let can_descend = max_depth < 0 || depth < max_depth || pathspec_descend
      if can_descend {
        // A pathspec-forced descent does not surface the tree itself unless
        // -t is set and the tree is within the normal depth budget.
        if show_trees && (max_depth < 0 || depth < max_depth) {
          out.push({ path, })
        }
        last_modified_collect_entries(
          db, fs, entry.id, path, depth + 1, max_depth, show_trees, pathspecs,
          out,
        )
      } else {
        out.push({ path, })
      }
    } else {
      out.push({ path, })
    }
  }
}

///|
/// Resolve `path` (slash-separated) to its object id within `tree_id`, or None.
fn last_modified_path_oid(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  tree_id : @bit.ObjectId,
  path : String,
) -> @bit.ObjectId? raise @bit.GitError {
  let comps : Array[String] = []
  for c in path.split("/") {
    comps.push(c.to_owned())
  }
  let mut cur = tree_id
  for k in 0..<comps.length() {
    let obj = db.get(fs, cur)
    guard obj is Some(o) else { return None }
    if o.obj_type != @bit.ObjectType::Tree {
      return None
    }
    let entries = @bit.parse_tree(o.data)
    let mut found : @bit.ObjectId? = None
    for entry in entries {
      if entry.name == comps[k] {
        found = Some(entry.id)
        break
      }
    }
    guard found is Some(next) else { return None }
    if k == comps.length() - 1 {
      return Some(next)
    }
    cur = next
  }
  None
}

///|
/// Minimal pathspec matcher: exact path, directory prefix, or a trailing `/*`
/// wildcard. Empty list matches everything.
pub fn last_modified_pathspec_matches(
  path : String,
  pathspecs : Array[String],
) -> Bool {
  if pathspecs.length() == 0 {
    return true
  }
  for spec in pathspecs {
    if last_modified_one_pathspec(path, spec) {
      return true
    }
  }
  false
}

///|
fn last_modified_one_pathspec(path : String, spec : String) -> Bool {
  if spec.has_suffix("/*") {
    let base = String::unsafe_substring(spec, start=0, end=spec.length() - 2)
    // Match direct children of base (one extra segment).
    if !(path.has_prefix(base + "/")) {
      return false
    }
    let rest = String::unsafe_substring(path, start=base.length() + 1, end=path.length())
    return !(rest.contains("/"))
  }
  if spec.has_suffix("*") {
    let base = String::unsafe_substring(spec, start=0, end=spec.length() - 1)
    return path.has_prefix(base)
  }
  path == spec || path.has_prefix(spec + "/")
}

///|
fn last_modified_load_commit(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  id : @bit.ObjectId,
) -> LmCommit raise @bit.GitError {
  let obj = db.get(fs, id)
  guard obj is Some(o) else {
    raise @bit.GitError::InvalidObject("bad commit \{id.to_hex()}")
  }
  if o.obj_type != @bit.ObjectType::Commit {
    raise @bit.GitError::InvalidObject("not a commit \{id.to_hex()}")
  }
  let info = @bit.parse_commit(o.data)
  let ts = last_modified_committer_ts(o.data)
  { id, tree: info.tree, parents: info.parents, timestamp: ts }
}

///|
fn last_modified_tag_target(data : Bytes) -> @bit.ObjectId raise @bit.GitError {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.has_prefix("object ") {
      let hex = String::unsafe_substring(line, start=7, end=line.length())
      return @bit.ObjectId::from_hex(hex)
    }
    if line.length() == 0 {
      break
    }
  }
  raise @bit.GitError::InvalidObject("tag has no object header")
}

///|
/// Peel `id` (commit/tag) to a commit; error with git's message if it is a tree.
pub fn last_modified_resolve_commitish(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  id : @bit.ObjectId,
  spec : String,
) -> LmCommit raise @bit.GitError {
  let obj = db.get(fs, id)
  guard obj is Some(o) else {
    raise @bit.GitError::InvalidObject("bad object \{id.to_hex()}")
  }
  match o.obj_type {
    @bit.ObjectType::Commit => last_modified_load_commit(db, fs, id)
    @bit.ObjectType::Tag => {
      let target = last_modified_tag_target(o.data)
      last_modified_resolve_commitish(db, fs, target, spec)
    }
    @bit.ObjectType::Tree =>
      raise @bit.GitError::InvalidObject(
        "revision argument '\{spec}' is a tree, not a commit-ish",
      )
    _ =>
      raise @bit.GitError::InvalidObject(
        "revision argument '\{spec}' is not a commit-ish",
      )
  }
}

///|
/// Compute the last-modified attribution for the tree of `start` commit.
/// `start_id` must already be resolved (e.g. via rev-parse) to a commit-ish.
pub fn last_modified_compute(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  start_id : @bit.ObjectId,
  spec : String,
  max_depth : Int,
  show_trees : Bool,
  max_count : Int,
  bottoms : Array[@bit.ObjectId],
  pathspecs : Array[String],
) -> Array[LmResult] raise @bit.GitError {
  let start = last_modified_resolve_commitish(db, fs, start_id, spec)
  let all_entries : Array[LmPath] = []
  last_modified_collect_entries(
    db, fs, start.tree, "", 0, max_depth, show_trees, pathspecs, all_entries,
  )
  let all_paths : Array[LmPath] = []
  for e in all_entries {
    if last_modified_pathspec_matches(e.path, pathspecs) {
      all_paths.push(e)
    }
  }
  // Commits reachable from any `bottom` (e.g. `A` in `A..B`) are excluded; the
  // walk treats them as boundaries and emits remaining paths with a `^` prefix.
  let bottom_set : Map[String, Bool] = {}
  let bstack : Array[@bit.ObjectId] = []
  for b in bottoms {
    let peeled = last_modified_resolve_commitish(db, fs, b, spec)
    bstack.push(peeled.id)
  }
  while bstack.length() > 0 {
    let cur = bstack.unsafe_pop()
    let hex = cur.to_hex()
    if bottom_set.contains(hex) {
      continue
    }
    bottom_set[hex] = true
    let obj = db.get(fs, cur)
    if obj is Some(o) && o.obj_type == @bit.ObjectType::Commit {
      for p in @bit.parse_commit(o.data).parents {
        bstack.push(p)
      }
    }
  }
  last_modified_walk(db, fs, start, all_paths, max_count, bottom_set)
}

///|
/// The walk: attribute each path via per-commit active-path bitmaps with
/// TREESAME propagation to parents.
fn last_modified_walk(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  start : LmCommit,
  all_paths : Array[LmPath],
  max_count : Int,
  bottom_set : Map[String, Bool],
) -> Array[LmResult] raise @bit.GitError {
  let n = all_paths.length()
  let results : Array[LmResult] = []
  if n == 0 {
    return results
  }
  let resolved = Array::make(n, false)
  let mut resolved_count = 0
  let commits : Map[String, LmCommit] = {}
  let stack = [start.id]
  commits[start.id.to_hex()] = start
  while stack.length() > 0 {
    let cur = stack.unsafe_pop()
    let c = commits.get(cur.to_hex()).unwrap()
    for p in c.parents {
      let hex = p.to_hex()
      if !(commits.contains(hex)) {
        commits[hex] = last_modified_load_commit(db, fs, p)
        stack.push(p)
      }
    }
  }
  let active : Map[String, Array[Bool]] = {}
  active[start.id.to_hex()] = Array::make(n, true)
  let processed : Map[String, Bool] = {}
  let mut popped = 0
  fn pick_next() -> String? {
    let mut best : String? = None
    let mut best_ts = 0L
    let mut have = false
    for hex, _ in active {
      if processed.contains(hex) {
        continue
      }
      let c = commits.get(hex).unwrap()
      if !(have) || c.timestamp > best_ts {
        best_ts = c.timestamp
        best = Some(hex)
        have = true
      }
    }
    best
  }

  while resolved_count < n {
    guard pick_next() is Some(chex) else { break }
    processed[chex] = true
    let c = commits.get(chex).unwrap()
    let act = active.get(chex).unwrap()
    popped += 1
    if (max_count >= 0 && popped > max_count) || bottom_set.contains(chex) {
      for idx in 0..<n {
        if act[idx] && !(resolved[idx]) {
          resolved[idx] = true
          resolved_count += 1
          results.push({ oid: c.id, path: all_paths[idx].path, boundary: true })
        }
      }
      continue
    }
    if c.parents.length() == 0 {
      for idx in 0..<n {
        if act[idx] && !(resolved[idx]) {
          resolved[idx] = true
          resolved_count += 1
          results.push({ oid: c.id, path: all_paths[idx].path, boundary: false })
        }
      }
      continue
    }
    let passed = Array::make(n, false)
    for p in c.parents {
      let p_commit = commits.get(p.to_hex()).unwrap()
      let phex = p.to_hex()
      let pact = match active.get(phex) {
        Some(s) => s
        None => {
          let s = Array::make(n, false)
          active[phex] = s
          s
        }
      }
      for idx in 0..<n {
        if !(act[idx]) || passed[idx] {
          continue
        }
        let path = all_paths[idx].path
        let c_oid = last_modified_path_oid(db, fs, c.tree, path)
        let p_oid = last_modified_path_oid(db, fs, p_commit.tree, path)
        let same = match (c_oid, p_oid) {
          (Some(a), Some(b)) => a == b
          (None, None) => true
          _ => false
        }
        if same {
          passed[idx] = true
          pact[idx] = true
        }
      }
    }
    for idx in 0..<n {
      if act[idx] && !(passed[idx]) && !(resolved[idx]) {
        resolved[idx] = true
        resolved_count += 1
        results.push({ oid: c.id, path: all_paths[idx].path, boundary: false })
      }
    }
  }
  results
}
