///|
priv struct PackRedundantEntry {
  pack_path : String
  ids : Array[String]
  remaining : Map[String, Bool]
  mut unique : Map[String, Bool]
  all_objects_size : Int
}

///|
fn load_pack_idx_entries(
  fs : OsFs,
  pack_dir : String,
) -> Array[PackRedundantEntry] {
  let result : Array[PackRedundantEntry] = []
  let entries = fs.readdir(pack_dir) catch { _ => return result }
  for entry in entries {
    let name = normalize_dir_entry(entry)
    if not(name.has_suffix(".idx")) {
      continue
    }
    let idx_path = pack_dir + "/" + name
    if not(fs.is_file(idx_path)) {
      continue
    }
    let base = String::unsafe_substring(name, start=0, end=name.length() - 4)
    let pack_path = pack_dir + "/" + base + ".pack"
    if not(fs.is_file(pack_path)) {
      continue
    }
    let data = fs.read_file(idx_path) catch { _ => continue }
    let ids = match parse_pack_index_ids(data) {
      Some(ids) => ids
      None => continue
    }
    let remaining : Map[String, Bool] = {}
    for id in ids {
      remaining[id] = true
    }
    result.push({
      pack_path,
      ids,
      remaining,
      unique: {},
      all_objects_size: ids.length(),
    })
  }
  result
}

///|
async fn handle_pack_redundant(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let mut load_all = false
  let mut verbose = false
  let mut alt_odb = false
  let mut i_still_use_this = false
  let pack_filenames : Array[String] = []
  for arg in args {
    match arg {
      "--all" => load_all = true
      "--verbose" => verbose = true
      "--alt-odb" => alt_odb = true
      "--i-still-use-this" => i_still_use_this = true
      _ if arg.has_prefix("-") => ()
      _ => pack_filenames.push(arg)
    }
  }
  if not(i_still_use_this) {
    @stdio.stderr.write(
      "WARNING: git pack-redundant has been nominated for removal.\nIf you still use this command, please add an extra\noption, '--i-still-use-this', on the command line and\nlet us know you still use it by sending an e-mail\nto git@vger.kernel.org. Thanks.\n",
    )
    @sys.exit(1)
  }
  let git_dir = find_git_dir(fs)
  let pack_dir = git_dir + "/objects/pack"
  // Load local pack indexes
  let local_packs : Array[PackRedundantEntry] = if load_all {
    if fs.is_dir(pack_dir) {
      load_pack_idx_entries(fs, pack_dir)
    } else {
      []
    }
  } else {
    let all_entries = if fs.is_dir(pack_dir) {
      load_pack_idx_entries(fs, pack_dir)
    } else {
      []
    }
    let filtered : Array[PackRedundantEntry] = []
    for filename in pack_filenames {
      for entry in all_entries {
        if entry.pack_path.contains(filename) {
          filtered.push(entry)
          break
        }
      }
    }
    filtered
  }
  if local_packs.length() == 0 {
    eprint_line("fatal: Zero packs found!")
    @sys.exit(1)
  }
  // Load alt-odb packs (when --alt-odb or --verbose)
  let altodb_packs : Array[PackRedundantEntry] = []
  if alt_odb || verbose {
    let alt_dirs = read_alternate_object_dirs(fs, git_dir)
    for alt_dir in alt_dirs {
      let alt_pack_dir = alt_dir + "/pack"
      if fs.is_dir(alt_pack_dir) {
        let entries = load_pack_idx_entries(fs, alt_pack_dir)
        altodb_packs.append(entries)
      }
    }
  }
  // Build all_objects = union of local pack objects
  let all_objects : Map[String, Bool] = {}
  for pack in local_packs {
    for id in pack.ids {
      all_objects[id] = true
    }
  }
  // Remove objects present in alt-odb packs (always, same as git's load_all_objects)
  for pack in altodb_packs {
    for id in pack.ids {
      all_objects.remove(id)
    }
  }
  // If --alt-odb: also remove alt objects from each local pack's remaining
  if alt_odb {
    for alt_pack in altodb_packs {
      for local_pack in local_packs {
        for id in alt_pack.ids {
          local_pack.remaining.remove(id)
        }
      }
    }
  }
  // Read stdin ignore objects (only if stdin is not a tty)
  let is_tty = pack_redundant_stdin_is_tty()
  if not(is_tty) {
    let input = read_all_stdin()
    let lines = split_lines_bytes(input)
    for line in lines {
      let trimmed = trim_line_bytes(line)
      if trimmed.length() == 0 {
        continue
      }
      let hex = line_to_string(trimmed)
      all_objects.remove(hex)
      for pack in local_packs {
        pack.remaining.remove(hex)
      }
    }
  }
  // Compute unique objects per pack
  let object_pack_count : Map[String, Int] = {}
  for pack in local_packs {
    for item in pack.remaining {
      let (id, _) = item
      match object_pack_count.get(id) {
        Some(c) => object_pack_count[id] = c + 1
        None => object_pack_count[id] = 1
      }
    }
  }
  for pack in local_packs {
    let unique : Map[String, Bool] = {}
    for item in pack.remaining {
      let (id, _) = item
      if object_pack_count.get(id) == Some(1) {
        unique[id] = true
      }
    }
    pack.unique = unique
  }
  // Minimize: find minimum set of packs covering all_objects
  let min_set = pack_redundant_minimize(local_packs, all_objects)
  let min_paths : Map[String, Bool] = {}
  for pack in min_set {
    min_paths[pack.pack_path] = true
  }
  // Verbose output (before stdout)
  if verbose {
    @stdio.stderr.write(
      "There are " +
      altodb_packs.length().to_string() +
      " packs available in alt-odbs.\n",
    )
    @stdio.stderr.write("The smallest (bytewise) set of packs is:\n")
    for pack in min_set {
      let rel = make_relative_to_git_dir(pack.pack_path, git_dir)
      @stdio.stderr.write("\t" + rel + "\n")
    }
    let redundancy = pack_redundant_get_redundancy(min_set)
    @stdio.stderr.write(
      "containing " +
      redundancy.to_string() +
      " duplicate objects " +
      "with a total size of 0kb.\n",
    )
    @stdio.stderr.write(
      "A total of " +
      all_objects.length().to_string() +
      " unique objects were considered.\n",
    )
    @stdio.stderr.write("Redundant packs (with indexes):\n")
  }
  // Output redundant packs: idx path first, then pack path
  // Use paths relative to git_dir (prefixed with "./" like git does)
  for pack in local_packs {
    if not(min_paths.contains(pack.pack_path)) {
      let rel_pack = make_relative_to_git_dir(pack.pack_path, git_dir)
      let rel_idx = pack_path_to_idx(rel_pack)
      print_line(rel_idx)
      print_line(rel_pack)
    }
  }
  if verbose {
    @stdio.stderr.write("0MB of redundant packs in total.\n")
  }
}

///|
fn pack_redundant_minimize(
  packs : Array[PackRedundantEntry],
  all_objects : Map[String, Bool],
) -> Array[PackRedundantEntry] {
  let essential : Array[PackRedundantEntry] = []
  let non_essential : Array[PackRedundantEntry] = []
  for pack in packs {
    if pack.unique.length() > 0 {
      essential.push(pack)
    } else {
      non_essential.push(pack)
    }
  }
  // Find objects not yet covered by essential packs
  let missing : Map[String, Bool] = {}
  for item in all_objects {
    let (id, _) = item
    missing[id] = true
  }
  for pack in essential {
    for item in pack.remaining {
      let (id, _) = item
      missing.remove(id)
    }
  }
  if missing.length() == 0 {
    return essential
  }
  // Remove objects covered by essential packs from non-essential remaining
  let covered_by_essential : Map[String, Bool] = {}
  for item in all_objects {
    let (id, _) = item
    if not(missing.contains(id)) {
      covered_by_essential[id] = true
    }
  }
  for pack in non_essential {
    for item in covered_by_essential {
      let (id, _) = item
      pack.remaining.remove(id)
    }
  }
  // Greedy: pick pack with most remaining objects
  while missing.length() > 0 {
    non_essential.sort_by(fn(a, b) {
      let size_cmp = b.remaining.length() - a.remaining.length()
      if size_cmp != 0 {
        size_cmp
      } else {
        b.all_objects_size - a.all_objects_size
      }
    })
    if non_essential.length() == 0 || non_essential[0].remaining.length() == 0 {
      break
    }
    let best = non_essential.remove(0)
    essential.push(best)
    for item in best.remaining {
      let (id, _) = item
      missing.remove(id)
      for pack in non_essential {
        pack.remaining.remove(id)
      }
    }
  }
  essential
}

///|
fn pack_redundant_get_redundancy(min_set : Array[PackRedundantEntry]) -> Int {
  if min_set.length() < 2 {
    return 0
  }
  let mut ret = 0
  for i in 0..<min_set.length() {
    for j in (i + 1)..<min_set.length() {
      let p1 = min_set[i]
      let p2 = min_set[j]
      let p2_set : Map[String, Bool] = {}
      for id in p2.ids {
        p2_set[id] = true
      }
      for id in p1.ids {
        if p2_set.contains(id) {
          ret += 1
        }
      }
    }
  }
  ret
}

///|
fn pack_path_to_idx(pack_path : String) -> String {
  if pack_path.has_suffix(".pack") {
    String::unsafe_substring(pack_path, start=0, end=pack_path.length() - 5) +
    ".idx"
  } else {
    pack_path + ".idx"
  }
}

///|
/// Convert an absolute pack path to a path relative to git_dir, prefixed with "./"
fn make_relative_to_git_dir(path : String, git_dir : String) -> String {
  if path.has_prefix(git_dir + "/") {
    "./" +
    String::unsafe_substring(
      path,
      start=git_dir.length() + 1,
      end=path.length(),
    )
  } else {
    path
  }
}

///|
async fn pack_redundant_stdin_is_tty() -> Bool {
  @process.run("sh", ["-c", "test -t 0"], inherit_env=true) == 0
}
