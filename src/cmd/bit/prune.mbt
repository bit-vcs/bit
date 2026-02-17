///|
async fn handle_prune(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let mut dry_run = false
  let mut verbose = false
  for arg in args {
    match arg {
      "-n" | "--dry-run" => dry_run = true
      "-v" | "--verbose" => verbose = true
      _ => ()
    }
  }
  if dry_run {
    if verbose {
      print_line("Would prune unreachable objects")
    }
    return
  }
  // Use gitlib's prune_repo
  let result = @bitlib.prune_repo(fs, fs, root)
  if verbose {
    print_line("Pruned \{result.pruned.length()} unreachable objects")
  }
}

///|
