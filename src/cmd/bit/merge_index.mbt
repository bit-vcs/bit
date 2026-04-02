///| git merge-index - run a merge for each unmerged file in the index

///|
async fn handle_merge_index(args : Array[String]) -> Unit raise Error {
  let mut process_all = false
  let mut quiet = false
  let mut one_shot = false
  let mut merge_program = ""
  let files : Array[String] = []
  let mut i = 0
  let mut found_program = false
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git merge-index [-o] [-q] <merge-program> (-a | <file>...)",
          summary="Run a merge for each unmerged file in the index.",
        )
        return
      }
      "-o" => one_shot = true
      "-q" => quiet = true
      "-a" => process_all = true
      _ if !found_program && !arg.has_prefix("-") => {
        merge_program = arg
        found_program = true
      }
      _ if found_program && !arg.has_prefix("-") => files.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("merge-index", arg)
      _ => ()
    }
    i += 1
  }
  if merge_program.length() == 0 {
    eprint_line(
      "usage: git merge-index [-o] [-q] <merge-program> (-a | <file>...)",
    )
    @sys.exit(1)
    return
  }
  if !process_all && files.length() == 0 {
    eprint_line(
      "usage: git merge-index [-o] [-q] <merge-program> (-a | <file>...)",
    )
    @sys.exit(1)
    return
  }
  let root = get_work_root()
  let fs = OsFs::new()
  let git_dir = resolve_git_dir(fs, root)
  // Read index with stage info
  let entries = @bitlib.read_index_stage_entries(fs, git_dir)
  // Group entries by path to find unmerged files (stage > 0)
  let unmerged : Map[String, Array[@bitlib.IndexStageEntry]] = {}
  for entry in entries {
    if entry.stage != 0 {
      match unmerged.get(entry.entry.path) {
        Some(arr) => arr.push(entry)
        None => unmerged.set(entry.entry.path, [entry])
      }
    }
  }
  let mut had_failures = false
  let null_oid = "0000000000000000000000000000000000000000"
  // Process each unmerged file
  for path, stages in unmerged {
    if !process_all && !files.contains(path) {
      continue
    }
    // Find stage 1 (base), 2 (ours), 3 (theirs)
    let mut base_oid = null_oid
    let mut ours_oid = null_oid
    let mut theirs_oid = null_oid
    let mut base_mode = ""
    let mut ours_mode = ""
    let mut theirs_mode = ""
    for se in stages {
      let oid_str = se.entry.id.to_hex()
      let mode_str = merge_index_format_mode(se.entry.mode)
      match se.stage {
        1 => {
          base_oid = oid_str
          base_mode = mode_str
        }
        2 => {
          ours_oid = oid_str
          ours_mode = mode_str
        }
        3 => {
          theirs_oid = oid_str
          theirs_mode = mode_str
        }
        _ => ()
      }
    }
    // git merge-index calls: pgm <base-hash> <base-mode> <ours-hash> <ours-mode> <theirs-hash> <theirs-mode> <path>
    let base_h = if base_oid == null_oid { "" } else { base_oid }
    let ours_h = if ours_oid == null_oid { "" } else { ours_oid }
    let theirs_h = if theirs_oid == null_oid { "" } else { theirs_oid }
    let code = @process.run(
      merge_program,
      [base_h, base_mode, ours_h, ours_mode, theirs_h, theirs_mode, path],
      inherit_env=true,
      cwd=root,
      stdin=@stdio.stdin,
      stdout=@stdio.stdout,
      stderr=@stdio.stderr,
    )
    if code != 0 {
      if !quiet {
        eprint_line("merge program failed for \{path}")
      }
      had_failures = true
      if !one_shot {
        @sys.exit(1)
        return
      }
    }
  }
  if had_failures {
    @sys.exit(1)
  }
}

///|
fn merge_index_format_mode(mode : Int) -> String {
  if mode == 0 {
    return ""
  }
  let mut n = mode
  let digits : Array[String] = []
  while n > 0 {
    digits.push((n % 8).to_string())
    n = n / 8
  }
  let sb = StringBuilder::new()
  for i = digits.length() - 1; i >= 0; i = i - 1 {
    sb.write_string(digits[i])
  }
  sb.to_string()
}
