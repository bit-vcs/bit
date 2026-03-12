///|

///|
async fn show_show_command_help() -> Unit {
  show_simple_command_help(
    "git show [<options>] [<object>...]",
    summary="Show various types of objects.",
  )
}

///|
priv struct ShowCommitInfo {
  author : String
  timestamp : Int64
  timezone : String
  message : String
}

///|
priv struct ShowTagInfo {
  target : @bitcore.ObjectId
  name : String
  tagger : String
  timestamp : Int64
  timezone : String
  message : String
}

///|
priv struct ShowArgs {
  revs : Array[String]
  range_excludes : Array[String]
  pretty_raw : Bool
  pretty_format : String?
  quiet : Bool
  oneline : Bool
  grep_patterns : Array[String]
  grep_pattern_type_override : GrepPatternType?
  grep_ignore_case : Bool
  graph_requested : Bool
  walk_mode : Bool
  max_count : Int
}

///|
fn parse_show_commit(data : Bytes) -> ShowCommitInfo {
  let text = decode_bytes(data)
  let mut author = ""
  let mut timestamp = 0L
  let mut timezone = "+0000"
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
      // format: Name <email> 1700000000 +0000
      let mut last_space = rest.rev_find(" ")
      if last_space is Some(tz_idx) {
        let before_tz = String::unsafe_substring(rest, start=0, end=tz_idx)
        timezone = String::unsafe_substring(
          rest,
          start=tz_idx + 1,
          end=rest.length(),
        )
        last_space = before_tz.rev_find(" ")
        if last_space is Some(time_idx) {
          author = String::unsafe_substring(before_tz, start=0, end=time_idx)
          let time_str = String::unsafe_substring(
            before_tz,
            start=time_idx + 1,
            end=before_tz.length(),
          )
          for c in time_str {
            if c >= '0' && c <= '9' {
              let digit = c.to_int() - '0'.to_int()
              timestamp = timestamp * 10L + digit.to_int64()
            }
          }
        } else {
          author = before_tz
        }
      } else {
        author = rest
      }
    }
  }
  let message = message_lines.join("\n")
  { author, timestamp, timezone, message }
}

///|
fn show_first_message_line(message : String) -> String {
  match message.find("\n") {
    Some(idx) => String::unsafe_substring(message, start=0, end=idx)
    None => message
  }
}

///|
fn format_show_date(timestamp : Int64, timezone : String) -> String {
  let tz_offset = parse_timezone_offset_seconds(timezone)
  let local_seconds = timestamp.to_int() + tz_offset
  let days = local_seconds / 86400
  let time_of_day = local_seconds % 86400
  let hours = time_of_day / 3600
  let minutes = time_of_day % 3600 / 60
  let seconds = time_of_day % 60
  let (year, month, day) = days_to_date(days)
  let weekday = (days + 4) % 7 // Jan 1, 1970 was Thursday.
  let weekday_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  let month_names = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let wd = weekday_names[weekday]
  let mn = month_names[month - 1]
  "\{wd} \{mn} \{day} \{pad_left_zero(hours.to_string(), 2)}:\{pad_left_zero(minutes.to_string(), 2)}:\{pad_left_zero(seconds.to_string(), 2)} \{year} \{timezone}"
}

///|
fn parse_timezone_offset_seconds(timezone : String) -> Int {
  if timezone.length() != 5 {
    return 0
  }
  let sign = timezone.unsafe_get(0)
  if sign != '+' && sign != '-' {
    return 0
  }
  let hh = String::unsafe_substring(timezone, start=1, end=3)
  let mm = String::unsafe_substring(timezone, start=3, end=5)
  let hours = @strconv.parse_int(hh) catch { _ => return 0 }
  let minutes = @strconv.parse_int(mm) catch { _ => return 0 }
  let total = hours * 3600 + minutes * 60
  if sign == '-' {
    -total
  } else {
    total
  }
}

///|
fn show_parse_person_ident(rest : String) -> (String, Int64, String) {
  let mut ident = rest
  let mut timestamp = 0L
  let mut timezone = "+0000"
  let mut last_space = rest.rev_find(" ")
  if last_space is Some(tz_idx) {
    let before_tz = String::unsafe_substring(rest, start=0, end=tz_idx)
    timezone = String::unsafe_substring(
      rest,
      start=tz_idx + 1,
      end=rest.length(),
    )
    last_space = before_tz.rev_find(" ")
    if last_space is Some(time_idx) {
      ident = String::unsafe_substring(before_tz, start=0, end=time_idx)
      let time_str = String::unsafe_substring(
        before_tz,
        start=time_idx + 1,
        end=before_tz.length(),
      )
      for c in time_str {
        if c >= '0' && c <= '9' {
          let digit = c.to_int() - '0'.to_int()
          timestamp = timestamp * 10L + digit.to_int64()
        }
      }
    } else {
      ident = before_tz
    }
  }
  (ident, timestamp, timezone)
}

///|
fn show_parse_tag_info(data : Bytes) -> ShowTagInfo? {
  let text = decode_bytes(data)
  let mut target : @bitcore.ObjectId? = None
  let mut name = ""
  let mut tagger = ""
  let mut timestamp = 0L
  let mut timezone = "+0000"
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
    if line.has_prefix("object ") {
      let hex = String::unsafe_substring(line, start=7, end=line.length())
      target = Some(@bitcore.ObjectId::from_hex(hex) catch { _ => return None })
    } else if line.has_prefix("tag ") {
      name = String::unsafe_substring(line, start=4, end=line.length())
    } else if line.has_prefix("tagger ") {
      let rest = String::unsafe_substring(line, start=7, end=line.length())
      let (parsed_tagger, parsed_timestamp, parsed_timezone) = show_parse_person_ident(
        rest,
      )
      tagger = parsed_tagger
      timestamp = parsed_timestamp
      timezone = parsed_timezone
    }
  }
  match target {
    Some(target_id) =>
      Some({
        target: target_id,
        name,
        tagger,
        timestamp,
        timezone,
        message: message_lines.join("\n"),
      })
    None => None
  }
}

///|
fn show_is_directory_mode(mode : String) -> Bool {
  mode == "40000" || mode == "040000"
}

///|
fn show_render_tree_lines(
  spec : String,
  entries : Array[@bitcore.TreeEntry],
) -> Array[String] {
  let lines : Array[String] = ["tree \{spec}", ""]
  for entry in entries {
    let name = if show_is_directory_mode(entry.mode) {
      entry.name + "/"
    } else {
      entry.name
    }
    lines.push(name)
  }
  lines
}

///|
fn show_parse_args(args : Array[String]) -> ShowArgs {
  let revs : Array[String] = []
  let range_excludes : Array[String] = []
  let symmetric_ranges : Array[(String, String)] = []
  let grep_patterns : Array[String] = []
  let mut pretty_raw = false
  let mut pretty_format : String? = None
  let mut quiet = false
  let mut oneline = false
  let mut grep_pattern_type_override : GrepPatternType? = None
  let mut grep_ignore_case = false
  let mut graph_requested = false
  let mut walk_mode = false
  let mut max_count = 1
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--pretty=raw" || arg == "--format=raw" {
      pretty_raw = true
    } else if arg == "-q" ||
      arg == "--quiet" ||
      arg == "-s" ||
      arg == "--no-patch" {
      quiet = true
    } else if arg == "--oneline" {
      oneline = true
    } else if arg == "--graph" {
      graph_requested = true
    } else if is_short_count_flag(arg) {
      let raw = String::unsafe_substring(arg, start=1, end=arg.length())
      max_count = @strconv.parse_int(raw) catch { _ => 1 }
      walk_mode = true
    } else if arg.has_prefix("--pretty=format:") {
      pretty_format = Some(
        String::unsafe_substring(arg, start=16, end=arg.length()),
      )
    } else if arg.has_prefix("--pretty=tformat:") {
      pretty_format = Some(
        String::unsafe_substring(arg, start=17, end=arg.length()),
      )
    } else if arg.has_prefix("--pretty=") {
      pretty_format = Some(
        String::unsafe_substring(arg, start=9, end=arg.length()),
      )
    } else if arg.has_prefix("--format=") {
      pretty_format = Some(
        String::unsafe_substring(arg, start=9, end=arg.length()),
      )
    } else if arg == "--grep" && i + 1 < args.length() {
      grep_patterns.push(args[i + 1])
      i += 1
    } else if arg.has_prefix("--grep=") {
      grep_patterns.push(
        String::unsafe_substring(arg, start=7, end=arg.length()),
      )
    } else if arg == "-i" || arg == "--regexp-ignore-case" {
      grep_ignore_case = true
    } else if arg == "-F" || arg == "--fixed-strings" {
      grep_pattern_type_override = Some(GrepPatternType::Fixed)
    } else if arg == "-E" || arg == "--extended-regexp" {
      grep_pattern_type_override = Some(GrepPatternType::Extended)
    } else if arg == "-P" || arg == "--perl-regexp" {
      grep_pattern_type_override = Some(GrepPatternType::Perl)
    } else if arg == "--basic-regexp" {
      grep_pattern_type_override = Some(GrepPatternType::Basic)
    } else if arg.has_prefix("^") &&
      arg.length() > 1 &&
      not(arg.has_prefix("^{")) {
      range_excludes.push(
        String::unsafe_substring(arg, start=1, end=arg.length()),
      )
      walk_mode = true
    } else if not(arg.has_prefix("-")) {
      if log_find_dotdot(arg) >= 0 || log_find_tripledot(arg) >= 0 {
        log_add_revision_input(arg, revs, range_excludes, symmetric_ranges)
        walk_mode = true
      } else {
        revs.push(arg)
      }
    }
    i += 1
  }
  {
    revs,
    range_excludes,
    pretty_raw,
    pretty_format,
    quiet,
    oneline,
    grep_patterns,
    grep_pattern_type_override,
    grep_ignore_case,
    graph_requested,
    walk_mode,
    max_count,
  }
}

///|
fn show_lines_to_block(lines : Array[String]) -> String {
  if lines.length() == 0 {
    ""
  } else {
    lines.join("\n") + "\n"
  }
}

///|
fn show_concat_blocks(blocks : Array[String], compact : Bool) -> String {
  if blocks.length() == 0 {
    return ""
  }
  let mut out = blocks[0]
  for i in 1..<blocks.length() {
    if compact {
      if not(out.has_suffix("\n")) {
        out = out + "\n"
      }
    } else {
      if not(out.has_suffix("\n")) {
        out = out + "\n"
      }
      out = out + "\n"
    }
    out = out + blocks[i]
  }
  out
}

///|
fn show_resolve_index_object_id(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  target : String,
) -> @bitcore.ObjectId? {
  guard target.has_prefix(":") && target.length() > 1 else { return None }
  let path = cat_file_normalize_spec_path(
    String::unsafe_substring(target, start=1, end=target.length()),
  )
  let entries = @bitlib.read_index_entries(fs, git_dir) catch { _ => [] }
  for entry in entries {
    if entry.path == path {
      return Some(entry.id)
    }
  }
  None
}

///|
fn show_resolve_target_object_id(
  fs : OsFs,
  git_dir : String,
  target : String,
  db : @bitlib.ObjectDb,
) -> @bitcore.ObjectId? raise Error {
  match show_resolve_index_object_id(fs, git_dir, target) {
    Some(index_id) => Some(index_id)
    None =>
      match cat_file_split_object_path_spec(target) {
        Some((rev_part, path_part)) =>
          match cat_file_rev_parse_with_compat(fs, git_dir, rev_part) {
            Some(base_id) =>
              match
                cat_file_find_tree_entry_from_base(db, fs, base_id, path_part) {
                Some(entry) => Some(entry.id)
                None => None
              }
            None => None
          }
        None => @bitrepo.rev_parse(fs, git_dir, target)
      }
  }
}

///|
fn show_render_commit_block(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  commit_id : @bitcore.ObjectId,
  data : Bytes,
  pretty_raw : Bool,
  pretty_format : String?,
  quiet : Bool,
  oneline : Bool,
  grep_patterns : Array[String],
  grep_pattern_type : GrepPatternType,
  grep_ignore_case : Bool,
) -> String? raise Error {
  let show_info = parse_show_commit(data)
  if not(
      grep_patterns_match_message(
        show_info.message,
        grep_patterns,
        grep_pattern_type,
        grep_ignore_case,
      ),
    ) {
    return None
  }
  if pretty_raw {
    let text = decode_bytes(data)
    let mut block = "commit \{commit_id.to_hex()}\n" + text
    if not(text.has_suffix("\n")) {
      block = block + "\n"
    }
    return Some(block)
  }
  if pretty_format is Some(fmt) {
    match fmt {
      "%h" => {
        let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
        return Some(short + "\n")
      }
      "%H" => return Some(commit_id.to_hex() + "\n")
      "%s" => return Some(show_first_message_line(show_info.message) + "\n")
      _ => ()
    }
  }
  if oneline {
    let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
    return Some(short + " " + show_first_message_line(show_info.message) + "\n")
  }
  let commit_info = @bitcore.parse_commit(data)
  let lines : Array[String] = [
    "commit \{commit_id.to_hex()}",
    "Author: \{show_info.author}",
    "Date:   \{format_show_date(show_info.timestamp, show_info.timezone)}",
    "",
  ]
  for line_view in show_info.message.split("\n") {
    lines.push("    \{line_view.to_string()}")
  }
  lines.push("")
  if not(quiet) && commit_info.parents.length() > 0 {
    let parent_id = commit_info.parents[0]
    let parent_files = @bitlib.collect_tree_files_from_commit(db, fs, parent_id)
    let current_files = @bitlib.collect_tree_files_from_commit(
      db, fs, commit_id,
    )
    for item in current_files.to_array() {
      let (path, entry) = item
      match parent_files.get(path) {
        None => lines.push("diff --git a/\{path} b/\{path}\nnew file")
        Some(parent_entry) =>
          if entry.id != parent_entry.id {
            lines.push("diff --git a/\{path} b/\{path}")
          }
      }
    }
    for item in parent_files.to_array() {
      let (path, _) = item
      if not(current_files.contains(path)) {
        lines.push("diff --git a/\{path} b/\{path}\ndeleted file")
      }
    }
  }
  Some(show_lines_to_block(lines))
}

///|
fn show_render_object_block(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  spec : String,
  id : @bitcore.ObjectId,
  db : @bitlib.ObjectDb,
  pretty_raw : Bool,
  pretty_format : String?,
  quiet : Bool,
  oneline : Bool,
  grep_patterns : Array[String],
  grep_pattern_type : GrepPatternType,
  grep_ignore_case : Bool,
) -> String? raise Error {
  let obj = db.get(fs, id)
  guard obj is Some(o) else {
    raise @bitcore.GitError::InvalidObject("Object not found: \{id.to_hex()}")
  }
  match o.obj_type {
    @bitcore.ObjectType::Blob => Some(decode_bytes(o.data))
    @bitcore.ObjectType::Tree =>
      Some(
        show_lines_to_block(
          show_render_tree_lines(spec, @bitcore.parse_tree(o.data)),
        ),
      )
    @bitcore.ObjectType::Commit =>
      show_render_commit_block(
        db,
        fs,
        id,
        o.data,
        pretty_raw,
        pretty_format,
        quiet,
        oneline,
        grep_patterns,
        grep_pattern_type,
        grep_ignore_case,
      )
    @bitcore.ObjectType::Tag => {
      let tag_info = show_parse_tag_info(o.data)
      guard tag_info is Some(info) else {
        raise @bitcore.GitError::InvalidObject(
          "Invalid tag object: \{id.to_hex()}",
        )
      }
      let target_block = show_render_object_block(
        fs,
        git_dir,
        spec,
        info.target,
        db,
        pretty_raw,
        pretty_format,
        quiet,
        oneline,
        grep_patterns,
        grep_pattern_type,
        grep_ignore_case,
      )
      guard target_block is Some(rendered_target) else { return None }
      let lines : Array[String] = ["tag \{info.name}"]
      if info.tagger.length() > 0 {
        lines.push("Tagger: \{info.tagger}")
        lines.push("Date:   \{format_show_date(info.timestamp, info.timezone)}")
        lines.push("")
      }
      if info.message.length() > 0 {
        for line_view in info.message.split("\n") {
          lines.push("    \{line_view.to_string()}")
        }
        lines.push("")
      }
      Some(
        show_concat_blocks([show_lines_to_block(lines), rendered_target], false),
      )
    }
  }
}

///|
async fn handle_show(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let git_dir = resolve_git_dir(fs, root)
  check_and_exit_unsupported_attrs(root)
  let options = show_parse_args(args)
  if options.graph_requested {
    raise @bitcore.GitError::InvalidObject(
      "options '--graph' and '--no-walk' cannot be used together",
    )
  }
  let grep_pattern_type = resolve_grep_pattern_type(
    fs,
    git_dir,
    options.grep_pattern_type_override,
  )
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  if options.walk_mode {
    let targets = log_resolve_targets(
      fs,
      git_dir,
      options.revs,
      [],
      false,
      default_head=options.revs.length() == 0,
    )
    let start_ids : Array[@bitcore.ObjectId] = []
    for target in targets {
      let (_, id) = target
      start_ids.push(id)
    }
    let exclude_ids : Map[String, Bool] = {}
    let exclude_targets = log_resolve_targets(
      fs,
      git_dir,
      options.range_excludes,
      [],
      false,
      default_head=false,
    )
    for target in exclude_targets {
      let (_, exclude_id) = target
      walk_commits_to_map(fs, git_dir, exclude_id, exclude_ids)
    }
    let max_count = if options.max_count > 0 {
      options.max_count
    } else {
      1 << 30
    }
    let blocks : Array[String] = []
    for
      entry in log_walk_commits(
        fs, git_dir, start_ids, exclude_ids, max_count, -9223372036854775807L, 9223372036854775807L,
        false,
      ) {
      let obj = db.get(fs, entry.id)
      guard obj is Some(o) else { continue }
      guard o.obj_type == @bitcore.ObjectType::Commit else { continue }
      match
        show_render_commit_block(
          db,
          fs,
          entry.id,
          o.data,
          options.pretty_raw,
          options.pretty_format,
          options.quiet,
          options.oneline,
          options.grep_patterns,
          grep_pattern_type,
          options.grep_ignore_case,
        ) {
        Some(block) => blocks.push(block)
        None => ()
      }
    }
    print_str(
      show_concat_blocks(
        blocks,
        options.pretty_format is Some(_) || options.oneline,
      ),
    )
    return ()
  }
  let targets : Array[String] = if options.revs.length() > 0 {
    options.revs
  } else {
    ["HEAD"]
  }
  let blocks : Array[String] = []
  for target in targets {
    let id = show_resolve_target_object_id(fs, git_dir, target, db)
    guard id is Some(resolved_id) else {
      raise @bitcore.GitError::InvalidObject("unknown revision: \{target}")
    }
    match
      show_render_object_block(
        fs,
        git_dir,
        target,
        resolved_id,
        db,
        options.pretty_raw,
        options.pretty_format,
        options.quiet,
        options.oneline,
        options.grep_patterns,
        grep_pattern_type,
        options.grep_ignore_case,
      ) {
      Some(block) => blocks.push(block)
      None => ()
    }
  }
  print_str(
    show_concat_blocks(
      blocks,
      options.pretty_format is Some(_) || options.oneline,
    ),
  )
}
