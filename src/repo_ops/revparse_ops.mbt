///| Ref resolution helpers (rev-parse/show-ref)

///|
pub fn rev_parse(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> @object.ObjectId? raise @object.GitError {
  if spec.has_prefix(":/") && spec.length() > 2 {
    let needle = substring_revparse(spec, 2, spec.length())
    return resolve_commit_message_search_all_refs(fs, git_dir, needle)
  }
  // :N:path — index stage entry lookup (e.g. :0:file, :2:file)
  // :path — shorthand for :0:path
  if spec.has_prefix(":") && not(spec.has_prefix(":/")) {
    let rest = substring_revparse(spec, 1, spec.length())
    let (target_stage, path) = if rest.length() >= 2 {
      let ch = rest[0]
      if (ch == '0' || ch == '1' || ch == '2' || ch == '3') && rest[1] == ':' {
        let stage = ch.to_int() - '0'.to_int()
        (stage, substring_revparse(rest, 2, rest.length()))
      } else {
        (0, rest)
      }
    } else {
      (0, rest)
    }
    if path.length() > 0 {
      return resolve_index_stage_entry(fs, git_dir, path, target_stage)
    }
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
  // ^{} — peel tags to the underlying object (any type)
  if spec.has_suffix("^{}") && spec.length() > 3 {
    let base_spec = substring_revparse(spec, 0, spec.length() - 3)
    let base = rev_parse(fs, git_dir, base_spec)
    guard base is Some(base_id) else { return None }
    return peel_tags(fs, git_dir, base_id)
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
  // ^{tag} — verify object is a tag
  if spec.has_suffix("^{tag}") && spec.length() > 6 {
    let base_spec = substring_revparse(spec, 0, spec.length() - 6)
    let base = rev_parse(fs, git_dir, base_spec)
    guard base is Some(base_id) else { return None }
    let db = @bitlib.ObjectDb::load(fs, git_dir)
    let obj = db.get(fs, base_id)
    guard obj is Some(o) else { return None }
    if o.obj_type == @object.ObjectType::Tag {
      return Some(base_id)
    }
    return None
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
  fs : &@types.RepoFileSystem,
  git_dir : String,
  base_spec : String,
  needle : String,
) -> @object.ObjectId? raise @object.GitError {
  if needle.length() == 0 {
    return None
  }
  // "!" prefix handling: "!!" = literal "!", "!-" = negation, bare "!" or "!X" = invalid
  if needle.has_prefix("!") {
    if needle.has_prefix("!!") {
      // "!!" prefix means literal "!" search (strip one "!")
      let base = rev_parse(fs, git_dir, base_spec)
      guard base is Some(base_id) else { return None }
      let actual_needle = substring_revparse(needle, 1, needle.length())
      return find_reachable_commit_by_message_from_many(
        fs,
        git_dir,
        [base_id],
        actual_needle,
      )
    }
    if needle.has_prefix("!-") {
      // "!-" prefix means negation
      let actual_needle = substring_revparse(needle, 2, needle.length())
      if actual_needle.length() == 0 {
        raise @object.GitError::InvalidObject(
          "Invalid search pattern: \\{base_spec}^{{/!-}}",
        )
      }
      let base = rev_parse(fs, git_dir, base_spec)
      guard base is Some(base_id) else { return None }
      return find_reachable_commit_by_message_from_many(
        fs,
        git_dir,
        [base_id],
        actual_needle,
        negate=true,
      )
    }
    // Bare "!" or "!X" (not "!!" or "!-") is invalid
    raise @object.GitError::InvalidObject(
      "Invalid search pattern: \\{base_spec}^{{/\\{needle}}}",
    )
  }
  let base = rev_parse(fs, git_dir, base_spec)
  guard base is Some(base_id) else { return None }
  find_reachable_commit_by_message_from_many(fs, git_dir, [base_id], needle)
}

///|
fn resolve_commit_message_search_all_refs(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  needle : String,
) -> @object.ObjectId? raise @object.GitError {
  if needle.length() == 0 {
    return None
  }
  let starts : Array[@object.ObjectId] = []
  let seen_start : Map[String, Bool] = {}
  let refs = show_ref(fs, git_dir)
  for item in refs {
    let (_, id) = item
    let hex = id.to_hex()
    if not(seen_start.contains(hex)) {
      seen_start[hex] = true
      starts.push(id)
    }
  }
  match @bitlib.resolve_head_commit(fs, git_dir) {
    Some(id) => {
      let hex = id.to_hex()
      if not(seen_start.contains(hex)) {
        seen_start[hex] = true
        starts.push(id)
      }
    }
    None => ()
  }
  if starts.length() == 0 {
    return None
  }
  // !-prefix means negation: find commit whose message does NOT contain the pattern
  if needle.has_prefix("!-") {
    let actual_needle = substring_revparse(needle, 2, needle.length())
    return find_reachable_commit_by_message_from_many(
      fs,
      git_dir,
      starts,
      actual_needle,
      negate=true,
    )
  }
  find_reachable_commit_by_message_from_many(fs, git_dir, starts, needle)
}

///|
fn find_reachable_commit_by_message_from_many(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  starts : Array[@object.ObjectId],
  needle : String,
  negate? : Bool = false,
) -> @object.ObjectId? raise @object.GitError {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let queue : Array[@object.ObjectId] = []
  for start in starts {
    queue.push(start)
  }
  let seen : Map[String, Bool] = {}
  let mut best_id : @object.ObjectId? = None
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
        if obj.obj_type == @object.ObjectType::Commit {
          let contains = commit_message_contains(obj.data, needle)
          let matches = if negate { not(contains) } else { contains }
          if matches {
            let ts = parse_commit_committer_timestamp(obj.data)
            if best_id is None || ts > best_time {
              best_id = Some(current)
              best_time = ts
            }
          }
          let info = @repo.parse_commit(obj.data)
          for parent in info.parents {
            if not(seen.contains(parent.to_hex())) {
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
    Some(idx) => {
      let msg = substring_revparse(text, idx + 2, text.length())
      regex_like_contains(msg, needle)
    }
    None => false
  }
}

///|
/// Simple regex-like substring search supporting `.` as any-char and `\\` escapes.
/// This matches git's basic regex behavior for `^{/pattern}`.
fn regex_like_contains(text : String, pattern : String) -> Bool {
  if pattern.length() == 0 {
    return true
  }
  let text_chars = text.to_array()
  let pat_chars = pattern.to_array()
  for start in 0..<text_chars.length() {
    if regex_like_match_at(text_chars, start, pat_chars) {
      return true
    }
  }
  false
}

///|
fn regex_like_match_at(
  text : Array[Char],
  start : Int,
  pattern : Array[Char],
) -> Bool {
  let mut ti = start
  let mut pi = 0
  while pi < pattern.length() {
    if ti >= text.length() {
      return false
    }
    let pc = pattern[pi]
    if pc == '\\' {
      if pi + 1 < pattern.length() {
        if text[ti] != pattern[pi + 1] {
          return false
        }
        ti += 1
        pi += 2
        continue
      }
      if text[ti] != '\\' {
        return false
      }
      ti += 1
      pi += 1
      continue
    }
    if pc == '.' {
      ti += 1
      pi += 1
      continue
    }
    if text[ti] != pc {
      return false
    }
    ti += 1
    pi += 1
  }
  true
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
fn peel_tags(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  id : @object.ObjectId,
) -> @object.ObjectId? raise @object.GitError {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let mut current = id
  for _ in 0..<64 {
    let obj = db.get(fs, current)
    guard obj is Some(o) else { return Some(current) }
    match o.obj_type {
      @object.ObjectType::Tag =>
        match parse_tag_object_target(o.data) {
          Some(next) => current = next
          None => return Some(current)
        }
      _ => return Some(current)
    }
  }
  Some(current)
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
  fs : &@types.RepoFileSystem,
  git_dir : String,
  id : @object.ObjectId,
) -> @object.ObjectId? raise @object.GitError {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let mut current = id
  for _ in 0..<8 {
    let obj = db.get(fs, current)
    guard obj is Some(o) else { return None }
    match o.obj_type {
      @object.ObjectType::Commit => return Some(current)
      @object.ObjectType::Tag =>
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
  fs : &@types.RepoFileSystem,
  git_dir : String,
  id : @object.ObjectId,
) -> @object.ObjectId? raise @object.GitError {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let mut current = id
  for _ in 0..<8 {
    let obj = db.get(fs, current)
    guard obj is Some(o) else { return None }
    match o.obj_type {
      @object.ObjectType::Tree => return Some(current)
      @object.ObjectType::Commit => return Some(@repo.parse_commit(o.data).tree)
      @object.ObjectType::Tag =>
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
fn parse_tag_object_target(data : Bytes) -> @object.ObjectId? {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("object ") {
      let hex = substring_revparse(line, 7, line.length())
      let id = @object.ObjectId::from_hex(hex) catch { _ => return None }
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
    if not(c == '^' || c == '~' || (c >= '0' && c <= '9')) {
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
  fs : &@types.RepoFileSystem,
  git_dir : String,
  start : @object.ObjectId,
  suffix : String,
) -> @object.ObjectId? raise @object.GitError {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
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
        // `^0` peels to the commit (dereference tags).
        if parent_index == 0 {
          current = peel_to_commit_id(db, fs, current)
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
      if not(has_digits) {
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
/// Peel tags to reach the underlying commit ID.
fn peel_to_commit_id(
  db : @bitlib.ObjectDb,
  fs : &@types.RepoFileSystem,
  id : @object.ObjectId,
) -> @object.ObjectId raise @object.GitError {
  let mut current = id
  for _ in 0..<8 {
    let obj = db.get(fs, current)
    guard obj is Some(o) else { break }
    match o.obj_type {
      @object.ObjectType::Commit => return current
      @object.ObjectType::Tag =>
        match parse_tag_object_target(o.data) {
          Some(next) => current = next
          None => break
        }
      _ => break
    }
  }
  current
}

///|
fn commit_nth_parent(
  db : @bitlib.ObjectDb,
  fs : &@types.RepoFileSystem,
  commit_id : @object.ObjectId,
  nth_parent : Int,
) -> @object.ObjectId? raise @object.GitError {
  if nth_parent <= 0 {
    return Some(commit_id)
  }
  // Peel tags to reach commit
  let peeled = peel_to_commit_id(db, fs, commit_id)
  let obj = db.get(fs, peeled)
  guard obj is Some(o) else { return None }
  if o.obj_type != @object.ObjectType::Commit {
    return None
  }
  let info = @repo.parse_commit(o.data)
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
/// Resolve :N:path by looking up index stage entries.
/// Parses the index binary format directly to find the entry with
/// matching path and stage number.
fn resolve_index_stage_entry(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  path : String,
  stage : Int,
) -> @object.ObjectId? raise @object.GitError {
  let index_path = git_dir + "/index"
  if not(fs.is_file(index_path)) {
    return None
  }
  let data = fs.read_file(index_path)
  if data.length() < 12 {
    return None
  }
  if data[0] != b'D' || data[1] != b'I' || data[2] != b'R' || data[3] != b'C' {
    return None
  }
  let version = revparse_read_u32_be(data, 4)
  let num_entries = revparse_read_u32_be(data, 8)
  let mut pos = 12
  for _ in 0..<num_entries {
    if pos + 62 > data.length() {
      break
    }
    let id_pos = pos + 40
    let id_bytes : FixedArray[Byte] = FixedArray::make(20, b'\x00')
    for i in 0..<20 {
      id_bytes[i] = data[id_pos + i]
    }
    let id = @object.ObjectId::new(id_bytes)
    let flags_pos = id_pos + 20
    let flags = (data[flags_pos].to_int() << 8) | data[flags_pos + 1].to_int()
    let entry_stage = (flags >> 12) & 0x3
    let name_len = flags & 0x0FFF
    let has_extended = version >= 3 && (flags & 0x4000) != 0
    let mut path_start = flags_pos + 2
    if has_extended {
      path_start += 2
    }
    let actual_len = if name_len < 0x0FFF {
      name_len
    } else {
      let mut len = 0
      while path_start + len < data.length() &&
            data[path_start + len] != b'\x00' {
        len += 1
      }
      len
    }
    let entry_path_buf = StringBuilder::new()
    for i in 0..<actual_len {
      if path_start + i < data.length() {
        entry_path_buf.write_char(
          data[path_start + i].to_int().unsafe_to_char(),
        )
      }
    }
    let entry_path = entry_path_buf.to_string()
    if entry_path == path && entry_stage == stage {
      return Some(id)
    }
    // Advance to next entry (aligned to 8 bytes)
    let entry_len = path_start + actual_len + 1 - pos
    let padded = (entry_len + 7).land(0x7FFFFFF8) // align to 8
    pos += padded
  }
  None
}

///|
fn revparse_read_u32_be(data : Bytes, pos : Int) -> Int {
  (data[pos].to_int() << 24) |
  (data[pos + 1].to_int() << 16) |
  (data[pos + 2].to_int() << 8) |
  data[pos + 3].to_int()
}

///|
fn resolve_abbrev_ref_id(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> @object.ObjectId? raise @object.GitError {
  if spec.length() < 4 ||
    spec.length() >= 64 ||
    not(@bithash.is_hex_string(spec)) {
    return None
  }
  let needle = @bithash.lower_hex_string(spec)
  let refs = show_ref(fs, git_dir)
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let queue : Array[@object.ObjectId] = []
  let seen : Map[String, Bool] = {}
  for item in refs {
    let (_, id) = item
    queue.push(id)
  }
  match @bitlib.resolve_head_commit(fs, git_dir) {
    Some(id) => queue.push(id)
    None => ()
  }
  let mut matched : @object.ObjectId? = None
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
        if obj.obj_type == @object.ObjectType::Commit {
          let info = @repo.parse_commit(obj.data)
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
/// Parse a spec containing @{upstream}, @{u}, @{push}, or @{p} (case-insensitive).
/// Returns (branch_name_or_empty, "upstream"|"push", rest_after_closing_brace) or None.
/// Finds the LAST @{ occurrence to handle branch names containing @.
pub fn parse_upstream_push_spec(spec : String) -> (String, String, String)? {
  let chars = spec.to_array()
  let len = chars.length()
  // Scan right-to-left for @{ that contains upstream/u/push/p.
  // We iterate from right to left so that branch names with @ are handled:
  // e.g. fun@ny@{u} → finds @{u} at the end, branch = "fun@ny"
  // For chained specs like my-side@{u}@{1}, we need the FIRST matching @{.
  // Strategy: collect all @{ positions, then try from leftmost to rightmost.
  let at_brace_positions : Array[Int] = []
  for i = 0; i < len - 1; i = i + 1 {
    if chars[i] == '@' && chars[i + 1] == '{' {
      at_brace_positions.push(i)
    }
  }
  // Try each @{ position from left to right
  for pos in at_brace_positions {
    // Find matching closing brace
    let mut close_idx = -1
    for i = pos + 2; i < len; i = i + 1 {
      if chars[i] == '}' {
        close_idx = i
        break
      }
    }
    if close_idx < 0 {
      continue
    }
    // Extract content between @{ and }
    let content = substring_revparse(spec, pos + 2, close_idx)
    let content_lower = content.to_lower()
    let kind = if content_lower == "upstream" || content_lower == "u" {
      "upstream"
    } else if content_lower == "push" || content_lower == "p" {
      "push"
    } else {
      continue
    }
    let branch = substring_revparse(spec, 0, pos)
    // If branch contains ':', this is a tree:path spec, not upstream/push
    if branch.find(":") is Some(_) {
      return None
    }
    let rest = substring_revparse(spec, close_idx + 1, len)
    return Some((branch, kind, rest))
  }
  None
}

///|
/// Resolve @{upstream} for a branch. Returns the upstream tracking ref name.
/// Errors with descriptive messages matching git behavior.
pub fn resolve_upstream_ref(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  branch : String,
) -> String raise @object.GitError {
  // If branch is empty, use HEAD
  let branch_name = if branch == "" || branch == "HEAD" || branch == "@" {
    match @bitlib.read_head_ref(fs, git_dir) {
      @bitlib.HeadRef::Branch(name) => name
      @bitlib.HeadRef::Detached(_) =>
        raise @object.GitError::InvalidObject("HEAD does not point to a branch")
    }
    // Strip refs/heads/ prefix if present
  } else if branch.has_prefix("refs/heads/") {
    // refs/heads/X@{upstream} should NOT resolve (git behavior)
    raise @object.GitError::InvalidObject(
      "no upstream configured for branch '" + branch + "'",
    )
  } else {
    branch
  }
  // Check branch exists
  let branch_ref = "refs/heads/" + branch_name
  let branch_exists = match @bitlib.resolve_ref(fs, git_dir, branch_ref) {
    Some(_) => true
    None => false
  }
  if not(branch_exists) {
    raise @object.GitError::InvalidObject(
      "no such branch: '" + branch_name + "'",
    )
  }
  // Read config
  let (_, branches) = @bitlib.read_repo_config(fs, git_dir)
  let cfg = match branches.get(branch_name) {
    Some(c) => c
    None =>
      raise @object.GitError::InvalidObject(
        "no upstream configured for branch '" + branch_name + "'",
      )
  }
  let remote = match cfg.remote {
    Some(r) => r
    None =>
      raise @object.GitError::InvalidObject(
        "no upstream configured for branch '" + branch_name + "'",
      )
  }
  if cfg.merges.length() == 0 {
    raise @object.GitError::InvalidObject(
      "no upstream configured for branch '" + branch_name + "'",
    )
  }
  let merge = cfg.merges[0]
  // Convert merge ref to tracking ref
  if merge.has_prefix("refs/heads/") {
    let branch_part = substring_revparse(merge, 11, merge.length())
    // Check if this remote actually fetches this ref
    // For remote "." (local tracking), the ref is the merge ref itself
    if remote == "." {
      return merge
    }
    let tracking_ref = "refs/remotes/" + remote + "/" + branch_part
    // Verify the remote-tracking ref exists (or at least could exist)
    // git checks if the remote's fetch refspec maps this
    let (remotes, _) = @bitlib.read_repo_config(fs, git_dir)
    match remotes.get(remote) {
      Some(remote_cfg) => {
        // Check if any fetch refspec maps the merge ref
        let fetch_specs = @bitlib.parse_fetch_refspecs(remote_cfg.fetch)
        let mut mapped = false
        for spec in fetch_specs {
          if spec.negative {
            continue
          }
          if @bitlib.refspec_map_dst(spec.src, spec.dst, merge) is Some(_) {
            mapped = true
            break
          }
        }
        if not(mapped) {
          raise @object.GitError::InvalidObject(
            "upstream branch '" +
            merge +
            "' not stored as a remote-tracking branch",
          )
        }
      }
      None => ()
    }
    tracking_ref
  } else {
    merge
  }
}

///|
/// Resolve @{push} for a branch. Returns the push tracking ref name.
pub fn resolve_push_ref(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  branch : String,
) -> String raise @object.GitError {
  // If branch is empty, use HEAD
  let branch_name = if branch == "" || branch == "HEAD" || branch == "@" {
    match @bitlib.read_head_ref(fs, git_dir) {
      @bitlib.HeadRef::Branch(name) => name
      @bitlib.HeadRef::Detached(_) =>
        raise @object.GitError::InvalidObject("HEAD does not point to a branch")
    }
  } else if branch.has_prefix("refs/heads/") {
    raise @object.GitError::InvalidObject(
      "no upstream configured for branch '" + branch + "'",
    )
  } else {
    branch
  }
  // Read config
  let (remotes, branches) = @bitlib.read_repo_config(fs, git_dir)
  // Determine push remote
  // Priority: branch.<name>.pushRemote > remote.pushDefault > branch.<name>.remote
  let content = @bitlib.read_config_content(fs, git_dir)
  let blocks = @bitlib.parse_config_blocks(content)
  let mut push_remote : String? = None
  // 1. branch.<name>.pushRemote
  for block in blocks {
    if block.section == Some("branch") && block.name == Some(branch_name) {
      for line in block.lines {
        match @bitlib.parse_config_kv(line) {
          Some((key, value)) if key == "pushremote" => {
            push_remote = Some(value)
            break
          }
          _ => ()
        }
      }
    }
  }
  // 2. remote.pushDefault
  if push_remote is None {
    for block in blocks {
      if block.section == Some("remote") && block.name is None {
        for line in block.lines {
          match @bitlib.parse_config_kv(line) {
            Some((key, value)) if key == "pushdefault" => {
              push_remote = Some(value)
              break
            }
            _ => ()
          }
        }
      }
    }
  }
  // 3. branch.<name>.remote
  if push_remote is None {
    match branches.get(branch_name) {
      Some(cfg) => push_remote = cfg.remote
      None => ()
    }
  }
  let remote = match push_remote {
    Some(r) => r
    None =>
      raise @object.GitError::InvalidObject(
        "no upstream configured for branch '" + branch_name + "'",
      )
  }
  // Check if remote exists
  guard remotes.get(remote) is Some(remote_cfg) else {
    raise @object.GitError::InvalidObject(
      "no upstream configured for branch '" + branch_name + "'",
    )
  }
  // Read push.default
  let mut push_default_str : String? = None
  for block in blocks {
    if block.section == Some("push") && block.name is None {
      for line in block.lines {
        match @bitlib.parse_config_kv(line) {
          Some((key, value)) if key == "default" => {
            push_default_str = Some(value)
            break
          }
          _ => ()
        }
      }
    }
  }
  let push_default = match push_default_str {
    Some(v) =>
      match v.to_lower() {
        "upstream" => "upstream"
        "current" => "current"
        "matching" => "matching"
        "nothing" => "nothing"
        _ => "simple"
      }
    None => "simple"
  }
  // Try push refspecs first (applies regardless of push.default)
  let local_ref = "refs/heads/" + branch_name
  let push_specs = @bitlib.parse_push_refspecs(remote_cfg.push)
  for spec in push_specs {
    match @bitlib.refspec_map_dst(spec.src, spec.dst, local_ref) {
      Some(dst) =>
        if dst.has_prefix("refs/heads/") {
          let dst_branch = substring_revparse(dst, 11, dst.length())
          return "refs/remotes/" + remote + "/" + dst_branch
        } else {
          return "refs/remotes/" + remote + "/" + branch_name
        }
      None => continue
    }
  }
  // Determine the push destination ref based on push.default
  match push_default {
    "nothing" =>
      raise @object.GitError::InvalidObject(
        "push has no destination (push.default is 'nothing')",
      )
    "upstream" => {
      let cfg = match branches.get(branch_name) {
        Some(c) => c
        None =>
          raise @object.GitError::InvalidObject(
            "no upstream configured for branch '" + branch_name + "'",
          )
      }
      guard cfg.merges.length() > 0 else {
        raise @object.GitError::InvalidObject(
          "no upstream configured for branch '" + branch_name + "'",
        )
      }
      let merge = cfg.merges[0]
      if merge.has_prefix("refs/heads/") {
        let bp = substring_revparse(merge, 11, merge.length())
        "refs/remotes/" + remote + "/" + bp
      } else {
        "refs/remotes/" + remote + "/" + branch_name
      }
    }
    "simple" => {
      // simple: like upstream if same remote and same branch name
      let cfg = branches.get(branch_name)
      let upstream_remote = match cfg {
        Some(c) => c.remote
        None => None
      }
      // Check if triangular (push remote != upstream remote)
      let is_triangular = match upstream_remote {
        Some(ur) => ur != remote
        None => true
      }
      if is_triangular {
        raise @object.GitError::InvalidObject(
          "no upstream configured for branch '" + branch_name + "'",
        )
      }
      // Check upstream branch name matches local branch name
      let upstream_branch = match cfg {
        Some(c) =>
          if c.merges.length() > 0 {
            let m = c.merges[0]
            if m.has_prefix("refs/heads/") {
              Some(substring_revparse(m, 11, m.length()))
            } else {
              None
            }
          } else {
            None
          }
        None => None
      }
      match upstream_branch {
        Some(ub) =>
          if ub != branch_name {
            raise @object.GitError::InvalidObject(
              "no upstream configured for branch '" + branch_name + "'",
            )
          }
        None =>
          raise @object.GitError::InvalidObject(
            "no upstream configured for branch '" + branch_name + "'",
          )
      }
      "refs/remotes/" + remote + "/" + branch_name
    }
    _ =>
      // "current" or "matching" — push to same branch name on remote
      "refs/remotes/" + remote + "/" + branch_name
  }
}

///|
/// Resolve base reference (without suffix)
fn resolve_base_ref(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> @object.ObjectId? raise @object.GitError {
  if spec == "HEAD" || spec == "" || spec == "@" {
    return @bitlib.resolve_head_commit(fs, git_dir)
  }
  if @bitlib.resolve_ref(fs, git_dir, spec) is Some(id) {
    return Some(id)
  }
  if spec.has_prefix("refs/") {
    return @bitlib.resolve_ref(fs, git_dir, spec)
  }
  if spec.has_prefix("heads/") ||
    spec.has_prefix("tags/") ||
    spec.has_prefix("remotes/") {
    return @bitlib.resolve_ref(fs, git_dir, "refs/" + spec)
  }
  if (spec.length() == 40 || spec.length() == 64) &&
    @bithash.is_hex_string(spec) {
    match @object.ObjectId::from_hex(spec) {
      id => return Some(id)
    }
  }
  if resolve_abbrev_ref_id(fs, git_dir, spec) is Some(id) {
    return Some(id)
  }
  if @bitlib.resolve_ref(fs, git_dir, "refs/heads/" + spec) is Some(id) {
    return Some(id)
  }
  if @bitlib.resolve_ref(fs, git_dir, "refs/remotes/" + spec) is Some(id) {
    return Some(id)
  }
  if @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + spec) is Some(id) {
    return Some(id)
  }
  None
}

///|
/// Resolve path within a commit/tree
fn resolve_path_in_commit(
  fs : &@types.RepoFileSystem,
  git_dir : String,
  base_id : @object.ObjectId,
  path : String,
) -> @object.ObjectId? raise @object.GitError {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let obj = db.get(fs, base_id)
  match obj {
    None => return None
    Some(o) => {
      let tree_id = match o.obj_type {
        @object.ObjectType::Commit => @repo.parse_commit(o.data).tree
        @object.ObjectType::Tree => base_id
        _ => return None
      }
      // Empty path means "return the tree itself" (e.g., HEAD:)
      if path.length() == 0 {
        return Some(tree_id)
      }
      let entry = @bitlib.find_tree_entry(db, fs, tree_id, path)
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
  fs : &@types.RepoFileSystem,
  git_dir : String,
) -> Array[(String, @object.ObjectId)] raise @object.GitError {
  let out : Map[String, @object.ObjectId] = {}
  let refs_dir = @repo.join_path(git_dir, "refs")
  if fs.is_dir(refs_dir) {
    ref_collect_loose(fs, git_dir, refs_dir, "refs", out)
  }
  let packed = @repo.join_path(git_dir, "packed-refs")
  if fs.is_file(packed) {
    ref_collect_packed(fs, packed, out)
  }
  let result : Array[(String, @object.ObjectId)] = []
  for item in out.to_array() {
    let (name, id) = item
    result.push((name, id))
  }
  result.sort_by(fn(a, b) {
    let la = a.0.to_array()
    let lb = b.0.to_array()
    let min_len = if la.length() < lb.length() {
      la.length()
    } else {
      lb.length()
    }
    for i in 0..<min_len {
      let ca = la[i].to_int()
      let cb = lb[i].to_int()
      if ca != cb {
        return ca - cb
      }
    }
    la.length() - lb.length()
  })
  result
}

///|
/// Format like `git show-ref` output.
pub fn show_ref_text(
  fs : &@types.RepoFileSystem,
  git_dir : String,
) -> Array[String] raise @object.GitError {
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
  fs : &@types.RepoFileSystem,
  git_dir : String,
  dir : String,
  prefix : String,
  out : Map[String, @object.ObjectId],
) -> Unit raise @object.GitError {
  let entries = fs.readdir(dir)
  for name in entries {
    let path = @repo.join_path(dir, name)
    let rel = if prefix == "" { name } else { prefix + "/" + name }
    if fs.is_dir(path) {
      ref_collect_loose(fs, git_dir, path, rel, out)
    } else if fs.is_file(path) {
      let line = ref_read_line(fs, path)
      if line.has_prefix("ref: ") {
        let target = String::unsafe_substring(line, start=5, end=line.length())
        let resolved = @bitlib.resolve_ref(fs, git_dir, target) catch {
          _ => None
        }
        match resolved {
          Some(id) => out[rel] = id
          None => ()
        }
      } else {
        out[rel] = @object.ObjectId::from_hex(line)
      }
    }
  }
}

///|
fn ref_collect_packed(
  fs : &@types.RepoFileSystem,
  packed_path : String,
  out : Map[String, @object.ObjectId],
) -> Unit raise @object.GitError {
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
        if not(out.contains(name)) {
          out[name] = @object.ObjectId::from_hex(id_hex)
        }
      }
    }
  }
}

///|
fn ref_read_line(
  fs : &@types.RepoFileSystem,
  path : String,
) -> String raise @object.GitError {
  let text = @utf8.decode_lossy(fs.read_file(path)[:])
  for line_view in text.split("\n") {
    let line = ref_trim_line(line_view.to_string())
    if line.length() > 0 {
      return line
    }
  }
  raise @object.GitError::InvalidObject("Empty ref: \{path}")
}

///|
fn ref_trim_line(line : String) -> String {
  let mut s = line
  if s.has_suffix("\r") {
    s = String::unsafe_substring(s, start=0, end=s.length() - 1)
  }
  s
}
