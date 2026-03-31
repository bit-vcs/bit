///|

///|
fn merge_has_signing_args(args : Array[String]) -> Bool {
  for arg in args {
    if arg == "-S" ||
      arg == "--gpg-sign" ||
      arg == "--no-gpg-sign" ||
      arg.has_prefix("--gpg-sign=") {
      return true
    }
  }
  false
}

///|
fn merge_requires_real_git(
  args : Array[String],
  git_dir? : String = "",
) -> Bool {
  merge_has_signing_args(args) ||
  (git_dir.length() > 0 && signing_commit_config_enabled(git_dir))
}

///|
async fn delegate_merge_to_real_git(args : Array[String]) -> Unit {
  let argv : Array[String] = ["merge"]
  for arg in args {
    argv.push(arg)
  }
  let code = @process.run(
    resolve_real_git_for_dispatch(),
    argv,
    inherit_env=true,
    stdin=@stdio.stdin,
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  @sys.exit(code)
}

///|
async fn handle_merge(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  if merge_requires_real_git(args, git_dir~) {
    delegate_merge_to_real_git(args)
    return
  }
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  check_and_exit_unsupported_attrs(root)
  let wfs : &@bitcore.FileSystem = fs
  let mut message : String? = None
  let mut no_ff = false
  let mut ff_only = false
  let mut squash = false
  let mut quiet = false
  let mut abort_merge = false
  let mut continue_merge = false
  let mut allow_unrelated = false
  let mut strategy : String? = None
  let merge_heads : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-m" if i + 1 < args.length() => {
        message = Some(args[i + 1])
        i += 2
        continue
      }
      "--message" if i + 1 < args.length() => {
        message = Some(args[i + 1])
        i += 2
        continue
      }
      "-m" =>
        raise @bitcore.GitError::InvalidObject("option '-m' requires a value")
      "--message" =>
        raise @bitcore.GitError::InvalidObject(
          "option '--message' requires a value",
        )
      _ if arg.has_prefix("-m") && !(arg.has_prefix("--")) => {
        message = Some(string_slice_from(arg, 2))
        i += 1
        continue
      }
      _ if arg.has_prefix("--message=") => {
        message = Some(string_slice_from(arg, 10))
        i += 1
        continue
      }
      "--no-ff" => {
        no_ff = true
        i += 1
        continue
      }
      "--ff-only" => {
        ff_only = true
        i += 1
        continue
      }
      "--squash" => {
        squash = true
        i += 1
        continue
      }
      "-q" | "--quiet" => {
        quiet = true
        i += 1
        continue
      }
      "--abort" => {
        abort_merge = true
        i += 1
        continue
      }
      "--continue" => {
        continue_merge = true
        i += 1
        continue
      }
      "--allow-unrelated-histories" => {
        allow_unrelated = true
        i += 1
        continue
      }
      "-s" if i + 1 < args.length() => {
        strategy = Some(args[i + 1])
        i += 2
        continue
      }
      "--strategy" if i + 1 < args.length() => {
        strategy = Some(args[i + 1])
        i += 2
        continue
      }
      _ if arg.has_prefix("--strategy=") => {
        strategy = Some(string_slice_from(arg, 11))
        i += 1
        continue
      }
      _ if arg.has_prefix("-s") && !(arg.has_prefix("--")) && arg.length() > 2 => {
        strategy = Some(string_slice_from(arg, 2))
        i += 1
        continue
      }
      "-X" | "--strategy-option" => {
        // Strategy options: skip the value but warn
        if i + 1 < args.length() {
          i += 2
        } else {
          i += 1
        }
        // Strategy options are silently ignored for now
        continue
      }
      _ if arg.has_prefix("--strategy-option=") ||
        (arg.has_prefix("-X") && !(arg.has_prefix("--")) && arg.length() > 2) => {
        // Strategy options: silently ignored
        i += 1
        continue
      }
      _ if !(arg.has_prefix("-")) => {
        merge_heads.push(arg)
        i += 1
        continue
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("merge", arg)
      _ => ()
    }
    i += 1
  }
  // Handle octopus merge (>1 head)
  if merge_heads.length() > 1 {
    handle_octopus_merge(
      fs,
      root,
      git_dir,
      merge_heads,
      message,
      author=get_author_string(),
      timestamp=get_commit_timestamp(),
      quiet~,
      no_ff~,
    )
    return
  }
  // Validate strategy
  match strategy {
    Some(s) =>
      if s != "ours" && s != "recursive" && s != "ort" && s != "resolve" {
        @stdio.stderr.write("error: merge: unknown strategy '\{s}'\n")
        @sys.exit(1)
      }
    None => ()
  }
  let target_ref : String? = if merge_heads.length() == 1 {
    Some(merge_heads[0])
  } else {
    None
  }
  // Handle --abort
  if abort_merge {
    let orig_head_path = git_dir + "/ORIG_HEAD"
    let merge_head_path = git_dir + "/MERGE_HEAD"
    if rfs.is_file(orig_head_path) {
      let orig_hex = rfs.read_file(orig_head_path)
        |> decode_bytes
        |> trim_string
      ignore(@bitlib.reset(wfs, rfs, root, orig_hex, @bitlib.ResetMode::Hard))
      wfs.remove_file(orig_head_path) catch {
        err if @async.is_cancellation_error(err) => raise err
        _ => ()
      }
      wfs.remove_file(merge_head_path) catch {
        err if @async.is_cancellation_error(err) => raise err
        _ => ()
      }
      wfs.remove_file(git_dir + "/MERGE_MSG") catch {
        err if @async.is_cancellation_error(err) => raise err
        _ => ()
      }
      if !(quiet) {
        print_line("Merge aborted.")
      }
    } else {
      @stdio.stderr.write(
        "fatal: There is no merge to abort (ORIG_HEAD missing).",
      )
      @sys.exit(128)
    }
    return
  }
  // Handle --continue
  if continue_merge {
    let merge_head_path = git_dir + "/MERGE_HEAD"
    let merge_msg_path = git_dir + "/MERGE_MSG"
    if !(rfs.is_file(merge_head_path)) {
      @stdio.stderr.write(
        "fatal: There is no merge in progress (MERGE_HEAD missing).",
      )
      @sys.exit(128)
    }
    // Commit the merge
    let msg = if rfs.is_file(merge_msg_path) {
      rfs.read_file(merge_msg_path) |> decode_bytes |> trim_string
    } else {
      "Merge commit"
    }
    let author = get_author_string()
    let timestamp = get_commit_timestamp()
    let merge_heads = read_merge_head_ids(rfs, git_dir)
    let commit_id = if merge_heads.length() > 0 {
      commit_with_merge_heads(
        wfs, rfs, root, msg, author, timestamp, author, timestamp, merge_heads, false,
      )
    } else {
      @bitlib.commit(wfs, rfs, root, msg, author, timestamp)
    }
    let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
    // Clean up merge state
    wfs.remove_file(merge_head_path) catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => ()
    }
    wfs.remove_file(merge_msg_path) catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => ()
    }
    wfs.remove_file(git_dir + "/ORIG_HEAD") catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => ()
    }
    if !(quiet) {
      print_line("[\{short}] \{msg}")
    }
    return
  }
  guard target_ref is Some(refspec) else {
    raise @bitcore.GitError::InvalidObject("No commit to merge specified")
  }
  validate_current_branch_mergeoptions(rfs, git_dir)
  // Check if subdir-clone and handle specially
  match get_subdir_info(fs, git_dir) {
    Some((_, subdir_path, _)) => {
      handle_subdir_merge(fs, root, git_dir, refspec, subdir_path, message) catch {
        err => raise err
      }
      return
    }
    None => ()
  }
  // Resolve target
  let target_id = @bitrepo.rev_parse(fs, git_dir, refspec)
  guard target_id is Some(tid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{refspec}")
  }
  ignore(rfs) // merge commit targets handled natively
  let author = get_author_string()
  let timestamp = get_commit_timestamp()
  let msg = message.unwrap_or("Merge \{refspec}")
  // Handle -s ours: keep our tree, create merge commit
  if strategy is Some(s) && s == "ours" {
    let head_id = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
    guard head_id is Some(hid) else {
      raise @bitcore.GitError::InvalidObject("Cannot resolve HEAD")
    }
    let db = @bitlib.ObjectDb::load(rfs, git_dir)
    let head_obj = db.get(rfs, hid)
    guard head_obj is Some(ho) else {
      raise @bitcore.GitError::InvalidObject("Cannot read HEAD commit")
    }
    let head_info = @bitcore.parse_commit(ho.data)
    let tree_id = head_info.tree
    let commit = @bitcore.Commit::new(
      tree_id,
      [hid, tid],
      author,
      timestamp,
      "+0000",
      author,
      timestamp,
      "+0000",
      msg + "\n",
    )
    let (commit_id, commit_data) = @bitcore.create_commit(commit)
    @bitlib.write_object_bytes(wfs, git_dir, commit_id, commit_data)
    let head_path = git_dir + "/HEAD"
    let head_content = rfs.read_file(head_path) |> decode_bytes |> trim_string
    if head_content.has_prefix("ref: ") {
      let ref_path = git_dir +
        "/" +
        String::unsafe_substring(
          head_content,
          start=5,
          end=head_content.length(),
        )
      wfs.write_string(ref_path, commit_id.to_hex() + "\n")
    } else {
      wfs.write_string(head_path, commit_id.to_hex() + "\n")
    }
    let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
    if !(quiet) {
      print_line("Merge made by the 'ours' strategy. [\{short}]")
    }
    ignore(allow_unrelated)
    return
  }
  // Handle --squash
  if squash {
    // Squash merge: apply changes but don't commit
    let result = run_merge_with_sensitive_hooks(
      fs,
      fs,
      root,
      tid,
      msg,
      author,
      timestamp,
      theirs_label=refspec,
    )
    match result.status {
      @bitlib.MergeStatus::AlreadyUpToDate =>
        if !(quiet) {
          print_line("Already up to date.")
        }
      @bitlib.MergeStatus::FastForward | @bitlib.MergeStatus::Merged => {
        // Reset HEAD but keep working tree changes
        let head = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
        match head {
          Some(h) =>
            // Reset index to HEAD but keep working tree
            ignore(
              @bitlib.reset(wfs, rfs, root, h.to_hex(), @bitlib.ResetMode::Soft),
            )
          None => ()
        }
        if !(quiet) {
          print_line("Squash commit -- not updating HEAD")
        }
        // Save merge message for later commit
        wfs.write_string(
          git_dir + "/SQUASH_MSG",
          "Squashed commit of the following:\n\n" + msg + "\n",
        )
      }
      @bitlib.MergeStatus::Conflicted => {
        if !(quiet) {
          for path in result.conflicts {
            let ctype = result.conflict_types.get(path).unwrap_or("content")
            print_line("CONFLICT (\{ctype}): Merge conflict in \{path}")
          }
          print_line("Automatic merge failed; fix conflicts and then commit.")
        }
        @sys.exit(1)
      }
    }
    return
  }
  // Check if fast-forward is possible
  let head = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
  let is_ff = match head {
    Some(h) => is_ancestor(rfs, git_dir, h, tid)
    None => false
  }
  // Handle --ff-only
  if ff_only && !(is_ff) {
    @stdio.stderr.write("fatal: Not possible to fast-forward, aborting.")
    @sys.exit(128)
  }
  // Handle --no-ff: force merge commit even if fast-forward possible
  if no_ff && is_ff {
    // Create merge commit even though ff is possible
    let db = @bitlib.ObjectDb::load(rfs, git_dir)
    let head_id = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
    guard head_id is Some(hid) else {
      raise @bitcore.GitError::InvalidObject("Cannot resolve HEAD")
    }
    // Use target's tree
    let target_obj = db.get(rfs, tid)
    guard target_obj is Some(to) else {
      raise @bitcore.GitError::InvalidObject("Cannot read target commit")
    }
    let target_info = @bitcore.parse_commit(to.data)
    // Write tree (use target's tree)
    let tree_id = target_info.tree
    // Create merge commit with two parents
    let commit = @bitcore.Commit::new(
      tree_id,
      [hid, tid],
      author,
      timestamp,
      "+0000",
      author,
      timestamp,
      "+0000",
      msg + "\n",
    )
    let (commit_id, commit_data) = @bitcore.create_commit(commit)
    @bitlib.write_object_bytes(wfs, git_dir, commit_id, commit_data)
    // Update HEAD
    let head_path = git_dir + "/HEAD"
    let head_content = rfs.read_file(head_path) |> decode_bytes |> trim_string
    if head_content.has_prefix("ref: ") {
      let ref_path = git_dir +
        "/" +
        String::unsafe_substring(
          head_content,
          start=5,
          end=head_content.length(),
        )
      wfs.write_string(ref_path, commit_id.to_hex() + "\n")
    } else {
      wfs.write_string(head_path, commit_id.to_hex() + "\n")
    }
    // Checkout the new tree
    ignore(
      run_checkout_with_sensitive_hooks(
        wfs,
        rfs,
        root,
        commit_id.to_hex(),
        detach=false,
      ),
    )
    let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
    if !(quiet) {
      print_line("Merge made by the 'ort' strategy (--no-ff). [\{short}]")
    }
    return
  }
  // Regular merge (strategy=recursive/ort/resolve or no strategy specified)
  ignore(allow_unrelated)
  ignore(strategy)
  let result = run_merge_with_sensitive_hooks(
    fs,
    fs,
    root,
    tid,
    msg,
    author,
    timestamp,
    theirs_label=refspec,
  )
  match result.status {
    @bitlib.MergeStatus::AlreadyUpToDate =>
      if !(quiet) {
        print_line("Already up to date.")
      }
    @bitlib.MergeStatus::FastForward =>
      match result.commit_id {
        Some(id) => {
          let short = String::unsafe_substring(id.to_hex(), start=0, end=7)
          if !(quiet) {
            print_line("Fast-forward to \{short}")
          }
        }
        None => if !(quiet) { print_line("Fast-forward") }
      }
    @bitlib.MergeStatus::Merged =>
      match result.commit_id {
        Some(id) => {
          let short = String::unsafe_substring(id.to_hex(), start=0, end=7)
          if !(quiet) {
            print_line("Merge made by the 'ort' strategy. [\{short}]")
          }
        }
        None => if !(quiet) { print_line("Merged") }
      }
    @bitlib.MergeStatus::Conflicted => {
      if !(quiet) {
        for path in result.conflicts {
          let ctype = result.conflict_types.get(path).unwrap_or("content")
          print_line("CONFLICT (\{ctype}): Merge conflict in \{path}")
        }
        print_line("Automatic merge failed; fix conflicts and then commit.")
      }
      @sys.exit(1)
    }
  }
}

///|
async fn handle_octopus_merge(
  fs : OsFs,
  root : String,
  git_dir : String,
  heads : Array[String],
  message : String?,
  author~ : String,
  timestamp~ : Int64,
  quiet~ : Bool,
  no_ff~ : Bool,
) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let wfs : &@bitcore.FileSystem = fs
  // Resolve all merge heads
  let resolved_ids : Array[@bitcore.ObjectId] = []
  let labels : Array[String] = []
  for refspec in heads {
    let target_id = @bitrepo.rev_parse(fs, git_dir, refspec)
    guard target_id is Some(tid) else {
      raise @bitcore.GitError::InvalidObject(
        "merge: \{refspec} - not something we can merge",
      )
    }
    resolved_ids.push(tid)
    labels.push(refspec)
  }
  // Save original HEAD before any merges
  let original_head = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
  guard original_head is Some(orig_hid) else {
    raise @bitcore.GitError::InvalidObject("Cannot resolve HEAD")
  }
  // Save current reflog state so we can truncate intermediate entries later
  let head_reflog_before = @bitlib.read_reflog(rfs, git_dir, "HEAD") catch {
    _ => []
  }
  let head_reflog_count_before = head_reflog_before.length()
  let head_ref_opt = (@bitlib.read_head_ref(rfs, git_dir) |> Some) catch {
    _ => None
  }
  let branch_refname : String? = match head_ref_opt {
    Some(Branch(name)) => Some("refs/heads/" + name)
    _ => None
  }
  let branch_reflog_count_before = match branch_refname {
    Some(refname) => {
      let entries = @bitlib.read_reflog(rfs, git_dir, refname) catch { _ => [] }
      entries.length()
    }
    None => 0
  }
  // Merge each head sequentially. Track whether original HEAD was
  // fast-forwarded away (git's octopus excludes it from parents if so).
  let mut orig_head_ffwd = false
  for i = 0; i < resolved_ids.length(); i = i + 1 {
    let tid = resolved_ids[i]
    let label = labels[i]
    let cur_head = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
    match cur_head {
      Some(hid) => if is_ancestor(rfs, git_dir, tid, hid) { continue }
      None => ()
    }
    let step_msg = "Merge branch '\{label}'"
    let result = run_merge_with_sensitive_hooks(
      fs,
      fs,
      root,
      tid,
      step_msg,
      author,
      timestamp,
      theirs_label=label,
    )
    match result.status {
      @bitlib.MergeStatus::AlreadyUpToDate => continue
      @bitlib.MergeStatus::FastForward => orig_head_ffwd = true
      @bitlib.MergeStatus::Merged => ()
      @bitlib.MergeStatus::Conflicted => {
        // Restore HEAD to original
        ignore(
          @bitlib.reset(
            wfs,
            rfs,
            root,
            orig_hid.to_hex(),
            @bitlib.ResetMode::Hard,
          ),
        )
        if !(quiet) {
          for path in result.conflicts {
            let ctype = result.conflict_types.get(path).unwrap_or("content")
            print_line("CONFLICT (\{ctype}): Merge conflict in \{path}")
          }
          print_line(
            "Automatic merge failed; fix conflicts and then commit the result.",
          )
        }
        @sys.exit(1)
      }
    }
  }
  ignore(no_ff)
  // Get the merged tree from current HEAD
  let merged_head = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
  guard merged_head is Some(current_head) else {
    raise @bitcore.GitError::InvalidObject("Cannot resolve HEAD after merge")
  }
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let head_obj = db.get(rfs, current_head)
  guard head_obj is Some(ho) else {
    raise @bitcore.GitError::InvalidObject("Cannot read HEAD commit")
  }
  let head_info = @bitcore.parse_commit(ho.data)
  // Build parent list. If original HEAD was fast-forwarded to one of the
  // heads, exclude it (git's octopus does the same).
  let all_parents : Array[@bitcore.ObjectId] = []
  if !(orig_head_ffwd) {
    all_parents.push(orig_hid)
  }
  for id in resolved_ids {
    all_parents.push(id)
  }
  // Build merge message
  let msg = match message {
    Some(m) => m
    None => {
      let buf = StringBuilder::new()
      buf.write_string("Merge")
      for i = 0; i < labels.length(); i = i + 1 {
        if i == 0 {
          buf.write_string(" branches '")
        } else {
          buf.write_string(", '")
        }
        buf.write_string(labels[i])
        buf.write_string("'")
      }
      buf.to_string()
    }
  }
  let tree_id = head_info.tree
  let commit = @bitcore.Commit::new(
    tree_id,
    all_parents,
    author,
    timestamp,
    "+0000",
    author,
    timestamp,
    "+0000",
    msg + "\n",
  )
  let (commit_id, commit_data) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(wfs, git_dir, commit_id, commit_data)
  // Update HEAD ref
  let head_path = git_dir + "/HEAD"
  let head_content = rfs.read_file(head_path) |> decode_bytes |> trim_string
  if head_content.has_prefix("ref: ") {
    let ref_path = git_dir +
      "/" +
      String::unsafe_substring(head_content, start=5, end=head_content.length())
    wfs.write_string(ref_path, commit_id.to_hex() + "\n")
  } else {
    wfs.write_string(head_path, commit_id.to_hex() + "\n")
  }
  // Truncate reflog to remove intermediate merge entries, then add one entry
  // for the final octopus commit. This prevents git fsck from reporting
  // "invalid reflog entry" errors for unreachable intermediate commits.
  let octopus_reflog_msg = "merge: " + msg
  truncate_and_append_reflog(
    wfs, rfs, git_dir, "HEAD", head_reflog_count_before, orig_hid, commit_id, author,
    timestamp, octopus_reflog_msg,
  )
  match branch_refname {
    Some(refname) =>
      truncate_and_append_reflog(
        wfs, rfs, git_dir, refname, branch_reflog_count_before, orig_hid, commit_id,
        author, timestamp, octopus_reflog_msg,
      )
    None => ()
  }
  let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
  if !(quiet) {
    print_line("Merge made by the 'octopus' strategy. [\{short}]")
  }
}

///|
/// Truncate reflog to keep only entries before the intermediate merges,
/// then append a single entry for the final octopus merge commit.
fn truncate_and_append_reflog(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  refname : String,
  keep_count : Int,
  old_id : @bitcore.ObjectId,
  new_id : @bitcore.ObjectId,
  author : String,
  timestamp : Int64,
  message : String,
) -> Unit {
  let reflog_path = @bitlib.get_reflog_path(git_dir, refname)
  if !(rfs.is_file(reflog_path)) {
    return
  }
  // Read current reflog content
  let content = @utf8.decode_lossy(
    (rfs.read_file(reflog_path) catch { _ => return })[:],
  ).to_string()
  // Split into lines and keep only entries before the intermediate merges
  let lines : Array[String] = []
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    if line.length() > 0 {
      lines.push(line)
    }
  }
  // Keep only the first keep_count lines (entries before octopus merge started)
  let buf = StringBuilder::new()
  for i = 0; i < keep_count && i < lines.length(); i = i + 1 {
    buf.write_string(lines[i])
    buf.write_string("\n")
  }
  // Parse author identity for the reflog entry
  let (author_name, author_email) = parse_reflog_author(author)
  // Append the single octopus merge entry
  buf.write_string(
    "\{old_id.to_hex()} \{new_id.to_hex()} \{author_name} <\{author_email}> \{timestamp} +0000\t\{message}\n",
  )
  wfs.write_string(reflog_path, buf.to_string()) catch {
    _ => ()
  }
}

///|
/// Parse an author string like "Name <email> timestamp +tz" into (name, email).
fn parse_reflog_author(author : String) -> (String, String) {
  let trimmed = author.trim().to_string()
  match trimmed.find("<") {
    Some(start) =>
      match trimmed.find(">") {
        Some(end) if end > start => {
          let name = String::unsafe_substring(trimmed, start=0, end=start)
            .trim()
            .to_string()
          let email = String::unsafe_substring(trimmed, start=start + 1, end~)
          (if name.length() == 0 { "unknown" } else { name }, email)
        }
        _ => (trimmed, "unknown")
      }
    None => (trimmed, "unknown")
  }
}

///|
async fn validate_current_branch_mergeoptions(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Unit raise Error {
  let head_path = git_dir + "/HEAD"
  if !(rfs.is_file(head_path)) {
    return
  }
  let head = decode_bytes(rfs.read_file(head_path) catch { _ => return })
    |> trim_string
  if !(head.has_prefix("ref: refs/heads/")) {
    return
  }
  let branch_name = String::unsafe_substring(head, start=16, end=head.length())
  let merge_key = "branch." + branch_name + ".mergeoptions"
  match get_config_value(rfs, git_dir + "/config", merge_key, None, false) {
    Some(value) =>
      if split_cmdline_has_unclosed_quote(value) {
        eprint_line("fatal: bad " + merge_key + " string: unclosed quote")
        @sys.exit(128)
      }
    None => ()
  }
}

///|
fn split_cmdline_has_unclosed_quote(value : String) -> Bool {
  let mut in_single = false
  let mut in_double = false
  let mut escape = false
  for c in value {
    if escape {
      escape = false
      continue
    }
    if c == '\\' && !(in_single) {
      escape = true
      continue
    }
    if c == '\'' && !(in_double) {
      in_single = !(in_single)
      continue
    }
    if c == '"' && !(in_single) {
      in_double = !(in_double)
      continue
    }
  }
  in_single || in_double
}

///|
fn is_ancestor(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  ancestor : @bitcore.ObjectId,
  descendant : @bitcore.ObjectId,
) -> Bool {
  // Check if ancestor is an ancestor of descendant
  let db = @bitlib.ObjectDb::load(rfs, git_dir) catch { _ => return false }
  let ancestor_hex = ancestor.to_hex()
  let visited : Map[String, Bool] = {}
  let queue : Array[@bitcore.ObjectId] = [descendant]
  while queue.length() > 0 {
    let current = queue.pop()
    guard current is Some(cid) else { break }
    let hex = cid.to_hex()
    if hex == ancestor_hex {
      return true
    }
    if visited.get(hex).unwrap_or(false) {
      continue
    }
    visited[hex] = true
    let obj = db.get(rfs, cid) catch { _ => continue }
    match obj {
      Some(o) => {
        let info = @bitcore.parse_commit(o.data) catch { _ => continue }
        for p in info.parents {
          queue.push(p)
        }
      }
      None => ()
    }
  }
  false
}

///|
