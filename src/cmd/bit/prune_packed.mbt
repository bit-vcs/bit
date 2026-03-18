///|
async fn handle_prune_packed(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let git_dir = resolve_git_dir(fs, root)
  let mut dry_run = false
  let mut quiet = false
  for arg in args {
    match arg {
      "-n" | "--dry-run" => dry_run = true
      "-q" | "--quiet" => quiet = true
      _ => ()
    }
  }
  // Collect all OIDs that exist in pack indices
  let objects_dir = git_dir + "/objects"
  let pack_dir = objects_dir + "/pack"
  let packed_ids = collect_pack_ids_from_dir(fs, pack_dir)
  if packed_ids.is_empty() {
    return
  }
  // Walk objects/?? directories and remove loose objects that exist in packs
  let entries = fs.readdir(objects_dir) catch { _ => return }
  for entry in entries {
    let name = normalize_dir_entry(entry)
    // Only look at 2-char hex prefix directories
    if name.length() != 2 || not(is_hex_string(name)) {
      continue
    }
    let dir_path = objects_dir + "/" + name
    if not(fs.is_dir(dir_path)) {
      continue
    }
    let files = fs.readdir(dir_path) catch { _ => continue }
    let mut dir_count = 0
    let mut dir_removed = 0
    for file_entry in files {
      let file_name = normalize_dir_entry(file_entry)
      dir_count += 1
      if file_name.length() != 38 {
        continue
      }
      let hex = name + file_name
      if packed_ids.contains(hex) {
        let file_path = dir_path + "/" + file_name
        if dry_run {
          if not(quiet) {
            print_line(hex)
          }
        } else {
          fs.remove_file(file_path) catch {
            _ => ()
          }
          if not(quiet) {
            print_line(hex)
          }
        }
        dir_removed += 1
      }
    }
    // Try to remove empty directory
    if not(dry_run) && dir_removed == dir_count && dir_count > 0 {
      fs.remove_dir(dir_path) catch {
        _ => ()
      }
    }
  }
}
