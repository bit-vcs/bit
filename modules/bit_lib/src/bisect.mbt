///|
/// Calculate the number of bisect steps remaining (log2).
pub fn bisect_steps(n : Int) -> Int {
  if n <= 1 {
    return 0
  }
  let mut steps = 0
  let mut val = n
  while val > 1 {
    val = val / 2
    steps += 1
  }
  steps
}

///|
/// BFS candidate computation for bisect.
/// Returns commits between bad and good that are not skipped.
pub fn bisect_get_candidates(
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
  bad : @bit.ObjectId,
  goods : Array[@bit.ObjectId],
  skips : Array[@bit.ObjectId],
) -> Array[@bit.ObjectId] raise Error {
  let good_set : Map[String, Bool] = {}
  for g in goods {
    bisect_mark_ancestors(db, rfs, g, good_set)
  }
  // Pre-build skip set for O(1) lookup
  let skip_set : Map[String, Bool] = {}
  for s in skips {
    skip_set[s.to_hex()] = true
  }
  let candidates : Array[@bit.ObjectId] = []
  let visited : Map[String, Bool] = {}
  let queue : Array[@bit.ObjectId] = [bad]
  while queue.length() > 0 {
    let current = queue.pop()
    guard current is Some(cid) else { break }
    let hex = cid.to_hex()
    if visited.contains(hex) || good_set.contains(hex) {
      continue
    }
    visited[hex] = true
    if !skip_set.contains(hex) && cid != bad {
      candidates.push(cid)
    }
    let obj = db.get(rfs, cid)
    match obj {
      Some(o) => {
        let info = @bit.parse_commit(o.data)
        for p in info.parents {
          queue.push(p)
        }
      }
      None => ()
    }
  }
  candidates
}

///|
/// Mark all ancestors of a commit in the given set (BFS).
pub fn bisect_mark_ancestors(
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
  start : @bit.ObjectId,
  set : Map[String, Bool],
) -> Unit {
  let queue : Array[@bit.ObjectId] = [start]
  while queue.length() > 0 {
    let current = queue.pop()
    guard current is Some(cid) else { break }
    let hex = cid.to_hex()
    if set.contains(hex) {
      continue
    }
    set[hex] = true
    let obj = db.get(rfs, cid) catch { _ => None }
    match obj {
      Some(o) => {
        let info = @bit.parse_commit(o.data) catch { _ => continue }
        for p in info.parents {
          queue.push(p)
        }
      }
      None => ()
    }
  }
}

///|
/// Shell-quote arguments for bisect run command string.
pub fn bisect_shell_quote_args(args : Array[String]) -> String {
  let parts : Array[String] = []
  for arg in args {
    if arg.contains(" ") ||
      arg.contains("'") ||
      arg.contains("\"") ||
      arg.contains("\\") {
      // Single-quote with escaping
      let escaped = arg.replace(old="'", new="\\'")
      parts.push("'" + escaped + "'")
    } else {
      parts.push(arg)
    }
  }
  parts.join(" ")
}
