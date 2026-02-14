///|
async fn handle_update_index(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let git_dir = resolve_git_dir(fs, root)
  let mut add = false
  let mut remove = false
  let mut force_remove = false
  let mut refresh = false
  let mut quiet = false
  let mut ignore_missing = false
  let mut stdin = false
  let mut nul_term = false
  let mut verbose = false
  let mut skip_worktree_mode : Bool? = None
  let cacheinfo : Array[(String, String, String)] = []
  let paths : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--add" => add = true
      "--remove" => remove = true
      "--force-remove" => force_remove = true
      "--replace" => ()
      "--refresh" => refresh = true
      "--really-refresh" => refresh = true
      "-q" => quiet = true
      "--ignore-missing" => ignore_missing = true
      "--skip-worktree" => skip_worktree_mode = Some(true)
      "--no-skip-worktree" => skip_worktree_mode = Some(false)
      "--stdin" => stdin = true
      "-z" => nul_term = true
      "-v" | "--verbose" => verbose = true
      "--cacheinfo" if i + 3 < args.length() => {
        cacheinfo.push((args[i + 1], args[i + 2], args[i + 3]))
        i += 4
        continue
      }
      _ if arg.has_prefix("--cacheinfo=") => {
        let val = arg[12:].to_string()
        match val.find(",") {
          Some(idx1) => {
            let mode = val[:idx1].to_string()
            let rest = val[idx1 + 1:].to_string()
            match rest.find(",") {
              Some(idx2) => {
                let sha = rest[:idx2].to_string()
                let path = rest[idx2 + 1:].to_string()
                cacheinfo.push((mode, sha, path))
              }
              None => ()
            }
          }
          None => ()
        }
      }
      "--" => {
        for j in (i + 1)..<args.length() {
          paths.push(args[j])
        }
        break
      }
      _ if not(arg.has_prefix("-")) => paths.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("update-index", arg)
      _ => ()
    }
    i += 1
  }
  // Read from stdin if requested
  if stdin {
    let input = decode_bytes(read_all_stdin())
    let sep = if nul_term { "\u0000" } else { "\n" }
    for part_view in input.split(sep) {
      let part = trim_string(part_view.to_string())
      if part.length() > 0 {
        paths.push(part)
      }
    }
  }
  // For --cacheinfo, we need to write objects first
  for info in cacheinfo {
    let (mode_str, sha, path) = info
    // Just add to paths for now - the object should already exist
    ignore(mode_str)
    ignore(sha)
    if verbose {
      print_line("add '" + path + "'")
    }
  }
  // Use the existing add functionality
  if paths.length() > 0 {
    if add || force_remove || remove || refresh {
      // For now, delegate to the git add/rm logic
      let add_paths : Array[String] = []
      let remove_paths : Array[String] = []
      for path in paths {
        let normalized_path = normalize_update_index_path(path)
        let full_path = if normalized_path.has_prefix("/") {
          normalized_path
        } else {
          root + "/" + normalized_path
        }
        if force_remove || (remove && not(fs.is_file(full_path))) {
          remove_paths.push(normalized_path)
        } else if fs.is_file(full_path) {
          add_paths.push(normalized_path)
        } else if not(ignore_missing) && not(quiet) {
          eprint_line("error: " + normalized_path + ": does not exist")
        }
      }
      // Use gitlib functions
      if add_paths.length() > 0 {
        // Ensure replacing existing entries is idempotent for the same path.
        let existing_entries = @gitlib.read_index_entries(fs, git_dir)
        let add_set : Map[String, Bool] = {}
        for p in add_paths {
          add_set[normalize_update_index_path(p)] = true
        }
        let filtered_entries : Array[@gitlib.IndexEntry] = []
        for e in existing_entries {
          if not(add_set.contains(normalize_update_index_path(e.path))) {
            filtered_entries.push(e)
          }
        }
        @gitlib.write_index_entries(fs, git_dir, filtered_entries)
        @gitlib.add_paths_async(fs, fs, root, add_paths)
        let normalized_entries = dedupe_index_entries_by_path(
          @gitlib.read_index_entries(fs, git_dir),
        )
        @gitlib.write_index_entries(fs, git_dir, normalized_entries)
      }
      // For removals, filter out from index
      if remove_paths.length() > 0 {
        let entries = @gitlib.read_index_entries(fs, git_dir)
        let remove_set : Map[String, Bool] = {}
        for p in remove_paths {
          remove_set[normalize_update_index_path(p)] = true
        }
        let filtered : Array[@gitlib.IndexEntry] = []
        for e in entries {
          if not(remove_set.contains(normalize_update_index_path(e.path))) {
            filtered.push(e)
          }
        }
        @gitlib.write_index_entries(fs, git_dir, filtered)
      }
    }
  }
  // Handle --refresh
  if refresh && paths.length() == 0 {
    // Refresh all entries - recompute hashes
    let entries = @gitlib.read_index_entries(fs, git_dir)
    let refreshed : Array[@gitlib.IndexEntry] = []
    for e in entries {
      // Keep existing entries (could recompute hash if needed)
      refreshed.push(e)
    }
    @gitlib.write_index_entries(fs, git_dir, refreshed)
  }
  match skip_worktree_mode {
    Some(enabled) => {
      let normalized : Array[String] = []
      for p in paths {
        let clean = normalize_update_index_path(p)
        if clean.length() > 0 {
          normalized.push(clean)
        }
      }
      if normalized.length() > 0 {
        update_skip_worktree_state(fs, git_dir, normalized, enabled)
      }
    }
    None => ()
  }
}

///|
fn dedupe_index_entries_by_path(
  entries : Array[@gitlib.IndexEntry],
) -> Array[@gitlib.IndexEntry] {
  let by_path : Map[String, @gitlib.IndexEntry] = {}
  for entry in entries {
    by_path[normalize_update_index_path(entry.path)] = entry
  }
  let sorted : Array[(String, @gitlib.IndexEntry)] = by_path.to_array()
  sorted.sort_by((a, b) => String::compare(a.0, b.0))
  let out : Array[@gitlib.IndexEntry] = []
  for item in sorted {
    let (_, entry) = item
    out.push(entry)
  }
  out
}

///|
fn normalize_update_index_path(path : String) -> String {
  if path.length() >= 2 && path.has_prefix("./") {
    String::unsafe_substring(path, start=2, end=path.length())
  } else {
    path
  }
}

///|
fn update_skip_worktree_state(
  fs : OsFs,
  git_dir : String,
  paths : Array[String],
  enabled : Bool,
) -> Unit raise Error {
  let state_path = git_dir + "/bit-skip-worktree"
  let state : Map[String, Bool] = {}
  if fs.is_file(state_path) {
    let text = decode_bytes(fs.read_file(state_path))
    for line_view in text.split("\n") {
      let line = trim_string(line_view.to_string())
      if line.length() > 0 {
        state[line] = true
      }
    }
  }
  for p in paths {
    if enabled {
      state[p] = true
    } else {
      state.remove(p)
    }
  }
  let out : Array[String] = []
  for item in state.to_array() {
    let (path, marked) = item
    if marked {
      out.push(path)
    }
  }
  out.sort_by((a, b) => String::compare(a, b))
  if out.length() == 0 {
    fs.remove_file(state_path) catch {
      _ => ()
    }
  } else {
    fs.write_string(state_path, out.join("\n") + "\n")
  }
}

///|
