///|
async fn handle_cherry_pick(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let wfs : &@git.FileSystem = fs
  let rfs : &@git.RepoFileSystem = fs
  let mut do_abort = false
  // Parse arguments
  let mut commit_spec : String? = None
  for arg in args {
    if not(arg.has_prefix("-")) {
      commit_spec = Some(arg)
      break
    }
    if arg == "--abort" {
      do_abort = true
    } else {
      warn_unimplemented_arg("cherry-pick", arg)
    }
  }
  // Handle --abort
  if do_abort {
    ignore(@gitlib.reset(wfs, rfs, root, "HEAD", @gitlib.ResetMode::Hard))
    return
  }
  guard commit_spec is Some(spec) else {
    raise @git.GitError::InvalidObject("commit required")
  }
  // Check if subdir-clone and handle specially
  match get_subdir_info(fs, git_dir) {
    Some((_, subdir_path, _)) => {
      handle_subdir_cherry_pick(fs, root, git_dir, spec, subdir_path) catch {
        err => raise err
      }
      return
    }
    None => ()
  }
  // Resolve commit
  let commit_id = @gitrepo.rev_parse(fs, git_dir, spec)
  guard commit_id is Some(cid) else {
    raise @git.GitError::InvalidObject("unknown revision: \{spec}")
  }
  let author = get_author_string()
  let timestamp = get_commit_timestamp()
  let result = @gitlib.cherry_pick(fs, fs, root, cid, author, timestamp)
  match result.status {
    @gitlib.CherryPickStatus::Success =>
      match result.commit_id {
        Some(id) => {
          let short = String::unsafe_substring(id.to_hex(), start=0, end=7)
          print_line("[\{short}] Cherry-picked from \{spec}")
        }
        None => print_line("Cherry-pick successful")
      }
    @gitlib.CherryPickStatus::Conflict => {
      print_line("CONFLICT: Merge conflict in cherry-pick:")
      for path in result.conflicts {
        print_line("  \{path}")
      }
      print_line("")
      print_line("After fixing the conflicts, use \"git commit\" to continue.")
      @sys.exit(1)
    }
  }
}

///|
/// Handle cherry-pick for subdir-clone
async fn handle_subdir_cherry_pick(
  fs : OsFs,
  root : String,
  git_dir : String,
  spec : String,
  subdir_path : String,
) -> Unit raise Error {
  print_line("Cherry-picking from upstream (subdir: \{subdir_path})...")
  // Resolve commit
  let commit_id = resolve_ref_for_subdir(fs, git_dir, spec) catch {
    err => raise err
  }
  guard commit_id is Some(cid) else {
    raise @git.GitError::InvalidObject("unknown revision: \{spec}")
  }
  // Load object database
  let db = @gitlib.ObjectDb::load_lazy(fs, git_dir)
  // Get upstream commit's subdir tree
  let upstream_tree = get_subdir_tree_from_commit(db, fs, cid, subdir_path) catch {
    err => raise err
  }
  guard upstream_tree is Some(utree) else {
    raise @git.GitError::InvalidObject(
      "Subdirectory not found in commit: \{subdir_path}",
    )
  }
  // Get upstream commit's parent subdir tree
  let commit_obj = db.get(fs, cid)
  guard commit_obj is Some(co) else {
    raise @git.GitError::InvalidObject("Cannot read commit")
  }
  let commit_info = @git.parse_commit(co.data) catch { err => raise err }
  let parent_tree = if commit_info.parents.length() > 0 {
    get_subdir_tree_from_commit(db, fs, commit_info.parents[0], subdir_path) catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => None
    }
  } else {
    None
  }
  // Check if this commit changes the subdir
  let changed = match parent_tree {
    Some(pt) => pt.to_hex() != utree.to_hex()
    None => true
  }
  if not(changed) {
    print_line("Commit \{spec} does not change \{subdir_path}, skipping.")
    return
  }
  // Apply the subdir change
  let (author, message) = parse_commit_author_message(co.data)
  let change_info : SubdirChangeInfo = {
    id: cid,
    subdir_tree: utree,
    message,
    author,
  }
  apply_subdir_change(fs, db, root, git_dir, change_info) catch {
    err => raise err
  }
  print_line("Cherry-picked: \{message}")
}
