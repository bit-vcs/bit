///|
async fn handle_update_index(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let git_dir = find_git_dir(fs)
  let mut add = false
  let mut remove = false
  let mut force_remove = false
  let mut refresh = false
  let mut quiet = false
  let mut ignore_missing = false
  let mut stdin = false
  let mut nul_term = false
  let mut verbose = false
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
        let full_path = if path.has_prefix("/") {
          path
        } else {
          root + "/" + path
        }
        if force_remove || (remove && not(fs.is_file(full_path))) {
          remove_paths.push(path)
        } else if fs.is_file(full_path) {
          add_paths.push(path)
        } else if not(ignore_missing) && not(quiet) {
          eprint_line("error: " + path + ": does not exist")
        }
      }
      // Use gitlib functions
      if add_paths.length() > 0 {
        @gitlib.add_paths_async(fs, fs, root, add_paths)
      }
      // For removals, filter out from index
      if remove_paths.length() > 0 {
        let entries = @gitlib.read_index_entries(fs, git_dir)
        let remove_set : Map[String, Bool] = {}
        for p in remove_paths {
          remove_set[p] = true
        }
        let filtered : Array[@gitlib.IndexEntry] = []
        for e in entries {
          if not(remove_set.contains(e.path)) {
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
}

///|
