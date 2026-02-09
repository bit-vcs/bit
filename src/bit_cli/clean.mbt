///|
async fn handle_clean(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let mut force = false
  let mut dry_run = false
  let mut remove_dirs = false
  let mut remove_ignored = false
  let mut remove_only_ignored = false
  let mut quiet = false
  let paths : Array[String] = []
  for arg in args {
    match arg {
      "-f" | "--force" => force = true
      "-n" | "--dry-run" => dry_run = true
      "-d" => remove_dirs = true
      "-x" => remove_ignored = true
      "-X" => remove_only_ignored = true
      "-q" | "--quiet" => quiet = true
      "-fd" | "-df" => {
        force = true
        remove_dirs = true
      }
      _ if not(arg.has_prefix("-")) => paths.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("clean", arg)
      _ => ()
    }
  }
  // git clean requires -f unless -n is specified
  if not(force) && not(dry_run) {
    @stdio.stderr.write(
      "fatal: clean.requireForce defaults to true and neither -i, -n, nor -f given; refusing to clean",
    )
    @sys.exit(1)
  }
  // Get untracked files from status
  let status = @gitlib.status(fs, root)
  let mut files_to_clean : Array[String] = []
  if remove_only_ignored {
    // -X: only ignored files (not implemented - need gitignore parsing)
    @stdio.stderr.write(
      "warning: -X (remove only ignored) not fully implemented",
    )
  } else {
    // Regular untracked files
    for p in status.untracked {
      files_to_clean.push(p)
    }
  }
  // Filter by paths if specified
  if paths.length() > 0 {
    files_to_clean = files_to_clean
      .iter()
      .filter(fn(f) { paths.iter().any(p => f == p || f.has_prefix(p + "/")) })
      .collect()
  }
  // Process files
  let dirs_to_check : Array[String] = []
  for path in files_to_clean {
    let abs_path = root + "/" + path
    if dry_run {
      print_line("Would remove \{path}")
    } else if fs.is_file(abs_path) {
      fs.remove_file(abs_path)
      if not(quiet) {
        print_line("Removing \{path}")
      }
      // Track parent directory for potential removal
      if remove_dirs {
        match path.rev_find("/") {
          Some(idx) => {
            let parent = String::unsafe_substring(path, start=0, end=idx)
            if not(dirs_to_check.contains(parent)) {
              dirs_to_check.push(parent)
            }
          }
          None => ()
        }
      }
    } else if fs.is_dir(abs_path) && remove_dirs {
      remove_dir_recursive(fs, abs_path)
      if not(quiet) {
        print_line("Removing \{path}/")
      }
    }
  }
  // Remove empty directories if -d flag
  if remove_dirs && not(dry_run) {
    // Sort by depth (deepest first)
    dirs_to_check.sort_by((a, b) => b.length() - a.length())
    for dir in dirs_to_check {
      let abs_dir = root + "/" + dir
      if fs.is_dir(abs_dir) {
        let rfs : &@git.RepoFileSystem = fs
        let entries = rfs.readdir(abs_dir) catch {
          err if @async.is_cancellation_error(err) => raise err
          _ => continue
        }
        if entries.length() == 0 {
          let wfs : &@git.FileSystem = fs
          wfs.remove_dir(abs_dir) catch {
            err if @async.is_cancellation_error(err) => raise err
            _ => ()
          }
          if not(quiet) {
            print_line("Removing \{dir}/")
          }
        }
      }
    }
  }
  ignore(remove_ignored)
}

///|
fn remove_dir_recursive(fs : OsFs, path : String) -> Unit {
  let rfs : &@git.RepoFileSystem = fs
  let wfs : &@git.FileSystem = fs
  let entries = rfs.readdir(path) catch { _ => return }
  for entry in entries {
    let full = path + "/" + entry
    if rfs.is_dir(full) {
      remove_dir_recursive(fs, full)
    } else {
      wfs.remove_file(full) catch {
        _ => ()
      }
    }
  }
  wfs.remove_dir(path) catch {
    _ => ()
  }
}

///|
