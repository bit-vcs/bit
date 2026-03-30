///| git rerere - reuse recorded resolution of conflicted merges

///|
async fn handle_rerere(args : Array[String]) -> Unit {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git rerere [clear | forget <path>... | diff | status | gc]",
          summary="Reuse recorded resolution of conflicted merges.",
        )
        return
      }
      _ if !(arg.has_prefix("-")) => positional.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("rerere", arg)
      _ => ()
    }
  }
  let rr_cache_dir = git_dir + "/rr-cache"
  if positional.length() == 0 {
    // Default: record current conflict resolutions
    // Check for unmerged paths
    let unmerged = @bitlib.read_unmerged_paths(fs, git_dir)
    if unmerged.length() > 0 {
      // Ensure rr-cache directory exists
      fs.mkdir_p(rr_cache_dir) catch {
        _ => ()
      }
    }
    // Minimal: no-op for recording (requires full conflict hashing)
    return
  }
  let subcmd = positional[0]
  match subcmd {
    "clear" => rerere_clear(fs, rr_cache_dir)
    "forget" => {
      let mut has_path = false
      for j = 1; j < positional.length(); j = j + 1 {
        has_path = true
        ignore(positional[j])
      }
      if !(has_path) {
        eprint_line("usage: git rerere forget <path>...")
        @sys.exit(1)
      }
      // Minimal: no-op since we don't have full conflict hashing
    }
    "diff" => rerere_diff(fs, rr_cache_dir)
    "remaining" | "status" => rerere_status(fs, rr_cache_dir)
    "gc" => rerere_gc(fs, rr_cache_dir)
    _ => {
      eprint_line("error: unknown rerere subcommand: \{subcmd}")
      @sys.exit(1)
    }
  }
}

///|
async fn rerere_clear(fs : OsFs, rr_cache_dir : String) -> Unit {
  // Remove all entries in rr-cache
  let entries = fs.readdir(rr_cache_dir) catch { _ => return }
  for entry in entries {
    let path = rr_cache_dir + "/" + entry
    if fs.is_dir(path) {
      let sub_entries = fs.readdir(path) catch { _ => continue }
      for sub in sub_entries {
        fs.remove_file(path + "/" + sub) catch {
          _ => ()
        }
      }
    }
    fs.remove_file(path) catch {
      _ => ()
    }
  }
}

///|
async fn rerere_diff(fs : OsFs, rr_cache_dir : String) -> Unit {
  // Show diff of recorded resolutions
  let entries = fs.readdir(rr_cache_dir) catch { _ => return }
  for entry in entries {
    let preimage = rr_cache_dir + "/" + entry + "/preimage"
    let postimage = rr_cache_dir + "/" + entry + "/postimage"
    let pre_exists = fs.is_file(preimage)
    let post_exists = fs.is_file(postimage)
    if pre_exists && post_exists {
      print_line("--- a/\{entry}")
      print_line("+++ b/\{entry}")
    }
  }
}

///|
async fn rerere_status(fs : OsFs, rr_cache_dir : String) -> Unit {
  // Show files with recorded resolutions
  let entries = fs.readdir(rr_cache_dir) catch { _ => return }
  for entry in entries {
    let preimage = rr_cache_dir + "/" + entry + "/preimage"
    if fs.is_file(preimage) {
      print_line(entry)
    }
  }
}

///|
async fn rerere_gc(fs : OsFs, rr_cache_dir : String) -> Unit {
  // Remove old entries without postimage (unresolved)
  let entries = fs.readdir(rr_cache_dir) catch { _ => return }
  for entry in entries {
    let path = rr_cache_dir + "/" + entry
    if fs.is_dir(path) {
      let postimage = path + "/postimage"
      if !(fs.is_file(postimage)) {
        let sub_entries = fs.readdir(path) catch { _ => continue }
        for sub in sub_entries {
          fs.remove_file(path + "/" + sub) catch {
            _ => ()
          }
        }
        fs.remove_file(path) catch {
          _ => ()
        }
      }
    }
  }
}

///|
