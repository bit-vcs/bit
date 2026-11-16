///| Rename detection for merge

///|
priv struct SideRenames {
  /// old_path -> new_path
  old_to_new : Map[String, String]
  /// Paths where original content was replaced with new content (add-source)
  add_source_paths : Map[String, Bool]
}

///|
/// Detect renames between base and a side (ours or theirs).
///
/// Phase 1: Exact OID matching (fast)
/// Phase 2: Content similarity matching for unmatched pairs (threshold 50%)
///
/// Handles add-source pattern: file at old_path has different OID in side
/// (replaced), and the base content appears at a new_path in side.
fn merge_detect_renames(
  base : Map[String, TreeFileEntry],
  side : Map[String, TreeFileEntry],
  db : ObjectDb,
  rfs : &@bit.RepoFileSystem,
) -> SideRenames {
  // Potential rename sources: paths whose base content disappeared from that path
  let sources : Array[(String, TreeFileEntry)] = []
  let replaced_paths : Map[String, Bool] = Map([])
  // merge-ort turns rename_empty off: an empty blob is never a rename
  // source or destination.
  let empty = @bit.hash_blob(Bytes::new(0))
  for path, entry in base {
    if entry.id == empty {
      continue
    }
    if !side.contains(path) {
      sources.push((path, entry))
    } else {
      match side.get(path) {
        Some(side_entry) =>
          if side_entry.id != entry.id {
            sources.push((path, entry))
            replaced_paths[path] = true
          }
        None => ()
      }
    }
  }
  // Added paths: in side but not in base
  let added : Array[(String, TreeFileEntry)] = []
  for path, entry in side {
    if !base.contains(path) && entry.id != empty {
      added.push((path, entry))
    }
  }
  let old_to_new : Map[String, String] = Map([])
  let add_source_paths : Map[String, Bool] = Map([])
  let matched_source : Map[String, Bool] = Map([])
  let matched_added : Map[String, Bool] = Map([])
  // Phase 1: Build OID index for exact matching
  let source_by_oid : Map[String, Array[String]] = Map([])
  for item in sources {
    let (path, entry) = item
    let hex = entry.id.to_hex()
    match source_by_oid.get(hex) {
      Some(arr) => arr.push(path)
      None => source_by_oid[hex] = [path]
    }
  }
  for item in added {
    let (new_path, entry) = item
    if matched_added.contains(new_path) {
      continue
    }
    let hex = entry.id.to_hex()
    match source_by_oid.get(hex) {
      Some(candidates) =>
        for old_path in candidates {
          if !matched_source.contains(old_path) {
            old_to_new[old_path] = new_path
            matched_source[old_path] = true
            matched_added[new_path] = true
            if replaced_paths.contains(old_path) {
              add_source_paths[old_path] = true
            }
            break
          }
        }
      None => ()
    }
  }
  // Phase 2: Content similarity for unmatched pairs
  // Collect unmatched sources and added files
  let unmatched_sources : Array[(String, TreeFileEntry)] = []
  for item in sources {
    let (path, _) = item
    if !matched_source.contains(path) {
      unmatched_sources.push(item)
    }
  }
  let unmatched_added : Array[(String, TreeFileEntry)] = []
  for item in added {
    let (path, _) = item
    if !matched_added.contains(path) {
      unmatched_added.push(item)
    }
  }
  if unmatched_sources.length() > 0 && unmatched_added.length() > 0 {
    // Compute similarities and find best matches
    let best_matches : Array[(String, String, Int)] = []
    for src_item in unmatched_sources {
      let (src_path, src_entry) = src_item
      let src_text = get_blob_content(db, rfs, src_entry.id)
      if src_text.length() == 0 {
        continue
      }
      let mut best_score = 0
      let mut best_path = ""
      for add_item in unmatched_added {
        let (add_path, add_entry) = add_item
        if matched_added.contains(add_path) {
          continue
        }
        let add_text = get_blob_content(db, rfs, add_entry.id)
        if add_text.length() == 0 {
          continue
        }
        let score = rename_similarity_score(src_text, add_text)
        if score > best_score {
          best_score = score
          best_path = add_path
        }
      }
      if best_score >= 50 && best_path.length() > 0 {
        best_matches.push((src_path, best_path, best_score))
      }
    }
    // Sort by score descending, then greedily assign
    best_matches.sort_by(fn(a, b) { b.2.compare(a.2) })
    for item in best_matches {
      let (src_path, add_path, _) = item
      if matched_source.contains(src_path) || matched_added.contains(add_path) {
        continue
      }
      old_to_new[src_path] = add_path
      matched_source[src_path] = true
      matched_added[add_path] = true
      if replaced_paths.contains(src_path) {
        add_source_paths[src_path] = true
      }
    }
  }
  { old_to_new, add_source_paths }
}

///|
/// Compute similarity score (0-100) between two text contents, weighted by
/// bytes like git's diffcore (bytes of shared lines over the larger size),
/// so a few short common lines do not make two files "renames".
fn rename_similarity_score(a : String, b : String) -> Int {
  let a_lines : Array[String] = a.split("\n").map(l => l.to_owned()).collect()
  let b_lines : Array[String] = b.split("\n").map(l => l.to_owned()).collect()
  // Each line counts with its newline; a trailing "" after the final \n
  // is not a line.
  let weight = fn(l : String) { l.length() + 1 }
  let total = fn(lines : Array[String]) {
    let mut t = 0
    for i, l in lines {
      if i == lines.length() - 1 && l.length() == 0 {
        continue
      }
      t += weight(l)
    }
    t
  }
  let total_a = total(a_lines)
  let total_b = total(b_lines)
  if total_a == 0 && total_b == 0 {
    return 100
  }
  if total_a == 0 || total_b == 0 {
    return 0
  }
  let b_set : Map[String, Int] = Map([])
  for i, line in b_lines {
    if i == b_lines.length() - 1 && line.length() == 0 {
      continue
    }
    b_set[line] = b_set.get(line).unwrap_or(0) + 1
  }
  let mut common = 0
  for i, line in a_lines {
    if i == a_lines.length() - 1 && line.length() == 0 {
      continue
    }
    let count = b_set.get(line).unwrap_or(0)
    if count > 0 {
      common += weight(line)
      b_set[line] = count - 1
    }
  }
  let max_total = if total_a > total_b { total_a } else { total_b }
  100 * common / max_total
}
