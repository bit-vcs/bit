///|
async fn handle_revert(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = resolve_git_dir(OsFs::new(), root)
  let fs = OsFs::new()
  let mut no_commit = false
  let mut mainline : Int? = None
  let mut do_continue = false
  let mut do_abort = false
  let mut do_skip = false
  let commits : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-n" | "--no-commit" => no_commit = true
      "-m" if i + 1 < args.length() => {
        mainline = args[i + 1] |> @string.parse_int |> Some
        i += 1
      }
      _ if arg.has_prefix("-m") =>
        mainline = Some(
          @string.parse_int(
            String::unsafe_substring(arg, start=2, end=arg.length()),
          ),
        )
      "--continue" => do_continue = true
      "--abort" => do_abort = true
      "--skip" => do_skip = true
      _ if !arg.has_prefix("-") => commits.push(arg)
      _ => ()
    }
    i += 1
  }
  let rfs : &@bitcore.RepoFileSystem = fs
  let wfs : &@bitcore.FileSystem = fs
  let revert_head_path = git_dir + "/REVERT_HEAD"
  let merge_msg_path = git_dir + "/MERGE_MSG"
  let orig_head_path = git_dir + "/ORIG_HEAD"
  // Handle --abort
  if do_abort {
    if !rfs.is_file(revert_head_path) {
      @stdio.stderr.write(@utf8.encode("error: no revert in progress"))
      @sys.exit(1)
    }
    // Restore ORIG_HEAD if exists
    if rfs.is_file(orig_head_path) {
      let orig_hex = trim_chars(
        decode_bytes(rfs.read_file(orig_head_path)),
        " \t\r\n",
      )
      // Reset to ORIG_HEAD
      @bitlib.reset_merge(
        wfs,
        rfs,
        root,
        @bitcore.ObjectId::from_hex(orig_hex),
      )
      wfs.remove_file(orig_head_path) catch {
        _ => ()
      }
    }
    // Clean up state files
    wfs.remove_file(revert_head_path) catch {
      _ => ()
    }
    wfs.remove_file(merge_msg_path) catch {
      _ => ()
    }
    print_line("Revert aborted.")
    return
  }
  // Handle --skip
  if do_skip {
    if !rfs.is_file(revert_head_path) {
      @stdio.stderr.write(@utf8.encode("error: no revert in progress"))
      @sys.exit(1)
    }
    // Clean up state files (skip current revert)
    wfs.remove_file(revert_head_path) catch {
      _ => ()
    }
    wfs.remove_file(merge_msg_path) catch {
      _ => ()
    }
    // Reset index to HEAD
    ignore(@bitlib.reset(wfs, rfs, root, "HEAD", @bitlib.ResetMode::Mixed))
    print_line("Revert skipped.")
    return
  }
  // Handle --continue
  if do_continue {
    if !rfs.is_file(revert_head_path) {
      @stdio.stderr.write(@utf8.encode("error: no revert in progress"))
      @sys.exit(1)
    }
    // Read the commit message from MERGE_MSG
    let msg = if rfs.is_file(merge_msg_path) {
      decode_bytes(rfs.read_file(merge_msg_path))
    } else {
      "Revert commit\n"
    }
    // Create the commit
    let author = get_author_string()
    let timestamp = get_commit_timestamp()
    let new_commit_id = @bitlib.commit(wfs, rfs, root, msg, author, timestamp)
    let short_id = string_slice_to(new_commit_id.to_hex(), 7)
    let first_line = match msg.find("\n") {
      Some(idx) => String::unsafe_substring(msg, start=0, end=idx)
      None => msg
    }
    print_line("[\{short_id}] \{first_line}")
    // Clean up state files
    wfs.remove_file(revert_head_path) catch {
      _ => ()
    }
    wfs.remove_file(merge_msg_path) catch {
      _ => ()
    }
    wfs.remove_file(orig_head_path) catch {
      _ => ()
    }
    return
  }
  // Normal revert
  if commits.length() == 0 {
    raise @bitcore.GitError::InvalidObject("usage: git revert <commit>...")
  }
  // Check if revert already in progress
  if rfs.is_file(revert_head_path) {
    @stdio.stderr.write(
      @utf8.encode("error: revert already in progress, use --continue, --abort, or --skip"),
    )
    @sys.exit(1)
  }
  // Save ORIG_HEAD
  let current_head = @bitlib.resolve_head_commit(rfs, git_dir)
  if current_head is Some(hid) {
    wfs.write_string(orig_head_path, hid.to_hex() + "\n")
  }
  for commit_ref in commits {
    let commit_id = @bitrepo.rev_parse(rfs, git_dir, commit_ref)
    guard commit_id is Some(cid) else {
      raise @bitcore.GitError::InvalidObject("unknown revision: \{commit_ref}")
    }
    let author = get_author_string()
    let timestamp = get_commit_timestamp()
    // Three-way revert (local-change checks, conflict state, empty result)
    // lives in bit_lib, shared with cherry-pick.
    let result = @bitlib.revert(
      wfs,
      rfs,
      root,
      cid,
      author,
      timestamp,
      mainline~,
      no_commit~,
    )
    match result.status {
      @bitlib.CherryPickStatus::Success =>
        match result.commit_id {
          Some(id) => {
            let short = string_slice_to(id.to_hex(), 7)
            print_line("[\{short}] Revert \"\{revert_subject_of(rfs, git_dir, cid)}\"")
          }
          None => ()
        }
      @bitlib.CherryPickStatus::Empty => {
        print_line("nothing to commit, working tree clean")
        @sys.exit(1)
      }
      @bitlib.CherryPickStatus::Conflict => {
        for path in result.conflicts {
          print_line("CONFLICT (content): Merge conflict in \{path}")
        }
        let short = string_slice_to(cid.to_hex(), 7)
        eprint_line(
          "error: could not revert \{short}... \{revert_subject_of(rfs, git_dir, cid)}",
        )
        eprint_line(
          "hint: After resolving the conflicts, mark them with\nhint: \"git add/rm <pathspec>\", then run\nhint: \"git revert --continue\".",
        )
        @sys.exit(1)
      }
    }
  }
  // Clean up ORIG_HEAD on success
  wfs.remove_file(orig_head_path) catch {
    _ => ()
  }
}

///|
fn extract_commit_message(data : Bytes) -> String {
  let text = decode_bytes(data)
  let mut in_message = false
  let msg_lines : Array[String] = []
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if in_message {
      msg_lines.push(line)
      continue
    }
    if line.length() == 0 {
      in_message = true
    }
  }
  msg_lines.join("\n")
}

///|
fn normalize_notes_ref(ref_name : String?) -> String raise @bitcore.GitError {
  let name = ref_name.unwrap_or("commits")
  let normalized = @bitlib.normalize_repo_path(name) catch {
    _ => raise @bitcore.GitError::InvalidObject("invalid notes ref: " + name)
  }
  if normalized.has_prefix("refs/") {
    normalized
  } else {
    "refs/notes/" + normalized
  }
}

///|
/// Handle git notes command

///|
fn revert_subject_of(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  id : @bitcore.ObjectId,
) -> String {
  let db = @bitlib.ObjectDb::load(rfs, git_dir) catch { _ => return "" }
  let obj = db.get(rfs, id) catch { _ => None }
  match obj {
    Some(obj) => {
      let msg = extract_commit_message(obj.data)
      match msg.find("\n") {
        Some(i) => String::unsafe_substring(msg, start=0, end=i)
        None => msg
      }
    }
    None => ""
  }
}
