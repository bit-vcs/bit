///| Merge-base algorithms: ancestor check, all merge bases, independent tips

///|
/// Check if ancestor is an ancestor of descendant using BFS.
pub fn merge_base_is_ancestor(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  ancestor : @bit.ObjectId,
  descendant : @bit.ObjectId,
) -> Bool raise @bit.GitError {
  let ancestor_hex = ancestor.to_hex()
  let descendant_hex = descendant.to_hex()
  if ancestor_hex == descendant_hex {
    return true
  }
  let visited : Map[String, Bool] = {}
  let queue : Array[@bit.ObjectId] = [descendant]
  while queue.length() > 0 {
    let current = queue.unsafe_pop()
    let hex = current.to_hex()
    if hex == ancestor_hex {
      return true
    }
    if visited.contains(hex) {
      continue
    }
    visited[hex] = true
    let obj = db.get(fs, current)
    match obj {
      Some(o) =>
        if o.obj_type == @bit.ObjectType::Commit {
          let info = @bit.parse_commit(o.data)
          for parent in info.parents {
            queue.push(parent)
          }
        }
      None => ()
    }
  }
  false
}

///|
/// Find all merge bases between two commits.
/// A merge base is a common ancestor that is not an ancestor of any other common ancestor.
pub fn merge_base_all(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  a : @bit.ObjectId,
  b : @bit.ObjectId,
) -> Array[@bit.ObjectId] raise @bit.GitError {
  // Collect all ancestors of A (including A itself)
  let ancestors_a : Map[String, Bool] = {}
  let q1 : Array[@bit.ObjectId] = [a]
  while q1.length() > 0 {
    let current = q1.unsafe_pop()
    let hex = current.to_hex()
    if ancestors_a.contains(hex) {
      continue
    }
    ancestors_a[hex] = true
    let obj = db.get(fs, current)
    match obj {
      Some(o) =>
        if o.obj_type == @bit.ObjectType::Commit {
          let info = @bit.parse_commit(o.data)
          for parent in info.parents {
            q1.push(parent)
          }
        }
      None => ()
    }
  }
  // BFS from B, collect all common ancestors
  let common : Array[@bit.ObjectId] = []
  let common_set : Map[String, Bool] = {}
  let seen : Map[String, Bool] = {}
  let q2 : Array[@bit.ObjectId] = [b]
  while q2.length() > 0 {
    let current = q2.unsafe_pop()
    let hex = current.to_hex()
    if seen.contains(hex) {
      continue
    }
    seen[hex] = true
    if ancestors_a.contains(hex) {
      if not(common_set.contains(hex)) {
        common.push(current)
        common_set[hex] = true
      }
      // Don't traverse further — ancestors of this are also common but "deeper"
      continue
    }
    let obj = db.get(fs, current)
    match obj {
      Some(o) =>
        if o.obj_type == @bit.ObjectType::Commit {
          let info = @bit.parse_commit(o.data)
          for parent in info.parents {
            q2.push(parent)
          }
        }
      None => ()
    }
  }
  // Filter: remove any common ancestor that is an ancestor of another common ancestor.
  if common.length() <= 1 {
    return common
  }
  let result : Array[@bit.ObjectId] = []
  for ci in 0..<common.length() {
    let candidate = common[ci]
    let candidate_hex = candidate.to_hex()
    let mut is_ancestor_of_another = false
    for cj in 0..<common.length() {
      if ci == cj {
        continue
      }
      let other = common[cj]
      let other_hex = other.to_hex()
      if candidate_hex == other_hex {
        continue
      }
      // BFS from other to see if candidate is reachable
      let visited2 : Map[String, Bool] = {}
      let q3 : Array[@bit.ObjectId] = [other]
      while q3.length() > 0 {
        let cur = q3.unsafe_pop()
        let chex = cur.to_hex()
        if chex == candidate_hex {
          is_ancestor_of_another = true
          break
        }
        if visited2.contains(chex) {
          continue
        }
        visited2[chex] = true
        let obj = db.get(fs, cur)
        match obj {
          Some(o) =>
            if o.obj_type == @bit.ObjectType::Commit {
              let info = @bit.parse_commit(o.data)
              for parent in info.parents {
                q3.push(parent)
              }
            }
          None => ()
        }
      }
      if is_ancestor_of_another {
        break
      }
    }
    if not(is_ancestor_of_another) {
      result.push(candidate)
    }
  }
  result
}

///|
/// Find independent commits: those not reachable from any other in the set.
pub fn merge_base_independent(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  commits : Array[@bit.ObjectId],
) -> Array[@bit.ObjectId] raise @bit.GitError {
  let result : Array[@bit.ObjectId] = []
  for idx_i in 0..<commits.length() {
    let candidate = commits[idx_i]
    let mut reachable = false
    for idx_j in 0..<commits.length() {
      if idx_i == idx_j {
        continue
      }
      if merge_base_is_ancestor(db, fs, candidate, commits[idx_j]) {
        reachable = true
        break
      }
    }
    if not(reachable) {
      result.push(candidate)
    }
  }
  result
}
