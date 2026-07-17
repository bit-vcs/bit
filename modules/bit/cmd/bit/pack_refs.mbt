///|
fn handle_pack_refs(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut all = false
  let mut prune = true
  for arg in args {
    match arg {
      "--all" => all = true
      "--no-prune" => prune = false
      "--prune" => prune = true
      _ => ()
    }
  }
  let refs_dir = git_dir + "/refs"
  let packed_refs_path = git_dir + "/packed-refs"
  // Read existing packed-refs
  let entries : Array[@bitrefs.PackedRefEntry] = []
  if fs.is_file(packed_refs_path) {
    let content = decode_bytes(fs.read_file(packed_refs_path))
    for e in @bitrefs.parse_packed_refs_text(content) {
      entries.push(e)
    }
  }
  // Collect refs to pack (loose values appended last, so they win dedupe)
  let refs_to_pack : Array[(String, String)] = []
  collect_refs_to_pack(fs, refs_dir, "refs", refs_to_pack, all)
  for r in refs_to_pack {
    entries.push({ refname: r.0, oid: r.1, peeled: None })
  }
  fs.write_string(
    packed_refs_path,
    @bitrefs.serialize_packed_refs_entries(entries),
  )
  // Prune loose refs if requested
  if prune {
    for r in refs_to_pack {
      let ref_path = git_dir + "/" + r.0
      if fs.is_file(ref_path) {
        fs.remove_file(ref_path)
        cleanup_empty_dirs(fs, git_dir, r.0)
      }
    }
  }
}

///|
fn collect_refs_to_pack(
  fs : OsFs,
  dir : String,
  prefix : String,
  refs : Array[(String, String)],
  all : Bool,
) -> Unit raise Error {
  if !fs.is_dir(dir) {
    return
  }
  let entries = fs.readdir(dir)
  for entry in entries {
    let path = dir + "/" + entry
    let ref_name = prefix + "/" + entry
    if fs.is_file(path) {
      if all || ref_name.has_prefix("refs/tags/") {
        let sha = (fs.read_file(path) |> decode_bytes |> trim_string) catch {
          _ => ""
        }
        if sha.length() == 40 {
          refs.push((ref_name, sha))
        }
      }
    } else if fs.is_dir(path) {
      collect_refs_to_pack(fs, path, ref_name, refs, all)
    }
  }
}

///|
/// Remove directories left empty after pruning a loose ref, mirroring git's
/// files backend: only directories deeper than `refs/<category>` are removed.
/// `.git/refs` and `.git/refs/heads` / `.git/refs/tags` etc. must survive —
/// deleting `.git/refs` makes real git no longer recognize the repository.
fn cleanup_empty_dirs(
  fs : OsFs,
  git_dir : String,
  ref_path : String,
) -> Unit raise Error {
  let parts : Array[String] = ref_path
    .split("/")
    .map(v => v.to_owned())
    .collect()
  let mut current = git_dir
  let dirs : Array[String] = []
  for i in 0..<(parts.length() - 1) {
    current = current + "/" + parts[i]
    dirs.push(current)
  }
  // dirs[0] = .git/refs, dirs[1] = .git/refs/<category>; keep both.
  let mut i = dirs.length() - 1
  while i >= 2 {
    let dir = dirs[i]
    let entries = fs.readdir(dir)
    if entries.length() == 0 {
      let _ = fs.remove_dir(dir) catch { _ => () }
    } else {
      break
    }
    i -= 1
  }
}

///|
