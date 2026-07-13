///|
/// git history: EXPERIMENTAL history-rewriting command group (git 2.55).
/// Currently only the `fixup` subcommand is implemented.

///|
async fn handle_history(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    raise @bitcore.GitError::InvalidObject("git history: missing subcommand")
  }
  let sub = args[0]
  let rest = args[1:].to_array()
  match sub {
    "fixup" => handle_history_fixup(rest)
    _ =>
      raise @bitcore.GitError::InvalidObject(
        "git history: unknown subcommand '\{sub}' (only 'fixup' is supported)",
      )
  }
}

///|
async fn handle_history_fixup(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let ffs : &@bitcore.FileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)

  // -- parse arguments ------------------------------------------------------
  let mut dry_run = false
  let mut reedit = false
  let mut only_head = false
  let mut empty = @bitlib.HistoryEmptyAction::Drop
  let mut target_spec : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-n" | "--dry-run" => dry_run = true
      "--reedit-message" => reedit = true
      "--" => ()
      _ =>
        if arg.has_prefix("--empty=") {
          let v = String::unsafe_substring(arg, start=8, end=arg.length())
          empty = match v {
            "drop" => @bitlib.HistoryEmptyAction::Drop
            "keep" => @bitlib.HistoryEmptyAction::Keep
            "abort" => @bitlib.HistoryEmptyAction::Abort
            _ =>
              raise @bitcore.GitError::InvalidObject(
                "unrecognized value for --empty: \{v}",
              )
          }
        } else if arg.has_prefix("--update-refs=") {
          let v = String::unsafe_substring(arg, start=14, end=arg.length())
          match v {
            "branches" => only_head = false
            "head" => only_head = true
            _ =>
              raise @bitcore.GitError::InvalidObject(
                "invalid --update-refs value: \{v}",
              )
          }
        } else if arg.has_prefix("-") {
          raise @bitcore.GitError::InvalidObject(
            "unknown history fixup argument: \{arg}",
          )
        } else if target_spec is None {
          target_spec = Some(arg)
        } else {
          raise @bitcore.GitError::InvalidObject("command expects a single revision")
        }
    }
    i += 1
  }
  guard target_spec is Some(spec) else {
    raise @bitcore.GitError::InvalidObject("command expects a single revision")
  }

  // fixup needs a worktree/index; refuse in a bare repository.
  if is_bare_repo_dir(root) {
    raise @bitcore.GitError::InvalidObject("cannot run fixup in a bare repository")
  }
  let db = @bitlib.ObjectDb::load(rfs, git_dir)

  // Resolve target and HEAD.
  guard @bitrepo.rev_parse(rfs, git_dir, spec) is Some(target) else {
    raise @bitcore.GitError::InvalidObject("commit cannot be found: \{spec}")
  }
  guard @bitrepo.rev_parse(rfs, git_dir, "HEAD") is Some(head) else {
    raise @bitcore.GitError::InvalidObject("cannot look up HEAD")
  }

  // Write the index as a tree; require staged changes (index != HEAD tree).
  let entries = @bitlib.read_index_entries(rfs, git_dir)
  let index_tree = @bitlib.write_tree_from_index(ffs, rfs, git_dir, entries)
  let head_tree = history_commit_tree_cmd(db, rfs, head)
  if index_tree == head_tree {
    raise @bitcore.GitError::InvalidObject("nothing to fixup: no staged changes")
  }

  // Collect the tips to consider: all branches (+ HEAD) or just HEAD.
  let (head_ref, branches) = @bitlib.list_branches(rfs, git_dir)
  let tips : Array[@bitlib.HistoryRefUpdate] = []
  if only_head {
    // Only rewrite HEAD's branch; error if target is not in HEAD ancestry.
    if not(@bitlib.merge_base_is_ancestor(db, rfs, target, head)) {
      raise @bitcore.GitError::InvalidObject(
        "rewritten commit must be an ancestor of HEAD when using --update-refs=head",
      )
    }
    match head_ref {
      Branch(name) =>
        tips.push({
          refname: "refs/heads/" + name,
          old_id: head,
          new_id: head,
        })
      Detached(_) =>
        tips.push({ refname: "HEAD", old_id: head, new_id: head })
    }
  } else {
    for b in branches {
      tips.push({
        refname: "refs/heads/" + b.name,
        old_id: b.id,
        new_id: b.id,
      })
    }
  }

  // Reject histories containing merges between target and any tip.
  for tip in tips {
    if @bitlib.merge_base_is_ancestor(db, rfs, target, tip.new_id) {
      history_reject_merges_cmd(db, rfs, target, tip.new_id)
    }
  }

  let reedit_message : String? = if reedit {
    // Open the target's message in the editor and use whatever comes back.
    let orig_msg = history_commit_message_cmd(db, rfs, target)
    let msg_path = git_dir + "/COMMIT_EDITMSG"
    ffs.write_string(msg_path, orig_msg)
    match resolve_commit_editor() {
      Some(editor) => {
        let code = run_editor_on_path(editor, msg_path)
        if code != 0 {
          raise @bitcore.GitError::InvalidObject("editor exited with \{code}")
        }
        let edited = decode_bytes(rfs.read_file(msg_path))
        Some(history_clean_editmsg(edited))
      }
      None => None
    }
  } else {
    None
  }
  let result = @bitlib.history_fixup(
    db, ffs, rfs, git_dir, target, index_tree, head, tips, empty, reedit_message,
  )

  if dry_run {
    for u in result.updates {
      print_line("update \{u.refname} \{u.new_id.to_hex()} \{u.old_id.to_hex()}")
    }
    return
  }

  // Apply the ref updates, recording a reflog entry for each.
  let mut new_head : @bitcore.ObjectId? = None
  let head_branch = match head_ref {
    Branch(name) => Some("refs/heads/" + name)
    Detached(_) => None
  }
  let (rl_author, rl_email, rl_ts, rl_tz) = get_committer_identity()
  let reflog_msg = "fixup: updating " + spec
  for u in result.updates {
    history_write_ref_cmd(ffs, git_dir, u.refname, u.new_id)
    try
      @bitlib.append_reflog(
        ffs, rfs, git_dir, u.refname, u.old_id, u.new_id, rl_author, rl_email,
        rl_ts, rl_tz, reflog_msg,
      )
    catch {
      _ => ()
    }
    if head_branch is Some(hb) && hb == u.refname {
      try
        @bitlib.append_reflog(
          ffs, rfs, git_dir, "HEAD", u.old_id, u.new_id, rl_author, rl_email,
          rl_ts, rl_tz, reflog_msg,
        )
      catch {
        _ => ()
      }
      new_head = Some(u.new_id)
    }
  }

  // Reset the index to the new HEAD so staged changes are consumed, while
  // leaving unstaged worktree changes in place (mixed reset semantics).
  // Best-effort: a failure here must not abort the (already applied) rewrite.
  match new_head {
    Some(nh) =>
      try
        ignore(
          @bitlib.reset(ffs, rfs, root, nh.to_hex(), @bitlib.ResetMode::Mixed),
        )
      catch {
        _ => ()
      }
    None => ()
  }
}

///|
///|
fn history_is_blank_line(s : String) -> Bool {
  for c in s {
    if c != ' ' && c != '\t' && c != '\r' {
      return false
    }
  }
  true
}

///|
/// Extract a commit's message (everything after the header's blank line).
fn history_commit_message_cmd(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commit_id : @bitcore.ObjectId,
) -> String raise Error {
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) && o.obj_type == @bitcore.ObjectType::Commit else {
    raise @bitcore.GitError::InvalidObject("not a commit \{commit_id.to_hex()}")
  }
  let text = decode_bytes(o.data)
  match text.find("\n\n") {
    Some(idx) => String::unsafe_substring(text, start=idx + 2, end=text.length())
    None => ""
  }
}

///|
/// Strip `#` comment lines and trailing blank lines from an edited message.
fn history_clean_editmsg(raw : String) -> String {
  let out : Array[String] = []
  for line_view in raw.split("\n") {
    let line = line_view.to_owned()
    if line.has_prefix("#") {
      continue
    }
    out.push(line)
  }
  // Drop trailing blank lines.
  while out.length() > 0 && history_is_blank_line(out[out.length() - 1]) {
    out.pop() |> ignore
  }
  if out.length() == 0 {
    ""
  } else {
    out.join("\n") + "\n"
  }
}

///|
fn history_commit_tree_cmd(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commit_id : @bitcore.ObjectId,
) -> @bitcore.ObjectId raise Error {
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) && o.obj_type == @bitcore.ObjectType::Commit else {
    raise @bitcore.GitError::InvalidObject("not a commit \{commit_id.to_hex()}")
  }
  @bitcore.parse_commit(o.data).tree
}

///|
/// Walk tip -> target following first parents; error if any commit is a merge.
fn history_reject_merges_cmd(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  target : @bitcore.ObjectId,
  tip : @bitcore.ObjectId,
) -> Unit raise Error {
  let mut cur = tip
  while cur != target {
    let obj = db.get(rfs, cur)
    guard obj is Some(o) && o.obj_type == @bitcore.ObjectType::Commit else {
      return
    }
    let info = @bitcore.parse_commit(o.data)
    if info.parents.length() > 1 {
      raise @bitcore.GitError::InvalidObject(
        "replaying merge commits is not supported yet!",
      )
    }
    match info.parents.get(0) {
      Some(p) => cur = p
      None => break
    }
  }
}

///|
fn history_write_ref_cmd(
  fs : &@bitcore.FileSystem,
  git_dir : String,
  refname : String,
  id : @bitcore.ObjectId,
) -> Unit raise Error {
  let path = git_dir + "/" + refname
  let slash = history_last_slash(path)
  if slash > 0 {
    fs.mkdir_p(String::unsafe_substring(path, start=0, end=slash))
  }
  fs.write_string(path, id.to_hex() + "\n")
}

///|
fn history_last_slash(s : String) -> Int {
  let mut idx = -1
  let mut k = 0
  while k < s.length() {
    if s[k] == '/' {
      idx = k
    }
    k += 1
  }
  idx
}
