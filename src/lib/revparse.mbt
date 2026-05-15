///| Ref resolution helpers (rev-parse/show-ref)

///|
pub fn rev_parse(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> @bit.ObjectId? raise @bit.GitError {
  if spec.has_prefix(":/") && spec.length() > 2 {
    let needle = substring_revparse(spec, 2, spec.length())
    return resolve_commit_message_search_all_refs(fs, git_dir, needle)
  }
  match parse_commit_message_search_spec(spec) {
    Some((base_spec, needle)) =>
      return resolve_commit_message_search(fs, git_dir, base_spec, needle)
    None => ()
  }
  match spec.find(":") {
    Some(idx) =>
      if idx > 0 && idx + 1 <= spec.length() {
        let rev_part = substring_revparse(spec, 0, idx)
        let path_part = substring_revparse(spec, idx + 1, spec.length())
        let base = rev_parse(fs, git_dir, rev_part)
        guard base is Some(base_id) else { return None }
        return resolve_path_in_commit(fs, git_dir, base_id, path_part)
      }
    None => ()
  }
  match parse_peel_commit_spec(spec) {
    Some(base_spec) => {
      let base = rev_parse(fs, git_dir, base_spec)
      guard base is Some(base_id) else { return None }
      return peel_object_to_commit(fs, git_dir, base_id)
    }
    None => ()
  }
  match parse_peel_tree_spec(spec) {
    Some(base_spec) => {
      let base = rev_parse(fs, git_dir, base_spec)
      guard base is Some(base_id) else { return None }
      return peel_object_to_tree(fs, git_dir, base_id)
    }
    None => ()
  }
  match parse_peel_tag_spec(spec) {
    Some(base_spec) => {
      let base = rev_parse(fs, git_dir, base_spec)
      guard base is Some(base_id) else { return None }
      return peel_object_to_tag(fs, git_dir, base_id)
    }
    None => ()
  }
  // Parse suffix (^, ^^, ~n, ^n)
  let (base_spec, suffix) = parse_rev_suffix(spec)
  // Resolve base reference
  let base_id = match resolve_base_ref(fs, git_dir, base_spec) {
    Some(id) => id
    None => return None
  }
  match suffix {
    None => Some(base_id)
    Some(parsed_suffix) => apply_rev_suffix(fs, git_dir, base_id, parsed_suffix)
  }
}

///|
fn parse_commit_message_search_spec(spec : String) -> (String, String)? {
  let marker = "^{/"
  match spec.find(marker) {
    Some(idx) if idx > 0 &&
      spec.has_suffix("}") &&
      idx + marker.length() <= spec.length() - 1 =>
      Some(
        (
          substring_revparse(spec, 0, idx),
          substring_revparse(spec, idx + marker.length(), spec.length() - 1),
        ),
      )
    _ => None
  }
}

///|
fn resolve_commit_message_search(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  base_spec : String,
  needle : String,
) -> @bit.ObjectId? raise @bit.GitError {
  if needle.length() == 0 {
    return None
  }
  let base = rev_parse(fs, git_dir, base_spec)
  guard base is Some(base_id) else { return None }
  find_reachable_commit_by_message_from_many(fs, git_dir, [base_id], needle)
}

///|
fn resolve_commit_message_search_all_refs(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  needle : String,
) -> @bit.ObjectId? raise @bit.GitError {
  if needle.length() == 0 {
    return None
  }
  let starts : Array[@bit.ObjectId] = []
  let seen_start : Map[String, Bool] = {}
  let refs = show_ref(fs, git_dir)
  for item in refs {
    let (_, id) = item
    let hex = id.to_hex()
    if !seen_start.contains(hex) {
      seen_start[hex] = true
      starts.push(id)
    }
  }
  match resolve_head_commit(fs, git_dir) {
    Some(id) => {
      let hex = id.to_hex()
      if !seen_start.contains(hex) {
        seen_start[hex] = true
        starts.push(id)
      }
    }
    None => ()
  }
  if starts.length() == 0 {
    return None
  }
  find_reachable_commit_by_message_from_many(fs, git_dir, starts, needle)
}

///|
fn find_reachable_commit_by_message_from_many(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  starts : Array[@bit.ObjectId],
  needle : String,
) -> @bit.ObjectId? raise @bit.GitError {
  let db = ObjectDb::load(fs, git_dir)
  let queue : Array[@bit.ObjectId] = []
  for start in starts {
    queue.push(start)
  }
  let seen : Map[String, Bool] = {}
  let mut best_id : @bit.ObjectId? = None
  let mut best_time = -1L
  while queue.length() > 0 {
    let current = queue.unsafe_pop()
    let hex = current.to_hex()
    if seen.contains(hex) {
      continue
    }
    seen[hex] = true
    match db.get(fs, current) {
      Some(obj) =>
        if obj.obj_type == @bit.ObjectType::Commit {
          if commit_message_contains(obj.data, needle) {
            let ts = parse_commit_committer_timestamp(obj.data)
            if best_id is None || ts > best_time {
              best_id = Some(current)
              best_time = ts
            }
          }
          let info = @bit.parse_commit(obj.data)
          for parent in info.parents {
            if !seen.contains(parent.to_hex()) {
              queue.push(parent)
            }
          }
        }
      None => ()
    }
  }
  best_id
}

///|
fn commit_message_contains(data : Bytes, needle : String) -> Bool {
  let text = @utf8.decode_lossy(data[:])
  match text.find("\n\n") {
    Some(idx) =>
      substring_revparse(text, idx + 2, text.length()).find(needle) is Some(_)
    None => false
  }
}

///|
fn parse_commit_committer_timestamp(data : Bytes) -> Int64 {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("committer ") {
      let rest = substring_revparse(line, 10, line.length())
      return parse_identity_timestamp(rest)
    }
  }
  0L
}

///|
fn parse_identity_timestamp(identity : String) -> Int64 {
  let last_space = identity.rev_find(" ")
  guard last_space is Some(tz_idx) else { return 0L }
  let before_tz = substring_revparse(identity, 0, tz_idx)
  let second_last = before_tz.rev_find(" ")
  guard second_last is Some(ts_idx) else { return 0L }
  let ts = substring_revparse(before_tz, ts_idx + 1, before_tz.length())
  parse_revparse_int64(ts)
}

///|
fn parse_revparse_int64(s : String) -> Int64 {
  let mut value = 0L
  for c in s {
    if c < '0' || c > '9' {
      return value
    }
    let digit = c.to_int() - '0'.to_int()
    value = value * 10L + digit.to_int64()
  }
  value
}

///|
fn parse_peel_commit_spec(spec : String) -> String? {
  let suffix = "^{commit}"
  if spec.has_suffix(suffix) && spec.length() > suffix.length() {
    return Some(substring_revparse(spec, 0, spec.length() - suffix.length()))
  }
  None
}

///|
fn parse_peel_tree_spec(spec : String) -> String? {
  let suffix = "^{tree}"
  if spec.has_suffix(suffix) && spec.length() > suffix.length() {
    return Some(substring_revparse(spec, 0, spec.length() - suffix.length()))
  }
  None
}

///|
fn peel_object_to_commit(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  id : @bit.ObjectId,
) -> @bit.ObjectId? raise @bit.GitError {
  let db = ObjectDb::load(fs, git_dir)
  let mut current = id
  for _ in 0..<8 {
    let obj = db.get(fs, current)
    guard obj is Some(o) else { return None }
    match o.obj_type {
      @bit.ObjectType::Commit => return Some(current)
      @bit.ObjectType::Tag =>
        match parse_tag_object_target(o.data) {
          Some(next) => current = next
          None => return None
        }
      _ => return None
    }
  }
  None
}

///|
fn peel_object_to_tree(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  id : @bit.ObjectId,
) -> @bit.ObjectId? raise @bit.GitError {
  let db = ObjectDb::load(fs, git_dir)
  let mut current = id
  for _ in 0..<8 {
    let obj = db.get(fs, current)
    guard obj is Some(o) else { return None }
    match o.obj_type {
      @bit.ObjectType::Tree => return Some(current)
      @bit.ObjectType::Commit => return Some(@bit.parse_commit(o.data).tree)
      @bit.ObjectType::Tag =>
        match parse_tag_object_target(o.data) {
          Some(next) => current = next
          None => return None
        }
      _ => return None
    }
  }
  None
}

///|
fn parse_peel_tag_spec(spec : String) -> String? {
  let suffix = "^{tag}"
  if spec.has_suffix(suffix) && spec.length() > suffix.length() {
    return Some(substring_revparse(spec, 0, spec.length() - suffix.length()))
  }
  None
}

///|
fn peel_object_to_tag(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  id : @bit.ObjectId,
) -> @bit.ObjectId? raise @bit.GitError {
  let db = ObjectDb::load(fs, git_dir)
  let obj = db.get(fs, id)
  guard obj is Some(o) else { return None }
  if o.obj_type == @bit.ObjectType::Tag {
    return Some(id)
  }
  None
}

///|
fn parse_tag_object_target(data : Bytes) -> @bit.ObjectId? {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("object ") {
      let hex = substring_revparse(line, 7, line.length())
      let id = @bit.ObjectId::from_hex(hex) catch { _ => return None }
      return Some(id)
    }
  }
  None
}

///|
/// Parse revision suffix like ^, ^^, ~n
fn parse_rev_suffix(spec : String) -> (String, String?) {
  let chars = spec.to_array()
  let len = chars.length()
  if len == 0 {
    return (spec, None)
  }
  // Find where suffix starts - must start with ^ or ~
  let mut suffix_start = -1
  for i = 0; i < len; i = i + 1 {
    let c = chars[i]
    if c == '^' || c == '~' {
      suffix_start = i
      break
    }
  }
  if suffix_start < 0 {
    return (spec, None)
  }
  // Validate suffix - only ^, ~, and digits after the first ^ or ~
  for i = suffix_start; i < len; i = i + 1 {
    let c = chars[i]
    if !(c == '^' || c == '~' || (c >= '0' && c <= '9')) {
      // Invalid suffix character - no suffix
      return (spec, None)
    }
  }
  let base = substring_revparse(spec, 0, suffix_start)
  let suffix = substring_revparse(spec, suffix_start, len)
  (base, Some(suffix))
}

///|
/// Apply revision suffix operators.
fn apply_rev_suffix(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  start : @bit.ObjectId,
  suffix : String,
) -> @bit.ObjectId? raise @bit.GitError {
  let db = ObjectDb::load(fs, git_dir)
  let chars = suffix.to_array()
  let mut current = start
  let mut i = 0
  while i < chars.length() {
    let op = chars[i]
    if op == '^' {
      i += 1
      let mut parent_index = 0
      let mut has_digits = false
      while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
        has_digits = true
        parent_index = parent_index * 10 + (chars[i].to_int() - '0'.to_int())
        i += 1
      }
      if has_digits {
        // `^0` peels to the commit itself.
        if parent_index == 0 {
          continue
        }
      } else {
        parent_index = 1
      }
      let next = commit_nth_parent(db, fs, current, parent_index)
      guard next is Some(parent_id) else { return None }
      current = parent_id
      continue
    }
    if op == '~' {
      i += 1
      let mut steps = 0
      let mut has_digits = false
      while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
        has_digits = true
        steps = steps * 10 + (chars[i].to_int() - '0'.to_int())
        i += 1
      }
      if !has_digits {
        steps = 1
      }
      for _ in 0..<steps {
        let next = commit_nth_parent(db, fs, current, 1)
        guard next is Some(parent_id) else { return None }
        current = parent_id
      }
      continue
    }
    return None
  }
  Some(current)
}

///|
fn commit_nth_parent(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  commit_id : @bit.ObjectId,
  nth_parent : Int,
) -> @bit.ObjectId? raise @bit.GitError {
  if nth_parent <= 0 {
    return Some(commit_id)
  }
  let obj = db.get(fs, commit_id)
  guard obj is Some(o) else { return None }
  if o.obj_type != @bit.ObjectType::Commit {
    return None
  }
  let info = @bit.parse_commit(o.data)
  if nth_parent > info.parents.length() {
    return None
  }
  Some(info.parents[nth_parent - 1])
}

///|
fn substring_revparse(s : String, start : Int, end : Int) -> String {
  let chars = s.to_array()
  let result = StringBuilder::new()
  for i = start; i < end && i < chars.length(); i = i + 1 {
    result.write_char(chars[i])
  }
  result.to_string()
}

///|
fn resolve_abbrev_ref_id(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> @bit.ObjectId? raise @bit.GitError {
  if spec.length() < 4 || spec.length() >= 40 || !@bithash.is_hex_string(spec) {
    return None
  }
  let needle = @bithash.lower_hex_string(spec)
  let refs = show_ref(fs, git_dir)
  let db = ObjectDb::load(fs, git_dir)
  let queue : Array[@bit.ObjectId] = []
  let seen : Map[String, Bool] = {}
  for item in refs {
    let (_, id) = item
    queue.push(id)
  }
  match resolve_head_commit(fs, git_dir) {
    Some(id) => queue.push(id)
    None => ()
  }
  let mut matched : @bit.ObjectId? = None
  while queue.length() > 0 {
    let id = match queue.pop() {
      Some(oid) => oid
      None => break
    }
    let hex = id.to_hex()
    if seen.contains(hex) {
      continue
    }
    seen[hex] = true
    if hex.has_prefix(needle) {
      match matched {
        None => matched = Some(id)
        Some(prev) => if prev != id { return None }
      }
    }
    match db.get(fs, id) {
      Some(obj) =>
        if obj.obj_type == @bit.ObjectType::Commit {
          let info = @bit.parse_commit(obj.data)
          for parent in info.parents {
            queue.push(parent)
          }
        }
      None => ()
    }
  }
  matched
}

///|
/// Resolve base reference (without suffix)
fn resolve_base_ref(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> @bit.ObjectId? raise @bit.GitError {
  if spec == "HEAD" || spec == "" || spec == "@" {
    return resolve_head_commit(fs, git_dir)
  }
  if resolve_ref(fs, git_dir, spec) is Some(id) {
    return Some(id)
  }
  if spec.has_prefix("refs/") {
    return resolve_ref(fs, git_dir, spec)
  }
  if spec.has_prefix("heads/") ||
    spec.has_prefix("tags/") ||
    spec.has_prefix("remotes/") {
    return resolve_ref(fs, git_dir, "refs/" + spec)
  }
  if (spec.length() == 40 || spec.length() == 64) &&
    @bithash.is_hex_string(spec) {
    match @bit.ObjectId::from_hex(spec) {
      id => return Some(id)
    }
  }
  if resolve_abbrev_ref_id(fs, git_dir, spec) is Some(id) {
    return Some(id)
  }
  if resolve_ref(fs, git_dir, "refs/heads/" + spec) is Some(id) {
    return Some(id)
  }
  if resolve_ref(fs, git_dir, "refs/remotes/" + spec) is Some(id) {
    return Some(id)
  }
  if resolve_ref(fs, git_dir, "refs/tags/" + spec) is Some(id) {
    return Some(id)
  }
  None
}

///|
/// Resolve path within a commit/tree
fn resolve_path_in_commit(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  base_id : @bit.ObjectId,
  path : String,
) -> @bit.ObjectId? raise @bit.GitError {
  let db = ObjectDb::load(fs, git_dir)
  let obj = db.get(fs, base_id)
  match obj {
    None => return None
    Some(o) => {
      let tree_id = match o.obj_type {
        @bit.ObjectType::Commit => @bit.parse_commit(o.data).tree
        @bit.ObjectType::Tree => base_id
        _ => return None
      }
      // Empty path means "return the tree itself" (e.g., HEAD:)
      if path.length() == 0 {
        return Some(tree_id)
      }
      let entry = find_tree_entry(db, fs, tree_id, path)
      match entry {
        Some(e) => Some(e.id)
        None => None
      }
    }
  }
}

///|
/// List all refs (loose + packed).
pub fn show_ref(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
) -> Array[(String, @bit.ObjectId)] raise @bit.GitError {
  let out : Map[String, @bit.ObjectId] = {}
  // Collect from reftable if present
  if fs.is_dir(join_path(git_dir, "reftable")) {
    let reftable_refs = @reftable.collect_reftable_refs(fs, git_dir)
    for pair in reftable_refs {
      let (name, id) = pair
      out[name] = id
    }
  }
  let refs_dir = join_path(git_dir, "refs")
  if fs.is_dir(refs_dir) {
    ref_collect_loose(fs, git_dir, refs_dir, "refs", out)
  }
  let packed = join_path(git_dir, "packed-refs")
  if fs.is_file(packed) {
    ref_collect_packed(fs, packed, out)
  }
  let result : Array[(String, @bit.ObjectId)] = []
  for item in out.to_array() {
    let (name, id) = item
    result.push((name, id))
  }
  result.sort_by((a, b) => String::compare(a.0, b.0))
  result
}

///|
/// Format like `git show-ref` output.
pub fn show_ref_text(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
) -> Array[String] raise @bit.GitError {
  let refs = show_ref(fs, git_dir)
  let lines : Array[String] = []
  for item in refs {
    let (name, id) = item
    lines.push("\{id.to_hex()} \{name}")
  }
  lines
}

///|
fn ref_collect_loose(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  dir : String,
  prefix : String,
  out : Map[String, @bit.ObjectId],
) -> Unit raise @bit.GitError {
  let entries = fs.readdir(dir)
  for name in entries {
    let path = join_path(dir, name)
    let rel = if prefix == "" { name } else { prefix + "/" + name }
    if fs.is_dir(path) {
      ref_collect_loose(fs, git_dir, path, rel, out)
    } else if fs.is_file(path) {
      let line = ref_read_line(fs, path)
      if line.has_prefix("ref: ") {
        let target = String::unsafe_substring(line, start=5, end=line.length())
        let resolved = resolve_ref(fs, git_dir, target) catch { _ => None }
        match resolved {
          Some(id) => out[rel] = id
          None => ()
        }
      } else {
        out[rel] = @bit.ObjectId::from_hex(line)
      }
    }
  }
}

///|
fn ref_collect_packed(
  fs : &@bit.RepoFileSystem,
  packed_path : String,
  out : Map[String, @bit.ObjectId],
) -> Unit raise @bit.GitError {
  let text = @utf8.decode_lossy(fs.read_file(packed_path)[:])
  for line_view in text.split("\n") {
    let line = ref_trim_line(line_view.to_string())
    if line.length() == 0 {
      continue
    }
    if line.has_prefix("#") || line.has_prefix("^") {
      continue
    }
    let space = line.find(" ")
    match space {
      None => continue
      Some(idx) => {
        if idx + 1 >= line.length() {
          continue
        }
        let id_hex = String::unsafe_substring(line, start=0, end=idx)
        let name = String::unsafe_substring(
          line,
          start=idx + 1,
          end=line.length(),
        )
        if !out.contains(name) {
          out[name] = @bit.ObjectId::from_hex(id_hex)
        }
      }
    }
  }
}

///|
fn ref_read_line(
  fs : &@bit.RepoFileSystem,
  path : String,
) -> String raise @bit.GitError {
  let text = @utf8.decode_lossy(fs.read_file(path)[:])
  for line_view in text.split("\n") {
    let line = ref_trim_line(line_view.to_string())
    if line.length() > 0 {
      return line
    }
  }
  raise @bit.GitError::InvalidObject("Empty ref: \{path}")
}

///|
fn ref_trim_line(line : String) -> String {
  let mut s = line
  if s.has_suffix("\r") {
    s = String::unsafe_substring(s, start=0, end=s.length() - 1)
  }
  s
}

// ─── Pure parsing helpers (extracted from src/cmd/bit/rev_parse.mbt) ───

///|
/// Parse `--short=N` value into an integer.
pub fn parse_rev_parse_short_length(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }
  let mut result = 0
  for c in value {
    if c < '0' || c > '9' {
      return None
    }
    result = result * 10 + (c.to_int() - '0'.to_int())
  }
  Some(result)
}

///|
/// Parse a reflog numeric selector like `main@{2}` or `@{0}`.
/// Returns (refname, index) where refname is canonicalised.
pub fn parse_reflog_selector(spec : String) -> (String, Int)? {
  guard spec.has_suffix("}") else { return None }
  match spec.find("@{") {
    Some(idx) => {
      let number_start = idx + 2
      guard number_start < spec.length() - 1 else { return None }
      let number_text = String::unsafe_substring(
        spec,
        start=number_start,
        end=spec.length() - 1,
      )
      let mut number = 0
      for c in number_text {
        if c < '0' || c > '9' {
          return None
        }
        number = number * 10 + (c.to_int() - '0'.to_int())
      }
      let raw_ref = String::unsafe_substring(spec, start=0, end=idx)
      let refname = if raw_ref == "HEAD" {
        "HEAD"
      } else if raw_ref.length() == 0 {
        ""
      } else if raw_ref.has_prefix("refs/") {
        raw_ref
      } else {
        "refs/heads/" + raw_ref
      }
      Some((refname, number))
    }
    None => None
  }
}

///|
/// Parse a reflog date selector like `main@{May 25 2005}` or `HEAD@{2005-05-26}`.
/// Returns (refname, date_string) when the content is non-numeric.
pub fn parse_reflog_date_selector(spec : String) -> (String, String)? {
  guard spec.has_suffix("}") else { return None }
  match spec.find("@{") {
    Some(idx) => {
      let content_start = idx + 2
      guard content_start < spec.length() - 1 else { return None }
      let content = String::unsafe_substring(
        spec,
        start=content_start,
        end=spec.length() - 1,
      )
      let mut all_digits = true
      for c in content {
        if c < '0' || c > '9' {
          all_digits = false
          break
        }
      }
      if all_digits {
        return None
      }
      let raw_ref = String::unsafe_substring(spec, start=0, end=idx)
      let refname = if raw_ref == "HEAD" {
        "HEAD"
      } else if raw_ref.length() == 0 {
        ""
      } else if raw_ref.has_prefix("refs/") {
        raw_ref
      } else {
        "refs/heads/" + raw_ref
      }
      Some((refname, content))
    }
    None => None
  }
}

///|
/// Parse `^@`, `^!`, `^-N` parent suffixes.
/// Returns (base_spec, suffix_type) where suffix_type is "@", "!", "-N", etc.
pub fn rev_parse_parse_parent_suffix(spec : String) -> (String, String)? {
  if spec.has_suffix("^@") && spec.length() > 2 {
    let base = String::unsafe_substring(spec, start=0, end=spec.length() - 2)
    return Some((base, "@"))
  }
  if spec.has_suffix("^!") && spec.length() > 2 {
    let base = String::unsafe_substring(spec, start=0, end=spec.length() - 2)
    return Some((base, "!"))
  }
  let chars = spec.to_array()
  let len = chars.length()
  for i = len - 1; i >= 1; i = i - 1 {
    if chars[i - 1] == '^' && chars[i] == '-' {
      let base = String::unsafe_substring(spec, start=0, end=i - 1)
      if base.length() == 0 {
        return None
      }
      let rest = String::unsafe_substring(spec, start=i + 1, end=len)
      if rest.length() == 0 {
        return Some((base, "-1"))
      }
      let mut all_digits = true
      for c in rest {
        if c < '0' || c > '9' {
          all_digits = false
          break
        }
      }
      if all_digits {
        return Some((base, "-" + rest))
      }
      return Some((base, "-invalid:" + rest))
    }
  }
  None
}

///|
/// Normalize a glob pattern by expanding shorthand prefixes.
/// `"heads/*"` -> `"refs/heads/*"`, `"refs/heads/*"` unchanged.
pub fn rev_parse_normalize_glob_pattern(pattern : String) -> String {
  if pattern.has_prefix("refs/") {
    pattern
  } else if pattern.has_prefix("heads/") {
    "refs/" + pattern
  } else if pattern.has_prefix("tags/") {
    "refs/" + pattern
  } else if pattern.has_prefix("remotes/") {
    "refs/" + pattern
  } else {
    "refs/" + pattern
  }
}

///|
/// Glob match for ref patterns. Supports `*` (any chars) and `?` (single char).
/// Non-glob patterns match as exact or path prefix (with `/` boundary).
pub fn rev_parse_glob_match(text : String, pattern : String) -> Bool {
  let has_star = pattern.find("*") is Some(_)
  let has_question = pattern.find("?") is Some(_)
  if !has_star && !has_question {
    text == pattern ||
    (
      text.has_prefix(pattern) &&
      pattern.length() < text.length() &&
      (pattern[pattern.length() - 1] == '/' || text[pattern.length()] == '/')
    )
  } else {
    let t = text.to_array()
    let p = pattern.to_array()
    rev_parse_glob_match_inner(t, 0, p, 0)
  }
}

///|
fn rev_parse_glob_match_inner(
  t : Array[Char],
  ti : Int,
  p : Array[Char],
  pi : Int,
) -> Bool {
  let mut ti = ti
  let mut pi = pi
  while pi < p.length() {
    if p[pi] == '*' {
      pi += 1
      for k = ti; k <= t.length(); k = k + 1 {
        if rev_parse_glob_match_inner(t, k, p, pi) {
          return true
        }
      }
      return false
    } else if p[pi] == '?' {
      if ti >= t.length() {
        return false
      }
      ti += 1
      pi += 1
    } else {
      if ti >= t.length() || t[ti] != p[pi] {
        return false
      }
      ti += 1
      pi += 1
    }
  }
  ti == t.length()
}

///|
/// Parse `@{-N}` prefix. Returns (N, rest_of_spec).
pub fn parse_at_minus_prefix(spec : String) -> (Int, String)? {
  guard spec.has_prefix("@{-") else { return None }
  let chars = spec.to_array()
  let mut i = 3
  let mut n = 0
  let mut found_digit = false
  while i < chars.length() && chars[i] != '}' {
    if chars[i] < '0' || chars[i] > '9' {
      return None
    }
    n = n * 10 + (chars[i].to_int() - '0'.to_int())
    found_digit = true
    i += 1
  }
  guard found_digit && i < chars.length() && chars[i] == '}' else {
    return None
  }
  let rest = String::unsafe_substring(spec, start=i + 1, end=spec.length())
  Some((n, rest))
}

///|
/// Shorten a hex OID to the requested length (minimum 4).
pub fn shorten_oid_hex(hex : String, requested : Int) -> String {
  let mut length = requested
  if length < 4 {
    length = 4
  }
  if length > hex.length() {
    length = hex.length()
  }
  String::unsafe_substring(hex, start=0, end=length)
}

///|
/// Shell-escape a value with single quotes.
pub fn shell_single_quote(value : String) -> String {
  let out = StringBuilder::new()
  out.write_char('\'')
  for c in value {
    if c == '\'' {
      out.write_char('\'')
      out.write_char('\\')
      out.write_char('\'')
      out.write_char('\'')
    } else {
      out.write_char(c)
    }
  }
  out.write_char('\'')
  out.to_string()
}

///|
/// Check whether cwd is inside the git directory.
pub fn rev_parse_is_inside_git_dir(
  cwd_abs : String,
  abs_git_dir : String,
) -> Bool {
  if cwd_abs == abs_git_dir {
    return true
  }
  let prefix = if abs_git_dir.has_suffix("/") {
    abs_git_dir
  } else {
    abs_git_dir + "/"
  }
  cwd_abs.has_prefix(prefix)
}

///|
/// Compute a relative path from `cwd_abs` to `abs_target`.
pub fn rev_parse_make_relative(abs_target : String, cwd_abs : String) -> String {
  if abs_target == cwd_abs {
    return "./"
  }
  let cwd_prefix = if cwd_abs.has_suffix("/") { cwd_abs } else { cwd_abs + "/" }
  if abs_target.has_prefix(cwd_prefix) {
    return String::unsafe_substring(
      abs_target,
      start=cwd_prefix.length(),
      end=abs_target.length(),
    )
  }
  let mut common_len = 0
  let target_chars = abs_target.to_array()
  let cwd_chars = cwd_abs.to_array()
  let min_len = if target_chars.length() < cwd_chars.length() {
    target_chars.length()
  } else {
    cwd_chars.length()
  }
  for i in 0..<min_len {
    if target_chars[i] != cwd_chars[i] {
      break
    }
    if target_chars[i] == '/' {
      common_len = i + 1
    }
  }
  if common_len == 0 && min_len > 0 {
    common_len = 1
  }
  let remaining_cwd = String::unsafe_substring(
    cwd_abs,
    start=common_len,
    end=cwd_abs.length(),
  )
  let remaining_target = String::unsafe_substring(
    abs_target,
    start=common_len,
    end=abs_target.length(),
  )
  let depth = remaining_cwd.iter().filter(fn(c) { c == '/' }).count() + 1
  let parts : Array[String] = []
  for _ in 0..<depth {
    parts.push("..")
  }
  let up = parts.join("/")
  if remaining_target.length() == 0 {
    up
  } else {
    up + "/" + remaining_target
  }
}

///|
/// Normalize a path by resolving `.` and `..` components.
pub fn rev_parse_normalize_path(path : String) -> String {
  let parts = path.split("/")
  let result : Array[String] = []
  for part in parts {
    let s = part.to_string()
    if s == "." {
      continue
    } else if s == ".." {
      if result.length() > 0 {
        let _ = result.pop()
      }
    } else {
      result.push(s)
    }
  }
  result.join("/")
}

///|
/// Apply `--prefix` to `revision:path` specs with relative paths.
pub fn rev_parse_apply_prefix_to_colon_path(
  spec : String,
  prefix : String,
) -> String {
  guard spec.find(":") is Some(colon_idx) else { return spec }
  guard colon_idx > 0 else { return spec }
  let path_part = String::unsafe_substring(
    spec,
    start=colon_idx + 1,
    end=spec.length(),
  )
  if !path_part.has_prefix("./") && !path_part.has_prefix("../") {
    return spec
  }
  let rev_part = String::unsafe_substring(spec, start=0, end=colon_idx)
  let combined = prefix + path_part
  let normalized = rev_parse_normalize_path(combined)
  rev_part + ":" + normalized
}

///|
/// Parse index pathspec like `:0:path` or `:path`.
pub fn parse_index_pathspec(spec : String) -> (Int, String?) {
  if !spec.has_prefix(":") || spec.length() <= 1 {
    return (0, None)
  }
  let rest = String::unsafe_substring(spec, start=1, end=spec.length())
  let mut stage = 0
  let mut path = rest
  if rest.length() >= 3 && rest[0] >= '0' && rest[0] <= '3' && rest[1] == ':' {
    stage = rest[0].to_int() - '0'.to_int()
    path = String::unsafe_substring(rest, start=2, end=rest.length())
  }
  if path.length() == 0 {
    (stage, None)
  } else {
    (stage, Some(path))
  }
}

///|
/// Strip leading `./` and trailing `/` from an index pathspec path.
pub fn normalize_index_pathspec_path(path : String) -> String {
  let mut out = path
  while out.has_prefix("./") {
    out = String::unsafe_substring(out, start=2, end=out.length())
  }
  while out.length() > 1 && out.has_suffix("/") {
    out = String::unsafe_substring(out, start=0, end=out.length() - 1)
  }
  out
}

///|
/// Extract the `object` header hex from tag text.
pub fn rev_parse_extract_tag_target_name(tag_text : String) -> String? {
  for line_view in tag_text.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("object ") {
      return Some(
        rev_parse_trim_string(
          String::unsafe_substring(line, start=7, end=line.length()),
        ),
      )
    }
  }
  None
}

///|
fn rev_parse_trim_string(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end &&
        (
          s[start] == ' ' ||
          s[start] == '\t' ||
          s[start] == '\n' ||
          s[start] == '\r'
        ) {
    start += 1
  }
  while end > start &&
        (
          s[end - 1] == ' ' ||
          s[end - 1] == '\t' ||
          s[end - 1] == '\n' ||
          s[end - 1] == '\r'
        ) {
    end -= 1
  }
  String::unsafe_substring(s, start~, end~)
}

///|
/// Check whether a git path should use the common directory.
pub fn rev_parse_git_path_uses_common_dir(requested_path : String) -> Bool {
  requested_path == "objects" ||
  requested_path.has_prefix("objects/") ||
  requested_path == "refs" ||
  requested_path.has_prefix("refs/") ||
  requested_path == "packed-refs" ||
  requested_path == "config" ||
  requested_path == "hooks" ||
  requested_path.has_prefix("hooks/") ||
  requested_path == "info" ||
  requested_path.has_prefix("info/") ||
  requested_path == "logs/refs" ||
  requested_path.has_prefix("logs/refs/")
}

///|
/// Parse a date string to a Unix timestamp.
pub fn parse_date_to_timestamp(date_str : String) -> Int64 {
  if date_str.find("T") is Some(_) {
    return parse_iso8601_timestamp(date_str)
  }
  let mut is_numeric = true
  for c in date_str {
    if c < '0' || c > '9' {
      is_numeric = false
      break
    }
  }
  if is_numeric && date_str.length() > 0 {
    let mut result = 0L
    for c in date_str {
      result = result * 10L + (c.to_int() - '0'.to_int()).to_int64()
    }
    return result
  }
  0L
}

///|
/// Parse ISO 8601 timestamp (YYYY-MM-DDTHH:MM:SS).
pub fn parse_iso8601_timestamp(date_str : String) -> Int64 {
  let s = date_str.to_array()
  if s.length() < 19 {
    return 0L
  }
  let year = @date_parse.parse_date_digits(s, 0, 4)
  let month = @date_parse.parse_date_digits(s, 5, 7)
  let day = @date_parse.parse_date_digits(s, 8, 10)
  let hour = @date_parse.parse_date_digits(s, 11, 13)
  let minute = @date_parse.parse_date_digits(s, 14, 16)
  let second = @date_parse.parse_date_digits(s, 17, 19)
  let days = @date_parse.days_since_epoch(year, month, day)
  days.to_int64() * 86400L +
  hour.to_int64() * 3600L +
  minute.to_int64() * 60L +
  second.to_int64()
}

///|
/// Parse a boolean config value (true/yes/1/false/no/0).
pub fn rev_parse_parse_config_bool(raw : String) -> Bool? {
  let value = config_strip_quotes(raw).to_lower()
  if value == "true" || value == "yes" || value == "1" {
    Some(true)
  } else if value == "false" || value == "no" || value == "0" {
    Some(false)
  } else {
    None
  }
}

///|
/// Split a string into lines (parseopt helper).
pub fn parseopt_split_lines(s : String) -> Array[String] {
  let lines : Array[String] = []
  let buf = StringBuilder::new()
  for c in s {
    if c == '\n' {
      lines.push(buf.to_string())
      buf.reset()
    } else {
      buf.write_char(c)
    }
  }
  let last = buf.to_string()
  if last.length() > 0 {
    lines.push(last)
  }
  lines
}

///|
/// Find the first space or tab in a string.
pub fn parseopt_find_space(s : String) -> Int? {
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c == ' ' || c == '\t' {
      return Some(i)
    }
  }
  None
}

///|
/// Skip leading spaces and tabs.
pub fn parseopt_skipspaces(s : String) -> String {
  let mut i = 0
  while i < s.length() {
    let c = s[i]
    if c != ' ' && c != '\t' {
      break
    }
    i = i + 1
  }
  String::unsafe_substring(s, start=i, end=s.length())
}

///|
/// Find the index of the first flag character (`*`, `=`, `?`, `!`).
pub fn parseopt_find_flags(s : String) -> Int {
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c == '*' || c == '=' || c == '?' || c == '!' {
      return i
    }
  }
  s.length()
}

///|
/// Find the index of a specific character in a string.
pub fn parseopt_find_char(s : String, ch : Char) -> Int? {
  for i = 0; i < s.length(); i = i + 1 {
    if s[i].to_int() == ch.to_int() {
      return Some(i)
    }
  }
  None
}
