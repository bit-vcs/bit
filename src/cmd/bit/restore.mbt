///|
struct RestoreConflictStage {
  id : @bitcore.ObjectId
}

///|
struct RestoreConflictRecord {
  base : RestoreConflictStage?
  ours : RestoreConflictStage?
  theirs : RestoreConflictStage?
}

///|
async fn handle_restore(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let mut source : String? = None
  let mut staged = false
  let mut worktree = false
  let mut ignore_unmerged = false
  let mut quiet = false
  let mut merge_mode = false
  let mut ours = false
  let mut theirs = false
  let mut conflict_style : String? = None
  let raw_paths : Array[String] = []
  let mut options_terminated = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options_terminated {
      raw_paths.push(arg)
      i += 1
      continue
    }
    match arg {
      "--" => {
        options_terminated = true
        i += 1
      }
      "--staged" => {
        staged = true
        i += 1
      }
      "--worktree" => {
        worktree = true
        i += 1
      }
      "--ignore-unmerged" => {
        ignore_unmerged = true
        i += 1
      }
      "--quiet" | "-q" => {
        quiet = true
        i += 1
      }
      "--merge" => {
        merge_mode = true
        i += 1
      }
      "--ours" => {
        ours = true
        i += 1
      }
      "--theirs" => {
        theirs = true
        i += 1
      }
      "--conflict" => {
        if i + 1 >= args.length() {
          eprint_line("fatal: option '--conflict' requires a value")
          @sys.exit(128)
        }
        conflict_style = Some(args[i + 1])
        i += 2
      }
      _ if arg.has_prefix("--conflict=") => {
        conflict_style = Some(
          String::unsafe_substring(arg, start=11, end=arg.length()),
        )
        i += 1
      }
      "--source" => {
        if i + 1 >= args.length() {
          eprint_line("fatal: option '--source' requires a value")
          @sys.exit(128)
        }
        source = Some(args[i + 1])
        i += 2
      }
      _ if arg.has_prefix("--source=") => {
        source = Some(String::unsafe_substring(arg, start=9, end=arg.length()))
        i += 1
      }
      _ if arg.has_prefix("-") => {
        warn_unimplemented_arg("restore", arg)
        i += 1
      }
      _ => {
        raw_paths.push(arg)
        i += 1
      }
    }
  }
  if raw_paths.length() == 0 {
    eprint_line("fatal: you must specify path(s) to restore")
    @sys.exit(128)
  }
  if !(staged) && !(worktree) {
    worktree = true
  }
  let special_name = restore_first_special_mode_name(
    merge_mode, ours, theirs, conflict_style,
  )
  match special_name {
    Some(name) => {
      if staged {
        eprint_line("fatal: option '\{name}' cannot be used with --staged")
        @sys.exit(128)
      }
      if source is Some(_) {
        eprint_line("fatal: option '\{name}' cannot be used with --source")
        @sys.exit(128)
      }
    }
    None => ()
  }
  let resolved_paths = restore_resolve_cli_paths(root, raw_paths)
  let paths = restore_expand_cli_paths(rfs, git_dir, resolved_paths)
  if special_name is Some(_) {
    restore_paths_with_unmerged_state(
      fs, rfs, root, git_dir, paths, merge_mode, ours, theirs, conflict_style,
    )
    return
  }
  if source is None && worktree && !(staged) {
    let (matched_unmerged, filtered_paths) = restore_filter_unmerged_paths(
      rfs, git_dir, paths,
    )
    if matched_unmerged.length() > 0 {
      if !(ignore_unmerged) {
        eprint_line("error: path '\{matched_unmerged[0]}' is unmerged")
        @sys.exit(1)
      }
      if !(quiet) {
        for path in matched_unmerged {
          eprint_line("warning: path '\{path}' is unmerged")
        }
      }
      if filtered_paths.length() == 0 {
        return
      }
      @bitlib.restore_paths(fs, rfs, root, filtered_paths)
      return
    }
  }
  match source {
    Some(spec) =>
      checkout_restore_paths_from_spec_mode(
        fs,
        rfs,
        root,
        git_dir,
        spec,
        paths,
        update_worktree=worktree,
        update_index=staged,
      )
    None =>
      if staged {
        checkout_restore_paths_from_spec_mode(
          fs,
          rfs,
          root,
          git_dir,
          "HEAD",
          paths,
          update_worktree=worktree,
          update_index=true,
        )
      } else {
        @bitlib.restore_paths(fs, rfs, root, paths)
      }
  }
}

///|
fn restore_first_special_mode_name(
  merge_mode : Bool,
  ours : Bool,
  theirs : Bool,
  conflict_style : String?,
) -> String? {
  if merge_mode {
    return Some("--merge")
  }
  if ours {
    return Some("--ours")
  }
  if theirs {
    return Some("--theirs")
  }
  match conflict_style {
    Some(_) => Some("--conflict")
    None => None
  }
}

///|
fn restore_paths_with_unmerged_state(
  fs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  paths : Array[String],
  merge_mode : Bool,
  ours : Bool,
  theirs : Bool,
  conflict_style : String?,
) -> Unit raise Error {
  let object_git_dir = checkout_resolve_common_git_dir(rfs, git_dir)
  let db = @bitlib.ObjectDb::load(rfs, object_git_dir)
  let records = restore_collect_conflict_records(rfs, git_dir)
  for path in paths {
    let safe_path = @bitlib.normalize_repo_path(path)
    match records.get(safe_path) {
      Some(record) =>
        restore_write_unmerged_path(
          db, rfs, fs, root, safe_path, record, merge_mode, ours, theirs, conflict_style,
        )
      None =>
        raise @bitcore.GitError::InvalidObject(
          "error: pathspec '\{path}' did not match any file(s) known to git",
        )
    }
  }
}

///|
fn restore_collect_conflict_records(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Map[String, RestoreConflictRecord] raise Error {
  let records : Map[String, RestoreConflictRecord] = {}
  for entry in @bitlib.read_resolve_undo_entries(rfs, git_dir) {
    records[entry.path] = {
      base: restore_conflict_stage_from_resolve_undo(entry.base),
      ours: restore_conflict_stage_from_resolve_undo(entry.ours),
      theirs: restore_conflict_stage_from_resolve_undo(entry.theirs),
    }
  }
  for item in @bitlib.read_index_stage_entries(rfs, git_dir) {
    if item.stage == 0 {
      continue
    }
    let path = item.entry.path
    let current = records
      .get(path)
      .unwrap_or({ base: None, ours: None, theirs: None })
    let stage : RestoreConflictStage = { id: item.entry.id }
    let stage_entry = Some(stage)
    records[path] = {
      base: if item.stage == 1 {
        stage_entry
      } else {
        current.base
      },
      ours: if item.stage == 2 {
        stage_entry
      } else {
        current.ours
      },
      theirs: if item.stage == 3 {
        stage_entry
      } else {
        current.theirs
      },
    }
  }
  records
}

///|
fn restore_conflict_stage_from_resolve_undo(
  stage : @bitlib.ResolveUndoStage?,
) -> RestoreConflictStage? {
  match stage {
    Some(value) => Some({ id: value.id })
    None => None
  }
}

///|
fn restore_write_unmerged_path(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  fs : &@bitcore.FileSystem,
  root : String,
  path : String,
  record : RestoreConflictRecord,
  merge_mode : Bool,
  ours : Bool,
  theirs : Bool,
  conflict_style : String?,
) -> Unit raise Error {
  let full_path = @bitcore.join_path(root, path)
  let dir = parent_dir(full_path)
  if dir.length() > 0 && dir != root {
    fs.mkdir_p(dir)
  }
  let base_text = restore_read_conflict_stage_content(db, rfs, record.base)
  let ours_text = restore_read_conflict_stage_content(db, rfs, record.ours)
  let theirs_text = restore_read_conflict_stage_content(db, rfs, record.theirs)
  if ours {
    fs.write_string(full_path, ours_text)
    return
  }
  if theirs {
    fs.write_string(full_path, theirs_text)
    return
  }
  let style = match conflict_style {
    Some(value) => value
    None => if merge_mode { "merge" } else { "merge" }
  }
  let merged = if style == "diff3" || style == "zdiff3" {
    "<<<<<<< ours\n" +
    ours_text +
    "||||||| base\n" +
    base_text +
    "=======\n" +
    theirs_text +
    ">>>>>>> theirs\n"
  } else {
    "<<<<<<< ours\n" +
    ours_text +
    "=======\n" +
    theirs_text +
    ">>>>>>> theirs\n"
  }
  fs.write_string(full_path, merged)
}

///|
fn restore_read_conflict_stage_content(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  stage : RestoreConflictStage?,
) -> String raise Error {
  match stage {
    Some(entry) =>
      match db.get(rfs, entry.id) {
        Some(obj) => @utf8.decode_lossy(obj.data[:])
        None =>
          raise @bitcore.GitError::InvalidObject(
            "Object not found: \{entry.id.to_hex()}",
          )
      }
    None => ""
  }
}

///|
fn restore_resolve_cli_paths(
  root : String,
  raw_paths : Array[String],
) -> Array[String] {
  let cwd_prefix = compute_cwd_prefix(root)
  let resolved : Array[String] = []
  for path in raw_paths {
    if cwd_prefix.length() == 0 || path.has_prefix("/") {
      resolved.push(path)
    } else {
      resolved.push(cwd_prefix + "/" + path)
    }
  }
  resolved
}

///|
fn restore_expand_cli_paths(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  raw_paths : Array[String],
) -> Array[String] raise Error {
  let tracked_paths = restore_collect_tracked_paths(rfs, git_dir)
  let expanded : Array[String] = []
  let seen : Map[String, Bool] = {}
  for path in raw_paths {
    let matched = restore_expand_single_cli_path(path, tracked_paths)
    for item in matched {
      if !(seen.contains(item)) {
        expanded.push(item)
        seen[item] = true
      }
    }
  }
  expanded
}

///|
fn restore_collect_tracked_paths(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Array[String] raise Error {
  let tracked : Array[String] = []
  let seen : Map[String, Bool] = {}
  for entry in @bitlib.read_index_entries(rfs, git_dir) {
    if !(seen.contains(entry.path)) {
      tracked.push(entry.path)
      seen[entry.path] = true
    }
  }
  for path, _ in @bitlib.read_unmerged_paths(rfs, git_dir) {
    if !(seen.contains(path)) {
      tracked.push(path)
      seen[path] = true
    }
  }
  tracked
}

///|
fn restore_expand_single_cli_path(
  raw_path : String,
  tracked_paths : Array[String],
) -> Array[String] raise Error {
  let normalized = restore_normalize_cli_pathspec(raw_path)
  let prefix = if normalized.length() == 0 { "" } else { normalized + "/" }
  let matched : Array[String] = []
  for path in tracked_paths {
    if normalized.length() == 0 || path == normalized || path.has_prefix(prefix) {
      matched.push(path)
    }
  }
  if matched.length() > 0 {
    matched
  } else {
    [raw_path]
  }
}

///|
fn restore_normalize_cli_pathspec(path : String) -> String raise Error {
  if path == "." {
    return ""
  }
  if path.has_suffix("/.") && path.length() > 2 {
    let base = String::unsafe_substring(path, start=0, end=path.length() - 2)
    return @bitlib.normalize_repo_path(base)
  }
  @bitlib.normalize_repo_path(path)
}

///|
fn restore_filter_unmerged_paths(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  paths : Array[String],
) -> (Array[String], Array[String]) {
  let unmerged = @bitlib.read_unmerged_paths(rfs, git_dir)
  let matched_unmerged : Array[String] = []
  let filtered : Array[String] = []
  for path in paths {
    if unmerged.contains(path) {
      matched_unmerged.push(path)
    } else {
      filtered.push(path)
    }
  }
  (matched_unmerged, filtered)
}
