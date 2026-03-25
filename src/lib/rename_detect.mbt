///| Rename detection for merge

///|
priv struct SideRenames {
  /// old_path -> new_path
  old_to_new : Map[String, String]
  /// Paths where original content was replaced with new content (add-source)
  /// These paths had their original content renamed away; the current content
  /// at these paths is a new, unrelated file.
  add_source_paths : Map[String, Bool]
}

///| Detect exact-OID renames between base and a side (ours or theirs).
///
/// Handles two patterns:
/// 1. Simple rename: file deleted at old_path, added at new_path with same OID
/// 2. Rename + add-source: file at old_path has different OID in side (replaced),
///    and the base OID appears at a new_path in side. This means the original
///    content was renamed to new_path, and old_path got new unrelated content.
fn merge_detect_renames(
  base : Map[String, TreeFileEntry],
  side : Map[String, TreeFileEntry],
) -> SideRenames {
  // Potential rename sources: paths whose base content disappeared from that path
  // Case 1: deleted (in base, not in side)
  // Case 2: replaced (in both, but different OID - "add-source" pattern)
  let sources : Array[(String, TreeFileEntry)] = []
  let replaced_paths : Map[String, Bool] = {}
  for path, entry in base {
    if not(side.contains(path)) {
      // Deleted: definitely a rename source candidate
      sources.push((path, entry))
    } else {
      match side.get(path) {
        Some(side_entry) =>
          if side_entry.id != entry.id {
            // Content changed: potential add-source rename
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
  // Build OID index for source files
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
  { old_to_new, add_source_paths }
}
