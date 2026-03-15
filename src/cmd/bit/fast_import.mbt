///| git fast-import: Backend for fast data importers

///|
async fn handle_fast_import(args : Array[String]) -> Unit raise Error {
  // Parse arguments
  let mut force = false
  let mut quiet = false
  let mut require_done = false
  let mut import_marks_file : String? = None
  let mut export_marks_file : String? = None
  let mut date_format = "raw"
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git fast-import [<options>]",
          summary="Backend for fast Git data importers.\nReads a stream from stdin describing objects and refs to create.",
        )
        return
      }
      "--force" => force = true
      "--quiet" => quiet = true
      "--stats" => quiet = false
      "--done" => require_done = true
      _ if arg.has_prefix("--import-marks=") =>
        import_marks_file = Some(
          String::unsafe_substring(arg, start=15, end=arg.length()),
        )
      _ if arg.has_prefix("--export-marks=") =>
        export_marks_file = Some(
          String::unsafe_substring(arg, start=15, end=arg.length()),
        )
      _ if arg.has_prefix("--date-format=") =>
        date_format = String::unsafe_substring(arg, start=14, end=arg.length())
      _ if arg.has_prefix("-") => warn_unimplemented_arg("fast-import", arg)
      _ => ()
    }
  }
  let _ = date_format
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let wfs : &@bitcore.FileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  // State
  let marks : Map[Int, @bitcore.ObjectId] = {}
  let branch_heads : Map[String, @bitcore.ObjectId] = {}
  // Load import marks if specified
  if import_marks_file is Some(path) {
    let abs_path = if path.has_prefix("/") { path } else { root + "/" + path }
    let content = decode_bytes(
      rfs.read_file(abs_path) catch {
        _ => Bytes::new(0)
      },
    )
    if content.length() > 0 {
      for line_view in content.split("\n") {
        let line = line_view.to_string()
        if line.length() == 0 {
          continue
        }
        // Format: :N <hex>
        if line.has_prefix(":") {
          match line.find(" ") {
            Some(sp) => {
              let mark_str = String::unsafe_substring(line, start=1, end=sp)
              let hex = String::unsafe_substring(
                line,
                start=sp + 1,
                end=line.length(),
              )
              let mark_num = @strconv.parse_int(mark_str) catch { _ => 0 }
              if mark_num > 0 && hex.length() == 40 {
                marks[mark_num] = @bitcore.ObjectId::from_hex(hex)
              }
            }
            None => ()
          }
        }
      }
    }
  }
  // Read all stdin
  let input = read_all_stdin()
  let input_str = decode_bytes(input)
  // Parse stream
  let parser = FastImportParser::new(input_str)
  let mut num_blobs = 0
  let mut num_commits = 0
  let mut num_tags = 0
  let mut done_seen = false
  // Main parse loop
  while parser.has_more() {
    let cmd = parser.peek_line()
    if cmd.has_prefix("blob") {
      fast_import_parse_blob(parser, marks, wfs, git_dir)
      num_blobs += 1
    } else if cmd.has_prefix("commit ") {
      fast_import_parse_commit(
        parser, marks, branch_heads, wfs, rfs, git_dir, force, db,
      )
      num_commits += 1
    } else if cmd.has_prefix("tag ") {
      fast_import_parse_tag(parser, marks, branch_heads, wfs, rfs, git_dir)
      num_tags += 1
    } else if cmd.has_prefix("reset ") {
      fast_import_parse_reset(parser, marks, branch_heads, rfs, git_dir)
    } else if cmd == "done" {
      parser.skip_line()
      done_seen = true
      break
    } else if cmd.has_prefix("progress ") {
      let msg = String::unsafe_substring(cmd, start=9, end=cmd.length())
      eprint_line(msg)
      parser.skip_line()
    } else if cmd == "checkpoint" {
      parser.skip_line()
      // No-op: all objects already written as loose
    } else if cmd.has_prefix("feature ") {
      let feature = String::unsafe_substring(cmd, start=8, end=cmd.length())
      if feature == "done" {
        require_done = true
      } else if feature.has_prefix("import-marks=") {
        // Handle feature import-marks
        let path = String::unsafe_substring(
          feature,
          start=13,
          end=feature.length(),
        )
        let abs_path = if path.has_prefix("/") {
          path
        } else {
          root + "/" + path
        }
        let content = decode_bytes(
          rfs.read_file(abs_path) catch {
            _ => Bytes::new(0)
          },
        )
        if content.length() > 0 {
          fast_import_load_marks(content, marks)
        }
      } else if feature.has_prefix("export-marks=") {
        export_marks_file = Some(
          String::unsafe_substring(feature, start=13, end=feature.length()),
        )
      }
      // Other features: ignore for now
      parser.skip_line()
    } else if cmd.has_prefix("option ") {
      // Ignore options for now
      parser.skip_line()
    } else if cmd.length() == 0 {
      parser.skip_line()
    } else {
      // Unknown command, skip
      parser.skip_line()
    }
  }
  if require_done && not(done_seen) {
    eprint_line("fatal: stream did not end with 'done' command")
    @sys.exit(1)
  }
  // Write refs
  for ref_name, commit_id in branch_heads {
    write_ref_file(fs, git_dir, ref_name, commit_id)
  }
  // Export marks if specified
  if export_marks_file is Some(path) {
    let abs_path = if path.has_prefix("/") { path } else { root + "/" + path }
    let buf = StringBuilder::new()
    // Sort marks by number for deterministic output
    let mark_keys : Array[Int] = []
    for k, _ in marks {
      mark_keys.push(k)
    }
    mark_keys.sort()
    for k in mark_keys {
      match marks.get(k) {
        Some(id) => {
          buf.write_string(":")
          buf.write_string(k.to_string())
          buf.write_string(" ")
          buf.write_string(id.to_hex())
          buf.write_string("\n")
        }
        None => ()
      }
    }
    let dir = parent_dir(abs_path)
    if dir.length() > 0 {
      ensure_dir(dir)
    }
    fs.write_string(abs_path, buf.to_string())
  }
  // Print stats unless quiet
  if not(quiet) {
    let total = num_blobs + num_commits + num_tags
    eprint_line(
      "fast-import statistics: \{total} objects (\{num_blobs} blobs, \{num_commits} commits, \{num_tags} tags)",
    )
  }
}

///|
fn fast_import_load_marks(
  content : String,
  marks : Map[Int, @bitcore.ObjectId],
) -> Unit {
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    if line.has_prefix(":") {
      match line.find(" ") {
        Some(sp) => {
          let mark_str = String::unsafe_substring(line, start=1, end=sp)
          let hex = String::unsafe_substring(
            line,
            start=sp + 1,
            end=line.length(),
          )
          let mark_num = @strconv.parse_int(mark_str) catch { _ => 0 }
          if mark_num > 0 && hex.length() == 40 {
            marks[mark_num] = @bitcore.ObjectId::from_hex(hex) catch {
              _ => @bitcore.ObjectId::zero()
            }
          }
        }
        None => ()
      }
    }
  }
}

///| Simple line-oriented parser for fast-import stream.
/// We work on the string representation but also keep the raw bytes
/// for binary data sections.
struct FastImportParser {
  lines : Array[String] // pre-split lines
  mut line_idx : Int
}

///|
fn FastImportParser::new(text : String) -> FastImportParser {
  let lines : Array[String] = []
  for lv in text.split("\n") {
    lines.push(lv.to_string())
  }
  { lines, line_idx: 0 }
}

///|
fn FastImportParser::has_more(self : FastImportParser) -> Bool {
  self.line_idx < self.lines.length()
}

///|
fn FastImportParser::peek_line(self : FastImportParser) -> String {
  if self.line_idx < self.lines.length() {
    self.lines[self.line_idx]
  } else {
    ""
  }
}

///|
fn FastImportParser::consume_line(self : FastImportParser) -> String {
  if self.line_idx < self.lines.length() {
    let line = self.lines[self.line_idx]
    self.line_idx += 1
    line
  } else {
    ""
  }
}

///|
fn FastImportParser::skip_line(self : FastImportParser) -> Unit {
  if self.line_idx < self.lines.length() {
    self.line_idx += 1
  }
}

///| Read data command: `data <count>\n<bytes>` or `data <<DELIM\n...\nDELIM\n`
fn FastImportParser::read_data(self : FastImportParser) -> Bytes {
  let line = self.consume_line()
  if not(line.has_prefix("data ")) {
    return Bytes::new(0)
  }
  let rest = String::unsafe_substring(line, start=5, end=line.length())
  if rest.has_prefix("<<") {
    // Delimited form
    let delim = String::unsafe_substring(rest, start=2, end=rest.length())
    let buf : Array[Byte] = []
    while self.has_more() {
      let l = self.consume_line()
      if l == delim {
        break
      }
      if buf.length() > 0 {
        buf.push(b'\n')
      }
      for c in l {
        buf.push(c.to_int().to_byte())
      }
    }
    bytes_from_array(buf)
  } else {
    // Exact byte count form
    let count = @strconv.parse_int(rest) catch { _ => 0 }
    if count == 0 {
      return Bytes::new(0)
    }
    // We need to read exactly `count` bytes from the remaining lines.
    // Since we pre-split by \n, we need to reconstruct bytes from lines
    // accounting for the newlines between them.
    let buf : Array[Byte] = []
    let mut remaining = count
    while remaining > 0 && self.has_more() {
      let l = self.lines[self.line_idx]
      // Each line was split by \n, so between lines there's an implicit \n
      let line_bytes = fast_import_string_byte_count(l)
      if buf.length() > 0 {
        // Account for the \n separator that was stripped by split
        if remaining > 0 {
          buf.push(b'\n')
          remaining -= 1
        }
      }
      if line_bytes <= remaining {
        // Consume entire line
        for c in l {
          buf.push(c.to_int().to_byte())
        }
        remaining -= line_bytes
        self.line_idx += 1
      } else {
        // Partial line: take only `remaining` bytes
        let mut taken = 0
        for c in l {
          if taken >= remaining {
            break
          }
          buf.push(c.to_int().to_byte())
          taken += 1
        }
        remaining = 0
        // Don't consume line - but we need to handle this carefully.
        // In practice, data sections end on line boundaries.
        // We advance past this line since we've read into it.
        self.line_idx += 1
      }
    }
    // After data, there may be a trailing LF (blank line) — consume it
    if self.has_more() && self.peek_line().length() == 0 {
      self.skip_line()
    }
    bytes_from_array(buf)
  }
}

///| Count bytes in a string (ASCII characters = 1 byte each)
fn fast_import_string_byte_count(s : String) -> Int {
  let mut count = 0
  for _c in s {
    count += 1
  }
  count
}

///| Resolve a dataref: either `:N` (mark) or 40-char hex SHA
fn fast_import_resolve_dataref(
  ref_str : String,
  marks : Map[Int, @bitcore.ObjectId],
) -> @bitcore.ObjectId {
  if ref_str.has_prefix(":") {
    let mark_str = String::unsafe_substring(
      ref_str,
      start=1,
      end=ref_str.length(),
    )
    let mark_num = @strconv.parse_int(mark_str) catch { _ => 0 }
    marks.get(mark_num).unwrap_or(@bitcore.ObjectId::zero())
  } else if ref_str.length() == 40 {
    @bitcore.ObjectId::from_hex(ref_str) catch { _ => @bitcore.ObjectId::zero() }
  } else {
    @bitcore.ObjectId::zero()
  }
}

///| Resolve a committish: mark, hex, or ref name
fn fast_import_resolve_committish(
  ref_str : String,
  marks : Map[Int, @bitcore.ObjectId],
  branch_heads : Map[String, @bitcore.ObjectId],
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> @bitcore.ObjectId {
  if ref_str.has_prefix(":") {
    return fast_import_resolve_dataref(ref_str, marks)
  }
  if ref_str.length() == 40 {
    return @bitcore.ObjectId::from_hex(ref_str) catch {
      _ => @bitcore.ObjectId::zero()
    }
  }
  // Try branch_heads first
  match branch_heads.get(ref_str) {
    Some(id) => return id
    None => ()
  }
  // Try reading ref from disk
  let ref_path = if ref_str.has_prefix("refs/") {
    git_dir + "/" + ref_str
  } else {
    git_dir + "/refs/heads/" + ref_str
  }
  let content = decode_bytes(
    fs.read_file(ref_path) catch {
      _ => return @bitcore.ObjectId::zero()
    },
  )
  let hex = fast_import_trim(content)
  if hex.length() == 40 {
    @bitcore.ObjectId::from_hex(hex) catch { _ => @bitcore.ObjectId::zero() }
  } else {
    @bitcore.ObjectId::zero()
  }
}

///| Trim whitespace from string
fn fast_import_trim(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  while start < end &&
    (chars[start] == ' ' || chars[start] == '\n' || chars[start] == '\r' ||
    chars[start] == '\t') {
    start += 1
  }
  while end > start &&
    (chars[end - 1] == ' ' || chars[end - 1] == '\n' || chars[end - 1] == '\r' ||
    chars[end - 1] == '\t') {
    end -= 1
  }
  if start == 0 && end == s.length() {
    s
  } else {
    let buf = StringBuilder::new()
    for i in start..<end {
      buf.write_char(chars[i])
    }
    buf.to_string()
  }
}

///| Parse a blob command
async fn fast_import_parse_blob(
  parser : FastImportParser,
  marks : Map[Int, @bitcore.ObjectId],
  fs : &@bitcore.FileSystem,
  git_dir : String,
) -> Unit {
  parser.skip_line() // "blob"
  // Optional mark
  let mut mark_num = 0
  if parser.has_more() && parser.peek_line().has_prefix("mark :") {
    let mark_line = parser.consume_line()
    let mark_str = String::unsafe_substring(
      mark_line,
      start=6,
      end=mark_line.length(),
    )
    mark_num = @strconv.parse_int(mark_str) catch { _ => 0 }
  }
  // data
  let data = parser.read_data()
  let blob_id = @bitlib.write_loose_object(
    fs,
    git_dir,
    @bitcore.ObjectType::Blob,
    data,
  )
  if mark_num > 0 {
    marks[mark_num] = blob_id
  }
}

///| Parse author/committer line: `Name <email> timestamp tz`
fn fast_import_parse_ident(
  line : String,
) -> (String, Int64, String) {
  // Format: "Name <email> timestamp tz"
  // Find the last '>' to split ident from timestamp
  let chars : Array[Char] = []
  for c in line {
    chars.push(c)
  }
  let mut gt_pos = -1
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    if chars[i] == '>' {
      gt_pos = i
      break
    }
  }
  if gt_pos < 0 {
    return (line, 0L, "+0000")
  }
  // ident is everything up to and including '>'
  let ident_buf = StringBuilder::new()
  for i in 0..=gt_pos {
    ident_buf.write_char(chars[i])
  }
  let ident = ident_buf.to_string()
  // After '>' there should be " timestamp tz"
  let rest_buf = StringBuilder::new()
  for i in (gt_pos + 1)..<chars.length() {
    rest_buf.write_char(chars[i])
  }
  let rest = fast_import_trim(rest_buf.to_string())
  // Split rest by space: "timestamp tz"
  match rest.find(" ") {
    Some(sp) => {
      let ts_str = String::unsafe_substring(rest, start=0, end=sp)
      let tz = String::unsafe_substring(rest, start=sp + 1, end=rest.length())
      let ts = @strconv.parse_int64(ts_str) catch { _ => 0L }
      (ident, ts, tz)
    }
    None => {
      let ts = @strconv.parse_int64(rest) catch { _ => 0L }
      (ident, ts, "+0000")
    }
  }
}

///| Parse a commit command
async fn fast_import_parse_commit(
  parser : FastImportParser,
  marks : Map[Int, @bitcore.ObjectId],
  branch_heads : Map[String, @bitcore.ObjectId],
  fs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  _force : Bool,
  db : @bitlib.ObjectDb,
) -> Unit {
  let commit_line = parser.consume_line() // "commit <ref>"
  let ref_name = String::unsafe_substring(
    commit_line,
    start=7,
    end=commit_line.length(),
  )
  // Optional mark
  let mut mark_num = 0
  if parser.has_more() && parser.peek_line().has_prefix("mark :") {
    let mark_line = parser.consume_line()
    let mark_str = String::unsafe_substring(
      mark_line,
      start=6,
      end=mark_line.length(),
    )
    mark_num = @strconv.parse_int(mark_str) catch { _ => 0 }
  }
  // Optional author
  let mut author_ident = ""
  let mut author_time = 0L
  let mut author_tz = "+0000"
  if parser.has_more() && parser.peek_line().has_prefix("author ") {
    let author_line = parser.consume_line()
    let author_rest = String::unsafe_substring(
      author_line,
      start=7,
      end=author_line.length(),
    )
    let result = fast_import_parse_ident(author_rest)
    author_ident = result.0
    author_time = result.1
    author_tz = result.2
  }
  // Required committer
  let mut committer_ident = ""
  let mut committer_time = 0L
  let mut committer_tz = "+0000"
  if parser.has_more() && parser.peek_line().has_prefix("committer ") {
    let committer_line = parser.consume_line()
    let committer_rest = String::unsafe_substring(
      committer_line,
      start=10,
      end=committer_line.length(),
    )
    let result = fast_import_parse_ident(committer_rest)
    committer_ident = result.0
    committer_time = result.1
    committer_tz = result.2
  }
  // If author not specified, use committer
  if author_ident == "" {
    author_ident = committer_ident
    author_time = committer_time
    author_tz = committer_tz
  }
  // Commit message (data command)
  let message_bytes = parser.read_data()
  let message = decode_bytes(message_bytes)
  // Parents
  let parents : Array[@bitcore.ObjectId] = []
  // Optional from
  if parser.has_more() && parser.peek_line().has_prefix("from ") {
    let from_line = parser.consume_line()
    let from_ref = String::unsafe_substring(
      from_line,
      start=5,
      end=from_line.length(),
    )
    let parent_id = fast_import_resolve_committish(
      from_ref, marks, branch_heads, rfs, git_dir,
    )
    if parent_id != @bitcore.ObjectId::zero() {
      parents.push(parent_id)
    }
  } else {
    // If no from, use the current branch head as parent (if any)
    match branch_heads.get(ref_name) {
      Some(id) => parents.push(id)
      None => ()
    }
  }
  // Optional merge (can repeat)
  while parser.has_more() && parser.peek_line().has_prefix("merge ") {
    let merge_line = parser.consume_line()
    let merge_ref = String::unsafe_substring(
      merge_line,
      start=6,
      end=merge_line.length(),
    )
    let merge_id = fast_import_resolve_committish(
      merge_ref, marks, branch_heads, rfs, git_dir,
    )
    if merge_id != @bitcore.ObjectId::zero() {
      parents.push(merge_id)
    }
  }
  // File operations — build tree state
  // Start from parent tree if we have one
  let tree_state : Map[String, (String, @bitcore.ObjectId)] = {}
  if parents.length() > 0 {
    // Load tree from first parent
    fast_import_load_tree_recursive(db, rfs, parents[0], tree_state)
  }
  // Process file operations
  while parser.has_more() {
    let line = parser.peek_line()
    if line.has_prefix("M ") {
      parser.skip_line()
      fast_import_parse_filemodify(line, marks, fs, git_dir, tree_state, parser)
    } else if line.has_prefix("D ") {
      parser.skip_line()
      let path = String::unsafe_substring(line, start=2, end=line.length())
      // Remove the path and any entries under it (directory delete)
      let to_remove : Array[String] = []
      for key, _ in tree_state {
        if key == path || key.has_prefix(path + "/") {
          to_remove.push(key)
        }
      }
      for key in to_remove {
        tree_state.remove(key)
      }
    } else if line == "deleteall" {
      parser.skip_line()
      tree_state.clear()
    } else if line.has_prefix("R ") {
      parser.skip_line()
      // Rename: R <old> <new>
      let rest = String::unsafe_substring(line, start=2, end=line.length())
      match fast_import_split_two_paths(rest) {
        Some((old_path, new_path)) => {
          match tree_state.get(old_path) {
            Some(entry) => {
              tree_state.remove(old_path)
              tree_state[new_path] = entry
            }
            None => ()
          }
        }
        None => ()
      }
    } else if line.has_prefix("C ") {
      parser.skip_line()
      // Copy: C <old> <new>
      let rest = String::unsafe_substring(line, start=2, end=line.length())
      match fast_import_split_two_paths(rest) {
        Some((old_path, new_path)) => {
          match tree_state.get(old_path) {
            Some(entry) => tree_state[new_path] = entry
            None => ()
          }
        }
        None => ()
      }
    } else if line.has_prefix("N ") {
      // Note command — skip for now
      parser.skip_line()
    } else {
      break
    }
  }
  // Build tree hierarchy from flat path map
  let tree_id = fast_import_build_tree(tree_state, fs, git_dir)
  // Create commit
  let commit = @bitcore.Commit::new(
    tree_id,
    parents,
    author_ident,
    author_time,
    author_tz,
    committer_ident,
    committer_time,
    committer_tz,
    message,
  )
  let (commit_id, compressed) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(fs, git_dir, commit_id, compressed)
  // Update marks and branch heads
  if mark_num > 0 {
    marks[mark_num] = commit_id
  }
  branch_heads[ref_name] = commit_id
}

///| Parse inline data or resolve dataref for M command
async fn fast_import_parse_filemodify(
  line : String,
  marks : Map[Int, @bitcore.ObjectId],
  fs : &@bitcore.FileSystem,
  git_dir : String,
  tree_state : Map[String, (String, @bitcore.ObjectId)],
  parser : FastImportParser,
) -> Unit {
  // M <mode> <dataref> <path>
  // or M <mode> inline <path> followed by data command
  let rest = String::unsafe_substring(line, start=2, end=line.length())
  // Split: mode space rest
  match rest.find(" ") {
    Some(sp1) => {
      let mode = String::unsafe_substring(rest, start=0, end=sp1)
      let after_mode = String::unsafe_substring(
        rest,
        start=sp1 + 1,
        end=rest.length(),
      )
      match after_mode.find(" ") {
        Some(sp2) => {
          let dataref = String::unsafe_substring(after_mode, start=0, end=sp2)
          let path = fast_import_unquote_path(
            String::unsafe_substring(
              after_mode,
              start=sp2 + 1,
              end=after_mode.length(),
            ),
          )
          if dataref == "inline" {
            // Read inline data
            let data = parser.read_data()
            let blob_id = @bitlib.write_loose_object(
              fs,
              git_dir,
              @bitcore.ObjectType::Blob,
              data,
            )
            tree_state[path] = (mode, blob_id)
          } else {
            let blob_id = fast_import_resolve_dataref(dataref, marks)
            tree_state[path] = (mode, blob_id)
          }
        }
        None => ()
      }
    }
    None => ()
  }
}

///| Unquote a C-style quoted path (e.g., "foo/bar" → foo/bar)
fn fast_import_unquote_path(path : String) -> String {
  if path.has_prefix("\"") && path.length() > 1 {
    // Remove quotes and unescape
    let inner = String::unsafe_substring(path, start=1, end=path.length())
    let inner = if inner.length() > 0 {
      // Check for trailing quote
      let chars : Array[Char] = []
      for c in inner {
        chars.push(c)
      }
      if chars.length() > 0 && chars[chars.length() - 1] == '"' {
        let buf = StringBuilder::new()
        for i in 0..<(chars.length() - 1) {
          buf.write_char(chars[i])
        }
        buf.to_string()
      } else {
        inner
      }
    } else {
      inner
    }
    // Simple unescape: handle \\, \n, \t, \"
    let chars : Array[Char] = []
    for c in inner {
      chars.push(c)
    }
    let buf = StringBuilder::new()
    let mut i = 0
    while i < chars.length() {
      if chars[i] == '\\' && i + 1 < chars.length() {
        match chars[i + 1] {
          'n' => buf.write_char('\n')
          't' => buf.write_char('\t')
          '\\' => buf.write_char('\\')
          '"' => buf.write_char('"')
          _ => {
            buf.write_char('\\')
            buf.write_char(chars[i + 1])
          }
        }
        i += 2
      } else {
        buf.write_char(chars[i])
        i += 1
      }
    }
    buf.to_string()
  } else {
    path
  }
}

///| Split two space-separated paths, handling quoted paths
fn fast_import_split_two_paths(s : String) -> (String, String)? {
  if s.has_prefix("\"") {
    // First path is quoted — find closing quote
    let chars : Array[Char] = []
    for c in s {
      chars.push(c)
    }
    let mut i = 1
    while i < chars.length() {
      if chars[i] == '"' && (i == 0 || chars[i - 1] != '\\') {
        let first = String::unsafe_substring(s, start=0, end=i + 1)
        let rest = if i + 2 < chars.length() {
          String::unsafe_substring(s, start=i + 2, end=chars.length())
        } else {
          ""
        }
        return Some(
          (fast_import_unquote_path(first), fast_import_unquote_path(rest)),
        )
      }
      i += 1
    }
    None
  } else {
    match s.find(" ") {
      Some(sp) => {
        let first = String::unsafe_substring(s, start=0, end=sp)
        let second = String::unsafe_substring(
          s,
          start=sp + 1,
          end=s.length(),
        )
        Some((first, fast_import_unquote_path(second)))
      }
      None => None
    }
  }
}

///| Load tree entries recursively from a commit into the flat path map
async fn fast_import_load_tree_recursive(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  commit_id : @bitcore.ObjectId,
  tree_state : Map[String, (String, @bitcore.ObjectId)],
) -> Unit {
  // Read commit object to get tree ID
  let commit_obj = db.get(fs, commit_id) catch { _ => return }
  match commit_obj {
    None => return
    Some(obj) => {
      if obj.obj_type != @bitcore.ObjectType::Commit {
        return
      }
      let info = @bitcore.parse_commit(obj.data)
      fast_import_load_tree_entries(db, fs, info.tree, "", tree_state)
    }
  }
}

///| Recursively load tree entries into flat path map
async fn fast_import_load_tree_entries(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  tree_id : @bitcore.ObjectId,
  prefix : String,
  tree_state : Map[String, (String, @bitcore.ObjectId)],
) -> Unit {
  let tree_obj = db.get(fs, tree_id) catch { _ => return }
  match tree_obj {
    None => return
    Some(obj) => {
      let entries = @bitcore.parse_tree(obj.data)
      for entry in entries {
        let full_path = if prefix.length() > 0 {
          prefix + "/" + entry.name
        } else {
          entry.name
        }
        if entry.mode == "40000" || entry.mode == "040000" {
          // Recurse into subtree
          fast_import_load_tree_entries(
            db, fs, entry.id, full_path, tree_state,
          )
        } else {
          tree_state[full_path] = (entry.mode, entry.id)
        }
      }
    }
  }
}

///| Build a tree hierarchy from flat path→(mode, id) map.
/// Returns the root tree ObjectId.
async fn fast_import_build_tree(
  tree_state : Map[String, (String, @bitcore.ObjectId)],
  fs : &@bitcore.FileSystem,
  git_dir : String,
) -> @bitcore.ObjectId {
  // Group entries by top-level directory component
  // For each directory, recursively build subtrees
  let top_entries : Map[String, (String, @bitcore.ObjectId)] = {} // direct files
  let subtrees : Map[String, Map[String, (String, @bitcore.ObjectId)]] = {} // dir → sub-entries
  for path, entry in tree_state {
    match path.find("/") {
      Some(slash) => {
        let dir = String::unsafe_substring(path, start=0, end=slash)
        let rest = String::unsafe_substring(
          path,
          start=slash + 1,
          end=path.length(),
        )
        match subtrees.get(dir) {
          Some(sub) => sub[rest] = entry
          None => {
            let sub : Map[String, (String, @bitcore.ObjectId)] = {}
            sub[rest] = entry
            subtrees[dir] = sub
          }
        }
      }
      None => top_entries[path] = entry
    }
  }
  // Build tree entries
  let entries : Array[@bitcore.TreeEntry] = []
  // Add files
  for name, entry in top_entries {
    entries.push(@bitcore.TreeEntry::new(entry.0, name, entry.1))
  }
  // Recursively build subtrees
  for dir_name, sub_state in subtrees {
    let sub_tree_id = fast_import_build_tree(sub_state, fs, git_dir)
    entries.push(@bitcore.TreeEntry::new("40000", dir_name, sub_tree_id))
  }
  // Sort entries by name (git requires sorted tree entries)
  entries.sort_by(fn(a, b) {
    // git sorts tree entries with trailing '/' for directories
    let a_name = if a.mode == "40000" || a.mode == "040000" {
      a.name + "/"
    } else {
      a.name
    }
    let b_name = if b.mode == "40000" || b.mode == "040000" {
      b.name + "/"
    } else {
      b.name
    }
    a_name.compare(b_name)
  })
  if entries.length() == 0 {
    // Empty tree
    let (tree_id, compressed) = @bitcore.create_tree([])
    @bitlib.write_object_bytes(fs, git_dir, tree_id, compressed)
    return tree_id
  }
  let (tree_id, compressed) = @bitcore.create_tree(entries)
  @bitlib.write_object_bytes(fs, git_dir, tree_id, compressed)
  tree_id
}

///| Parse a tag command
async fn fast_import_parse_tag(
  parser : FastImportParser,
  marks : Map[Int, @bitcore.ObjectId],
  branch_heads : Map[String, @bitcore.ObjectId],
  fs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Unit {
  let tag_line = parser.consume_line() // "tag <name>"
  let tag_name = String::unsafe_substring(
    tag_line,
    start=4,
    end=tag_line.length(),
  )
  // Optional mark
  let mut mark_num = 0
  if parser.has_more() && parser.peek_line().has_prefix("mark :") {
    let mark_line = parser.consume_line()
    let mark_str = String::unsafe_substring(
      mark_line,
      start=6,
      end=mark_line.length(),
    )
    mark_num = @strconv.parse_int(mark_str) catch { _ => 0 }
  }
  // from
  let mut target_id = @bitcore.ObjectId::zero()
  if parser.has_more() && parser.peek_line().has_prefix("from ") {
    let from_line = parser.consume_line()
    let from_ref = String::unsafe_substring(
      from_line,
      start=5,
      end=from_line.length(),
    )
    target_id = fast_import_resolve_committish(
      from_ref, marks, branch_heads, rfs, git_dir,
    )
  }
  // Optional tagger
  let mut tagger_line = ""
  if parser.has_more() && parser.peek_line().has_prefix("tagger ") {
    let tl = parser.consume_line()
    tagger_line = String::unsafe_substring(tl, start=7, end=tl.length())
  }
  // data (tag message)
  let message_bytes = parser.read_data()
  let message = decode_bytes(message_bytes)
  // Build tag object content
  let buf = StringBuilder::new()
  buf.write_string("object ")
  buf.write_string(target_id.to_hex())
  buf.write_string("\n")
  buf.write_string("type commit\n")
  buf.write_string("tag ")
  buf.write_string(tag_name)
  buf.write_string("\n")
  if tagger_line.length() > 0 {
    buf.write_string("tagger ")
    buf.write_string(tagger_line)
    buf.write_string("\n")
  }
  buf.write_string("\n")
  buf.write_string(message)
  let tag_content_str = buf.to_string()
  let tag_content : Array[Byte] = []
  for c in tag_content_str {
    tag_content.push(c.to_int().to_byte())
  }
  let tag_bytes = bytes_from_array(tag_content)
  let tag_id = @bitlib.write_loose_object(
    fs,
    git_dir,
    @bitcore.ObjectType::Tag,
    tag_bytes,
  )
  if mark_num > 0 {
    marks[mark_num] = tag_id
  }
  // Write tag ref
  let ref_path = git_dir + "/refs/tags/" + tag_name
  let dir = parent_dir(ref_path)
  if dir.length() > 0 {
    ensure_dir(dir)
  }
  let osfs = OsFs::new()
  osfs.write_string(ref_path, tag_id.to_hex() + "\n")
}

///| Parse a reset command
async fn fast_import_parse_reset(
  parser : FastImportParser,
  marks : Map[Int, @bitcore.ObjectId],
  branch_heads : Map[String, @bitcore.ObjectId],
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Unit {
  let reset_line = parser.consume_line() // "reset <ref>"
  let ref_name = String::unsafe_substring(
    reset_line,
    start=6,
    end=reset_line.length(),
  )
  // Optional from
  if parser.has_more() && parser.peek_line().has_prefix("from ") {
    let from_line = parser.consume_line()
    let from_ref = String::unsafe_substring(
      from_line,
      start=5,
      end=from_line.length(),
    )
    let commit_id = fast_import_resolve_committish(
      from_ref, marks, branch_heads, fs, git_dir,
    )
    branch_heads[ref_name] = commit_id
  } else {
    // Reset without from: remove branch head
    branch_heads.remove(ref_name)
  }
  // Consume optional LF
  if parser.has_more() && parser.peek_line().length() == 0 {
    parser.skip_line()
  }
}
