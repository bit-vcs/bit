///| Rename detection for merge

///|
priv struct SideRenames {
  /// old_path -> new_path
  old_to_new : Map[String, String]
  /// Paths where original content was replaced with new content (add-source)
  add_source_paths : Map[String, Bool]
}

///| Detect renames between base and a side (ours or theirs).
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
  let replaced_paths : Map[String, Bool] = {}
  for path, entry in base {
    if not(side.contains(path)) {
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
    if not(base.contains(path)) {
      added.push((path, entry))
    }
  }
  let old_to_new : Map[String, String] = {}
  let add_source_paths : Map[String, Bool] = {}
  let matched_source : Map[String, Bool] = {}
  let matched_added : Map[String, Bool] = {}
  // Phase 1: Build OID index for exact matching
  let source_by_oid : Map[String, Array[String]] = {}
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
          if not(matched_source.contains(old_path)) {
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
    if not(matched_source.contains(path)) {
      unmatched_sources.push(item)
    }
  }
  let unmatched_added : Array[(String, TreeFileEntry)] = []
  for item in added {
    let (path, _) = item
    if not(matched_added.contains(path)) {
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

///| Compute similarity score (0-100) between two text contents.
/// Uses line-based comparison: score = 100 * common_lines / max(lines_a, lines_b)
fn rename_similarity_score(a : String, b : String) -> Int {
  let a_lines : Array[String] = []
  for line in a.split("\n") {
    let s = line.to_string()
    if s.length() > 0 {
      a_lines.push(s)
    }
  }
  let b_lines : Array[String] = []
  for line in b.split("\n") {
    let s = line.to_string()
    if s.length() > 0 {
      b_lines.push(s)
    }
  }
  if a_lines.length() == 0 && b_lines.length() == 0 {
    return 100
  }
  if a_lines.length() == 0 || b_lines.length() == 0 {
    return 0
  }
  // Count common lines using a set
  let b_set : Map[String, Int] = {}
  for line in b_lines {
    b_set[line] = b_set.get(line).unwrap_or(0) + 1
  }
  let mut common = 0
  for line in a_lines {
    let count = b_set.get(line).unwrap_or(0)
    if count > 0 {
      common += 1
      b_set[line] = count - 1
    }
  }
  let max_lines = if a_lines.length() > b_lines.length() {
    a_lines.length()
  } else {
    b_lines.length()
  }
  100 * common / max_lines
}
