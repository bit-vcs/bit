///|
/// Result of bisect_compute_next: either found the bad commit, moved to next
/// candidate, or still waiting for good/bad marks.
enum BisectNextResult {
  /// Found the first bad commit (hex of bad commit)
  Found(String)
  /// Checked out next candidate (hex, message, remaining count, steps)
  Next(String, String, Int, Int)
  /// Waiting for more marks (status message)
  Waiting(String)
}

///|
async fn handle_bisect(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let wfs : &@bitcore.FileSystem = fs
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let subcmd = args.get(0).unwrap_or("help")
  match subcmd {
    "start" => bisect_start(wfs, rfs, root, git_dir, args)
    "bad" | "new" => bisect_mark(wfs, rfs, git_dir, args, "bad")
    "good" | "old" => bisect_mark(wfs, rfs, git_dir, args, "good")
    "skip" => bisect_skip(wfs, rfs, git_dir, args)
    "reset" => bisect_reset(wfs, rfs, root, git_dir, args)
    "log" => bisect_log(rfs, git_dir)
    "replay" => bisect_replay(wfs, rfs, root, git_dir, args)
    "visualize" | "view" => bisect_visualize(rfs, git_dir, args)
    "run" => {
      let run_args : Array[String] = []
      for i in 1..<args.length() {
        run_args.push(args[i])
      }
      bisect_run(
        wfs,
        rfs,
        root,
        git_dir,
        run_args,
        run_command=bisect_run_shell_command,
      )
    }
    "terms" => bisect_terms(rfs, git_dir, args)
    "help" | _ => {
      print_line(
        "usage: git bisect [start|bad|good|skip|reset|run|log|replay|visualize|terms]",
      )
      print_line("")
      print_line("  start [bad [good...]] - Start bisect session")
      print_line("  bad [commit]          - Mark commit as bad")
      print_line("  good [commit]         - Mark commit as good")
      print_line("  skip [commit]         - Skip commit")
      print_line("  reset [commit]        - End bisect and checkout commit")
      print_line("  run <cmd>             - Run command to auto-bisect")
      print_line("  log                   - Show bisect log")
      print_line("  replay <logfile>      - Replay bisect log")
      print_line("  visualize             - Show remaining commits in gitk")
      print_line("  terms                 - Show current terms")
    }
  }
}

///|
async fn bisect_start(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  _root : String,
  git_dir : String,
  args : Array[String],
) -> Unit raise Error {
  let bisect_start_path = git_dir + "/BISECT_START"
  let bisect_log_path = git_dir + "/BISECT_LOG"
  let bisect_terms_path = git_dir + "/BISECT_TERMS"
  let bisect_refs_dir = git_dir + "/refs/bisect"
  // Check if already in bisect
  if rfs.is_file(bisect_start_path) {
    @stdio.stderr.write("error: bisect already in progress")
    @stdio.stderr.write("use 'git bisect reset' to abort")
    @sys.exit(1)
  }
  // Get current branch
  let head_content = decode_bytes(rfs.read_file(git_dir + "/HEAD"))
  let current_branch = if head_content.has_prefix("ref: refs/heads/") {
    trim_string(
      String::unsafe_substring(
        head_content,
        start=16,
        end=head_content.length(),
      ),
    )
  } else {
    "HEAD"
  }
  // Create bisect directory
  wfs.mkdir_p(bisect_refs_dir)
  // Save start state
  wfs.write_string(bisect_start_path, current_branch + "\n")
  wfs.write_string(bisect_terms_path, "bad\ngood\n")
  wfs.write_string(bisect_log_path, "git bisect start\n")
  eprint_line("status: waiting for both good and bad commits")
  // Handle optional bad/good arguments
  // git bisect start [bad [good...]] [--] [paths...]
  let mut i = 1
  let mut bad_set = false
  while i < args.length() {
    let arg = args[i]
    if arg == "--" {
      break
    }
    if not(arg.has_prefix("-")) {
      if not(bad_set) {
        bisect_mark(wfs, rfs, git_dir, ["bad", arg], "bad")
        bad_set = true
      } else {
        bisect_mark(wfs, rfs, git_dir, ["good", arg], "good")
      }
    }
    i += 1
  }
}

///|
async fn bisect_mark(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  args : Array[String],
  mark_type : String,
  auto_next? : Bool = true,
) -> Unit raise Error {
  let bisect_start_path = git_dir + "/BISECT_START"
  let bisect_log_path = git_dir + "/BISECT_LOG"
  let bisect_refs_dir = git_dir + "/refs/bisect"
  if not(rfs.is_file(bisect_start_path)) {
    @stdio.stderr.write("error: not in a bisect session")
    @stdio.stderr.write("use 'git bisect start' first")
    @sys.exit(1)
  }
  let commit_ref = args.get(1).unwrap_or("HEAD")
  let commit_id = @bitrepo.rev_parse(rfs, git_dir, commit_ref)
  guard commit_id is Some(cid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{commit_ref}")
  }
  let commit_hex = cid.to_hex()
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let commit_msg = bisect_first_line_of_commit(db, rfs, cid)
  if mark_type == "bad" {
    wfs.write_string(bisect_refs_dir + "/bad", commit_hex + "\n")
  } else {
    wfs.write_string(bisect_refs_dir + "/good-" + commit_hex, commit_hex + "\n")
  }
  let log_entry = "# \{mark_type}: [\{commit_hex}] \{commit_msg}\ngit bisect \{mark_type} \{commit_hex}\n"
  let existing_log = decode_bytes(rfs.read_file(bisect_log_path)) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => ""
  }
  wfs.write_string(bisect_log_path, existing_log + log_entry)
  if auto_next {
    let root = bisect_root_from_git_dir(git_dir)
    bisect_next(wfs, rfs, root, git_dir)
  }
}

///|
async fn bisect_skip(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  args : Array[String],
) -> Unit raise Error {
  let bisect_start_path = git_dir + "/BISECT_START"
  let bisect_log_path = git_dir + "/BISECT_LOG"
  let bisect_refs_dir = git_dir + "/refs/bisect"
  if not(rfs.is_file(bisect_start_path)) {
    @stdio.stderr.write("error: not in a bisect session")
    @sys.exit(1)
  }
  let commit_ref = args.get(1).unwrap_or("HEAD")
  let commit_id = @bitrepo.rev_parse(rfs, git_dir, commit_ref)
  guard commit_id is Some(cid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{commit_ref}")
  }
  let commit_hex = cid.to_hex()
  wfs.write_string(bisect_refs_dir + "/skip-" + commit_hex, commit_hex + "\n")
  let log_entry = "git bisect skip \{commit_hex}\n"
  let existing_log = decode_bytes(rfs.read_file(bisect_log_path)) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => ""
  }
  wfs.write_string(bisect_log_path, existing_log + log_entry)
  let root = bisect_root_from_git_dir(git_dir)
  bisect_next(wfs, rfs, root, git_dir)
}

///|
/// Compute bisect next candidate without side effects (no checkout, no output).
/// Returns the result for the caller to act on.
fn bisect_compute_next(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> BisectNextResult raise Error {
  let bisect_refs_dir = git_dir + "/refs/bisect"
  let bad_path = bisect_refs_dir + "/bad"
  if not(rfs.is_file(bad_path)) {
    return Waiting("status: waiting for bad commit")
  }
  let bad_hex = rfs.read_file(bad_path) |> decode_bytes |> trim_string
  let bad_id = @bitcore.ObjectId::from_hex(bad_hex)
  let good_commits : Array[@bitcore.ObjectId] = []
  let skip_commits : Array[@bitcore.ObjectId] = []
  let bisect_entries = (rfs : &@bitcore.RepoFileSystem).readdir(bisect_refs_dir) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => []
  }
  for entry in bisect_entries {
    if entry.has_prefix("good-") {
      let good_hex = trim_string(
        decode_bytes(rfs.read_file(bisect_refs_dir + "/" + entry)),
      )
      good_commits.push(@bitcore.ObjectId::from_hex(good_hex))
    } else if entry.has_prefix("skip-") {
      let skip_hex = trim_string(
        decode_bytes(rfs.read_file(bisect_refs_dir + "/" + entry)),
      )
      skip_commits.push(@bitcore.ObjectId::from_hex(skip_hex))
    }
  }
  if good_commits.length() == 0 {
    return Waiting("status: waiting for good commit(s), bad commit known")
  }
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let candidates = bisect_get_candidates(
    db, rfs, bad_id, good_commits, skip_commits,
  )
  if candidates.length() == 0 {
    return Found(bad_hex)
  }
  let mid_idx = candidates.length() / 2
  let mid_id = candidates[mid_idx]
  let mid_hex = mid_id.to_hex()
  let commit_msg = bisect_first_line_of_commit(db, rfs, mid_id)
  let remaining = candidates.length()
  let steps = bisect_steps(remaining)
  Next(mid_hex, commit_msg, remaining, steps)
}

///|
/// Perform bisect next: compute, checkout, and print status.
async fn bisect_next(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
) -> Unit raise Error {
  let result = bisect_compute_next(rfs, git_dir)
  bisect_apply_next_result(wfs, rfs, root, git_dir, result)
}

///|
/// Apply the result of bisect_compute_next: checkout and print.
async fn bisect_apply_next_result(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  result : BisectNextResult,
) -> Unit raise Error {
  let bisect_expected_path = git_dir + "/BISECT_EXPECTED_REV"
  match result {
    Found(bad_hex) => eprint_line("\{bad_hex} is the first bad commit")
    Next(mid_hex, commit_msg, remaining, steps) => {
      wfs.write_string(bisect_expected_path, mid_hex + "\n")
      ignore(
        run_checkout_with_sensitive_hooks(wfs, rfs, root, mid_hex, detach=true),
      )
      eprint_line(
        "Bisecting: \{remaining} revisions left to test after this (roughly \{steps} steps)",
      )
      eprint_line("[\{mid_hex}] \{commit_msg}")
    }
    Waiting(msg) => eprint_line(msg)
  }
}

///|
fn bisect_steps(n : Int) -> Int {
  if n <= 1 {
    return 0
  }
  let mut steps = 0
  let mut val = n
  while val > 1 {
    val = val / 2
    steps += 1
  }
  steps
}

///|
fn bisect_get_candidates(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  bad : @bitcore.ObjectId,
  goods : Array[@bitcore.ObjectId],
  skips : Array[@bitcore.ObjectId],
) -> Array[@bitcore.ObjectId] raise Error {
  let good_set : Map[String, Bool] = {}
  for g in goods {
    mark_ancestors(db, rfs, g, good_set)
  }
  // Pre-build skip set for O(1) lookup
  let skip_set : Map[String, Bool] = {}
  for s in skips {
    skip_set[s.to_hex()] = true
  }
  let candidates : Array[@bitcore.ObjectId] = []
  let visited : Map[String, Bool] = {}
  let queue : Array[@bitcore.ObjectId] = [bad]
  while queue.length() > 0 {
    let current = queue.pop()
    guard current is Some(cid) else { break }
    let hex = cid.to_hex()
    if visited.contains(hex) || good_set.contains(hex) {
      continue
    }
    visited[hex] = true
    if not(skip_set.contains(hex)) && cid != bad {
      candidates.push(cid)
    }
    let obj = db.get(rfs, cid)
    match obj {
      Some(o) => {
        let info = @bitcore.parse_commit(o.data)
        for p in info.parents {
          queue.push(p)
        }
      }
      None => ()
    }
  }
  candidates
}

///|
fn mark_ancestors(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  start : @bitcore.ObjectId,
  set : Map[String, Bool],
) -> Unit {
  let queue : Array[@bitcore.ObjectId] = [start]
  while queue.length() > 0 {
    let current = queue.pop()
    guard current is Some(cid) else { break }
    let hex = cid.to_hex()
    if set.contains(hex) {
      continue
    }
    set[hex] = true
    let obj = db.get(rfs, cid) catch { _ => None }
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
}

///|
/// Run bisect automated search with an injectable command runner.
/// `run_command` takes (root_dir, command_string) and returns exit code.
async fn bisect_run(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  args : Array[String],
  run_command~ : async (String, String) -> Int raise Error,
) -> Unit raise Error {
  if args.length() == 0 {
    raise @bitcore.GitError::InvalidObject(
      "bisect run failed: no command provided.",
    )
  }
  // Verify bisect is ready (both good and bad set)
  match bisect_compute_next(rfs, git_dir) {
    Waiting(_) =>
      raise @bitcore.GitError::InvalidObject(
        "bisect run requires both good and bad commits to be set",
      )
    Found(bad_hex) => {
      eprint_line("\{bad_hex} is the first bad commit")
      return
    }
    Next(_, _, _, _) => ()
  }
  let command = bisect_shell_quote_args(args)
  let mut is_first_run = true
  while true {
    eprint_line("running \{command}")
    let res = run_command(root, command)
    // Exit codes 126/127 on first run: verify script works on good commit
    if is_first_run && (res == 126 || res == 127) {
      let verify_res = bisect_verify_good(
        wfs,
        rfs,
        root,
        git_dir,
        command,
        run_command~,
      )
      is_first_run = false
      if verify_res < 0 || verify_res >= 128 {
        raise @bitcore.GitError::InvalidObject(
          "unable to verify \{command} on good revision",
        )
      }
      if verify_res == res {
        raise @bitcore.GitError::InvalidObject(
          "bogus exit code \{verify_res} for good revision",
        )
      }
    }
    is_first_run = false
    if res < 0 || res >= 128 {
      raise @bitcore.GitError::InvalidObject(
        "bisect run failed: exit code \{res} from \{command} is < 0 or >= 128",
      )
    }
    let new_state = if res == 125 {
      "skip"
    } else if res == 0 {
      "good"
    } else {
      "bad"
    }
    // Mark the current commit (skip auto_next; we handle checkout ourselves)
    bisect_mark(wfs, rfs, git_dir, [new_state], new_state, auto_next=false)
    // Check result
    match bisect_compute_next(rfs, git_dir) {
      Found(bad_hex) => {
        eprint_line("\{bad_hex} is the first bad commit")
        eprint_line("bisect found first bad commit")
        return
      }
      Waiting(_) => {
        // Only skipped commits left
        eprint_line("bisect run cannot continue any more")
        return
      }
      Next(mid_hex, commit_msg, remaining, steps) =>
        // Checkout next candidate and continue loop
        bisect_apply_next_result(
          wfs,
          rfs,
          root,
          git_dir,
          Next(mid_hex, commit_msg, remaining, steps),
        )
    }
  }
}

///|
/// Verify the command works on a known-good commit.
/// Checks out a good revision, runs the command, then restores current.
async fn bisect_verify_good(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  command : String,
  run_command~ : async (String, String) -> Int raise Error,
) -> Int raise Error {
  let bisect_refs_dir = git_dir + "/refs/bisect"
  // Find a good commit
  let bisect_entries = (rfs : &@bitcore.RepoFileSystem).readdir(bisect_refs_dir) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => []
  }
  let mut good_hex : String? = None
  for entry in bisect_entries {
    if entry.has_prefix("good-") {
      good_hex = Some(
        trim_string(decode_bytes(rfs.read_file(bisect_refs_dir + "/" + entry))),
      )
      break
    }
  }
  guard good_hex is Some(good_rev) else { return -1 }
  // Save current HEAD
  let current_hex = match @bitlib.resolve_ref(rfs, git_dir, "HEAD") {
    Some(id) => id.to_hex()
    None => return -1
  }
  // Checkout good revision
  ignore(
    run_checkout_with_sensitive_hooks(wfs, rfs, root, good_rev, detach=true),
  )
  // Run command on good revision
  let rc = run_command(root, command)
  // Restore original revision
  ignore(
    run_checkout_with_sensitive_hooks(wfs, rfs, root, current_hex, detach=true),
  )
  rc
}

///|
/// Default shell command runner for bisect run.
async fn bisect_run_shell_command(
  cwd : String,
  command : String,
) -> Int raise Error {
  @process.run(
    "sh",
    ["-c", command],
    inherit_env=true,
    cwd~,
    stdin=@stdio.stdin,
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
}

///|
/// Replay a bisect log file.
async fn bisect_replay(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  args : Array[String],
) -> Unit raise Error {
  guard args.length() > 1 else {
    raise @bitcore.GitError::InvalidObject("no logfile given")
  }
  let filename = args[1]
  let fs = OsFs::new()
  if not(fs.is_file(filename)) {
    raise @bitcore.GitError::InvalidObject(
      "cannot read file '\{filename}' for replaying",
    )
  }
  // Reset current bisect state
  bisect_reset(wfs, rfs, root, git_dir, ["reset"])
  // Read and process log file
  let content = decode_bytes(fs.read_file(filename))
  for line_view in content.split("\n") {
    let line = trim_string(line_view.to_string())
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    // Parse "git bisect <subcmd> [args...]" or "git-bisect <subcmd> [args...]"
    let rest = if line.has_prefix("git bisect ") {
      String::unsafe_substring(line, start=11, end=line.length())
    } else if line.has_prefix("git-bisect ") {
      String::unsafe_substring(line, start=11, end=line.length())
    } else {
      continue
    }
    // Split into subcmd and args
    let parts : Array[String] = []
    for part in rest.split(" ") {
      let s = part.to_string()
      if s.length() > 0 {
        parts.push(s)
      }
    }
    if parts.length() == 0 {
      continue
    }
    let subcmd = parts[0]
    match subcmd {
      "start" => bisect_start(wfs, rfs, root, git_dir, parts)
      "bad" | "new" => bisect_mark(wfs, rfs, git_dir, parts, "bad")
      "good" | "old" => bisect_mark(wfs, rfs, git_dir, parts, "good")
      "skip" => bisect_skip(wfs, rfs, git_dir, parts)
      _ => ()
    }
  }
}

///|
/// Show remaining commits for visualization (delegates to git log).
async fn bisect_visualize(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  _args : Array[String],
) -> Unit raise Error {
  let bisect_refs_dir = git_dir + "/refs/bisect"
  let bad_path = bisect_refs_dir + "/bad"
  if not(rfs.is_file(bad_path)) {
    raise @bitcore.GitError::InvalidObject(
      "bisect visualize requires a bad commit",
    )
  }
  let bad_hex = rfs.read_file(bad_path) |> decode_bytes |> trim_string
  // Collect good commits for --not
  let good_hexes : Array[String] = []
  let bisect_entries = (rfs : &@bitcore.RepoFileSystem).readdir(bisect_refs_dir) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => []
  }
  for entry in bisect_entries {
    if entry.has_prefix("good-") {
      let good_hex = trim_string(
        decode_bytes(rfs.read_file(bisect_refs_dir + "/" + entry)),
      )
      good_hexes.push(good_hex)
    }
  }
  // Build rev-list args: bad --not good1 good2 ...
  let log_args : Array[String] = ["--oneline", bad_hex, "--not"]
  for g in good_hexes {
    log_args.push(g)
  }
  handle_log(log_args)
}

///|
/// Show current bisect terms.
async fn bisect_terms(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  _args : Array[String],
) -> Unit raise Error {
  let bisect_terms_path = git_dir + "/BISECT_TERMS"
  if not(rfs.is_file(bisect_terms_path)) {
    raise @bitcore.GitError::InvalidObject("no terms saved")
  }
  let content = decode_bytes(rfs.read_file(bisect_terms_path))
  let lines : Array[String] = []
  for line in content.split("\n") {
    let s = trim_string(line.to_string())
    if s.length() > 0 {
      lines.push(s)
    }
  }
  let term_bad = lines.get(0).unwrap_or("bad")
  let term_good = lines.get(1).unwrap_or("good")
  eprint_line("Your current terms are \{term_good} for the old state")
  eprint_line("and \{term_bad} for the new state.")
}

///|
async fn bisect_reset(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  args : Array[String],
) -> Unit raise Error {
  let bisect_start_path = git_dir + "/BISECT_START"
  let bisect_log_path = git_dir + "/BISECT_LOG"
  let bisect_terms_path = git_dir + "/BISECT_TERMS"
  let bisect_expected_path = git_dir + "/BISECT_EXPECTED_REV"
  let bisect_ancestors_path = git_dir + "/BISECT_ANCESTORS_OK"
  let bisect_names_path = git_dir + "/BISECT_NAMES"
  let bisect_run_path = git_dir + "/BISECT_RUN"
  let bisect_refs_dir = git_dir + "/refs/bisect"
  let checkout_ref = if args.length() > 1 {
    args[1]
  } else if rfs.is_file(bisect_start_path) {
    rfs.read_file(bisect_start_path) |> decode_bytes |> trim_string
  } else {
    "HEAD"
  }
  if checkout_ref != "HEAD" && checkout_ref.length() > 0 {
    if rfs.is_file(git_dir + "/refs/heads/" + checkout_ref) {
      ignore(
        run_checkout_with_sensitive_hooks(
          wfs,
          rfs,
          root,
          checkout_ref,
          detach=false,
        ),
      )
    } else {
      let target = @bitrepo.rev_parse(rfs, git_dir, checkout_ref)
      match target {
        Some(_) =>
          ignore(
            run_checkout_with_sensitive_hooks(
              wfs,
              rfs,
              root,
              checkout_ref,
              detach=true,
            ),
          )
        None => ()
      }
    }
  }
  let cleanup_files = [
    bisect_start_path, bisect_log_path, bisect_terms_path, bisect_expected_path,
    bisect_ancestors_path, bisect_names_path, bisect_run_path,
  ]
  for path in cleanup_files {
    wfs.remove_file(path) catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => ()
    }
  }
  let entries = (rfs : &@bitcore.RepoFileSystem).readdir(bisect_refs_dir) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => []
  }
  for entry in entries {
    wfs.remove_file(bisect_refs_dir + "/" + entry) catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => ()
    }
  }
  wfs.remove_file(bisect_refs_dir) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => ()
  }
  eprint_line("Bisect reset")
}

///|
async fn bisect_log(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Unit raise Error {
  let bisect_log_path = git_dir + "/BISECT_LOG"
  if not(rfs.is_file(bisect_log_path)) {
    @stdio.stderr.write("error: no bisect log found")
    @sys.exit(1)
  }
  let content = decode_bytes(rfs.read_file(bisect_log_path))
  print_line(content)
}

///|
fn bisect_first_line_of_commit(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  cid : @bitcore.ObjectId,
) -> String {
  let obj = db.get(rfs, cid) catch { _ => None }
  match obj {
    Some(o) => {
      let msg = extract_commit_message(o.data)
      match msg.find("\n") {
        Some(idx) => String::unsafe_substring(msg, start=0, end=idx)
        None => msg
      }
    }
    None => ""
  }
}

///|
/// Shell-quote arguments for bisect run command string.
fn bisect_shell_quote_args(args : Array[String]) -> String {
  let parts : Array[String] = []
  for arg in args {
    if arg.contains(" ") ||
      arg.contains("'") ||
      arg.contains("\"") ||
      arg.contains("\\") {
      // Single-quote with escaping
      let escaped = arg.replace(old="'", new="\\'")
      parts.push("'" + escaped + "'")
    } else {
      parts.push(arg)
    }
  }
  parts.join(" ")
}

///|
/// Resolve work root from git_dir.
fn bisect_root_from_git_dir(git_dir : String) -> String {
  if git_dir.has_suffix("/.git") {
    String::unsafe_substring(git_dir, start=0, end=git_dir.length() - 5)
  } else {
    git_dir + "/.."
  }
}

/// Handle git describe command
