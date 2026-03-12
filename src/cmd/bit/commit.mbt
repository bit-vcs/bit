///|

///|
async fn show_commit_command_help() -> Unit {
  show_simple_command_help(
    "git commit [<options>]",
    summary="Record changes to the repository.",
  )
}

///|
fn commit_need_real_git() -> Bool {
  false
}

///|
async fn delegate_commit_to_real_git(
  args : Array[String],
  cwd : String,
) -> Unit {
  let argv : Array[String] = ["commit"]
  for arg in args {
    argv.push(arg)
  }
  let code = @process.run(
    resolve_real_git_for_dispatch(),
    argv,
    inherit_env=true,
    cwd~,
    stdin=@stdio.stdin,
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  @sys.exit(code)
}

///|
fn commit_storage_runtime_parsed_args(
  args : Array[String],
) -> @runtime.StorageCommitArgs? {
  if commit_need_real_git() {
    return None
  }
  let parsed = storage_runtime_parse_command("commit", args) catch {
    _ => return None
  }
  match parsed {
    @runtime.StorageCommand::Commit(commit_args) => Some(commit_args)
    _ => None
  }
}

///|
fn commit_should_use_storage_runtime(args : Array[String]) -> Bool {
  commit_storage_runtime_parsed_args(args) is Some(_)
}

///|
fn commit_has_no_verify_flag(args : Array[String]) -> Bool {
  for arg in args {
    if arg == "--no-verify" {
      return true
    }
  }
  false
}

///|
fn commit_has_merge_state(fs : OsFs, git_dir : String) -> Bool {
  fs.is_file(git_dir + "/MERGE_HEAD") ||
  fs.is_file(git_dir + "/MERGE_MSG") ||
  fs.is_file(git_dir + "/MERGE_MODE") ||
  fs.is_file(git_dir + "/SQUASH_MSG")
}

///|
fn commit_storage_runtime_delegate_args(
  fs : OsFs,
  git_dir : String,
  args : Array[String],
) -> @runtime.StorageCommitArgs? {
  let parsed = match commit_storage_runtime_parsed_args(args) {
    Some(value) => value
    None => return None
  }
  if commit_has_merge_state(fs, git_dir) {
    return None
  }
  if not(commit_has_no_verify_flag(args)) &&
    fs.is_file(git_dir + "/hooks/pre-commit") {
    return None
  }
  if not(parsed.quiet) && get_subdir_info(fs, git_dir) is Some(_) {
    return None
  }
  Some({
    message: parsed.message,
    all_modified: parsed.all_modified,
    allow_empty: parsed.allow_empty,
    quiet: parsed.quiet,
    encoding: resolve_commit_message_encoding(git_dir),
  })
}

///|
async fn handle_commit(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  if commit_repo_requires_real_git(rfs, git_dir) {
    delegate_commit_to_real_git(args, root)
    return
  }
  if commit_args_require_standalone_error(args) {
    eprint_line("fatal: this commit mode is not supported in standalone mode")
    @sys.exit(1)
  }
  if commit_should_use_storage_runtime(args) {
    match commit_storage_runtime_delegate_args(fs, git_dir, args) {
      Some(commit_args) => {
        @runtime.run_storage_command(
          fs,
          rfs,
          root,
          @runtime.StorageCommand::Commit(commit_args),
        )
        return
      }
      None => ()
    }
  }
  let commit_message_encoding = resolve_commit_message_encoding(git_dir)
  // Track message source for mutual exclusivity checks
  let messages : Array[String] = []
  let mut message_source : String = "" // "m", "F", "C", "c"
  let mut all_modified = false
  let mut amend = false
  let mut allow_empty = false
  let mut allow_empty_message = false
  let mut no_verify = false
  let mut no_edit = false
  let mut quiet = false
  let mut signoff = false
  let mut author_override : String? = None
  let mut date_override : String? = None
  let mut edit_flag : Bool? = None
  let pathspecs : Array[String] = []
  let mut end_of_options = false
  let mut include_mode = false
  let mut only_mode = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if end_of_options {
      pathspecs.push(arg)
      i += 1
      continue
    }
    match arg {
      "--" => {
        end_of_options = true
        i += 1
        continue
      }
      "-m" if i + 1 < args.length() => {
        commit_check_message_source_conflict(message_source, "m")
        message_source = "m"
        messages.push(args[i + 1])
        i += 2
        continue
      }
      "--message" if i + 1 < args.length() => {
        commit_check_message_source_conflict(message_source, "m")
        message_source = "m"
        messages.push(args[i + 1])
        i += 2
        continue
      }
      "-am" | "-ma" if i + 1 < args.length() => {
        commit_check_message_source_conflict(message_source, "m")
        message_source = "m"
        all_modified = true
        messages.push(args[i + 1])
        i += 2
        continue
      }
      "--author" if i + 1 < args.length() => {
        author_override = Some(args[i + 1])
        i += 2
        continue
      }
      "--date" if i + 1 < args.length() => {
        date_override = Some(args[i + 1])
        i += 2
        continue
      }
      "-F" if i + 1 < args.length() => {
        commit_check_message_source_conflict(message_source, "F")
        message_source = "F"
        messages.push(
          read_commit_message_from_file(
            fs,
            root,
            args[i + 1],
            commit_message_encoding,
          ),
        )
        i += 2
        continue
      }
      "-C" if i + 1 < args.length() => {
        commit_check_message_source_conflict(message_source, "C")
        message_source = "C"
        let rev_msg = read_commit_message_from_revision(fs, root, args[i + 1])
        match rev_msg {
          Some(m) => messages.push(m)
          None => {
            eprint_line("fatal: could not lookup commit \{args[i + 1]}")
            @sys.exit(128)
          }
        }
        i += 2
        continue
      }
      "-c" if i + 1 < args.length() => {
        commit_check_message_source_conflict(message_source, "c")
        message_source = "c"
        let rev_msg = read_commit_message_from_revision(fs, root, args[i + 1])
        match rev_msg {
          Some(m) => messages.push(m)
          None => {
            eprint_line("fatal: could not lookup commit \{args[i + 1]}")
            @sys.exit(128)
          }
        }
        edit_flag = Some(true)
        i += 2
        continue
      }
      _ if arg.has_prefix("-m") && not(arg.has_prefix("-ma")) => {
        commit_check_message_source_conflict(message_source, "m")
        message_source = "m"
        messages.push((try! arg[2:]).to_string())
        i += 1
        continue
      }
      _ if arg.has_prefix("-am") || arg.has_prefix("-ma") => {
        commit_check_message_source_conflict(message_source, "m")
        message_source = "m"
        all_modified = true
        messages.push((try! arg[3:]).to_string())
        i += 1
        continue
      }
      _ if arg.has_prefix("--message=") => {
        commit_check_message_source_conflict(message_source, "m")
        message_source = "m"
        messages.push((try! arg[10:]).to_string())
        i += 1
        continue
      }
      _ if arg.has_prefix("--author=") => {
        author_override = Some((try! arg[9:]).to_string())
        i += 1
        continue
      }
      _ if arg.has_prefix("--date=") => {
        date_override = Some((try! arg[7:]).to_string())
        i += 1
        continue
      }
      _ if arg.has_prefix("-F") => {
        commit_check_message_source_conflict(message_source, "F")
        message_source = "F"
        let file = (try! arg[2:]).to_string()
        messages.push(
          read_commit_message_from_file(fs, root, file, commit_message_encoding),
        )
        i += 1
        continue
      }
      _ if arg.has_prefix("-C") => {
        commit_check_message_source_conflict(message_source, "C")
        message_source = "C"
        let spec = (try! arg[2:]).to_string()
        let rev_msg = read_commit_message_from_revision(fs, root, spec)
        match rev_msg {
          Some(m) => messages.push(m)
          None => {
            eprint_line("fatal: could not lookup commit \{spec}")
            @sys.exit(128)
          }
        }
        i += 1
        continue
      }
      _ if arg.has_prefix("-c") && arg.length() > 2 => {
        commit_check_message_source_conflict(message_source, "c")
        message_source = "c"
        let spec = (try! arg[2:]).to_string()
        let rev_msg = read_commit_message_from_revision(fs, root, spec)
        match rev_msg {
          Some(m) => messages.push(m)
          None => {
            eprint_line("fatal: could not lookup commit \{spec}")
            @sys.exit(128)
          }
        }
        edit_flag = Some(true)
        i += 1
        continue
      }
      "-a" | "--all" => all_modified = true
      "--amend" => amend = true
      "--allow-empty" => allow_empty = true
      "--allow-empty-message" => allow_empty_message = true
      "--no-verify" | "-n" => no_verify = true
      "--no-edit" => no_edit = true
      "--edit" | "-e" => edit_flag = Some(true)
      "-q" | "--quiet" => quiet = true
      "-s" | "--signoff" => signoff = true
      "--no-signoff" => signoff = false
      "-i" | "--include" => include_mode = true
      "-o" | "--only" => only_mode = true
      "--dry-run"
      | "--short"
      | "--porcelain"
      | "--long"
      | "--status"
      | "--no-status" => ()
      "-t" | "--template" if i + 1 < args.length() => {
        i += 2
        continue
      }
      _ if arg.has_prefix("--template=") || arg.has_prefix("-t") => ()
      _ if arg.has_prefix("-") => warn_unimplemented_arg("commit", arg)
      _ => pathspecs.push(arg)
    }
    i += 1
  }
  // Validate --include and --only don't mix
  if include_mode && only_mode {
    eprint_line(
      "fatal: options '-i/--include' and '-o/--only' cannot be used together",
    )
    @sys.exit(128)
  }
  // Validate -a and pathspecs don't mix
  if all_modified && pathspecs.length() > 0 {
    eprint_line(
      "fatal: paths '\{pathspecs[0]} ...' with -a does not make sense",
    )
    @sys.exit(128)
  }
  let git_dir = resolve_git_dir(fs, root)
  let merge_heads = read_merge_head_ids(fs, git_dir)
  let should_cleanup_merge_state = merge_heads.length() > 0 ||
    fs.is_file(git_dir + "/MERGE_MSG") ||
    fs.is_file(git_dir + "/MERGE_MODE") ||
    fs.is_file(git_dir + "/SQUASH_MSG")
  // If -a flag, stage all modified files
  if all_modified {
    let status = @bitlib.status(fs, root)
    let paths_to_add : Array[String] = []
    for p in status.unstaged_modified {
      paths_to_add.push(p)
    }
    for p in status.unstaged_deleted {
      paths_to_add.push(p)
    }
    if paths_to_add.length() > 0 {
      @bitlib.add_paths_async(fs, fs, root, paths_to_add)
    }
  }
  // Handle pathspec-based partial commit (--include / --only / positional args)
  if pathspecs.length() > 0 {
    commit_handle_pathspec_staging(
      fs, rfs, root, git_dir, pathspecs, include_mode, only_mode,
    )
  }
  // Build final message
  let mut message : String? = if messages.length() > 0 {
    Some(messages.join("\n\n"))
  } else {
    None
  }
  // Open editor when message is not specified.
  let should_edit = match edit_flag {
    Some(v) => v
    None => message is None
  }
  if message is None {
    if no_edit {
      message = resolve_no_edit_commit_message(fs, root, git_dir, amend)
    } else {
      let initial_message = if amend {
        get_head_commit_message(fs, root)
      } else {
        None
      }
      message = read_commit_message_from_editor(fs, root, initial_message~)
    }
  } else if should_edit && not(no_edit) {
    // -c or --edit: open editor with existing message
    message = read_commit_message_from_editor(fs, root, initial_message=message)
  }
  guard message is Some(msg) else {
    raise @bitcore.GitError::InvalidObject(
      "Aborting commit due to empty commit message.",
    )
  }
  // Validate empty message
  let stripped_msg = commit_strip_message(msg)
  if stripped_msg.length() == 0 && not(allow_empty_message) {
    eprint_line("Aborting commit due to empty commit message.")
    @sys.exit(1)
  }
  // Apply --signoff
  let msg = if signoff { commit_apply_signoff(msg) } else { msg }
  let default_author = get_author_string()
  let default_timestamp = get_commit_timestamp()
  let commit_timezone = get_commit_timezone()
  let author = match author_override {
    Some(a) => a
    None => default_author
  }
  let author_timestamp = match date_override {
    Some(d) => parse_commit_date(d)
    None => default_timestamp
  }
  // Committer is always the current user
  let committer = get_committer_string()
  let committer_timestamp = default_timestamp
  if not(no_verify) {
    let hook_status = run_pre_commit_hook(fs, root, git_dir)
    if hook_status != 0 {
      raise @bitcore.GitError::InvalidObject("pre-commit hook failed")
    }
  }
  let commit_id = if amend {
    @bitlib.commit_amend(
      fs,
      fs,
      root,
      msg,
      author,
      author_timestamp,
      committer~,
      committer_timestamp~,
      timezone=commit_timezone,
      encoding=commit_message_encoding,
    )
  } else if merge_heads.length() > 0 {
    commit_with_merge_heads(
      fs,
      fs,
      root,
      msg,
      author,
      author_timestamp,
      committer,
      committer_timestamp,
      merge_heads,
      allow_empty,
      encoding=commit_message_encoding,
    )
  } else {
    @bitlib.commit(
      fs,
      fs,
      root,
      msg,
      author,
      author_timestamp,
      committer~,
      committer_timestamp~,
      allow_empty~,
      timezone=commit_timezone,
      encoding=commit_message_encoding,
    )
  }
  if should_cleanup_merge_state {
    cleanup_merge_state_files(fs, git_dir)
  }
  // Build output like git: [branch (root-commit) short_id] first_line
  let short_id = (try! commit_id.to_hex()[:7]).to_string()
  let first_line = match msg.find("\n") {
    Some(idx) => (try! msg[:idx]).to_string()
    None => msg
  }
  if not(quiet) {
    let branch_name = commit_get_current_branch(rfs, git_dir)
    let head_parent = @bitlib.resolve_head_commit(rfs, git_dir)
    let is_root = head_parent is None && not(amend)
    let branch_display = match branch_name {
      Some(name) => if is_root { name + " (root-commit)" } else { name }
      None => if is_root { "(root-commit)" } else { "HEAD" }
    }
    match get_subdir_info(fs, git_dir) {
      Some((_, path, _)) =>
        print_line(
          "[\{branch_display} (subdir: \{path}) \{short_id}] \{first_line}",
        )
      None => print_line("[\{branch_display} \{short_id}] \{first_line}")
    }
    // Show diffstat summary
    commit_show_diffstat(fs, rfs, root, git_dir, commit_id)
  }
  // Restore index from backup if --only mode was used
  if pathspecs.length() > 0 && only_mode {
    commit_restore_index_backup(fs, git_dir)
  }
}

///|
fn commit_repo_requires_real_git(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Bool {
  // Only check primary object format; compat format is informational
  repo_object_format(fs, git_dir) != "sha1"
}

///|
fn resolve_no_edit_commit_message(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  amend : Bool,
) -> String? raise Error {
  let merge_head_path = git_dir + "/MERGE_HEAD"
  let squash_msg_path = git_dir + "/SQUASH_MSG"
  let merge_msg_path = git_dir + "/MERGE_MSG"
  if fs.is_file(merge_head_path) {
    if fs.is_file(merge_msg_path) {
      return Some(decode_bytes(fs.read_file(merge_msg_path)))
    }
    if amend {
      return get_head_commit_message(fs, root)
    }
    return None
  }
  if fs.is_file(squash_msg_path) {
    let squash_msg = decode_bytes(fs.read_file(squash_msg_path))
    if fs.is_file(merge_msg_path) {
      let merge_msg = decode_bytes(fs.read_file(merge_msg_path))
      return Some(join_commit_messages(squash_msg, merge_msg))
    }
    return Some(squash_msg)
  }
  if fs.is_file(merge_msg_path) {
    return Some(decode_bytes(fs.read_file(merge_msg_path)))
  }
  if amend {
    return get_head_commit_message(fs, root)
  }
  None
}

///|
fn join_commit_messages(primary : String, secondary : String) -> String {
  if primary.length() == 0 {
    return secondary
  }
  if secondary.length() == 0 {
    return primary
  }
  if primary.has_suffix("\n") || secondary.has_prefix("\n") {
    primary + secondary
  } else {
    primary + "\n" + secondary
  }
}

///|
fn read_merge_head_ids(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Array[@bitcore.ObjectId] raise Error {
  let path = git_dir + "/MERGE_HEAD"
  if not(fs.is_file(path)) {
    return []
  }
  let ids : Array[@bitcore.ObjectId] = []
  let content = decode_bytes(fs.read_file(path))
  for line_view in content.split("\n") {
    let line = trim_string(line_view.to_string())
    if line.length() == 0 {
      continue
    }
    let id = @bitcore.ObjectId::from_hex(line) catch {
      _ => raise @bitcore.GitError::InvalidObject("invalid MERGE_HEAD: \{line}")
    }
    ids.push(id)
  }
  ids
}

///|
fn commit_with_merge_heads(
  fs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  message : String,
  author : String,
  author_timestamp : Int64,
  committer : String,
  committer_timestamp : Int64,
  merge_heads : Array[@bitcore.ObjectId],
  allow_empty : Bool,
  encoding? : String = "UTF-8",
) -> @bitcore.ObjectId raise Error {
  let git_dir = resolve_git_dir(rfs, root)
  let head_parent = @bitlib.resolve_head_commit(rfs, git_dir)
  let entries = @bitlib.read_index_entries(rfs, git_dir)
  let tree_id = if entries.length() == 0 {
    if not(allow_empty) {
      raise @bitcore.GitError::InvalidObject("Empty index")
    }
    match head_parent {
      Some(parent_id) => {
        let db = @bitlib.ObjectDb::load_lazy(rfs, git_dir)
        let parent_tree = match db.get(rfs, parent_id) {
          Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit =>
            (@bitcore.parse_commit(obj.data).tree |> Some) catch {
              _ => None
            }
          _ => None
        }
        match parent_tree {
          Some(tree) => tree
          None => {
            let (empty_tree_id, empty_tree_compressed) = @bitcore.create_tree([])
            @bitlib.write_object_bytes(
              fs, git_dir, empty_tree_id, empty_tree_compressed,
            )
            empty_tree_id
          }
        }
      }
      None => {
        let (empty_tree_id, empty_tree_compressed) = @bitcore.create_tree([])
        @bitlib.write_object_bytes(
          fs, git_dir, empty_tree_id, empty_tree_compressed,
        )
        empty_tree_id
      }
    }
  } else {
    @bitlib.write_tree_from_index(fs, rfs, git_dir, entries)
  }
  let parents : Array[@bitcore.ObjectId] = []
  let seen : Map[String, Bool] = {}
  match head_parent {
    Some(parent_id) => {
      parents.push(parent_id)
      seen[parent_id.to_hex()] = true
    }
    None => ()
  }
  for merge_head in merge_heads {
    let hex = merge_head.to_hex()
    if seen.contains(hex) {
      continue
    }
    seen[hex] = true
    parents.push(merge_head)
  }
  let commit = @bitcore.Commit::new(
    tree_id,
    parents,
    author,
    author_timestamp,
    "+0000",
    committer,
    committer_timestamp,
    "+0000",
    message,
    encoding~,
  )
  let (commit_id, compressed) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(fs, git_dir, commit_id, compressed)
  @bitlib.update_head_ref(fs, rfs, git_dir, commit_id)
  if entries.length() > 0 {
    @bitlib.write_index_entries_with_tree(fs, rfs, git_dir, entries, tree_id)
  }
  commit_id
}

///|
fn cleanup_merge_state_files(
  fs : &@bitcore.FileSystem,
  git_dir : String,
) -> Unit raise Error {
  let files = ["MERGE_HEAD", "MERGE_MSG", "MERGE_MODE", "SQUASH_MSG"]
  for file in files {
    fs.remove_file(git_dir + "/" + file) catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => ()
    }
  }
}

///|
fn commit_args_require_standalone_error(args : Array[String]) -> Bool {
  let mut expect_value = false
  for arg in args {
    if expect_value {
      expect_value = false
      continue
    }
    if arg == "-S" ||
      arg == "--gpg-sign" ||
      arg == "--no-gpg-sign" ||
      arg.has_prefix("-S") ||
      arg.has_prefix("--gpg-sign=") {
      return true
    }
    if arg == "-m" ||
      arg == "--message" ||
      arg == "-F" ||
      arg == "--file" ||
      arg == "-C" ||
      arg == "--reuse-message" ||
      arg == "-c" ||
      arg == "--reedit-message" ||
      arg == "--author" ||
      arg == "--date" ||
      arg == "-t" ||
      arg == "--template" {
      expect_value = true
      continue
    }
    if arg.has_prefix("--message=") ||
      arg.has_prefix("--author=") ||
      arg.has_prefix("--date=") ||
      arg.has_prefix("--file=") ||
      arg.has_prefix("--reuse-message=") ||
      arg.has_prefix("--reedit-message=") ||
      arg.has_prefix("--template=") {
      continue
    }
    if arg.has_prefix("-m") ||
      arg.has_prefix("-F") ||
      arg.has_prefix("-C") ||
      arg.has_prefix("-c") ||
      arg.has_prefix("-am") ||
      arg.has_prefix("-ma") ||
      arg.has_prefix("-t") {
      continue
    }
    if arg.has_prefix("-") || arg == "--" {
      continue
    }
    // Positional arguments are pathspecs — now supported
    continue
  }
  false
}

///|
async fn commit_check_message_source_conflict(
  current_source : String,
  new_source : String,
) -> Unit raise Error {
  if current_source.length() == 0 {
    return
  }
  // -m can be used multiple times
  if current_source == "m" && new_source == "m" {
    return
  }
  let source_name = fn(s : String) -> String {
    match s {
      "m" => "-m"
      "F" => "-F"
      "C" => "-C"
      "c" => "-c"
      _ => s
    }
  }
  eprint_line(
    "fatal: options '\{source_name(current_source)}' and '\{source_name(new_source)}' cannot be used together",
  )
  @sys.exit(128)
}

///|
fn commit_strip_message(msg : String) -> String {
  let lines : Array[String] = []
  for line_view in msg.split("\n") {
    let line = line_view.to_string()
    let trimmed = trim_string(line)
    // Skip comment lines (lines starting with #)
    if trimmed.has_prefix("#") {
      continue
    }
    lines.push(line)
  }
  // Strip trailing empty lines
  while lines.length() > 0 {
    let last = lines[lines.length() - 1]
    if trim_string(last).length() == 0 {
      let _ = lines.pop()
    } else {
      break
    }
  }
  // Strip leading empty lines
  while lines.length() > 0 && trim_string(lines[0]).length() == 0 {
    let _ = lines.remove(0)
  }
  lines.join("\n")
}

///|
fn commit_apply_signoff(msg : String) -> String {
  let committer = get_committer_string()
  let signoff_line = "Signed-off-by: " + committer
  // Check if signoff already present at the end
  let lines : Array[String] = []
  for line_view in msg.split("\n") {
    lines.push(line_view.to_string())
  }
  // Strip trailing newlines for checking
  let mut last_nonblank = lines.length() - 1
  while last_nonblank >= 0 && trim_string(lines[last_nonblank]).length() == 0 {
    last_nonblank -= 1
  }
  if last_nonblank >= 0 && trim_string(lines[last_nonblank]) == signoff_line {
    return msg
  }
  // Determine if we need a blank line separator.
  // A blank line is needed if the last non-blank line is not a trailer.
  let need_blank = if last_nonblank >= 0 {
    not(commit_is_trailer_line(lines[last_nonblank]))
  } else {
    true
  }
  let result = StringBuilder::new()
  // Preserve original message
  if msg.has_suffix("\n") {
    result.write_string(msg)
  } else {
    result.write_string(msg)
    result.write_char('\n')
  }
  if need_blank {
    result.write_char('\n')
  }
  result.write_string(signoff_line)
  result.write_char('\n')
  result.to_string()
}

///|
fn commit_is_trailer_line(line : String) -> Bool {
  let trimmed = trim_string(line)
  // A trailer line matches "Token: Value" or "Token #Value"
  match trimmed.find(": ") {
    Some(idx) => {
      // Token must be non-empty and contain only word chars and hyphens
      let token = (trimmed[:idx] catch { _ => return false }).to_string()
      if token.length() == 0 {
        return false
      }
      for c in token {
        if not(
            (c >= 'a' && c <= 'z') ||
            (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9') ||
            c == '-',
          ) {
          return false
        }
      }
      true
    }
    None => false
  }
}

///|
fn commit_get_current_branch(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> String? {
  let head_path = git_dir + "/HEAD"
  let content = decode_bytes(rfs.read_file(head_path)) catch {
    _ => return None
  }
  let trimmed = trim_string(content)
  if trimmed.has_prefix("ref: refs/heads/") {
    Some(trimmed[16:].to_string() catch { _ => return None })
  } else {
    None
  }
}

///|
async fn commit_show_diffstat(
  _fs : OsFs,
  rfs : &@bitcore.RepoFileSystem,
  _root : String,
  git_dir : String,
  commit_id : @bitcore.ObjectId,
) -> Unit raise Error {
  // Show summary of files changed
  let db = @bitlib.ObjectDb::load_lazy(rfs, git_dir)
  let commit_obj = match db.get(rfs, commit_id) {
    Some(obj) => obj
    None => return
  }
  let commit = @bitcore.parse_commit(commit_obj.data) catch { _ => return }
  let tree_id = commit.tree
  let parent_tree_id : @bitcore.ObjectId? = if commit.parents.length() > 0 {
    match db.get(rfs, commit.parents[0]) {
      Some(parent_obj) =>
        Some(@bitcore.parse_commit(parent_obj.data).tree) catch {
          _ => None
        }
      None => None
    }
  } else {
    None
  }
  // Count files by comparing tree entries
  let new_entries = commit_collect_tree_entries(rfs, db, tree_id)
  let old_entries = match parent_tree_id {
    Some(pid) => commit_collect_tree_entries(rfs, db, pid)
    None => {}
  }
  let mut files_changed = 0
  let mut insertions = 0
  let mut deletions = 0
  let creates : Array[String] = []
  // Check new/modified files
  for path, new_id in new_entries {
    match old_entries.get(path) {
      Some(old_id) =>
        if old_id.to_hex() != new_id.to_hex() {
          files_changed += 1
        }
      None => {
        files_changed += 1
        creates.push(path)
      }
    }
  }
  // Check deleted files
  for path, _ in old_entries {
    if not(new_entries.contains(path)) {
      files_changed += 1
    }
  }
  // For a simple diffstat, count blob size differences
  for path, new_id in new_entries {
    match old_entries.get(path) {
      Some(old_id) =>
        if old_id.to_hex() != new_id.to_hex() {
          let new_size = commit_blob_line_count(rfs, db, new_id)
          let old_size = commit_blob_line_count(rfs, db, old_id)
          if new_size > old_size {
            insertions += new_size - old_size
          } else {
            deletions += old_size - new_size
          }
        }
      None => insertions += commit_blob_line_count(rfs, db, new_id)
    }
  }
  for path, old_id in old_entries {
    if not(new_entries.contains(path)) {
      deletions += commit_blob_line_count(rfs, db, old_id)
    }
  }
  if files_changed > 0 {
    let parts : Array[String] = []
    let files_s = if files_changed > 1 { "s" } else { "" }
    parts.push(" \{files_changed} file\{files_s} changed")
    if insertions > 0 {
      let ins_s = if insertions > 1 { "s" } else { "" }
      parts.push(" \{insertions} insertion\{ins_s}(+)")
    }
    if deletions > 0 {
      let del_s = if deletions > 1 { "s" } else { "" }
      parts.push(" \{deletions} deletion\{del_s}(-)")
    }
    print_line(parts.join(","))
  }
  for path in creates {
    print_line(" create mode 100644 \{path}")
  }
}

///|
fn commit_collect_tree_entries(
  rfs : &@bitcore.RepoFileSystem,
  db : @bitlib.ObjectDb,
  tree_id : @bitcore.ObjectId,
) -> Map[String, @bitcore.ObjectId] raise Error {
  let result : Map[String, @bitcore.ObjectId] = {}
  commit_collect_tree_entries_recursive(rfs, db, tree_id, "", result)
  result
}

///|
fn commit_collect_tree_entries_recursive(
  rfs : &@bitcore.RepoFileSystem,
  db : @bitlib.ObjectDb,
  tree_id : @bitcore.ObjectId,
  prefix : String,
  result : Map[String, @bitcore.ObjectId],
) -> Unit raise Error {
  let tree_obj = match db.get(rfs, tree_id) {
    Some(obj) => obj
    None => return
  }
  let entries = @bitcore.parse_tree(tree_obj.data) catch { _ => return }
  for entry in entries {
    let path = if prefix.length() > 0 {
      prefix + "/" + entry.name
    } else {
      entry.name
    }
    if entry.mode == "40000" || entry.mode == "040000" {
      commit_collect_tree_entries_recursive(rfs, db, entry.id, path, result)
    } else {
      result[path] = entry.id
    }
  }
}

///|
fn commit_blob_line_count(
  rfs : &@bitcore.RepoFileSystem,
  db : @bitlib.ObjectDb,
  blob_id : @bitcore.ObjectId,
) -> Int raise Error {
  match db.get(rfs, blob_id) {
    Some(obj) => {
      let mut count = 0
      for b in obj.data {
        if b == b'\n' {
          count += 1
        }
      }
      // Count final line without newline
      if obj.data.length() > 0 && obj.data[obj.data.length() - 1] != b'\n' {
        count += 1
      }
      count
    }
    None => 0
  }
}

///|
async fn commit_handle_pathspec_staging(
  fs : OsFs,
  _rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  pathspecs : Array[String],
  _include_mode : Bool,
  only_mode : Bool,
) -> Unit raise Error {
  // For --only mode, save the current index and create a temporary one
  // with only the specified paths
  if only_mode {
    commit_save_index_backup(fs, git_dir)
  }
  // Validate pathspecs exist in index or working tree
  let entries = @bitlib.read_index_entries(fs, git_dir)
  let index_paths : Map[String, Bool] = {}
  for e in entries {
    index_paths[e.path] = true
  }
  for pathspec in pathspecs {
    let rel_path = commit_resolve_pathspec(root, pathspec)
    // Check if path exists in index or as a file
    if not(index_paths.contains(rel_path)) &&
      not(fs.is_file(root + "/" + rel_path)) {
      eprint_line(
        "error: pathspec '\{pathspec}' did not match any file(s) known to git",
      )
      @sys.exit(1)
    }
  }
  // Stage the specified paths
  let paths_to_add : Array[String] = []
  for pathspec in pathspecs {
    let rel_path = commit_resolve_pathspec(root, pathspec)
    paths_to_add.push(rel_path)
  }
  if paths_to_add.length() > 0 {
    @bitlib.add_paths_async(fs, fs, root, paths_to_add)
    stage_submodule_gitlinks(fs, root, paths_to_add)
  }
}

///|
fn commit_resolve_pathspec(root : String, pathspec : String) -> String {
  // Resolve pathspec relative to root
  if pathspec.has_prefix("/") {
    return pathspec
  }
  // Get relative path from current directory
  let cwd = match @env.current_dir() {
    Some(dir) => dir
    None => root
  }
  let abs = normalize_path(cwd + "/" + pathspec)
  if abs.has_prefix(root + "/") {
    abs[root.length() + 1:].to_string() catch {
      _ => pathspec
    }
  } else {
    pathspec
  }
}

///|
fn commit_save_index_backup(fs : OsFs, git_dir : String) -> Unit raise Error {
  let index_path = git_dir + "/index"
  let backup_path = git_dir + "/index.commit-backup"
  if fs.is_file(index_path) {
    let data = (fs : &@bitcore.RepoFileSystem).read_file(index_path)
    (fs : &@bitcore.FileSystem).write_file(backup_path, data)
  }
}

///|
fn commit_restore_index_backup(fs : OsFs, git_dir : String) -> Unit raise Error {
  let backup_path = git_dir + "/index.commit-backup"
  let index_path = git_dir + "/index"
  if fs.is_file(backup_path) {
    let data = (fs : &@bitcore.RepoFileSystem).read_file(backup_path)
    (fs : &@bitcore.FileSystem).write_file(index_path, data)
    (fs : &@bitcore.FileSystem).remove_file(backup_path) catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => ()
    }
  }
}

///|
async fn read_commit_message_from_file(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  file : String,
  encoding : String,
) -> String raise Error {
  if file == "-" {
    return decode_commit_message_bytes(read_all_stdin(), encoding)
  }
  let path = if file.has_prefix("/") { file } else { root + "/" + file }
  decode_commit_message_bytes(fs.read_file(path), encoding)
}

///|
fn read_commit_message_from_revision(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  spec : String,
) -> String? raise Error {
  let git_dir = resolve_git_dir(fs, root)
  let commit_id = @bitrepo.rev_parse(fs, git_dir, spec)
  match commit_id {
    Some(id) => {
      let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
      match db.get(fs, id) {
        Some(obj) => Some(extract_commit_message(obj.data))
        None => None
      }
    }
    None => None
  }
}

///|
fn resolve_commit_message_encoding(git_dir : String) -> String {
  let overrides = @bitlib.parse_config_overrides()
  match overrides.get("i18n.commitencoding") {
    Some(value) => {
      let trimmed = trim_string(value)
      if trimmed.length() > 0 {
        trimmed
      } else {
        "UTF-8"
      }
    }
    None =>
      match bit_config_get(git_dir, "i18n", "commitEncoding") {
        Some(value) => {
          let trimmed = trim_string(value)
          if trimmed.length() > 0 {
            trimmed
          } else {
            "UTF-8"
          }
        }
        None => "UTF-8"
      }
  }
}

///|
fn decode_commit_message_bytes(data : Bytes, encoding : String) -> String {
  if is_iso_8859_1_encoding(encoding) {
    let out = StringBuilder::new()
    for b in data {
      out.write_char(b.to_int().unsafe_to_char())
    }
    out.to_string()
  } else {
    decode_bytes(data)
  }
}

///|
fn is_iso_8859_1_encoding(encoding : String) -> Bool {
  let normalized = normalize_commit_encoding_name(encoding)
  normalized == "iso88591" || normalized == "latin1" || normalized == "latin"
}

///|
fn normalize_commit_encoding_name(value : String) -> String {
  let out = StringBuilder::new()
  for c in trim_string(value).to_lower() {
    if c == '-' || c == '_' || c == ' ' {
      continue
    }
    out.write_char(c)
  }
  out.to_string()
}

///|
fn abs_path(path : String) -> String {
  if path.has_prefix("/") {
    return path
  }
  let cwd = match @env.current_dir() {
    Some(dir) => dir
    None => "."
  }
  normalize_path(cwd + "/" + path)
}

///|
async fn run_pre_commit_hook(fs : OsFs, root : String, git_dir : String) -> Int {
  let hook_git_dir = abs_path(git_dir)
  let hook_path = hook_git_dir + "/hooks/pre-commit"
  if not(fs.is_file(hook_path)) {
    return 0
  }
  let work_root = abs_path(root)
  @process.run(hook_path, [], inherit_env=true, cwd=work_root) catch {
    _ => 1
  }
}

///|
fn parse_commit_date(date_str : String) -> Int64 {
  // Support common formats:
  // - Unix timestamp: "1234567890"
  // - @timestamp: "@1234567890"
  // - ISO 8601: "2024-01-01T12:00:00"
  if date_str.has_prefix("@") {
    let ts_str = try date_str[1:] catch {
      _ => return 0L
    } noraise {
      s => s.to_string()
    }
    return parse_int64(ts_str)
  }
  // Try parsing as unix timestamp
  if date_str.iter().all(c => c >= '0' && c <= '9') {
    return parse_int64(date_str)
  }
  // Fallback to current time if format not recognized
  get_commit_timestamp()
}

///|
fn parse_int64(s : String) -> Int64 {
  let mut result = 0L
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10L + (c.to_int() - '0'.to_int()).to_int64()
    }
  }
  result
}
