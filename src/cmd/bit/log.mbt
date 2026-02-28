///|

///|
async fn show_log_command_help() -> Unit {
  show_simple_command_help(
    "git log [<options>] [<revision-range>] [--] [<pathspec>...]",
    summary="Show commit logs.",
  )
}

///|
/// Find byte index of ".." in arg, returning -1 if not found or if "..." is present.
fn log_find_dotdot(arg : String) -> Int {
  // Convert to array of chars for indexed access
  let chars : Array[Char] = []
  for c in arg {
    chars.push(c)
  }
  let len = chars.length()
  let mut i = 0
  while i < len - 1 {
    if chars[i] == '.' && chars[i + 1] == '.' {
      if i + 2 < len && chars[i + 2] == '.' {
        return -1 // triple dot, not a range
      }
      return i
    }
    i += 1
  }
  -1
}

///|
fn is_short_count_flag(arg : String) -> Bool {
  if not(arg.has_prefix("-")) || arg.length() <= 1 {
    return false
  }
  let raw = String::unsafe_substring(arg, start=1, end=arg.length())
  for c in raw {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
fn log_need_real_git() -> Bool {
  false
}

///|
fn log_storage_runtime_delegate_args(
  args : Array[String],
) -> @runtime.StorageLogArgs? {
  if log_need_real_git() {
    return None
  }
  let parsed = storage_runtime_parse_command("log", args) catch {
    _ => return None
  }
  match parsed {
    @runtime.StorageCommand::Log(log_args) if log_args.oneline => Some(log_args)
    _ => None
  }
}

///|
fn log_should_use_storage_runtime(args : Array[String]) -> Bool {
  log_storage_runtime_delegate_args(args) is Some(_)
}

///|
fn format_log_oneline(
  fmt : String,
  id : @bitcore.ObjectId,
  subject : String,
) -> String {
  let short = (try! id.to_hex()[:7]).to_string()
  match fmt {
    "%h %s" => short + " " + subject
    "%h" => short
    "%H" => id.to_hex()
    "%H %s" => id.to_hex() + " " + subject
    "%s" => subject
    _ => short + " " + subject
  }
}

///|
fn resolve_log_reflog_refname(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  rev : String,
) -> String? {
  if rev == "HEAD" {
    return Some("HEAD")
  }
  if rev.has_prefix("refs/") {
    return Some(rev)
  }
  let heads_ref = "refs/heads/" + rev
  if (@bitlib.resolve_ref(rfs, git_dir, heads_ref) catch { _ => None })
    is Some(_) {
    return Some(heads_ref)
  }
  let tags_ref = "refs/tags/" + rev
  if (@bitlib.resolve_ref(rfs, git_dir, tags_ref) catch { _ => None })
    is Some(_) {
    return Some(tags_ref)
  }
  let remotes_ref = "refs/remotes/" + rev
  if (@bitlib.resolve_ref(rfs, git_dir, remotes_ref) catch { _ => None })
    is Some(_) {
    return Some(remotes_ref)
  }
  if (@bitlib.resolve_ref(rfs, git_dir, rev) catch { _ => None }) is Some(_) {
    return Some(rev)
  }
  None
}

///|
fn shorten_reflog_refname(refname : String) -> String {
  if refname.has_prefix("refs/heads/") {
    String::unsafe_substring(refname, start=11, end=refname.length())
  } else if refname.has_prefix("refs/tags/") {
    String::unsafe_substring(refname, start=10, end=refname.length())
  } else if refname.has_prefix("refs/remotes/") {
    String::unsafe_substring(refname, start=13, end=refname.length())
  } else {
    refname
  }
}

///|
fn format_reflog_entry(fmt : String?, gd : String, message : String) -> String {
  match fmt {
    Some("%gd") => gd
    Some("%gs") => message
    Some("%gd %gs") => gd + " " + message
    Some(_) => gd + " " + message
    None => gd + " " + message
  }
}

///|
fn get_head_commit_message(
  fs : &@bitcore.RepoFileSystem,
  root : String,
) -> String? {
  let git_dir = resolve_git_dir(fs, root)
  let head = @bitlib.resolve_head_commit(fs, git_dir) catch { _ => return None }
  guard head is Some(commit_id) else { return None }
  let db = @bitlib.ObjectDb::load(fs, git_dir) catch { _ => return None }
  let obj = db.get(fs, commit_id) catch { _ => return None }
  guard obj is Some(o) else { return None }
  // Extract message from raw commit data (after blank line)
  let text = decode_bytes(o.data)
  let mut in_message = false
  let msg_lines : Array[String] = []
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if in_message {
      msg_lines.push(line)
      continue
    }
    if line.length() == 0 {
      in_message = true
    }
  }
  if msg_lines.length() > 0 {
    Some(msg_lines.join("\n"))
  } else {
    None
  }
}

///|
async fn handle_log(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(fs, root)
  if log_should_use_storage_runtime(args) {
    match log_storage_runtime_delegate_args(args) {
      Some(log_args) => {
        @runtime.run_storage_command(
          fs,
          rfs,
          root,
          @runtime.StorageCommand::Log(log_args),
        )
        return
      }
      None => ()
    }
  }
  let mut oneline = false
  let mut graph = false
  let mut all_refs = false
  let mut decorate = false
  let mut show_stat = false
  let mut show_patch = false
  let mut max_count = 10
  let mut since_ts = 0L
  let mut until_ts = 9223372036854775807L
  let mut no_walk = false
  let mut walk_reflogs = false
  let mut format : String? = None
  let revs : Array[String] = []
  let range_excludes : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--oneline" => oneline = true
      "--graph" => graph = true
      "--all" => all_refs = true
      "--no-walk" => no_walk = true
      "-g" | "--walk-reflogs" => walk_reflogs = true
      "--decorate" => decorate = true
      "--stat" => show_stat = true
      "-p" | "--patch" => show_patch = true
      "--format" if i + 1 < args.length() => {
        format = Some(args[i + 1])
        i += 1
      }
      "--pretty" if i + 1 < args.length() => {
        format = Some(args[i + 1])
        i += 1
      }
      "-n" if i + 1 < args.length() => {
        max_count = @strconv.parse_int(args[i + 1])
        i += 1
      }
      "--max-count" if i + 1 < args.length() => {
        max_count = @strconv.parse_int(args[i + 1])
        i += 1
      }
      "--since" if i + 1 < args.length() => {
        since_ts = @strconv.parse_int64(args[i + 1]) catch { _ => 0L }
        i += 1
      }
      "--until" if i + 1 < args.length() => {
        until_ts = @strconv.parse_int64(args[i + 1]) catch {
          _ => 9223372036854775807L
        }
        i += 1
      }
      _ if arg.has_prefix("--format=") => {
        let value = String::unsafe_substring(arg, start=9, end=arg.length())
        format = Some(value)
      }
      _ if arg.has_prefix("--pretty=") => {
        let value = String::unsafe_substring(arg, start=9, end=arg.length())
        format = Some(value)
      }
      _ if arg.has_prefix("-n") && arg.length() > 2 => {
        let num_str = (try! arg[2:]).to_string()
        max_count = @strconv.parse_int(num_str)
      }
      _ if is_short_count_flag(arg) => {
        let num_str = String::unsafe_substring(arg, start=1, end=arg.length())
        max_count = @strconv.parse_int(num_str)
      }
      _ if arg.has_prefix("--max-count=") => {
        let num_str = (try! arg[12:]).to_string()
        max_count = @strconv.parse_int(num_str)
      }
      _ if arg.has_prefix("--since=") => {
        let val = (try! arg[8:]).to_string()
        since_ts = @strconv.parse_int64(val) catch { _ => 0L }
      }
      _ if arg.has_prefix("--until=") => {
        let val = (try! arg[8:]).to_string()
        until_ts = @strconv.parse_int64(val) catch { _ => 9223372036854775807L }
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("log", arg)
      _ => {
        // Detect A..B range (but not A...B)
        let dot_idx = log_find_dotdot(arg)
        if dot_idx >= 0 {
          let left = String::unsafe_substring(arg, start=0, end=dot_idx)
          let right = String::unsafe_substring(
            arg,
            start=dot_idx + 2,
            end=arg.length(),
          )
          if left.length() > 0 {
            range_excludes.push(left)
          }
          revs.push(if right.length() > 0 { right } else { "HEAD" })
        } else {
          revs.push(arg)
        }
      }
    }
    i += 1
  }
  if walk_reflogs {
    let targets : Array[String] = if revs.length() > 0 {
      revs
    } else {
      ["HEAD"]
    }
    let mut emitted = 0
    for target in targets {
      if emitted >= max_count {
        break
      }
      let refname = resolve_log_reflog_refname(rfs, git_dir, target)
      guard refname is Some(actual_refname) else {
        raise @bitcore.GitError::InvalidObject("Unknown revision: " + target)
      }
      let display_ref = if target.has_prefix("refs/") {
        shorten_reflog_refname(actual_refname)
      } else {
        target
      }
      let entries = @bitrepo.read_reflog(rfs, git_dir, actual_refname)
      let mut idx = 0
      let mut entry_i = entries.length()
      while entry_i > 0 && emitted < max_count {
        entry_i -= 1
        let entry = entries[entry_i]
        let gd = display_ref + "@{" + idx.to_string() + "}"
        print_line(format_reflog_entry(format, gd, entry.message))
        emitted += 1
        idx += 1
      }
    }
    return
  }
  if format is Some(fmt) {
    let db = @bitlib.ObjectDb::load(rfs, git_dir)
    let targets : Array[(String, @bitcore.ObjectId)] = []
    if all_refs || no_walk {
      let refs = @bitlib.list_refs_with_ids(rfs, git_dir, None)
      for name, id in refs {
        targets.push((name, id))
      }
      targets.sort_by((a, b) => a.0.compare(b.0))
    }
    for rev in revs {
      let resolved = @bitrepo.rev_parse(rfs, git_dir, rev)
      guard resolved is Some(id) else {
        raise @bitcore.GitError::InvalidObject("Unknown revision: " + rev)
      }
      targets.push((rev, id))
    }
    if targets.length() == 0 {
      let head = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
      guard head is Some(id) else { return }
      targets.push(("HEAD", id))
    }
    let seen : Map[String, Bool] = {}
    let mut emitted = 0
    for target in targets {
      if emitted >= max_count {
        break
      }
      let id = target.1
      let hex = id.to_hex()
      if seen.contains(hex) {
        continue
      }
      seen[hex] = true
      let subject = get_commit_subject(db, rfs, id)
      print_line(format_log_oneline(fmt, id, subject))
      emitted += 1
    }
    return
  }
  // Show subdir-clone info if applicable (only in full format)
  if not(oneline) {
    match get_subdir_info(fs, git_dir) {
      Some((remote, path, base)) => {
        print_line("# subdir-clone: \{path} from \{remote}")
        print_line("# base: \{base[:7].to_string()}")
        print_line("")
      }
      None => ()
    }
  }
  // Determine whether we need the new walk path
  let need_walk = all_refs ||
    decorate ||
    revs.length() > 0 ||
    range_excludes.length() > 0
  if graph {
    log_with_graph(
      rfs, git_dir, max_count, oneline, all_refs, decorate, since_ts, until_ts,
    )
  } else if need_walk {
    // Build start_ids from revs
    let start_ids : Array[@bitcore.ObjectId] = []
    for rev in revs {
      match @bitrepo.rev_parse(rfs, git_dir, rev) {
        Some(id) => start_ids.push(id)
        None =>
          raise @bitcore.GitError::InvalidObject("Unknown revision: " + rev)
      }
    }
    // Build exclude_ids from range_excludes
    let exclude_ids : Map[String, Bool] = {}
    for spec in range_excludes {
      match @bitrepo.rev_parse(rfs, git_dir, spec) {
        Some(id) => walk_commits_to_map(fs, git_dir, id, exclude_ids)
        None =>
          raise @bitcore.GitError::InvalidObject("Unknown revision: " + spec)
      }
    }
    // --all: add all refs as start points
    if all_refs {
      let all_ref_list = @bitrepo.show_ref(rfs, git_dir)
      for item in all_ref_list {
        start_ids.push(item.1)
      }
    }
    // Default to HEAD
    if start_ids.length() == 0 {
      match @bitrepo.rev_parse(rfs, git_dir, "HEAD") {
        Some(id) => start_ids.push(id)
        None => return
      }
    }
    // Build decoration map
    let ref_names : Map[String, Array[String]] = {}
    if decorate || all_refs {
      let all_ref_list = @bitrepo.show_ref(rfs, git_dir)
      for item in all_ref_list {
        let name = shorten_reflog_refname(item.0)
        let hex = item.1.to_hex()
        match ref_names.get(hex) {
          Some(arr) => arr.push(name)
          None => ref_names[hex] = [name]
        }
      }
      // Add HEAD -> branch decoration
      let head_path = git_dir + "/HEAD"
      if rfs.is_file(head_path) {
        let content = rfs.read_file(head_path) |> decode_bytes |> trim_string
        if content.has_prefix("ref: refs/heads/") {
          let branch = String::unsafe_substring(
            content,
            start=16,
            end=content.length(),
          )
          match @bitrepo.rev_parse(rfs, git_dir, "HEAD") {
            Some(head_id) => {
              let hex = head_id.to_hex()
              let deco = "HEAD -> " + branch
              match ref_names.get(hex) {
                Some(arr) => {
                  // Insert at front, remove bare branch name if present
                  let new_arr : Array[String] = [deco]
                  for n in arr {
                    if n != branch {
                      new_arr.push(n)
                    }
                  }
                  ref_names[hex] = new_arr
                }
                None => ref_names[hex] = [deco]
              }
            }
            None => ()
          }
        }
      }
    }
    // BFS walk
    let entries = log_walk_commits(
      rfs,
      git_dir,
      start_ids,
      exclude_ids,
      max_count,
      since_ts,
      until_ts,
      show_stat || show_patch,
    )
    if oneline {
      for entry in entries {
        let short = (try! entry.id.to_hex()[:7]).to_string()
        let deco = format_decoration(ref_names, entry.id.to_hex())
        print_line(short + deco + " " + entry.message)
      }
    } else {
      for entry in entries {
        let deco = format_decoration(ref_names, entry.id.to_hex())
        print_line("commit " + entry.id.to_hex() + deco)
        print_line("Author: " + entry.author)
        print_line("")
        print_line("    " + entry.message)
        print_line("")
        if show_stat || show_patch {
          let diff_files = @bitdiff.diff_trees(
            rfs,
            git_dir,
            entry.parent_tree,
            entry.tree,
          )
          if show_stat {
            let stat_lines = @bitdiff.diff_stat(diff_files)
            for line in stat_lines {
              print_line(line)
            }
            print_line("")
          }
          if show_patch {
            let patch_lines = @bitdiff.diff_text(diff_files)
            for line in patch_lines {
              print_line(line)
            }
            print_line("")
          }
        }
      }
    }
  } else if oneline {
    // Fast path: simple HEAD walk
    let lines = @bitlib.log_head_oneline(
      fs,
      git_dir,
      max_count~,
      since=since_ts,
      until=until_ts,
    )
    for line in lines {
      print_line(line)
    }
  } else {
    // Fast path: simple HEAD walk (full format)
    let entries = @bitlib.log_head(
      fs,
      git_dir,
      max_count~,
      since=since_ts,
      until=until_ts,
      include_parent_tree=show_stat || show_patch,
    )
    for entry in entries {
      print_line("commit " + entry.id.to_hex())
      print_line("Author: " + entry.author)
      print_line("")
      print_line("    " + entry.message)
      print_line("")
      if show_stat || show_patch {
        let diff_files = @bitdiff.diff_trees(
          rfs,
          git_dir,
          entry.parent_tree,
          entry.tree,
        )
        if show_stat {
          let stat_lines = @bitdiff.diff_stat(diff_files)
          for line in stat_lines {
            print_line(line)
          }
          print_line("")
        }
        if show_patch {
          let patch_lines = @bitdiff.diff_text(diff_files)
          for line in patch_lines {
            print_line(line)
          }
          print_line("")
        }
      }
    }
  }
}

///|
struct LogWalkEntry {
  id : @bitcore.ObjectId
  message : String
  author : String
  timestamp : Int64
  tree : @bitcore.ObjectId
  parent_tree : @bitcore.ObjectId?
}

///|
fn format_decoration(
  ref_names : Map[String, Array[String]],
  hex : String,
) -> String {
  match ref_names.get(hex) {
    Some(names) if names.length() > 0 => " (" + names.join(", ") + ")"
    _ => ""
  }
}

///|
/// BFS walk from start_ids, excluding exclude_ids, with timestamp filtering.
/// Returns entries sorted by timestamp descending.
fn log_walk_commits(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  start_ids : Array[@bitcore.ObjectId],
  exclude_ids : Map[String, Bool],
  max_count : Int,
  since_ts : Int64,
  until_ts : Int64,
  include_parent_tree : Bool,
) -> Array[LogWalkEntry] raise Error {
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let result : Array[LogWalkEntry] = []
  let visited : Map[String, Bool] = {}
  // Priority queue: (timestamp, id) sorted desc by timestamp
  // Use insertion-sorted array
  let queue : Array[(Int64, @bitcore.ObjectId)] = []
  for id in start_ids {
    let hex = id.to_hex()
    if not(visited.contains(hex)) && not(exclude_ids.contains(hex)) {
      // Get timestamp for sorting
      let ts = log_get_commit_timestamp(db, rfs, id)
      log_queue_insert(queue, (ts, id))
      visited[hex] = true
    }
  }
  let mut emitted = 0
  while queue.length() > 0 && emitted < max_count {
    let (_, id) = queue[0]
    // Remove front
    let new_q : Array[(Int64, @bitcore.ObjectId)] = []
    for i in 1..<queue.length() {
      new_q.push(queue[i])
    }
    while queue.length() > 0 {
      ignore(queue.unsafe_pop())
    }
    for item in new_q {
      queue.push(item)
    }
    let hex = id.to_hex()
    if exclude_ids.contains(hex) {
      continue
    }
    // Get commit data
    let obj = db.get(rfs, id)
    guard obj is Some(o) else { continue }
    let info = @bitcore.parse_commit(o.data)
    // Add parents to queue
    for parent in info.parents {
      let phex = parent.to_hex()
      if not(visited.contains(phex)) && not(exclude_ids.contains(phex)) {
        visited[phex] = true
        let pts = log_get_commit_timestamp(db, rfs, parent)
        log_queue_insert(queue, (pts, parent))
      }
    }
    // Build LogWalkEntry
    let entry = log_parse_entry_from_obj(id, o.data, info.tree)
    // Apply since/until filters using parsed timestamp
    if entry.timestamp > until_ts {
      continue // newer than until, skip but keep walking
    }
    if entry.timestamp < since_ts {
      continue // older than since, skip but keep walking for branches
    }
    let parent_tree : @bitcore.ObjectId? = if include_parent_tree &&
      info.parents.length() > 0 {
      match db.get(rfs, info.parents[0]) {
        Some(po) => {
          let pi = @bitcore.parse_commit(po.data)
          Some(pi.tree)
        }
        None => None
      }
    } else {
      None
    }
    result.push({ ..entry, parent_tree, })
    emitted += 1
  }
  result
}

///|
/// Insert into timestamp-descending sorted array.
fn log_queue_insert(
  queue : Array[(Int64, @bitcore.ObjectId)],
  item : (Int64, @bitcore.ObjectId),
) -> Unit {
  let ts = item.0
  let mut pos = queue.length()
  // Find insertion point (descending order)
  for i in 0..<queue.length() {
    if ts > queue[i].0 {
      pos = i
      break
    }
  }
  queue.push(item) // push to end first
  // Shift elements right
  let mut j = queue.length() - 1
  while j > pos {
    queue[j] = queue[j - 1]
    j -= 1
  }
  queue[pos] = item
}

///|
fn log_get_commit_timestamp(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> Int64 {
  let obj = db.get(rfs, id) catch { _ => return 0L }
  guard obj is Some(o) else { return 0L }
  log_extract_author_timestamp(o.data)
}

///|
fn log_extract_author_timestamp(data : Bytes) -> Int64 {
  let text = decode_bytes(data)
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("author ") {
      let rest = String::unsafe_substring(line, start=7, end=line.length())
      let (_, ts) = log_parse_author_parts(rest)
      return ts
    }
  }
  0L
}

///|
/// Parse author line "Name <email> TIMESTAMP +TZ" into (name, timestamp).
fn log_parse_author_parts(rest : String) -> (String, Int64) {
  let chars : Array[Char] = []
  for c in rest {
    chars.push(c)
  }
  let len = chars.length()
  let mut last_sp = -1
  let mut second_last_sp = -1
  for i in 0..<len {
    if chars[i] == ' ' {
      second_last_sp = last_sp
      last_sp = i
    }
  }
  if second_last_sp >= 0 {
    let name = String::unsafe_substring(rest, start=0, end=second_last_sp)
    let ts_str = String::unsafe_substring(
      rest,
      start=second_last_sp + 1,
      end=last_sp,
    )
    let ts = @strconv.parse_int64(ts_str) catch { _ => 0L }
    (name, ts)
  } else {
    (rest, 0L)
  }
}

///|
fn log_parse_entry_from_obj(
  id : @bitcore.ObjectId,
  data : Bytes,
  tree : @bitcore.ObjectId,
) -> LogWalkEntry {
  let text = decode_bytes(data)
  let mut author = ""
  let mut timestamp = 0L
  let mut in_message = false
  let message_lines : Array[String] = []
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if in_message {
      message_lines.push(line)
      continue
    }
    if line.length() == 0 {
      in_message = true
      continue
    }
    if line.has_prefix("author ") {
      let rest = String::unsafe_substring(line, start=7, end=line.length())
      let (name, ts) = log_parse_author_parts(rest)
      author = name
      timestamp = ts
    }
  }
  let message = if message_lines.length() > 0 { message_lines[0] } else { "" }
  { id, message, author, timestamp, tree, parent_tree: None }
}

///|
async fn log_with_graph(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  max_count : Int,
  oneline : Bool,
  all_refs : Bool,
  decorate : Bool,
  since_ts : Int64,
  until_ts : Int64,
) -> Unit raise Error {
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  // Collect starting points
  let starts : Array[@bitcore.ObjectId] = []
  let ref_names : Map[String, Array[String]] = {} // commit hex -> ref names
  if all_refs {
    // Add all branches
    let heads_dir = git_dir + "/refs/heads"
    if rfs.is_dir(heads_dir) {
      let branches = rfs.readdir(heads_dir) catch {
        err if @async.is_cancellation_error(err) => raise err
        _ => []
      }
      for branch in branches {
        let ref_path = heads_dir + "/" + branch
        if rfs.is_file(ref_path) {
          let hex = rfs.read_file(ref_path) |> decode_bytes |> trim_string
          let id = @bitcore.ObjectId::from_hex(hex)
          starts.push(id)
          match ref_names.get(hex) {
            Some(arr) => arr.push(branch)
            None => ref_names[hex] = [branch]
          }
        }
      }
    }
  } else {
    let head = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
    match head {
      Some(h) => {
        starts.push(h)
        if decorate {
          // Get current branch name
          let head_path = git_dir + "/HEAD"
          if rfs.is_file(head_path) {
            let content = rfs.read_file(head_path)
              |> decode_bytes
              |> trim_string
            if content.has_prefix("ref: refs/heads/") {
              let branch = String::unsafe_substring(
                content,
                start=16,
                end=content.length(),
              )
              ref_names[h.to_hex()] = ["HEAD -> " + branch]
            } else {
              ref_names[h.to_hex()] = ["HEAD"]
            }
          }
        }
      }
      None => return
    }
  }
  // BFS to collect commits with graph structure
  let commits : Array[(@bitcore.ObjectId, Array[@bitcore.ObjectId], Int)] = [] // (id, parents, column)
  let visited : Map[String, Bool] = {}
  let active_columns : Array[@bitcore.ObjectId?] = [] // Track which columns are active
  let queue : Array[(@bitcore.ObjectId, Int)] = [] // (commit, column)
  // Initialize queue
  for i, start in starts {
    queue.push((start, i))
    while active_columns.length() <= i {
      active_columns.push(None)
    }
    active_columns[i] = Some(start)
  }
  let mut count = 0
  while queue.length() > 0 && count < max_count {
    // Sort queue by column to process in order
    queue.sort_by((a, b) => a.1.compare(b.1))
    let (current, col) = queue[0]
    // Remove first element
    let new_queue : Array[(@bitcore.ObjectId, Int)] = []
    for i in 1..<queue.length() {
      new_queue.push(queue[i])
    }
    while queue.length() > 0 {
      ignore(queue.pop())
    }
    for item in new_queue {
      queue.push(item)
    }
    let hex = current.to_hex()
    if visited.get(hex).unwrap_or(false) {
      continue
    }
    visited[hex] = true
    let obj = db.get(rfs, current)
    match obj {
      Some(o) => {
        let info = @bitcore.parse_commit(o.data)
        // Add parents to queue regardless of timestamp filter
        for i, parent in info.parents {
          let parent_col = if i == 0 {
            col
          } else {
            find_free_column(active_columns, col)
          }
          queue.push((parent, parent_col))
          if parent_col < active_columns.length() {
            active_columns[parent_col] = Some(parent)
          }
        }
        // Clear this column if no more commits
        if info.parents.length() == 0 && col < active_columns.length() {
          active_columns[col] = None
        }
        // Apply since/until filters
        let ts = log_extract_author_timestamp(o.data)
        if ts <= until_ts && ts >= since_ts {
          commits.push((current, info.parents, col))
          count += 1
        }
      }
      None => ()
    }
  }
  // Output with graph
  let max_col = get_max_column(commits)
  for entry in commits {
    let (commit_id, parents, col) = entry
    let hex = commit_id.to_hex()
    let short_hex = String::unsafe_substring(hex, start=0, end=7)
    // Build graph line
    let graph_line = build_graph_line(col, max_col, parents.length() > 1)
    // Get decorations
    let decorations = match ref_names.get(hex) {
      Some(names) => " (" + names.join(", ") + ")"
      None => ""
    }
    if oneline {
      print_line(
        graph_line +
        "* " +
        short_hex +
        decorations +
        " " +
        get_commit_subject(db, rfs, commit_id),
      )
    } else {
      print_line(graph_line + "* commit " + hex + decorations)
      let obj = db.get(rfs, commit_id)
      match obj {
        Some(o) => {
          let author_line = extract_author_line_from_bytes(o.data)
          print_line(graph_line + "| Author: " + author_line)
          print_line(graph_line + "|")
          let msg = get_commit_subject(db, rfs, commit_id)
          print_line(graph_line + "|     " + msg)
          print_line(graph_line + "|")
        }
        None => ()
      }
    }
  }
}

///|
fn find_free_column(columns : Array[@bitcore.ObjectId?], start : Int) -> Int {
  for i in (start + 1)..<columns.length() {
    if columns[i] is None {
      return i
    }
  }
  columns.length()
}

///|
fn get_max_column(
  commits : Array[(@bitcore.ObjectId, Array[@bitcore.ObjectId], Int)],
) -> Int {
  let mut max = 0
  for entry in commits {
    if entry.2 > max {
      max = entry.2
    }
  }
  max
}

///|
fn build_graph_line(col : Int, max_col : Int, is_merge : Bool) -> String {
  let sb = StringBuilder::new()
  for _ in 0..<col {
    sb.write_string("| ")
  }
  if is_merge {
    sb.write_string("|\\ ")
  }
  for _ in (col + 1)..<(max_col + 1) {
    sb.write_string("| ")
  }
  sb.to_string()
}

///|
fn get_commit_subject(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commit_id : @bitcore.ObjectId,
) -> String raise Error {
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else { return "" }
  let msg = extract_commit_message(o.data)
  get_first_line(msg)
}

///|
fn extract_author_line_from_bytes(data : Bytes) -> String {
  let text = decode_bytes(data)
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("author ") {
      return String::unsafe_substring(line, start=7, end=line.length())
    }
    if line.length() == 0 {
      break
    }
  }
  "unknown"
}
