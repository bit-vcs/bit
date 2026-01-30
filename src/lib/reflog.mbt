///| Git reflog implementation

///|
pub struct ReflogEntry {
  old_id : @git.ObjectId
  new_id : @git.ObjectId
  author : String
  email : String
  timestamp : Int64
  timezone : String
  message : String
}

///|
/// Check if a reflog exists for the given ref.
pub fn reflog_exists(
  fs : &@git.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Bool {
  let reflog_path = get_reflog_path(git_dir, refname)
  fs.is_file(reflog_path)
}

///|
/// Get the reflog file path for a given ref.
pub fn get_reflog_path(git_dir : String, refname : String) -> String {
  if refname == "HEAD" {
    git_dir + "/logs/HEAD"
  } else {
    git_dir + "/logs/" + refname
  }
}

///|
/// Read reflog entries for a given ref.
pub fn read_reflog(
  fs : &@git.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Array[ReflogEntry] raise @git.GitError {
  let reflog_path = get_reflog_path(git_dir, refname)
  if not(fs.is_file(reflog_path)) {
    return []
  }
  let content = @utf8.decode_lossy(fs.read_file(reflog_path)[:])
  let entries : Array[ReflogEntry] = []
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    match parse_reflog_line(line) {
      Some(entry) => entries.push(entry)
      None => continue
    }
  }
  entries
}

///|
/// Parse a single reflog line.
fn parse_reflog_line(line : String) -> ReflogEntry? {
  // Format: <old-sha> <new-sha> <name> <<email>> <timestamp> <tz>\t<message>
  let tab_idx = line.find("\t")
  guard tab_idx is Some(idx) else { return None }
  let prefix = String::unsafe_substring(line, start=0, end=idx)
  let message = String::unsafe_substring(line, start=idx + 1, end=line.length())
  // Parse prefix: old_sha new_sha author_name <author_email> timestamp tz
  let parts : Array[String] = []
  for p in prefix.split(" ") {
    parts.push(p.to_string())
  }
  if parts.length() < 5 {
    return None
  }
  let old_id = @git.ObjectId::from_hex(parts[0]) catch { _ => return None }
  let new_id = @git.ObjectId::from_hex(parts[1]) catch { _ => return None }
  // Author name can have spaces, email is in angle brackets
  // Find the email (surrounded by < >)
  let mut author = ""
  let mut email = ""
  let mut timestamp : Int64 = 0L
  let mut timezone = "+0000"
  let mut i = 2
  // Collect author name until we hit <
  while i < parts.length() {
    if parts[i].has_prefix("<") {
      // Found email start
      let email_part = parts[i]
      email = String::unsafe_substring(
        email_part,
        start=1,
        end=email_part.length() - 1,
      )
      i += 1
      break
    }
    if author.length() > 0 {
      author = author + " "
    }
    author = author + parts[i]
    i += 1
  }
  // Next should be timestamp and timezone
  if i < parts.length() {
    timestamp = @strconv.parse_int64(parts[i]) catch { _ => 0L }
    i += 1
  }
  if i < parts.length() {
    timezone = parts[i]
  }
  Some({ old_id, new_id, author, email, timestamp, timezone, message })
}

///|
/// Append a reflog entry.
pub fn append_reflog(
  wfs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  refname : String,
  old_id : @git.ObjectId,
  new_id : @git.ObjectId,
  author : String,
  email : String,
  timestamp : Int64,
  timezone : String,
  message : String,
) -> Unit raise @git.GitError {
  let reflog_path = get_reflog_path(git_dir, refname)
  // Ensure parent directory exists
  let parent_dir = match reflog_path.rev_find("/") {
    None => ""
    Some(i) => String::unsafe_substring(reflog_path, start=0, end=i)
  }
  if parent_dir.length() > 0 && not(rfs.is_dir(parent_dir)) {
    wfs.mkdir_p(parent_dir)
  }
  // Format: <old-sha> <new-sha> <name> <<email>> <timestamp> <tz>\t<message>\n
  let entry = "\{old_id.to_hex()} \{new_id.to_hex()} \{author} <\{email}> \{timestamp} \{timezone}\t\{message}\n"
  // Append to file
  if rfs.is_file(reflog_path) {
    let existing = @utf8.decode_lossy(rfs.read_file(reflog_path)[:])
    wfs.write_string(reflog_path, existing.to_string() + entry)
  } else {
    wfs.write_string(reflog_path, entry)
  }
}

///|
/// Create an empty reflog file for a ref.
pub fn create_reflog(
  wfs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Unit raise @git.GitError {
  let reflog_path = get_reflog_path(git_dir, refname)
  let parent_dir = match reflog_path.rev_find("/") {
    None => ""
    Some(i) => String::unsafe_substring(reflog_path, start=0, end=i)
  }
  if parent_dir.length() > 0 && not(rfs.is_dir(parent_dir)) {
    wfs.mkdir_p(parent_dir)
  }
  if not(rfs.is_file(reflog_path)) {
    wfs.write_string(reflog_path, "")
  }
}

///|
/// Delete a reflog file.
pub fn delete_reflog(
  wfs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Unit raise @git.GitError {
  let reflog_path = get_reflog_path(git_dir, refname)
  if rfs.is_file(reflog_path) {
    wfs.remove_file(reflog_path)
  }
}

///|
fn trim_whitespace(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = s.unsafe_get(start)
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start += 1
    } else {
      break
    }
  }
  while end > start {
    let c = s.unsafe_get(end - 1)
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end -= 1
    } else {
      break
    }
  }
  String::unsafe_substring(s, start~, end~)
}

///|
/// Check if reflogs should be created for a ref based on config.
/// Returns: (should_log, always_log)
/// - should_log: true if this ref should have reflogs
/// - always_log: true if core.logAllRefUpdates=always
pub fn should_log_ref(
  fs : &@git.RepoFileSystem,
  git_dir : String,
  refname : String,
  is_bare : Bool,
) -> (Bool, Bool) raise @git.GitError {
  // Read core.logAllRefUpdates from config
  let config_path = git_dir + "/config"
  let mut log_all_ref_updates : String? = None
  if fs.is_file(config_path) {
    let content = @utf8.decode_lossy(fs.read_file(config_path)[:])
    let mut in_core = false
    for line_view in content.split("\n") {
      let line = trim_whitespace(line_view.to_string())
      if line.has_prefix("[core]") {
        in_core = true
        continue
      }
      if line.has_prefix("[") {
        in_core = false
        continue
      }
      if in_core {
        if line.has_prefix("logAllRefUpdates") ||
          line.has_prefix("logallrefupdates") {
          let eq_idx = line.find("=")
          match eq_idx {
            Some(i) =>
              log_all_ref_updates = Some(
                trim_whitespace(
                  String::unsafe_substring(line, start=i + 1, end=line.length()),
                ),
              )
            None => ()
          }
        }
      }
    }
  }
  match log_all_ref_updates {
    Some("always") => (true, true)
    Some("true") | Some("1") =>
      // Log refs/heads/* and refs/remotes/* only, not arbitrary refs
      if is_bare {
        (false, false) // bare repos don't log by default even with true
      } else {
        (
          refname.has_prefix("refs/heads/") ||
          refname.has_prefix("refs/remotes/") ||
          refname == "HEAD",
          false,
        )
      }
    _ => (false, false)
  }
}
