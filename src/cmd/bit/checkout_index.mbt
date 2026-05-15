///| git checkout-index - copy files from the index to the working tree

///|
async fn handle_checkout_index(args : Array[String]) -> Unit raise Error {
  let mut all = false
  let mut force = false
  let mut no_create = false
  let mut update_index = false
  let mut prefix = ""
  let mut temp = false
  let mut use_stdin = false
  let mut nul_sep = false
  let positional : Array[String] = []
  let mut past_dashdash = false
  for arg in args {
    if past_dashdash {
      positional.push(arg)
      continue
    }
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git checkout-index [-a] [-f] [-n] [-u] [--prefix=<string>] [--temp] [--stdin] [-z] [--] [<file>...]",
          summary="Copy files from the index to the working tree.",
        )
        return
      }
      "-a" | "--all" => all = true
      "-f" | "--force" => force = true
      "-n" | "--no-create" => no_create = true
      "-u" | "--index" => update_index = true
      "--temp" => temp = true
      "--stdin" => use_stdin = true
      "-z" => nul_sep = true
      "--" => past_dashdash = true
      _ if arg.has_prefix("--prefix=") =>
        prefix = String::unsafe_substring(arg, start=9, end=arg.length())
      _ if arg.has_prefix("-") && !past_dashdash =>
        warn_unimplemented_arg("checkout-index", arg)
      _ => positional.push(arg)
    }
  }
  let fs = OsFs::new()
  let root = get_work_root()
  let git_dir = resolve_git_dir(fs, root)
  let entries = @bitlib.read_index_entries(fs, git_dir)
  // Build index map: path -> entry
  let index_map : Map[String, @bitlib.IndexEntry] = {}
  for e in entries {
    index_map[e.path] = e
  }
  // Load object databases
  let dbs = checkout_index_load_dbs(fs, git_dir)
  // Collect files to check out
  let files_to_checkout : Array[String] = []
  if all {
    for e in entries {
      files_to_checkout.push(e.path)
    }
  }
  // Add positional args
  for f in positional {
    files_to_checkout.push(f)
  }
  // Read from stdin if --stdin
  if use_stdin {
    let stdin_data = read_all_stdin()
    let stdin_text = decode_bytes(stdin_data)
    let sep = if nul_sep { "\u0000" } else { "\n" }
    for part_view in stdin_text.split(sep) {
      let part = part_view.to_string()
      let trimmed = trim_string(part)
      if trimmed.length() > 0 {
        files_to_checkout.push(trimmed)
      }
    }
  }
  if files_to_checkout.length() == 0 && !all {
    // Nothing to do — git checkout-index with no args does nothing
    return
  }
  // Process each file
  let mut updated_entries = false
  let new_entries : Array[@bitlib.IndexEntry] = []
  let entry_index_by_path : Map[String, Int] = {}
  if update_index {
    for i, e in entries {
      new_entries.push(e)
      entry_index_by_path[e.path] = i
    }
  }
  for file in files_to_checkout {
    let path = checkout_index_normalize_path(file)
    let entry = index_map.get(path)
    match entry {
      None => {
        eprint_line("git checkout-index: \{path} is not in the index")
        continue
      }
      Some(e) => {
        let dest_path = if prefix.length() > 0 {
          root + "/" + prefix + path
        } else {
          root + "/" + path
        }
        // Check if file already exists (unless --force or --temp)
        if !force && !temp && fs.is_file(dest_path) {
          eprint_line("git checkout-index: \{path} already exists, no checkout")
          continue
        }
        // Find the blob object
        let obj = checkout_index_find_object(dbs, fs, e.id)
        match obj {
          None => {
            eprint_line(
              "git checkout-index: unable to read sha1 file of \{path} (\{e.id.to_hex()})",
            )
            continue
          }
          Some(o) => {
            if no_create {
              // With -n, don't actually create files
              continue
            }
            if temp {
              // Write to temp file and print mapping
              let temp_path = checkout_index_make_temp(fs, root)
              fs.write_file(temp_path, o.data) catch {
                err => {
                  eprint_line(
                    "git checkout-index: unable to write temp file: \{err}",
                  )
                  continue
                }
              }
              // Set executable if mode indicates
              if e.mode == 0o100755 {
                @asyncfs.chmod(temp_path[:], 0o755) catch {
                  _ => ()
                }
              }
              // Output: tempname\tpath
              print_line("\{temp_path}\t\{path}")
            } else {
              // Create parent directories
              let dir = parent_dir(dest_path)
              if dir.length() > 0 {
                fs.mkdir_p(dir) catch {
                  _ => ()
                }
              }
              // Write file content
              fs.write_file(dest_path, o.data) catch {
                err => {
                  eprint_line(
                    "git checkout-index: unable to create file \{path}: \{err}",
                  )
                  continue
                }
              }
              // Set executable if mode indicates
              if e.mode == 0o100755 {
                @asyncfs.chmod(dest_path[:], 0o755) catch {
                  _ => ()
                }
              }
              // Update index stat info if -u
              if update_index {
                let abs_path = dest_path
                let meta = @bitio.worktree_entry_meta(fs, abs_path)
                match meta {
                  Some(m) => {
                    let (mtime_sec, mtime_nsec) = m.mtime()
                    match entry_index_by_path.get(path) {
                      Some(idx) => {
                        new_entries[idx] = @bitlib.IndexEntry::new(
                          path,
                          e.id,
                          e.mode,
                          m.size.unwrap_or(e.size),
                          mtime_sec~,
                          mtime_nsec~,
                          intent_to_add=e.intent_to_add,
                          dev=m.dev.unwrap_or(e.dev),
                          ino=m.ino.unwrap_or(e.ino),
                          uid=m.uid.unwrap_or(e.uid),
                          gid=m.gid.unwrap_or(e.gid),
                        )
                        updated_entries = true
                      }
                      None => ()
                    }
                  }
                  None => ()
                }
              }
            }
          }
        }
      }
    }
  }
  // Write updated index if needed
  if update_index && updated_entries {
    @bitlib.write_index_entries(fs, git_dir, new_entries) catch {
      _ => ()
    }
  }
}

///|
fn checkout_index_normalize_path(path : String) -> String {
  let mut p = path
  // Strip leading "./"
  while p.has_prefix("./") {
    p = String::unsafe_substring(p, start=2, end=p.length())
  }
  // Strip trailing "/"
  while p.has_suffix("/") && p.length() > 1 {
    p = String::unsafe_substring(p, start=0, end=p.length() - 1)
  }
  p
}

///|
fn checkout_index_load_dbs(
  fs : OsFs,
  git_dir : String,
) -> Array[@bitlib.ObjectDb] {
  let out : Array[@bitlib.ObjectDb] = []
  let primary = @bitlib.ObjectDb::load_lazy_from_objects_dir(
    fs,
    git_dir + "/objects",
  ) catch {
    _ => return out
  }
  primary.set_skip_verify(true)
  out.push(primary)
  // Check alternates
  let alt_data = fs.read_file(git_dir + "/objects/info/alternates") catch {
    _ => return out
  }
  let alt_text = decode_bytes(alt_data)
  for line_view in alt_text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let alt_db = @bitlib.ObjectDb::load_lazy_from_objects_dir(fs, line) catch {
      _ => continue
    }
    alt_db.set_skip_verify(true)
    out.push(alt_db)
  }
  out
}

///|
fn checkout_index_find_object(
  dbs : Array[@bitlib.ObjectDb],
  fs : OsFs,
  id : @bitcore.ObjectId,
) -> @bitcore.PackObject? raise Error {
  for db in dbs {
    let obj = db.get(fs, id)
    if obj is Some(o) {
      return Some(o)
    }
  }
  None
}

///|
fn checkout_index_make_temp(fs : OsFs, root : String) -> String {
  let ts = get_current_timestamp()
  let base = root + "/.merge_file_" + "\{ts}"
  let mut candidate = base
  let mut i = 0
  while fs.is_file(candidate) {
    i += 1
    candidate = base + "_" + "\{i}"
  }
  candidate
}
