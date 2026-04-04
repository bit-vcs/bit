///|

///|
async fn show_log_command_help() -> Unit {
  show_simple_command_help(
    "git log [<options>] [<revision-range>] [--] [<pathspec>...]",
    summary="Show commit logs.",
  )
}

///|
fn log_parse_bool_value(value : String) -> Bool? {
  @config_parse.parse_bool_keyword_value(value)
}

///|
fn log_normalize_abbrev_length(value : Int) -> Int {
  if value <= 0 {
    7
  } else if value < 4 {
    4
  } else if value >= 40 {
    40
  } else {
    value
  }
}

///|
fn log_parse_abbrev_length_value(value : String) -> Int? {
  let trimmed = trim_string(value)
  match log_parse_bool_value(trimmed) {
    Some(false) => Some(40)
    Some(true) => Some(7)
    None => {
      let parsed = @string.parse_int(trimmed) catch { _ => return None }
      Some(log_normalize_abbrev_length(parsed))
    }
  }
}

///|
fn log_resolve_abbrev_length(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  cli_override : Int?,
  no_abbrev : Bool,
) -> Int {
  if no_abbrev {
    return 40
  }
  match cli_override {
    Some(value) => log_normalize_abbrev_length(value)
    None =>
      match get_config_override("core.abbrev") {
        Some(value) => log_parse_abbrev_length_value(value).unwrap_or(7)
        None =>
          match
            @bitlib.read_config_value(
              rfs,
              git_dir + "/config",
              "core",
              "abbrev",
            ) {
            Some(value) => log_parse_abbrev_length_value(value).unwrap_or(7)
            None => 7
          }
      }
  }
}

///|
fn log_resolve_abbrev_commit(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  cli_override : Bool?,
) -> Bool {
  match cli_override {
    Some(value) => value
    None =>
      match get_config_override("log.abbrevCommit") {
        Some(value) => log_parse_bool_value(value).unwrap_or(false)
        None =>
          @bitlib.read_config_bool(
            rfs,
            git_dir + "/config",
            "log",
            "abbrevcommit",
          ).unwrap_or(false)
      }
  }
}

///|
fn log_abbrev_hex(hex : String, abbrev_len : Int) -> String {
  if abbrev_len >= hex.length() {
    hex
  } else {
    String::unsafe_substring(hex, start=0, end=abbrev_len)
  }
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
fn log_find_tripledot(arg : String) -> Int {
  let chars : Array[Char] = []
  for c in arg {
    chars.push(c)
  }
  let len = chars.length()
  let mut i = 0
  while i < len - 2 {
    if chars[i] == '.' && chars[i + 1] == '.' && chars[i + 2] == '.' {
      return i
    }
    i += 1
  }
  -1
}

///|
fn is_short_count_flag(arg : String) -> Bool {
  if !arg.has_prefix("-") || arg.length() <= 1 {
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
async fn delegate_log_to_real_git(args : Array[String], cwd : String) -> Unit {
  let argv : Array[String] = ["log"]
  for arg in args {
    argv.push(arg)
  }
  let code = @process.run(
    resolve_real_git_for_dispatch(),
    argv,
    inherit_env=true,
    cwd~,
    stdin=@stdio.stdin,
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  @sys.exit(code)
}

///|
fn log_format_requests_signature_display(format : String) -> Bool {
  format.contains("%G")
}

///|
fn log_args_request_signature_display(args : Array[String]) -> Bool {
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--show-signature" {
      return true
    }
    if (arg == "--pretty" || arg == "--format") && i + 1 < args.length() {
      if log_format_requests_signature_display(args[i + 1]) {
        return true
      }
      i += 2
      continue
    }
    if arg.has_prefix("--pretty=") {
      let value = String::unsafe_substring(arg, start=9, end=arg.length())
      if log_format_requests_signature_display(value) {
        return true
      }
    }
    if arg.has_prefix("--format=") {
      let value = String::unsafe_substring(arg, start=9, end=arg.length())
      if log_format_requests_signature_display(value) {
        return true
      }
    }
    i += 1
  }
  false
}

///|
fn log_signature_display_config_enabled(git_dir : String) -> Bool {
  match get_config_override("log.showsignature") {
    Some(value) => log_parse_bool_value(value).unwrap_or(false)
    None =>
      @bitlib.read_config_bool(
        OsFs::new(),
        git_dir + "/config",
        "log",
        "showsignature",
      ).unwrap_or(false)
  }
}

///|
fn log_need_real_git(args : Array[String], git_dir? : String = "") -> Bool {
  if log_args_request_signature_display(args) {
    return true
  }
  if git_dir.length() > 0 && log_signature_display_config_enabled(git_dir) {
    return true
  }
  let mut saw_double_dash = false
  for arg in args {
    if saw_double_dash {
      return true
    }
    if arg == "--" {
      saw_double_dash = true
      continue
    }
    if arg == "--name-only" ||
      arg == "--name-status" ||
      arg == "--stdin" ||
      arg == "--boundary" ||
      arg == "--parents" ||
      arg == "--full-history" ||
      arg == "--topo-order" ||
      arg == "--date-order" ||
      arg == "--author-date-order" ||
      arg == "--ancestry-path" ||
      arg == "--simplify-by-decoration" ||
      arg == "--simplify-merges" ||
      arg == "--show-pulls" ||
      arg == "--exclude-first-parent-only" ||
      arg == "--full-diff" ||
      arg.has_prefix("--ancestry-path=") {
      return true
    }
  }
  false
}

///|
fn log_storage_runtime_delegate_args(
  args : Array[String],
) -> @runtime.StorageLogArgs? {
  if log_need_real_git(args) {
    return None
  }
  let mut seen_oneline = false
  let mut seen_limit = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--oneline" => seen_oneline = true
      "-n" | "--max-count" => {
        seen_limit = true
        if i + 1 < args.length() {
          i += 1
        } else {
          return None
        }
      }
      _ if arg.has_prefix("--max-count=") => seen_limit = true
      _ if is_short_count_flag(arg) => seen_limit = true
      _ => return None
    }
    i += 1
  }
  if !seen_oneline || !seen_limit {
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
fn log_storage_runtime_blocked_by_repo_config(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Bool {
  log_read_config_entries(rfs, git_dir, "log", "decorate").length() > 0 ||
  log_read_config_entries(rfs, git_dir, "log", "excludeDecoration").length() > 0 ||
  log_read_config_entries(rfs, git_dir, "log", "abbrevCommit").length() > 0 ||
  log_read_config_entries(rfs, git_dir, "core", "abbrev").length() > 0
}

///|
fn log_should_use_storage_runtime_in_repo(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  args : Array[String],
) -> Bool {
  log_should_use_storage_runtime(args) &&
  !log_storage_runtime_blocked_by_repo_config(rfs, git_dir)
}

///|
fn log_glob_match(pattern : String, text : String) -> Bool {
  let p = pattern.to_array()
  let t = text.to_array()
  let plen = p.length()
  let tlen = t.length()
  let mut pi = 0
  let mut ti = 0
  let mut star_pi = -1
  let mut star_ti = -1
  while ti < tlen {
    if pi < plen && (p[pi] == t[ti] || p[pi] == '?') {
      pi += 1
      ti += 1
    } else if pi < plen && p[pi] == '*' {
      star_pi = pi
      star_ti = ti
      pi += 1
    } else if star_pi >= 0 {
      pi = star_pi + 1
      star_ti += 1
      ti = star_ti
    } else {
      return false
    }
  }
  while pi < plen && p[pi] == '*' {
    pi += 1
  }
  pi == plen
}

///|
priv enum LogDecorationDisplayMode {
  Disabled
  Short
  Full
}

///|
priv struct LogConfigEntry {
  has_value : Bool
  value : String
}

///|
priv struct LogDecorationOptions {
  mode : LogDecorationDisplayMode
  include_patterns : Array[String]
  exclude_patterns : Array[String]
  include_all_refs : Bool
}

///|
priv struct LogDecorationRef {
  refname : String
  display_name : String
  is_head : Bool
  is_tag : Bool
  is_lightweight_tag : Bool
}

///|
fn log_parse_decorate_mode(value : String) -> LogDecorationDisplayMode? {
  match trim_string(value).to_lower() {
    "" | "true" | "yes" | "on" | "1" | "short" =>
      Some(LogDecorationDisplayMode::Short)
    "full" => Some(LogDecorationDisplayMode::Full)
    "false" | "no" | "off" | "0" => Some(LogDecorationDisplayMode::Disabled)
    _ => None
  }
}

///|
fn log_decoration_mode_is_none(mode : LogDecorationDisplayMode) -> Bool {
  match mode {
    LogDecorationDisplayMode::Disabled => true
    _ => false
  }
}

///|
fn log_decoration_mode_is_full(mode : LogDecorationDisplayMode) -> Bool {
  match mode {
    LogDecorationDisplayMode::Full => true
    _ => false
  }
}

///|
fn log_normalize_decoration_pattern(pattern : String) -> String {
  let trimmed = trim_string(pattern)
  if trimmed == "HEAD" || trimmed.has_prefix("refs/") {
    trimmed
  } else {
    "refs/" + trimmed
  }
}

///|
fn log_decoration_pattern_matches(refname : String, pattern : String) -> Bool {
  let normalized = log_normalize_decoration_pattern(pattern)
  if normalized == "HEAD" {
    return refname == "HEAD"
  }
  let has_glob = normalized.contains("*") ||
    normalized.contains("?") ||
    normalized.contains("[")
  if has_glob {
    return log_glob_match(normalized, refname)
  }
  let prefix = if normalized.has_suffix("/") {
    normalized
  } else {
    normalized + "/"
  }
  refname == normalized || refname.has_prefix(prefix)
}

///|
fn log_ref_hidden_by_default(refname : String) -> Bool {
  refname.has_prefix("refs/hidden/") ||
  refname.has_prefix("refs/prefetch/") ||
  refname.has_prefix("refs/rewritten/")
}

///|
fn log_read_config_entries(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  section : String,
  key : String,
) -> Array[LogConfigEntry] {
  let entries : Array[LogConfigEntry] = []
  let content = @bitlib.read_config_content(rfs, git_dir)
  let mut current_section = ""
  let section_lower = section.to_lower()
  let key_lower = key.to_lower()
  for raw_line_view in content.split("\n") {
    let raw_line = raw_line_view.to_string()
    let line = trim_string(raw_line)
    if line.length() == 0 || line.has_prefix("#") || line.has_prefix(";") {
      continue
    }
    let mut config_line = line
    if line.has_prefix("[") {
      match line.find("]") {
        Some(end_idx) => {
          let inner = trim_string(
            String::unsafe_substring(line, start=1, end=end_idx),
          )
          current_section = match inner.find(" ") {
            Some(idx) =>
              String::unsafe_substring(inner, start=0, end=idx).to_lower()
            None => inner.to_lower()
          }
          config_line = trim_string(
            String::unsafe_substring(line, start=end_idx + 1, end=line.length()),
          )
          if config_line.length() == 0 {
            continue
          }
        }
        None => continue
      }
    }
    if current_section != section_lower {
      continue
    }
    match config_line.find("=") {
      Some(eq_idx) => {
        let found_key = trim_string(
          String::unsafe_substring(config_line, start=0, end=eq_idx),
        ).to_lower()
        if found_key == key_lower {
          let value = trim_string(
            String::unsafe_substring(
              config_line,
              start=eq_idx + 1,
              end=config_line.length(),
            ),
          )
          entries.push({ has_value: true, value })
        }
      }
      None => {
        let raw_token = match config_line.find(" ") {
          Some(idx) => String::unsafe_substring(config_line, start=0, end=idx)
          None => config_line
        }
        let token = raw_token.to_lower()
        if token == key_lower {
          entries.push({ has_value: false, value: "" })
        }
      }
    }
  }
  let override_key = section_lower + "." + key_lower
  match @sys.get_env_var("GIT_CONFIG_OVERRIDES") {
    Some(data) =>
      for line_view in data.split("\n") {
        let line = line_view.to_string()
        if line.length() == 0 {
          continue
        }
        match line.find("=") {
          Some(eq_idx) => {
            let found_key = String::unsafe_substring(line, start=0, end=eq_idx).to_lower()
            if found_key == override_key {
              entries.push({
                has_value: true,
                value: String::unsafe_substring(
                  line,
                  start=eq_idx + 1,
                  end=line.length(),
                ),
              })
            }
          }
          None =>
            if line.to_lower() == override_key {
              entries.push({ has_value: false, value: "" })
            }
        }
      }
    None => ()
  }
  entries
}

///|
fn log_resolve_decorate_mode(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  cli_override : LogDecorationDisplayMode?,
  implied_by_format : Bool,
  config_allowed : Bool,
) -> LogDecorationDisplayMode {
  match cli_override {
    Some(mode) => mode
    None => {
      if config_allowed {
        let config_entries = log_read_config_entries(
          rfs, git_dir, "log", "decorate",
        )
        if config_entries.length() > 0 {
          let entry = config_entries[config_entries.length() - 1]
          if !entry.has_value {
            return LogDecorationDisplayMode::Short
          }
          return log_parse_decorate_mode(entry.value).unwrap_or(
            LogDecorationDisplayMode::Disabled,
          )
        }
      }
      if implied_by_format {
        LogDecorationDisplayMode::Short
      } else {
        LogDecorationDisplayMode::Disabled
      }
    }
  }
}

///|
fn log_read_exclude_decoration_patterns(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Array[String] {
  let entries = log_read_config_entries(
    rfs, git_dir, "log", "excludeDecoration",
  )
  let out : Array[String] = []
  for entry in entries {
    if entry.has_value {
      out.push(entry.value)
    }
  }
  out
}

///|
fn log_has_missing_exclude_decoration_value(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Bool {
  let entries = log_read_config_entries(
    rfs, git_dir, "log", "excludeDecoration",
  )
  entries.iter().any(fn(entry) { !entry.has_value })
}

///|
fn log_initial_decoration_set_all(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Bool {
  match get_config_override("log.initialDecorationSet") {
    Some(value) => trim_string(value).to_lower() == "all"
    None =>
      match
        @bitlib.read_config_value(
          rfs,
          git_dir + "/config",
          "log",
          "initialdecorationset",
        ) {
        Some(value) => trim_string(value).to_lower() == "all"
        None => false
      }
  }
}

///|
fn log_should_include_decoration_ref(
  refname : String,
  include_patterns : Array[String],
  exclude_patterns : Array[String],
  include_all_refs : Bool,
) -> Bool {
  if !include_all_refs && log_ref_hidden_by_default(refname) {
    return false
  }
  if include_patterns.length() > 0 &&
    !include_patterns
    .iter()
    .any(p => log_decoration_pattern_matches(refname, p)) {
    return false
  }
  if exclude_patterns
    .iter()
    .any(p => log_decoration_pattern_matches(refname, p)) {
    return false
  }
  true
}

///|
fn log_clear_string_array(values : Array[String]) -> Unit {
  while values.length() > 0 {
    ignore(values.pop())
  }
}

///|
fn log_extend_string_array(dst : Array[String], src : Array[String]) -> Unit {
  for value in src {
    dst.push(value)
  }
}

///|
fn log_shorten_refname_for_decoration(refname : String) -> String {
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
fn log_format_decoration_refname(
  refname : String,
  mode : LogDecorationDisplayMode,
) -> String {
  if refname.has_prefix("refs/tags/") {
    let tag_name = if log_decoration_mode_is_full(mode) {
      refname
    } else {
      String::unsafe_substring(refname, start=10, end=refname.length())
    }
    "tag: " + tag_name
  } else if log_decoration_mode_is_full(mode) {
    refname
  } else {
    log_shorten_refname_for_decoration(refname)
  }
}

///|
fn log_make_decoration_options(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  cli_mode : LogDecorationDisplayMode?,
  cli_include_patterns : Array[String],
  cli_exclude_patterns : Array[String],
  clear_decorations : Bool,
  implied_by_format : Bool,
  config_allowed : Bool,
  simplify_by_decoration : Bool,
) -> LogDecorationOptions {
  let mode = log_resolve_decorate_mode(
    rfs, git_dir, cli_mode, implied_by_format, config_allowed,
  )
  let exclude_patterns : Array[String] = []
  if cli_include_patterns.length() == 0 {
    log_extend_string_array(
      exclude_patterns,
      log_read_exclude_decoration_patterns(rfs, git_dir),
    )
  }
  log_extend_string_array(exclude_patterns, cli_exclude_patterns)
  {
    mode,
    include_patterns: cli_include_patterns,
    exclude_patterns,
    include_all_refs: clear_decorations ||
    simplify_by_decoration ||
    log_initial_decoration_set_all(rfs, git_dir),
  }
}

///|
fn log_should_emit_simplified_entry(
  ref_names : Map[String, Array[String]],
  hex : String,
  parent_count : Int,
) -> Bool {
  match ref_names.get(hex) {
    Some(names) if names.length() > 0 => true
    _ => parent_count == 0
  }
}

///|
fn log_branch_pattern_matches(short_name : String, pattern : String) -> Bool {
  if pattern.length() == 0 || pattern == "*" {
    return true
  }
  if pattern.contains("*") || pattern.contains("?") {
    return log_glob_match(pattern, short_name)
  }
  short_name == pattern || short_name.has_prefix(pattern + "/")
}

///|
fn log_string_desc_before(a : String, b : String) -> Bool {
  let aa = a.to_array()
  let bb = b.to_array()
  let min_len = if aa.length() < bb.length() {
    aa.length()
  } else {
    bb.length()
  }
  for i in 0..<min_len {
    let ac = aa[i].to_int()
    let bc = bb[i].to_int()
    if ac != bc {
      return ac > bc
    }
  }
  aa.length() > bb.length()
}

///|
fn log_add_revision_input(
  arg : String,
  revs : Array[String],
  range_excludes : Array[String],
  symmetric_ranges : Array[(String, String)],
) -> Unit {
  if arg.has_prefix("^") && arg.length() > 1 {
    range_excludes.push(
      String::unsafe_substring(arg, start=1, end=arg.length()),
    )
    return
  }
  let tripledot_idx = log_find_tripledot(arg)
  if tripledot_idx >= 0 {
    let left = String::unsafe_substring(arg, start=0, end=tripledot_idx)
    let right = String::unsafe_substring(
      arg,
      start=tripledot_idx + 3,
      end=arg.length(),
    )
    let left_spec = if left.length() > 0 { left } else { "HEAD" }
    let right_spec = if right.length() > 0 { right } else { "HEAD" }
    revs.push(left_spec)
    revs.push(right_spec)
    symmetric_ranges.push((left_spec, right_spec))
    return
  }
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
    return
  }
  revs.push(arg)
}

///|
fn log_push_revision_input(
  arg : String,
  revs : Array[String],
  range_excludes : Array[String],
  symmetric_ranges : Array[(String, String)],
  exclude_mode : Bool,
) -> Unit {
  if arg.has_prefix("^") && arg.length() > 1 {
    range_excludes.push(
      String::unsafe_substring(arg, start=1, end=arg.length()),
    )
    return
  }
  if exclude_mode {
    range_excludes.push(arg)
    return
  }
  log_add_revision_input(arg, revs, range_excludes, symmetric_ranges)
}

///|
fn log_normalize_ref_glob_pattern(pattern : String) -> String {
  let normalized = rev_parse_normalize_glob_pattern(pattern)
  if normalized.contains("*") {
    normalized
  } else if normalized.has_suffix("/") {
    normalized + "*"
  } else {
    normalized + "/*"
  }
}

///|
fn log_append_glob_targets(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  pattern : String,
  revs : Array[String],
) -> Unit {
  let refs = rev_parse_list_matching_refs(
    rfs,
    git_dir,
    "",
    Some(log_normalize_ref_glob_pattern(pattern)),
    [],
  )
  for item in refs {
    revs.push(item.0)
  }
}

///|
fn log_assign_left_right_marker(
  markers : Map[String, String],
  hex : String,
  marker : String,
) -> Unit {
  match markers.get(hex) {
    Some(existing) if existing == marker => ()
    Some(_) => markers[hex] = "-"
    None => markers[hex] = marker
  }
}

///|
fn log_build_left_right_markers(
  fs : OsFs,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  symmetric_ranges : Array[(String, String)],
  ignore_missing : Bool,
) -> Map[String, String] raise Error {
  let db = @bitlib.ObjectDb::load(rfs, log_resolve_common_git_dir(rfs, git_dir))
  let markers : Map[String, String] = {}
  for pair in symmetric_ranges {
    let left_spec = pair.0
    let right_spec = pair.1
    match
      (
        @bitrepo.rev_parse(rfs, git_dir, left_spec),
        @bitrepo.rev_parse(rfs, git_dir, right_spec),
      ) {
      (Some(left_id), Some(right_id)) => {
        let left_commit = match peel_to_commit(db, rfs, left_id) {
          Some(id) => id
          None => left_id
        }
        let right_commit = match peel_to_commit(db, rfs, right_id) {
          Some(id) => id
          None => right_id
        }
        let left_seen : Map[String, Bool] = {}
        let right_seen : Map[String, Bool] = {}
        let merge_base_seen : Map[String, Bool] = {}
        walk_commits_to_map(fs, git_dir, left_commit, left_seen)
        walk_commits_to_map(fs, git_dir, right_commit, right_seen)
        match log_find_merge_base(rfs, git_dir, left_commit, right_commit) {
          Some(base_id) =>
            walk_commits_to_map(fs, git_dir, base_id, merge_base_seen)
          None => ()
        }
        let left_entries : Array[(String, Bool)] = left_seen.iter().collect()
        for entry in left_entries {
          let hex = entry.0
          if merge_base_seen.contains(hex) {
            continue
          }
          log_assign_left_right_marker(
            markers,
            hex,
            if right_seen.contains(hex) {
              "-"
            } else {
              "<"
            },
          )
        }
        let right_entries : Array[(String, Bool)] = right_seen.iter().collect()
        for entry in right_entries {
          let hex = entry.0
          if merge_base_seen.contains(hex) {
            continue
          }
          log_assign_left_right_marker(
            markers,
            hex,
            if left_seen.contains(hex) {
              "-"
            } else {
              ">"
            },
          )
        }
      }
      _ if ignore_missing => ()
      _ =>
        raise @bitcore.GitError::InvalidObject(
          "Unknown revision in symmetric range",
        )
    }
  }
  markers
}

///|
struct CommitFormatData {
  id : @bitcore.ObjectId
  tree : @bitcore.ObjectId
  parents : Array[@bitcore.ObjectId]
  abbrev_len : Int
  encoding : String
  author_name : String
  author_email : String
  author_timestamp : Int64
  author_tz : String
  committer_name : String
  committer_email : String
  committer_timestamp : Int64
  committer_tz : String
  subject : String
  body : String
  message : String
  ref_names : Map[String, Array[String]]
  date_format : String
  left_right_marker : String
  reflog_selector_short : String?
  reflog_selector : String?
  reflog_message : String?
  reflog_author_name : String?
  reflog_author_email : String?
  pretty_color_enabled : Bool
  pretty_auto_color : String
}

///|
fn log_extract_commit_message_and_encoding(data : Bytes) -> (Bytes, String?) {
  let mut offset = 0
  let mut encoding : String? = None
  while offset <= data.length() {
    let line_start = offset
    while offset < data.length() && data[offset] != b'\n' {
      offset += 1
    }
    let mut line_end = offset
    if line_end > line_start && data[line_end - 1] == b'\r' {
      line_end -= 1
    }
    let line = decode_bytes(reset_slice_bytes(data, line_start, line_end))
    if line.length() == 0 {
      let message_start = if offset < data.length() {
        offset + 1
      } else {
        offset
      }
      return (reset_slice_bytes(data, message_start, data.length()), encoding)
    }
    if line.has_prefix("encoding ") {
      encoding = Some(
        trim_string(String::unsafe_substring(line, start=9, end=line.length())),
      )
    }
    if offset < data.length() {
      offset += 1
    } else {
      break
    }
  }
  (Bytes::default(), encoding)
}

///|
fn parse_commit_format_data(
  id : @bitcore.ObjectId,
  data : Bytes,
  tree : @bitcore.ObjectId,
  parents : Array[@bitcore.ObjectId],
  ref_names : Map[String, Array[String]],
  abbrev_len? : Int = 7,
  date_format? : String = "",
  left_right_marker? : String = "",
  reflog_selector_short? : String? = None,
  reflog_selector? : String? = None,
  reflog_message? : String? = None,
  reflog_author_name? : String? = None,
  reflog_author_email? : String? = None,
  pretty_color_enabled? : Bool = false,
  pretty_auto_color? : String = "\u001b[33m",
) -> CommitFormatData {
  let text = decode_bytes(data)
  let (message_bytes, explicit_encoding) = log_extract_commit_message_and_encoding(
    data,
  )
  let source_encoding = reset_detect_commit_subject_encoding(
    message_bytes, explicit_encoding,
  )
  let message_text = decode_commit_message_bytes(message_bytes, source_encoding)
  let mut author_name = ""
  let mut author_email = ""
  let mut author_timestamp = 0L
  let mut author_tz = "+0000"
  let mut committer_name = ""
  let mut committer_email = ""
  let mut committer_timestamp = 0L
  let mut committer_tz = "+0000"
  let message_lines : Array[String] = []
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("author ") {
      let rest = String::unsafe_substring(line, start=7, end=line.length())
      let (name, email, ts, tz) = parse_ident_parts(rest)
      author_name = name
      author_email = email
      author_timestamp = ts
      author_tz = tz
    } else if line.has_prefix("committer ") {
      let rest = String::unsafe_substring(line, start=10, end=line.length())
      let (name, email, ts, tz) = parse_ident_parts(rest)
      committer_name = name
      committer_email = email
      committer_timestamp = ts
      committer_tz = tz
    }
  }
  for line_view in message_text.split("\n") {
    message_lines.push(line_view.to_string())
  }
  // Remove trailing empty lines from message
  while message_lines.length() > 0 &&
        message_lines[message_lines.length() - 1].length() == 0 {
    ignore(message_lines.pop())
  }
  let subject = if message_lines.length() > 0 { message_lines[0] } else { "" }
  let body_lines : Array[String] = []
  if message_lines.length() > 1 {
    // Skip the subject and blank line after it
    let mut start = 1
    while start < message_lines.length() && message_lines[start].length() == 0 {
      start += 1
    }
    for i = start; i < message_lines.length(); i = i + 1 {
      body_lines.push(message_lines[i])
    }
  }
  let body = if body_lines.length() > 0 {
    body_lines.join("\n") + "\n"
  } else {
    ""
  }
  let message = if message_lines.length() > 0 {
    message_lines.join("\n") + "\n"
  } else {
    ""
  }
  {
    id,
    tree,
    parents,
    abbrev_len,
    encoding: explicit_encoding.unwrap_or(""),
    author_name,
    author_email,
    author_timestamp,
    author_tz,
    committer_name,
    committer_email,
    committer_timestamp,
    committer_tz,
    subject,
    body,
    message,
    ref_names,
    date_format,
    left_right_marker,
    reflog_selector_short,
    reflog_selector,
    reflog_message,
    reflog_author_name,
    reflog_author_email,
    pretty_color_enabled,
    pretty_auto_color,
  }
}

///|
fn log_normalize_pretty_color_mode(value : String) -> String? {
  let trimmed = trim_string(value).to_lower()
  match trimmed {
    "always" | "true" | "yes" | "on" => Some("always")
    "never" | "false" | "no" | "off" | "" => Some("never")
    "auto" => Some("auto")
    _ => None
  }
}

///|
fn log_resolve_pretty_color_enabled_from_values(
  color_diff : String?,
  color_ui : String?,
  cli_mode : String?,
  stdout_is_tty : Bool,
) -> Bool {
  let effective_mode = match cli_mode {
    Some(value) =>
      match log_normalize_pretty_color_mode(value) {
        Some(mode) => Some(mode)
        None => Some("never")
      }
    None =>
      match color_diff {
        Some(value) =>
          match log_normalize_pretty_color_mode(value) {
            Some(mode) => Some(mode)
            None => None
          }
        None =>
          match color_ui {
            Some(value) => log_normalize_pretty_color_mode(value)
            None => None
          }
      }
  }
  match effective_mode {
    Some("always") => true
    Some("auto") => stdout_is_tty
    _ => false
  }
}

///|
fn log_resolve_pretty_color_enabled(
  git_dir : String,
  cli_mode : String?,
  stdout_is_tty : Bool,
) -> Bool {
  let color_diff = match get_config_override("color.diff") {
    Some(value) => Some(value)
    None => bit_config_get(git_dir, "color", "diff")
  }
  let color_ui = match get_config_override("color.ui") {
    Some(value) => Some(value)
    None => bit_config_get(git_dir, "color", "ui")
  }
  log_resolve_pretty_color_enabled_from_values(
    color_diff, color_ui, cli_mode, stdout_is_tty,
  )
}

///|
async fn log_stdout_is_tty() -> Bool {
  @process.run("sh", ["-c", "test -t 1"], inherit_env=true) == 0
}

///|
fn log_parse_pretty_color_directive_text(
  chars : Array[Char],
  percent_idx : Int,
) -> (String, Int)? {
  if percent_idx + 1 >= chars.length() || chars[percent_idx + 1] != 'C' {
    return None
  }
  if percent_idx + 2 < chars.length() && chars[percent_idx + 2] == '(' {
    let mut end = percent_idx + 3
    while end < chars.length() && chars[end] != ')' {
      end += 1
    }
    if end >= chars.length() {
      return None
    }
    return Some((String::from_array(chars[percent_idx + 3:end]), end + 1))
  }
  let rest = String::from_array(chars[percent_idx + 2:])
  for
    name in [
      "reset", "normal", "black", "red", "green", "yellow", "blue", "magenta", "cyan",
      "white",
    ] {
    if rest.has_prefix(name) {
      return Some((name, percent_idx + 2 + name.length()))
    }
  }
  None
}

///|
fn log_resolve_pretty_color_directive(
  spec : String,
  data : CommitFormatData,
) -> (String, Int) {
  let lower = trim_string(spec).to_lower()
  if lower == "" {
    return ("", -1)
  }
  if lower == "auto" {
    if data.pretty_color_enabled {
      return (data.pretty_auto_color, 1)
    }
    return ("", -1)
  }
  let mut always = false
  let mut target = lower
  if lower.has_prefix("auto,") {
    if !data.pretty_color_enabled {
      return ("", -1)
    }
    target = String::unsafe_substring(lower, start=5, end=lower.length())
  } else if lower.has_prefix("always,") {
    always = true
    target = String::unsafe_substring(lower, start=7, end=lower.length())
  } else if !data.pretty_color_enabled {
    return ("", -1)
  }
  if target == "reset" || target == "normal" {
    if always || data.pretty_color_enabled {
      return ("\u001b[m", 0)
    }
    return ("", -1)
  }
  match grep_parse_color_value(target) {
    Some(ansi) => (ansi, 1)
    None => ("", -1)
  }
}

///|
fn log_extract_author_tz(author : String) -> String {
  // author is "Name <email> timestamp tz" or just "Name <email>"
  // Extract tz (last token after last space)
  match author.rev_find(" ") {
    Some(idx) => {
      let last = String::unsafe_substring(
        author,
        start=idx + 1,
        end=author.length(),
      )
      if last.length() >= 4 && (last.has_prefix("+") || last.has_prefix("-")) {
        last
      } else {
        "+0000"
      }
    }
    None => "+0000"
  }
}

///|
fn parse_ident_parts(ident : String) -> (String, String, Int64, String) {
  // Format: "Name <email> timestamp timezone"
  let mut name = ""
  let mut email = ""
  let mut ts = 0L
  let mut tz = "+0000"
  match ident.find("<") {
    Some(lt) => {
      name = String::unsafe_substring(ident, start=0, end=lt).trim().to_string()
      match ident.find(">") {
        Some(gt) => {
          email = String::unsafe_substring(ident, start=lt + 1, end=gt)
          let rest = String::unsafe_substring(
              ident,
              start=gt + 1,
              end=ident.length(),
            )
            .trim()
            .to_string()
          // rest = "timestamp timezone"
          let parts : Array[String] = []
          for p in rest.split(" ") {
            let s = p.to_string().trim().to_string()
            if s.length() > 0 {
              parts.push(s)
            }
          }
          if parts.length() >= 1 {
            ts = @string.parse_int64(parts[0]) catch { _ => 0L }
          }
          if parts.length() >= 2 {
            tz = parts[1]
          }
        }
        None => ()
      }
    }
    None => name = ident
  }
  (name, email, ts, tz)
}

///|
struct LogWrapSpec {
  width : Int
  indent1 : Int
  indent2 : Int
}

///|
fn log_parse_wrap_spec(text : String) -> LogWrapSpec {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let width = if parts.length() > 0 && parts[0].length() > 0 {
    @string.parse_int(parts[0]) catch {
      _ => 0
    }
  } else {
    0
  }
  let indent1 = if parts.length() > 1 && parts[1].length() > 0 {
    @string.parse_int(parts[1]) catch {
      _ => 0
    }
  } else {
    0
  }
  let indent2 = if parts.length() > 2 && parts[2].length() > 0 {
    @string.parse_int(parts[2]) catch {
      _ => 0
    }
  } else {
    0
  }
  { width, indent1, indent2 }
}

///|
fn log_indent_string(count : Int) -> String {
  let out = StringBuilder::new()
  for _ in 0..<count {
    out.write_char(' ')
  }
  out.to_string()
}

///|
fn log_apply_wrap(text : String, spec : LogWrapSpec) -> String {
  let lines : Array[String] = []
  let mut first_output_line = true
  for raw_line_view in text.split("\n") {
    let raw_line = raw_line_view.to_string()
    let indent = if first_output_line { spec.indent1 } else { spec.indent2 }
    if spec.width <= 0 {
      lines.push(log_indent_string(indent) + raw_line)
      first_output_line = false
      continue
    }
    let words : Array[String] = []
    for word_view in raw_line.split(" ") {
      let word = word_view.to_string()
      if word.length() > 0 {
        words.push(word)
      }
    }
    if words.length() == 0 {
      lines.push(log_indent_string(indent))
      first_output_line = false
      continue
    }
    let mut current = log_indent_string(indent)
    let mut current_len = indent
    let mut word_i = 0
    while word_i < words.length() {
      let word = words[word_i]
      let word_len = word.length()
      let needs_space = current_len > indent
      let added_len = if needs_space { 1 + word_len } else { word_len }
      if needs_space && current_len + added_len > spec.width {
        lines.push(current)
        current = log_indent_string(spec.indent2) + word
        current_len = spec.indent2 + word_len
      } else {
        if needs_space {
          current = current + " " + word
        } else {
          current = current + word
        }
        current_len += added_len
      }
      first_output_line = false
      word_i += 1
    }
    lines.push(current)
  }
  lines.join("\n")
}

///|
async fn log_emit_output(
  text : String,
  trailing_newline : Bool,
  line_prefix : String,
) -> Unit raise Error {
  if line_prefix.length() == 0 {
    if trailing_newline {
      print_line(text)
    } else {
      print_str(text)
    }
    return
  }
  if text.length() == 0 {
    if trailing_newline {
      print_line(line_prefix)
    }
    return
  }
  let lines : Array[String] = []
  for line_view in text.split("\n") {
    lines.push(line_view.to_string())
  }
  for i in 0..<lines.length() {
    let prefixed = line_prefix + lines[i]
    if i + 1 < lines.length() || trailing_newline {
      print_line(prefixed)
    } else {
      print_str(prefixed)
    }
  }
}

///|
fn log_build_ref_names(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  options : LogDecorationOptions,
) -> Map[String, Array[String]] raise Error {
  let ref_entries : Map[String, Array[LogDecorationRef]] = {}
  let all_ref_list = @bitrepo.show_ref(rfs, git_dir)
  let db = @bitlib.ObjectDb::load(rfs, log_resolve_common_git_dir(rfs, git_dir))
  for item in all_ref_list {
    if !log_should_include_decoration_ref(
        item.0,
        options.include_patterns,
        options.exclude_patterns,
        options.include_all_refs,
      ) {
      continue
    }
    let resolved = if item.0.has_prefix("refs/tags/") {
      @bitrepo.rev_parse(rfs, git_dir, item.0 + "^{commit}") catch {
        _ => None
      }
    } else {
      Some(item.1)
    }
    let is_tag = item.0.has_prefix("refs/tags/")
    guard resolved is Some(target_id) else { continue }
    let hex = target_id.to_hex()
    let display_name = log_format_decoration_refname(item.0, options.mode)
    let is_lightweight_tag = if is_tag {
      match db.get(rfs, item.1) {
        Some(o) => o.obj_type != @bitcore.ObjectType::Tag
        None => false
      }
    } else {
      false
    }
    let entry : LogDecorationRef = {
      refname: item.0,
      display_name,
      is_head: false,
      is_tag,
      is_lightweight_tag,
    }
    match ref_entries.get(hex) {
      Some(arr) => arr.push(entry)
      None => ref_entries[hex] = [entry]
    }
  }
  let head_path = git_dir + "/HEAD"
  if rfs.is_file(head_path) {
    let content = rfs.read_file(head_path) |> decode_bytes |> trim_string
    if content.has_prefix("ref: ") &&
      log_should_include_decoration_ref(
        "HEAD",
        options.include_patterns,
        options.exclude_patterns,
        options.include_all_refs,
      ) {
      let head_ref = String::unsafe_substring(
        content,
        start=5,
        end=content.length(),
      )
      match @bitrepo.rev_parse(rfs, git_dir, "HEAD") {
        Some(head_id) => {
          let hex = head_id.to_hex()
          let head_target = if log_decoration_mode_is_full(options.mode) {
            head_ref
          } else {
            log_shorten_refname_for_decoration(head_ref)
          }
          let deco = "HEAD -> " + head_target
          let head_entry : LogDecorationRef = {
            refname: "HEAD",
            display_name: deco,
            is_head: true,
            is_tag: false,
            is_lightweight_tag: false,
          }
          match ref_entries.get(hex) {
            Some(arr) => {
              let new_arr : Array[LogDecorationRef] = [head_entry]
              for existing in arr {
                if existing.refname != head_ref {
                  new_arr.push(existing)
                }
              }
              ref_entries[hex] = new_arr
            }
            None => ref_entries[hex] = [head_entry]
          }
        }
        None => ()
      }
    }
  }
  let ref_names : Map[String, Array[String]] = {}
  for hex, entries in ref_entries {
    let head_names : Array[String] = []
    let plain_names : Array[String] = []
    let tag_entries : Array[LogDecorationRef] = []
    for entry in entries {
      if entry.is_head {
        head_names.push(entry.display_name)
      } else if entry.is_tag {
        tag_entries.push(entry)
      } else {
        plain_names.push(entry.display_name)
      }
    }
    let sorted_tag_entries : Array[LogDecorationRef] = []
    for entry in tag_entries {
      let mut pos = sorted_tag_entries.length()
      for i in 0..<sorted_tag_entries.length() {
        let current = sorted_tag_entries[i]
        let should_insert_before = if entry.is_lightweight_tag !=
          current.is_lightweight_tag {
          entry.is_lightweight_tag
        } else {
          log_string_desc_before(entry.display_name, current.display_name)
        }
        if should_insert_before {
          pos = i
          break
        }
      }
      sorted_tag_entries.push(entry)
      let mut j = sorted_tag_entries.length() - 1
      while j > pos {
        sorted_tag_entries[j] = sorted_tag_entries[j - 1]
        j -= 1
      }
      sorted_tag_entries[pos] = entry
    }
    let sorted_tags : Array[String] = []
    for entry in sorted_tag_entries {
      sorted_tags.push(entry.display_name)
    }
    ref_names[hex] = head_names + sorted_tags + plain_names
  }
  ref_names
}

///|
fn log_resolve_common_git_dir(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> String {
  let commondir_path = git_dir + "/commondir"
  if !rfs.is_file(commondir_path) {
    return git_dir
  }
  let raw = @utf8.decode_lossy(
    (rfs.read_file(commondir_path) catch { _ => Bytes::default() })[:],
  )
  let rel = trim_string(raw)
  if rel.length() == 0 {
    return git_dir
  }
  if rel.has_prefix("/") {
    normalize_path(rel)
  } else {
    normalize_path(git_dir + "/" + rel)
  }
}

///|
fn log_resolve_parents(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  commit_id : @bitcore.ObjectId,
  default_parents : Array[@bitcore.ObjectId],
) -> Array[@bitcore.ObjectId] {
  match log_read_graft_parents(rfs, git_dir, commit_id) {
    Some(parents) => parents
    None => default_parents
  }
}

///|
fn log_read_graft_parents(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  commit_id : @bitcore.ObjectId,
) -> Array[@bitcore.ObjectId]? {
  let graft_path = log_resolve_common_git_dir(rfs, git_dir) + "/info/grafts"
  if !rfs.is_file(graft_path) {
    return None
  }
  let content = @utf8.decode_lossy(
    (rfs.read_file(graft_path) catch { _ => return None })[:],
  )
  let commit_hex = commit_id.to_hex()
  for line_view in content.split("\n") {
    let line = trim_string(line_view.to_string())
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let tokens : Array[String] = []
    for token_view in line.split(" ") {
      let token = trim_string(token_view.to_string())
      if token.length() > 0 {
        tokens.push(token)
      }
    }
    if tokens.length() == 0 || tokens[0] != commit_hex {
      continue
    }
    let parents : Array[@bitcore.ObjectId] = []
    for i in 1..<tokens.length() {
      let parent_hex = tokens[i]
      if parent_hex.length() == 40 {
        let parent_id = @bitcore.ObjectId::from_hex(parent_hex) catch {
          _ => continue
        }
        parents.push(parent_id)
      }
    }
    return Some(parents)
  }
  None
}

///|
fn log_resolve_default_head(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> @bitcore.ObjectId raise Error {
  match @bitrepo.rev_parse(rfs, git_dir, "HEAD") {
    Some(id) => id
    None =>
      raise @bitcore.GitError::InvalidObject(
        "your current branch does not have any commits yet",
      )
  }
}

///|
fn log_collect_branch_targets(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  patterns : Array[String],
) -> Array[(String, @bitcore.ObjectId)] {
  let targets : Array[(String, @bitcore.ObjectId)] = []
  if patterns.length() == 0 {
    return targets
  }
  let refs = @bitlib.list_refs_with_ids(rfs, git_dir, Some("refs/heads/"))
  let entries = refs.to_array()
  entries.sort_by((a, b) => a.0.compare(b.0))
  let active_patterns = patterns
  for entry in entries {
    let refname = entry.0
    let id = entry.1
    let short_name = String::unsafe_substring(
      refname,
      start=11,
      end=refname.length(),
    )
    let mut matched = false
    for pattern in active_patterns {
      if log_branch_pattern_matches(short_name, pattern) {
        matched = true
        break
      }
    }
    if matched {
      targets.push((short_name, id))
    }
  }
  targets
}

///|
fn log_resolve_targets(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  revs : Array[String],
  branch_patterns : Array[String],
  all_refs : Bool,
  default_head? : Bool = true,
  ignore_missing? : Bool = false,
) -> Array[(String, @bitcore.ObjectId)] raise Error {
  let targets : Array[(String, @bitcore.ObjectId)] = []
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  if all_refs {
    let refs = @bitlib.list_refs_with_ids(rfs, git_dir, None)
    for name, id in refs {
      targets.push((name, id))
    }
    targets.sort_by((a, b) => a.0.compare(b.0))
  }
  for target in log_collect_branch_targets(rfs, git_dir, branch_patterns) {
    targets.push(target)
  }
  for rev in revs {
    let resolved = @bitrepo.rev_parse(rfs, git_dir, rev)
    guard resolved is Some(id) else {
      if ignore_missing {
        continue
      }
      raise @bitcore.GitError::InvalidObject("Unknown revision: " + rev)
    }
    let target_id = (@bitrepo.rev_parse(rfs, git_dir, rev + "^{commit}") catch {
      _ => None
    }).unwrap_or(id)
    if ignore_missing && db.get(rfs, target_id) is None {
      continue
    }
    targets.push((rev, target_id))
  }
  if targets.length() == 0 && default_head {
    targets.push(("HEAD", log_resolve_default_head(rfs, git_dir)))
  }
  targets
}

///|
fn log_collect_reflog_targets(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  revs : Array[String],
  branch_patterns : Array[String],
) -> Array[String] {
  let targets : Array[String] = []
  if revs.length() > 0 {
    targets.append(revs)
    return targets
  }
  if branch_patterns.length() > 0 {
    for target in log_collect_branch_targets(rfs, git_dir, branch_patterns) {
      targets.push(target.0)
    }
    return targets
  }
  ["HEAD"]
}

///|
fn log_sort_targets_by_time(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  targets : Array[(String, @bitcore.ObjectId)],
) -> Array[(String, @bitcore.ObjectId)] raise Error {
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let ordered : Array[(Int64, Int, (String, @bitcore.ObjectId))] = []
  for i in 0..<targets.length() {
    let target = targets[i]
    let ts = log_get_commit_timestamp(db, rfs, target.1)
    ordered.push((ts, i, target))
  }
  ordered.sort_by((a, b) => {
    if a.0 == b.0 {
      a.1.compare(b.1)
    } else {
      b.0.compare(a.0)
    }
  })
  let sorted : Array[(String, @bitcore.ObjectId)] = []
  for item in ordered {
    sorted.push(item.2)
  }
  sorted
}

///|
fn log_find_merge_base(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  left : @bitcore.ObjectId,
  right : @bitcore.ObjectId,
) -> @bitcore.ObjectId? raise Error {
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let left_ancestors : Map[String, Bool] = {}
  let left_queue : Array[@bitcore.ObjectId] = [left]
  while left_queue.length() > 0 {
    let current = left_queue.unsafe_pop()
    let hex = current.to_hex()
    if left_ancestors.contains(hex) {
      continue
    }
    left_ancestors[hex] = true
    let obj = db.get(rfs, current)
    match obj {
      Some(o) =>
        if o.obj_type == @bitcore.ObjectType::Commit {
          let info = @bitcore.parse_commit(o.data)
          for parent in info.parents {
            left_queue.push(parent)
          }
        }
      None => ()
    }
  }
  let seen : Map[String, Bool] = {}
  let right_queue : Array[@bitcore.ObjectId] = [right]
  while right_queue.length() > 0 {
    let current = right_queue.unsafe_pop()
    let hex = current.to_hex()
    if seen.contains(hex) {
      continue
    }
    seen[hex] = true
    if left_ancestors.contains(hex) {
      return Some(current)
    }
    let obj = db.get(rfs, current)
    match obj {
      Some(o) =>
        if o.obj_type == @bitcore.ObjectType::Commit {
          let info = @bitcore.parse_commit(o.data)
          for parent in info.parents {
            right_queue.push(parent)
          }
        }
      None => ()
    }
  }
  None
}

///|
fn log_build_commit_sources(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  start_targets : Array[(String, @bitcore.ObjectId)],
  exclude_ids : Map[String, Bool],
  first_parent? : Bool = false,
) -> Map[String, String] raise Error {
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let out : Map[String, String] = {}
  let visited : Map[String, Bool] = {}
  let queue : Array[(Int64, Int, @bitcore.ObjectId, String)] = []
  let mut seq = 0
  for target in start_targets {
    let name = target.0
    let id = target.1
    let hex = id.to_hex()
    if visited.contains(hex) || exclude_ids.contains(hex) {
      continue
    }
    visited[hex] = true
    let ts = log_get_commit_timestamp(db, rfs, id)
    let item = (ts, seq, id, name)
    let mut pos = queue.length()
    for i in 0..<queue.length() {
      let existing = queue[i]
      if ts > existing.0 || (ts == existing.0 && seq < existing.1) {
        pos = i
        break
      }
    }
    queue.push(item)
    let mut j = queue.length() - 1
    while j > pos {
      queue[j] = queue[j - 1]
      j -= 1
    }
    queue[pos] = item
    seq += 1
  }
  while queue.length() > 0 {
    let (_, _, id, name) = queue[0]
    let new_q : Array[(Int64, Int, @bitcore.ObjectId, String)] = []
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
    out[hex] = name
    let obj = db.get(rfs, id)
    guard obj is Some(o) else { continue }
    if o.obj_type != @bitcore.ObjectType::Commit {
      continue
    }
    let info = @bitcore.parse_commit(o.data)
    let parents_to_walk = if first_parent && info.parents.length() > 0 {
      [info.parents[0]]
    } else {
      info.parents
    }
    for parent in parents_to_walk {
      let phex = parent.to_hex()
      if visited.contains(phex) || exclude_ids.contains(phex) {
        continue
      }
      visited[phex] = true
      let pts = log_get_commit_timestamp(db, rfs, parent)
      let item = (pts, seq, parent, name)
      let mut pos = queue.length()
      for i in 0..<queue.length() {
        let existing = queue[i]
        if pts > existing.0 || (pts == existing.0 && seq < existing.1) {
          pos = i
          break
        }
      }
      queue.push(item)
      let mut j = queue.length() - 1
      while j > pos {
        queue[j] = queue[j - 1]
        j -= 1
      }
      queue[pos] = item
      seq += 1
    }
  }
  out
}

///|
fn log_diff_filter_key(ch : Char) -> String? {
  match ch {
    'A' | 'a' => Some("A")
    'C' | 'c' => Some("C")
    'D' | 'd' => Some("D")
    'M' | 'm' => Some("M")
    'R' | 'r' => Some("R")
    _ => None
  }
}

///|
fn log_add_diff_filter_chars(
  filter : String,
  include_bits : Map[String, Bool],
  exclude : Map[String, Bool],
) -> Unit {
  for ch in filter.to_array() {
    match log_diff_filter_key(ch) {
      Some(key) =>
        if ch >= 'a' && ch <= 'z' {
          exclude[key] = true
        } else {
          include_bits[key] = true
        }
      None => ()
    }
  }
}

///|
fn log_has_diff_filter(
  include_bits : Map[String, Bool],
  exclude : Map[String, Bool],
) -> Bool {
  include_bits.length() > 0 || exclude.length() > 0
}

///|
fn log_diff_content_oid(content : Bytes?) -> @bitcore.ObjectId? {
  match content {
    Some(bytes) =>
      Some(@bitcore.hash_object_content(@bitcore.ObjectType::Blob, bytes))
    None => None
  }
}

///|
fn log_commit_diff_statuses(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  db : @bitlib.ObjectDb,
  commit_id : @bitcore.ObjectId,
  detect_renames : Bool,
  detect_copies : Bool,
) -> Map[String, Bool] raise Error {
  let statuses : Map[String, Bool] = {}
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else { return statuses }
  let info = @bitcore.parse_commit(o.data)
  let old_tree : @bitcore.ObjectId? = if info.parents.length() > 0 {
    match db.get(rfs, info.parents[0]) {
      Some(parent_obj) => Some(@bitcore.parse_commit(parent_obj.data).tree)
      None => None
    }
  } else {
    None
  }
  let diff_files = @bitdiff.diff_trees(rfs, git_dir, old_tree, info.tree, db~)
  let added : Array[(String, @bitcore.ObjectId)] = []
  let deleted : Array[(String, @bitcore.ObjectId)] = []
  for file in diff_files {
    match file.kind {
      @bitdiff.DiffKind::Added =>
        match log_diff_content_oid(file.new_content) {
          Some(oid) => added.push((file.path, oid))
          None => statuses["A"] = true
        }
      @bitdiff.DiffKind::Deleted =>
        match log_diff_content_oid(file.old_content) {
          Some(oid) => deleted.push((file.path, oid))
          None => statuses["D"] = true
        }
      @bitdiff.DiffKind::Modified => statuses["M"] = true
    }
  }
  let renamed_added : Map[String, Bool] = {}
  let renamed_deleted : Map[String, Bool] = {}
  if detect_renames {
    for add_item in added {
      let added_path = add_item.0
      let added_oid = add_item.1
      for del_item in deleted {
        let deleted_path = del_item.0
        let deleted_oid = del_item.1
        if renamed_added.contains(added_path) ||
          renamed_deleted.contains(deleted_path) {
          continue
        }
        if added_oid == deleted_oid {
          renamed_added[added_path] = true
          renamed_deleted[deleted_path] = true
          statuses["R"] = true
          break
        }
      }
    }
  }
  if detect_copies {
    match old_tree {
      Some(old_tree_id) => {
        let old_entries = commit_collect_tree_entries(rfs, db, old_tree_id)
        for add_item in added {
          let added_path = add_item.0
          let added_oid = add_item.1
          if renamed_added.contains(added_path) {
            continue
          }
          let mut copied = false
          for old_path, old_oid in old_entries {
            if old_path != added_path && old_oid == added_oid {
              copied = true
              break
            }
          }
          if copied {
            statuses["C"] = true
          }
        }
      }
      None => ()
    }
  }
  for file in diff_files {
    match file.kind {
      @bitdiff.DiffKind::Added =>
        if !renamed_added.contains(file.path) {
          statuses["A"] = true
        }
      @bitdiff.DiffKind::Deleted =>
        if !renamed_deleted.contains(file.path) {
          statuses["D"] = true
        }
      @bitdiff.DiffKind::Modified => ()
    }
  }
  statuses
}

///|
fn log_commit_matches_diff_filter_with_statuses(
  statuses : Map[String, Bool],
  include_bits : Map[String, Bool],
  exclude : Map[String, Bool],
) -> Bool {
  if !log_has_diff_filter(include_bits, exclude) {
    return true
  }
  if include_bits.length() == 0 {
    for key, _ in statuses {
      if !exclude.contains(key) {
        return true
      }
    }
    return false
  }
  for key, _ in exclude {
    if statuses.contains(key) {
      return false
    }
  }
  for key, _ in include_bits {
    if statuses.contains(key) {
      return true
    }
  }
  false
}

///|
fn log_commit_matches_diff_filter(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  db : @bitlib.ObjectDb,
  commit_id : @bitcore.ObjectId,
  include_bits : Map[String, Bool],
  exclude : Map[String, Bool],
  detect_renames : Bool,
  detect_copies : Bool,
) -> Bool raise Error {
  if !log_has_diff_filter(include_bits, exclude) {
    return true
  }
  let statuses = log_commit_diff_statuses(
    rfs, git_dir, db, commit_id, detect_renames, detect_copies,
  )
  log_commit_matches_diff_filter_with_statuses(statuses, include_bits, exclude)
}

///|
fn log_commit_matches_pathspecs(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  db : @bitlib.ObjectDb,
  commit_id : @bitcore.ObjectId,
  pathspecs : Array[String],
) -> Bool raise Error {
  if pathspecs.length() == 0 {
    return true
  }
  match log_load_entry(db, rfs, git_dir, commit_id, true) {
    Some(entry) => {
      let diff_files = @bitdiff.diff_trees(
        rfs,
        git_dir,
        entry.parent_tree,
        entry.tree,
        db~,
      )
      for file in diff_files {
        if diff_path_matches_filters(file.path, pathspecs) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn log_commit_matches_history_filters(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  db : @bitlib.ObjectDb,
  commit_id : @bitcore.ObjectId,
  pathspecs : Array[String],
  include_bits : Map[String, Bool],
  exclude : Map[String, Bool],
  detect_renames : Bool,
  detect_copies : Bool,
) -> Bool raise Error {
  if !log_commit_matches_pathspecs(rfs, git_dir, db, commit_id, pathspecs) {
    return false
  }
  log_commit_matches_diff_filter(
    rfs, git_dir, db, commit_id, include_bits, exclude, detect_renames, detect_copies,
  )
}

///|
priv struct LogRawResult {
  sort_key : String
  old_mode : String
  new_mode : String
  old_id : @bitcore.ObjectId
  new_id : @bitcore.ObjectId
  status : String
  old_path : String
  new_path : String
}

///|
fn log_format_raw_result(result : LogRawResult, abbrev_len : Int) -> String {
  let old_hex = log_abbrev_hex(result.old_id.to_hex(), abbrev_len)
  let new_hex = log_abbrev_hex(result.new_id.to_hex(), abbrev_len)
  let path_part = if result.status.has_prefix("R") ||
    result.status.has_prefix("C") {
    result.old_path + "\t" + result.new_path
  } else {
    result.new_path
  }
  ":\{result.old_mode} \{result.new_mode} \{old_hex} \{new_hex} \{result.status}\t\{path_part}"
}

///|
fn log_collect_raw_results(
  rfs : &@bitcore.RepoFileSystem,
  db : @bitlib.ObjectDb,
  old_tree : @bitcore.ObjectId?,
  new_tree : @bitcore.ObjectId,
  detect_renames : Bool,
  detect_copies : Bool,
) -> Array[LogRawResult] raise Error {
  let old_entries : Map[String, DiffTreeEntry] = {}
  let new_entries : Map[String, DiffTreeEntry] = {}
  match old_tree {
    Some(tree_id) =>
      diff_tree_collect_entries(db, rfs, tree_id, "", true, false, old_entries)
    None => ()
  }
  diff_tree_collect_entries(db, rfs, new_tree, "", true, false, new_entries)
  let zero_id = @bitcore.ObjectId::zero()
  let results : Array[LogRawResult] = []
  let added : Array[(String, DiffTreeEntry)] = []
  let deleted : Array[(String, DiffTreeEntry)] = []
  for path, entry in new_entries {
    match old_entries.get(path) {
      None => added.push((path, entry))
      Some(old_entry) =>
        if old_entry.id != entry.id || old_entry.mode != entry.mode {
          let status = if old_entry.mode != entry.mode &&
            old_entry.id == entry.id {
            "T"
          } else {
            "M"
          }
          results.push({
            sort_key: path,
            old_mode: old_entry.mode,
            new_mode: entry.mode,
            old_id: old_entry.id,
            new_id: entry.id,
            status,
            old_path: path,
            new_path: path,
          })
        }
    }
  }
  for path, entry in old_entries {
    if !new_entries.contains(path) {
      deleted.push((path, entry))
    }
  }
  let renamed_added : Map[String, LogRawResult] = {}
  let renamed_deleted : Map[String, Bool] = {}
  if detect_renames {
    for add_item in added {
      let new_path = add_item.0
      let new_entry = add_item.1
      for del_item in deleted {
        let old_path = del_item.0
        let old_entry = del_item.1
        if renamed_added.contains(new_path) ||
          renamed_deleted.contains(old_path) {
          continue
        }
        if new_entry.id == old_entry.id {
          renamed_added[new_path] = {
            sort_key: new_path,
            old_mode: old_entry.mode,
            new_mode: new_entry.mode,
            old_id: old_entry.id,
            new_id: new_entry.id,
            status: "R100",
            old_path,
            new_path,
          }
          renamed_deleted[old_path] = true
          break
        }
      }
    }
  }
  let copied_added : Map[String, LogRawResult] = {}
  if detect_copies {
    for add_item in added {
      let new_path = add_item.0
      let new_entry = add_item.1
      if renamed_added.contains(new_path) {
        continue
      }
      for old_path, old_entry in old_entries {
        if old_path != new_path && old_entry.id == new_entry.id {
          copied_added[new_path] = {
            sort_key: new_path,
            old_mode: old_entry.mode,
            new_mode: new_entry.mode,
            old_id: old_entry.id,
            new_id: new_entry.id,
            status: "C100",
            old_path,
            new_path,
          }
          break
        }
      }
    }
  }
  for add_item in added {
    let path = add_item.0
    let entry = add_item.1
    match renamed_added.get(path) {
      Some(result) => results.push(result)
      None =>
        match copied_added.get(path) {
          Some(result) => results.push(result)
          None =>
            results.push({
              sort_key: path,
              old_mode: "000000",
              new_mode: entry.mode,
              old_id: zero_id,
              new_id: entry.id,
              status: "A",
              old_path: path,
              new_path: path,
            })
        }
    }
  }
  for del_item in deleted {
    let path = del_item.0
    let entry = del_item.1
    if renamed_deleted.contains(path) {
      continue
    }
    results.push({
      sort_key: path,
      old_mode: entry.mode,
      new_mode: "000000",
      old_id: entry.id,
      new_id: zero_id,
      status: "D",
      old_path: path,
      new_path: path,
    })
  }
  results.sort_by(fn(a, b) { String::compare(a.sort_key, b.sort_key) })
  results
}

///|
fn log_grep_patterns_match(
  message : String,
  patterns : Array[String],
  pattern_type : GrepPatternType,
  ignore_case : Bool,
  all_match : Bool,
) -> Bool {
  if patterns.length() == 0 {
    return true
  }
  if !all_match {
    return grep_patterns_match_message(
      message, patterns, pattern_type, ignore_case,
    )
  }
  for pattern in patterns {
    if !grep_message_matches_pattern(
        message, pattern, pattern_type, ignore_case,
      ) {
      return false
    }
  }
  true
}

///|
fn log_identity_patterns_match(
  text : String,
  patterns : Array[String],
  pattern_type : GrepPatternType,
  ignore_case : Bool,
) -> Bool {
  if patterns.length() == 0 {
    return true
  }
  for pattern in patterns {
    if grep_message_matches_pattern(text, pattern, pattern_type, ignore_case) {
      return true
    }
  }
  false
}

///|
fn log_validate_reflog_grep_options(
  walk_reflogs : Bool,
  grep_reflog_patterns : Array[String],
) -> Unit raise Error {
  if grep_reflog_patterns.length() > 0 && !walk_reflogs {
    raise @bitcore.GitError::InvalidObject(
      "fatal: the option '--grep-reflog' requires '--walk-reflogs'",
    )
  }
}

///|
fn log_commit_matches_text_filters(
  rfs : &@bitcore.RepoFileSystem,
  db : @bitlib.ObjectDb,
  commit_id : @bitcore.ObjectId,
  grep_patterns : Array[String],
  pattern_type : GrepPatternType,
  ignore_case : Bool,
  invert_grep : Bool,
  all_match : Bool,
  author_patterns : Array[String],
  committer_patterns : Array[String],
) -> Bool raise Error {
  if grep_patterns.length() == 0 &&
    author_patterns.length() == 0 &&
    committer_patterns.length() == 0 {
    return true
  }
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else { return false }
  let info = @bitcore.parse_commit(o.data)
  let data = parse_commit_format_data(
    commit_id,
    o.data,
    info.tree,
    info.parents,
    {},
  )
  let message_match = log_grep_patterns_match(
    data.message,
    grep_patterns,
    pattern_type,
    ignore_case,
    all_match,
  )
  let effective_message_match = if grep_patterns.length() > 0 && invert_grep {
    !message_match
  } else {
    message_match
  }
  if !effective_message_match {
    return false
  }
  let author_text = data.author_name + " <" + data.author_email + ">"
  if !log_identity_patterns_match(
      author_text, author_patterns, pattern_type, ignore_case,
    ) {
    return false
  }
  let committer_text = data.committer_name + " <" + data.committer_email + ">"
  if !log_identity_patterns_match(
      committer_text, committer_patterns, pattern_type, ignore_case,
    ) {
    return false
  }
  true
}

///|
fn log_string_without_last_char(text : String) -> String {
  let chars = text.to_array()
  if chars.length() == 0 {
    text
  } else {
    String::from_array(chars[:chars.length() - 1])
  }
}

///|
fn log_repeat_char(c : Char, count : Int) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < count {
    out.write_char(c)
    i += 1
  }
  out.to_string()
}

///|
fn log_apply_width_directive(
  text : String,
  width : Int,
  mode : String,
) -> String {
  if width <= 0 {
    return ""
  }
  let chars = text.to_array()
  let len = chars.length()
  if len <= width {
    return text + log_repeat_char(' ', width - len)
  }
  if width <= 2 {
    return String::from_array(chars[:width])
  }
  let keep = width - 2
  match mode {
    "ltrunc" => ".." + String::from_array(chars[len - keep:])
    "mtrunc" => {
      let left = keep / 2
      let right = keep - left
      String::from_array(chars[:left]) +
      ".." +
      String::from_array(chars[len - right:])
    }
    _ => String::from_array(chars[:keep]) + ".."
  }
}

///|
fn log_format_commit_spec(
  chars : Array[Char],
  spec_idx : Int,
  data : CommitFormatData,
) -> (String, Int) {
  if spec_idx >= chars.length() {
    return ("", spec_idx)
  }
  let spec = chars[spec_idx]
  match spec {
    'H' => (data.id.to_hex(), spec_idx + 1)
    'h' => (log_abbrev_hex(data.id.to_hex(), data.abbrev_len), spec_idx + 1)
    'm' => (data.left_right_marker, spec_idx + 1)
    'T' => (data.tree.to_hex(), spec_idx + 1)
    't' => (log_abbrev_hex(data.tree.to_hex(), data.abbrev_len), spec_idx + 1)
    'e' => (data.encoding, spec_idx + 1)
    'P' => {
      let parent_hexes = data.parents.map(fn(p) { p.to_hex() })
      (parent_hexes.join(" "), spec_idx + 1)
    }
    'p' => {
      let parent_shorts = data.parents.map(fn(p) {
        log_abbrev_hex(p.to_hex(), data.abbrev_len)
      })
      (parent_shorts.join(" "), spec_idx + 1)
    }
    'a' if spec_idx + 1 < chars.length() => {
      let subspec = chars[spec_idx + 1]
      match subspec {
        'n' => (data.author_name, spec_idx + 2)
        'e' => (data.author_email, spec_idx + 2)
        't' => (data.author_timestamp.to_string(), spec_idx + 2)
        'i' =>
          (
            format_timestamp_iso(data.author_timestamp, data.author_tz),
            spec_idx + 2,
          )
        'd' =>
          (
            format_date_by_mode(
              data.author_timestamp,
              data.author_tz,
              data.date_format,
            ),
            spec_idx + 2,
          )
        'D' =>
          (
            format_timestamp_rfc2822(data.author_timestamp, data.author_tz),
            spec_idx + 2,
          )
        _ => ("%a", spec_idx + 1)
      }
    }
    'c' if spec_idx + 1 < chars.length() => {
      let subspec = chars[spec_idx + 1]
      match subspec {
        'n' => (data.committer_name, spec_idx + 2)
        'e' => (data.committer_email, spec_idx + 2)
        't' => (data.committer_timestamp.to_string(), spec_idx + 2)
        'i' =>
          (
            format_timestamp_iso(data.committer_timestamp, data.committer_tz),
            spec_idx + 2,
          )
        'd' =>
          (
            format_date_by_mode(
              data.committer_timestamp,
              data.committer_tz,
              data.date_format,
            ),
            spec_idx + 2,
          )
        'D' =>
          (
            format_timestamp_rfc2822(
              data.committer_timestamp,
              data.committer_tz,
            ),
            spec_idx + 2,
          )
        _ => ("%c", spec_idx + 1)
      }
    }
    's' => (data.subject, spec_idx + 1)
    'f' => (log_sanitize_subject_for_format(data.subject), spec_idx + 1)
    'g' if spec_idx + 1 < chars.length() => {
      let subspec = chars[spec_idx + 1]
      match subspec {
        'd' => (data.reflog_selector_short.unwrap_or(""), spec_idx + 2)
        'D' =>
          (
            data.reflog_selector.unwrap_or(
              data.reflog_selector_short.unwrap_or(""),
            ),
            spec_idx + 2,
          )
        's' => (data.reflog_message.unwrap_or(""), spec_idx + 2)
        'n' => (data.reflog_author_name.unwrap_or(""), spec_idx + 2)
        'e' => (data.reflog_author_email.unwrap_or(""), spec_idx + 2)
        _ => ("%g", spec_idx + 1)
      }
    }
    'b' => (data.body, spec_idx + 1)
    'B' => (data.message, spec_idx + 1)
    'n' => ("\n", spec_idx + 1)
    '%' => ("%", spec_idx + 1)
    'd' => {
      let hex = data.id.to_hex()
      let rendered = match data.ref_names.get(hex) {
        Some(names) if names.length() > 0 => " (" + names.join(", ") + ")"
        _ => ""
      }
      (rendered, spec_idx + 1)
    }
    'D' => {
      let hex = data.id.to_hex()
      let rendered = match data.ref_names.get(hex) {
        Some(names) if names.length() > 0 => names.join(", ")
        _ => ""
      }
      (rendered, spec_idx + 1)
    }
    _ => ("%" + spec.to_string(), spec_idx + 1)
  }
}

///|
fn log_format_commit_width_spec(
  chars : Array[Char],
  percent_idx : Int,
  data : CommitFormatData,
) -> (String, Int)? {
  if percent_idx + 2 >= chars.length() ||
    chars[percent_idx + 1] != '<' ||
    chars[percent_idx + 2] != '(' {
    return None
  }
  let mut end = percent_idx + 3
  while end < chars.length() && chars[end] != ')' {
    end += 1
  }
  if end >= chars.length() || end + 2 >= chars.length() || chars[end + 1] != '%' {
    return None
  }
  let spec_text = String::from_array(chars[percent_idx + 3:end])
  let spec_chars = spec_text.to_array()
  let mut comma_idx = -1
  let mut spec_idx = 0
  while spec_idx < spec_chars.length() {
    if spec_chars[spec_idx] == ',' {
      comma_idx = spec_idx
      break
    }
    spec_idx += 1
  }
  let width_text = if comma_idx >= 0 {
    String::from_array(spec_chars[:comma_idx])
  } else {
    spec_text
  }
  let width = @string.parse_int(width_text) catch { _ => -1 }
  if width < 0 {
    return None
  }
  let mode = if comma_idx >= 0 {
    String::from_array(spec_chars[comma_idx + 1:])
  } else {
    "trunc"
  }
  let (raw_text, next_idx) = log_format_commit_spec(chars, end + 2, data)
  Some((log_apply_width_directive(raw_text, width, mode), next_idx))
}

///|
fn format_commit_string(fmt : String, data : CommitFormatData) -> String {
  let chars = fmt.to_array()
  let len = chars.length()
  let mut i = 0
  let mut wrap_spec : LogWrapSpec? = None
  let mut rendered = ""
  let mut pretty_color_active = false
  while i < len {
    if chars[i] == '%' && i + 1 < len {
      let next = chars[i + 1]
      match next {
        'C' =>
          match log_parse_pretty_color_directive_text(chars, i) {
            Some((spec, next_idx)) => {
              let (ansi, state_change) = log_resolve_pretty_color_directive(
                spec, data,
              )
              if state_change == 0 {
                if pretty_color_active {
                  rendered = rendered + "\u001b[m"
                  pretty_color_active = false
                }
              } else if state_change == 1 {
                rendered = rendered + ansi
                pretty_color_active = ansi != ""
              }
              i = next_idx
            }
            None => {
              rendered = rendered + "%C"
              i += 2
            }
          }
        'w' if i + 2 < len && chars[i + 2] == '(' => {
          let mut end = i + 3
          while end < len && chars[end] != ')' {
            end += 1
          }
          if end < len {
            let spec_text = String::from_array(chars[i + 3:end])
            wrap_spec = Some(log_parse_wrap_spec(spec_text))
            i = end + 1
          } else {
            rendered = rendered + "%w"
            i += 2
          }
        }
        '<' =>
          match log_format_commit_width_spec(chars, i, data) {
            Some((text, next_idx)) => {
              rendered = rendered + text
              i = next_idx
            }
            None => {
              rendered = rendered + "%<"
              i += 2
            }
          }
        '-' | '+' | ' ' if i + 2 < len => {
          let (text, next_idx) = log_format_commit_spec(chars, i + 2, data)
          if next_idx == i + 2 {
            rendered = rendered + "%" + next.to_string()
            i += 2
          } else {
            match next {
              '-' =>
                if text.length() == 0 &&
                  rendered.length() > 0 &&
                  rendered.to_array()[rendered.to_array().length() - 1] == '\n' {
                  rendered = log_string_without_last_char(rendered)
                } else {
                  rendered = rendered + text
                }
              '+' => {
                let prefix = if text.length() > 0 { "\n" + text } else { "" }
                rendered = rendered + prefix
              }
              ' ' => {
                let prefix = if text.length() > 0 { " " + text } else { "" }
                rendered = rendered + prefix
              }
              _ => ()
            }
            i = next_idx
          }
        }
        _ => {
          let (text, next_idx) = log_format_commit_spec(chars, i + 1, data)
          rendered = rendered + text
          i = next_idx
        }
      }
    } else {
      rendered = rendered + chars[i].to_string()
      i += 1
    }
  }
  if pretty_color_active {
    rendered = rendered + "\u001b[m"
  }
  match wrap_spec {
    Some(spec) => log_apply_wrap(rendered, spec)
    None => rendered
  }
}

///|
fn log_sanitize_subject_for_format(s : String) -> String {
  let sb = StringBuilder::new()
  let mut last_was_dash = false
  for c in s {
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') {
      sb.write_char(c)
      last_was_dash = false
    } else if !last_was_dash {
      sb.write_char('-')
      last_was_dash = true
    }
  }
  let result = sb.to_string()
  if result.length() > 0 && result[result.length() - 1] == '-' {
    String::unsafe_substring(result, start=0, end=result.length() - 1)
  } else {
    result
  }
}

///|
fn format_date_by_mode(ts : Int64, tz : String, mode : String) -> String {
  match mode {
    "iso" | "iso8601" => format_timestamp_iso(ts, tz)
    "iso-strict" | "iso8601-strict" => format_timestamp_iso_strict(ts, tz)
    "rfc" | "rfc2822" => format_timestamp_rfc2822(ts, tz)
    "short" => format_timestamp_short(ts, tz)
    "raw" => ts.to_string() + " " + tz
    "unix" => ts.to_string()
    "default" | "" => format_timestamp_default(ts, tz)
    _ => format_timestamp_default(ts, tz)
  }
}

///|
fn log_split_reflog_target(rev : String) -> (String, String?) {
  guard rev.has_suffix("}") else { return (rev, None) }
  match rev.rev_find("@{") {
    Some(idx) => {
      let base = String::unsafe_substring(rev, start=0, end=idx)
      let selector = String::unsafe_substring(
        rev,
        start=idx + 2,
        end=rev.length() - 1,
      )
      let normalized_base = if base.length() == 0 { "HEAD" } else { base }
      if selector.length() == 0 {
        (rev, None)
      } else {
        (normalized_base, Some(selector))
      }
    }
    None => (rev, None)
  }
}

///|
fn log_parse_reflog_selector_index(selector : String) -> Int? {
  if selector.length() == 0 {
    return None
  }
  for ch in selector {
    if ch < '0' || ch > '9' {
      return None
    }
  }
  Some(@string.parse_int(selector)) catch {
    _ => None
  }
}

///|
fn log_reflog_selector_uses_date(
  explicit_selector : String?,
  date_format : String,
) -> Bool {
  match explicit_selector {
    Some(selector) => log_parse_reflog_selector_index(selector) is None
    None => date_format.length() > 0
  }
}

///|
fn log_resolve_reflog_start_index(
  entry_count : Int,
  explicit_selector : String?,
) -> Int? {
  match explicit_selector {
    Some(selector) =>
      match log_parse_reflog_selector_index(selector) {
        Some(index) if index >= 0 && index < entry_count => Some(index)
        Some(_) => None
        None => Some(0)
      }
    None => Some(0)
  }
}

///|
fn log_format_reflog_selector(
  display_ref : String,
  index : Int,
  timestamp : Int64,
  timezone : String,
  explicit_selector : String?,
  date_format : String,
) -> String {
  let selector_text = if log_reflog_selector_uses_date(
      explicit_selector, date_format,
    ) {
    format_date_by_mode(
      timestamp,
      timezone,
      if date_format.length() == 0 {
        "default"
      } else {
        date_format
      },
    )
  } else {
    index.to_string()
  }
  display_ref + "@{" + selector_text + "}"
}

///|
fn format_timestamp_default(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let dow = day_of_week(year, month, day)
  let dow_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  let month_names = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let dn = dow_names[dow]
  let mn = month_names[month - 1]
  "\{dn} \{mn} \{day} \{pad2(hour)}:\{pad2(minute)}:\{pad2(second)} \{year} \{tz}"
}

///|
fn format_timestamp_default_notz(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let dow = day_of_week(year, month, day)
  let dow_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  let month_names = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let dn = dow_names[dow]
  let mn = month_names[month - 1]
  "\{dn} \{mn} \{day} \{pad2(hour)}:\{pad2(minute)}:\{pad2(second)} \{year}"
}

///|
fn format_timestamp_short(ts : Int64, tz : String) -> String {
  let (year, month, day, _, _, _) = epoch_to_calendar(ts, tz)
  "\{year}-\{pad2(month)}-\{pad2(day)}"
}

///|
fn format_timestamp_iso_strict(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let tz_formatted = if tz.length() >= 5 {
    String::unsafe_substring(tz, start=0, end=3) +
    ":" +
    String::unsafe_substring(tz, start=3, end=5)
  } else {
    tz
  }
  "\{year}-\{pad2(month)}-\{pad2(day)}T\{pad2(hour)}:\{pad2(minute)}:\{pad2(second)}\{tz_formatted}"
}

///|
fn format_timestamp_iso(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let y = year.to_string()
  let mo = pad2(month)
  let d = pad2(day)
  let h = pad2(hour)
  let mi = pad2(minute)
  let s = pad2(second)
  "\{y}-\{mo}-\{d} \{h}:\{mi}:\{s} \{tz}"
}

///|
fn format_timestamp_rfc2822(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let dow = day_of_week(year, month, day)
  let dow_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  let month_names = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let dn = dow_names[dow]
  let mn = month_names[month - 1]
  let d = day.to_string()
  let y = year.to_string()
  let h = pad2(hour)
  let mi = pad2(minute)
  let s = pad2(second)
  "\{dn}, \{d} \{mn} \{y} \{h}:\{mi}:\{s} \{tz}"
}

///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn epoch_to_calendar(ts : Int64, tz : String) -> (Int, Int, Int, Int, Int, Int) {
  // Parse timezone offset
  let tz_offset_seconds = parse_tz_offset(tz)
  let adjusted = ts + tz_offset_seconds.to_int64()
  // Convert epoch seconds to y/m/d h:m:s
  let mut days = (adjusted / 86400L).to_int()
  let mut remaining = (adjusted % 86400L).to_int()
  if remaining < 0 {
    days -= 1
    remaining += 86400
  }
  let hour = remaining / 3600
  remaining = remaining % 3600
  let minute = remaining / 60
  let second = remaining % 60
  // Days since 1970-01-01
  let (year, month, day) = log_days_to_date(days)
  (year, month, day, hour, minute, second)
}

///|
fn parse_tz_offset(tz : String) -> Int {
  if tz.length() < 5 {
    return 0
  }
  let chars = tz.to_array()
  let sign = if chars[0] == '-' { -1 } else { 1 }
  let h = (chars[1].to_int() - '0'.to_int()) * 10 +
    (chars[2].to_int() - '0'.to_int())
  let m = (chars[3].to_int() - '0'.to_int()) * 10 +
    (chars[4].to_int() - '0'.to_int())
  sign * (h * 3600 + m * 60)
}

///|
fn log_days_to_date(days_since_epoch : Int) -> (Int, Int, Int) {
  // Algorithm from http://howardhinnant.github.io/date_algorithms.html
  let z = days_since_epoch + 719468
  let era = (if z >= 0 { z } else { z - 146096 }) / 146097
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = mp + (if mp < 10 { 3 } else { -9 })
  let year = y + (if m <= 2 { 1 } else { 0 })
  (year, m, d)
}

///|
fn day_of_week(year : Int, month : Int, day : Int) -> Int {
  // Tomohiko Sakamoto's algorithm (0=Sunday)
  let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let y = if month < 3 { year - 1 } else { year }
  (y + y / 4 - y / 100 + y / 400 + t[month - 1] + day) % 7
}

///|
fn resolve_log_reflog_refname(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  rev : String,
) -> String? {
  let (rev, _) = log_split_reflog_target(rev)
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
async fn log_emit_default_commit_entry(
  entry : LogWalkEntry,
  ref_names : Map[String, Array[String]],
  abbrev_commit : Bool,
  abbrev_len : Int,
  date_format : String,
  line_prefix : String,
  show_stat : Bool,
  show_patch : Bool,
  show_raw : Bool,
  raw_detect_renames : Bool,
  detect_copies : Bool,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  db : @bitlib.ObjectDb,
  reflog_selector? : String? = None,
  reflog_identity? : String? = None,
  reflog_message? : String? = None,
) -> Unit raise Error {
  let deco = format_decoration(ref_names, entry.id.to_hex())
  let header_hex = if abbrev_commit {
    log_abbrev_hex(entry.id.to_hex(), abbrev_len)
  } else {
    entry.id.to_hex()
  }
  log_emit_output("commit " + header_hex + deco, true, line_prefix)
  match (reflog_selector, reflog_identity, reflog_message) {
    (Some(selector), Some(identity), Some(message)) => {
      log_emit_output(
        "Reflog: " + selector + " (" + identity + ")",
        true,
        line_prefix,
      )
      log_emit_output("Reflog message: " + message, true, line_prefix)
    }
    _ => ()
  }
  log_emit_output("Author: " + entry.author, true, line_prefix)
  let date_str = format_date_by_mode(
    entry.timestamp,
    log_extract_author_tz(entry.author),
    date_format,
  )
  log_emit_output("Date:   " + date_str, true, line_prefix)
  log_emit_output("", true, line_prefix)
  log_emit_output("    " + entry.message, true, line_prefix)
  log_emit_output("", true, line_prefix)
  if show_stat || show_patch {
    let diff_files = @bitdiff.diff_trees(
      rfs,
      git_dir,
      entry.parent_tree,
      entry.tree,
      db~,
    )
    if show_stat {
      let stat_lines = @bitdiff.diff_stat(diff_files)
      for line in stat_lines {
        log_emit_output(line, true, line_prefix)
      }
      log_emit_output("", true, line_prefix)
    }
    if show_patch {
      let patch_lines = @bitdiff.diff_text(diff_files)
      for line in patch_lines {
        log_emit_output(line, true, line_prefix)
      }
      log_emit_output("", true, line_prefix)
    }
  }
  if show_raw {
    let raw_results = log_collect_raw_results(
      rfs,
      db,
      entry.parent_tree,
      entry.tree,
      raw_detect_renames,
      detect_copies,
    )
    for raw_result in raw_results {
      log_emit_output(
        log_format_raw_result(raw_result, abbrev_len),
        true,
        line_prefix,
      )
    }
    log_emit_output("", true, line_prefix)
  }
}

///|
fn format_reflog_entry(fmt : String?, gd : String, message : String) -> String {
  match fmt {
    Some("%gd") => gd
    Some("%gD") => gd
    Some("%gs") => message
    Some("%gd %gs") => gd + " " + message
    Some("%gD %gs") => gd + " " + message
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
  let cwd = @env.current_dir().unwrap_or(root)
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(fs, root)
  if log_need_real_git(args, git_dir~) {
    delegate_log_to_real_git(args, cwd)
    return
  }
  validate_commit_graph_hash_version(fs, git_dir)
  if log_should_use_storage_runtime_in_repo(rfs, git_dir, args) {
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
  let mut decorate_mode_override : LogDecorationDisplayMode? = None
  let mut show_stat = false
  let mut show_patch = false
  let mut max_count = 2147483647
  let mut since_ts = 0L
  let mut until_ts = 9223372036854775807L
  let mut no_walk = false
  let mut no_walk_unsorted = false
  let mut walk_reflogs = false
  let mut reverse = false
  let mut first_parent = false
  let mut left_right = false
  let mut source = false
  let mut stdin_mode = false
  let mut ignore_missing = false
  let mut date_format = ""
  let mut line_prefix = ""
  let mut detect_renames = false
  let mut detect_copies = false
  let mut raw_detect_renames = true
  let mut show_raw = false
  let mut no_merges = false
  let mut abbrev_commit_override : Bool? = None
  let mut abbrev_len_override : Int? = None
  let mut no_abbrev = false
  let grep_patterns : Array[String] = []
  let grep_reflog_patterns : Array[String] = []
  let mut grep_pattern_type_override : GrepPatternType? = None
  let mut grep_ignore_case = false
  let mut invert_grep = false
  let mut all_match = false
  let author_patterns : Array[String] = []
  let committer_patterns : Array[String] = []
  let mut format : String? = None
  let mut pretty_color_cli_mode : String? = None
  let decoration_include_patterns : Array[String] = []
  let decoration_exclude_patterns : Array[String] = []
  let mut clear_decorations = false
  let mut simplify_by_decoration = false
  let diff_filter_include : Map[String, Bool] = {}
  let diff_filter_exclude : Map[String, Bool] = {}
  let branch_patterns : Array[String] = []
  let revs : Array[String] = []
  let range_excludes : Array[String] = []
  let symmetric_ranges : Array[(String, String)] = []
  let pathspecs : Array[String] = []
  let mut saw_revision_input = false
  let mut end_of_options = false
  let mut pathspec_mode = false
  let mut not_mode = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if pathspec_mode {
      pathspecs.push(arg)
      i += 1
      continue
    }
    if end_of_options {
      saw_revision_input = true
      log_push_revision_input(
        arg, revs, range_excludes, symmetric_ranges, not_mode,
      )
      i += 1
      continue
    }
    match arg {
      "--oneline" => oneline = true
      "--graph" => graph = true
      "--all" => all_refs = true
      "--" => pathspec_mode = true
      "--not" => not_mode = !not_mode
      "--end-of-options" => end_of_options = true
      "--source" => source = true
      "--left-right" => left_right = true
      "--stdin" => stdin_mode = true
      "--ignore-missing" => ignore_missing = true
      "--exclude-promisor-objects" =>
        raise @bitcore.GitError::InvalidObject(
          "unsupported option: --exclude-promisor-objects",
        )
      "--branches" => {
        branch_patterns.push("*")
        saw_revision_input = true
      }
      "--glob" if i + 1 < args.length() && !args[i + 1].has_prefix("-") => {
        log_append_glob_targets(rfs, git_dir, args[i + 1], revs)
        saw_revision_input = true
        i += 1
      }
      "--glob" =>
        raise @bitcore.GitError::InvalidObject(
          "Option '--glob' requires a value",
        )
      "--no-walk" => {
        no_walk = true
        no_walk_unsorted = false
      }
      "-g" | "--walk-reflogs" => walk_reflogs = true
      "--decorate" =>
        decorate_mode_override = Some(LogDecorationDisplayMode::Short)
      "--no-decorate" =>
        decorate_mode_override = Some(LogDecorationDisplayMode::Disabled)
      "--decorate-refs" if i + 1 < args.length() => {
        decoration_include_patterns.push(args[i + 1])
        i += 1
      }
      "--decorate-refs" =>
        raise @bitcore.GitError::InvalidObject(
          "option `--decorate-refs` requires a value",
        )
      "--decorate-refs-exclude" if i + 1 < args.length() => {
        decoration_exclude_patterns.push(args[i + 1])
        i += 1
      }
      "--decorate-refs-exclude" =>
        raise @bitcore.GitError::InvalidObject(
          "option `--decorate-refs-exclude` requires a value",
        )
      "--clear-decorations" => {
        log_clear_string_array(decoration_include_patterns)
        log_clear_string_array(decoration_exclude_patterns)
        clear_decorations = true
      }
      "--simplify-by-decoration" => simplify_by_decoration = true
      "--raw" => show_raw = true
      "--stat" => show_stat = true
      "-p" | "--patch" => show_patch = true
      "--no-merges" => no_merges = true
      "--abbrev-commit" => abbrev_commit_override = Some(true)
      "--no-abbrev-commit" => abbrev_commit_override = Some(false)
      "--no-abbrev" => no_abbrev = true
      "--abbrev" if i + 1 < args.length() => {
        let parsed = @string.parse_int(args[i + 1]) catch { _ => 7 }
        abbrev_len_override = Some(log_normalize_abbrev_length(parsed))
        i += 1
      }
      "--no-renames" => {
        detect_renames = false
        detect_copies = false
        raw_detect_renames = false
      }
      "-M" => {
        detect_renames = true
        raw_detect_renames = true
      }
      "-C" => {
        detect_renames = true
        detect_copies = true
        raw_detect_renames = true
      }
      "--diff-filter" if i + 1 < args.length() => {
        log_add_diff_filter_chars(
          args[i + 1],
          diff_filter_include,
          diff_filter_exclude,
        )
        i += 1
      }
      "--grep" if i + 1 < args.length() => {
        grep_patterns.push(args[i + 1])
        i += 1
      }
      "--grep" =>
        raise @bitcore.GitError::InvalidObject(
          "option `--grep` requires a value",
        )
      "--grep-reflog" if i + 1 < args.length() => {
        grep_reflog_patterns.push(args[i + 1])
        i += 1
      }
      "--grep-reflog" =>
        raise @bitcore.GitError::InvalidObject(
          "option `--grep-reflog` requires a value",
        )
      "--author" if i + 1 < args.length() => {
        author_patterns.push(args[i + 1])
        i += 1
      }
      "--committer" if i + 1 < args.length() => {
        committer_patterns.push(args[i + 1])
        i += 1
      }
      "-i" | "--regexp-ignore-case" => grep_ignore_case = true
      "--invert-grep" => invert_grep = true
      "--all-match" => all_match = true
      "-F" | "--fixed-strings" =>
        grep_pattern_type_override = Some(GrepPatternType::Fixed)
      "-E" | "--extended-regexp" =>
        grep_pattern_type_override = Some(GrepPatternType::Extended)
      "-P" | "--perl-regexp" =>
        grep_pattern_type_override = Some(GrepPatternType::Perl)
      "--basic-regexp" =>
        grep_pattern_type_override = Some(GrepPatternType::Basic)
      "--format" if i + 1 < args.length() => {
        format = Some(args[i + 1])
        i += 1
      }
      "--color" | "--color=always" => pretty_color_cli_mode = Some("always")
      "--color=auto" => pretty_color_cli_mode = Some("auto")
      "--no-color" | "--color=never" => pretty_color_cli_mode = Some("never")
      "--pretty" if i + 1 < args.length() => {
        format = Some(args[i + 1])
        i += 1
      }
      "-n" if i + 1 < args.length() => {
        max_count = @string.parse_int(args[i + 1])
        i += 1
      }
      "--max-count" if i + 1 < args.length() => {
        max_count = @string.parse_int(args[i + 1])
        i += 1
      }
      "--since" if i + 1 < args.length() => {
        since_ts = @string.parse_int64(args[i + 1]) catch { _ => 0L }
        i += 1
      }
      "--until" if i + 1 < args.length() => {
        until_ts = @string.parse_int64(args[i + 1]) catch {
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
      _ if arg.has_prefix("--decorate=") => {
        let value = String::unsafe_substring(arg, start=11, end=arg.length())
        decorate_mode_override = Some(
          log_parse_decorate_mode(value).unwrap_or(
            LogDecorationDisplayMode::Disabled,
          ),
        )
      }
      _ if arg.has_prefix("--decorate-refs=") =>
        decoration_include_patterns.push(string_slice_from(arg, 16))
      _ if arg.has_prefix("--decorate-refs-exclude=") =>
        decoration_exclude_patterns.push(string_slice_from(arg, 24))
      _ if arg.has_prefix("-n") && arg.length() > 2 => {
        let num_str = string_slice_from(arg, 2)
        max_count = @string.parse_int(num_str)
      }
      _ if is_short_count_flag(arg) => {
        let num_str = String::unsafe_substring(arg, start=1, end=arg.length())
        max_count = @string.parse_int(num_str)
      }
      _ if arg.has_prefix("--max-count=") => {
        let num_str = string_slice_from(arg, 12)
        max_count = @string.parse_int(num_str)
      }
      _ if arg.has_prefix("--diff-filter=") => {
        let value = string_slice_from(arg, 14)
        log_add_diff_filter_chars(
          value, diff_filter_include, diff_filter_exclude,
        )
      }
      _ if arg.has_prefix("--grep=") =>
        grep_patterns.push(string_slice_from(arg, 7))
      _ if arg.has_prefix("--grep-reflog=") =>
        grep_reflog_patterns.push(string_slice_from(arg, 14))
      _ if arg.has_prefix("--author=") =>
        author_patterns.push(string_slice_from(arg, 9))
      _ if arg.has_prefix("--committer=") =>
        committer_patterns.push(string_slice_from(arg, 12))
      _ if arg.has_prefix("--branches=") => {
        branch_patterns.push(string_slice_from(arg, 11))
        saw_revision_input = true
      }
      _ if arg.has_prefix("--glob=") => {
        log_append_glob_targets(
          rfs,
          git_dir,
          String::unsafe_substring(arg, start=7, end=arg.length()),
          revs,
        )
        saw_revision_input = true
      }
      _ if arg.has_prefix("--abbrev=") => {
        let parsed = @string.parse_int(string_slice_from(arg, 9)) catch {
          _ => 7
        }
        abbrev_len_override = Some(log_normalize_abbrev_length(parsed))
      }
      _ if arg.has_prefix("--no-walk=") => {
        no_walk = true
        let mode = string_slice_from(arg, 10)
        no_walk_unsorted = mode == "unsorted"
      }
      _ if arg.has_prefix("--since=") => {
        let val = string_slice_from(arg, 8)
        since_ts = @string.parse_int64(val) catch { _ => 0L }
      }
      _ if arg.has_prefix("--until=") => {
        let val = string_slice_from(arg, 8)
        until_ts = @string.parse_int64(val) catch { _ => 9223372036854775807L }
      }
      "--line-prefix" if i + 1 < args.length() => {
        line_prefix = args[i + 1]
        i += 1
      }
      _ if arg.has_prefix("--line-prefix=") =>
        line_prefix = string_slice_from(arg, 14)
      "--reverse" => reverse = true
      "--first-parent" => first_parent = true
      "--date" if i + 1 < args.length() => {
        date_format = args[i + 1]
        i += 1
      }
      _ if arg.has_prefix("--date=") => date_format = string_slice_from(arg, 7)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("log", arg)
      _ => {
        saw_revision_input = true
        log_push_revision_input(
          arg, revs, range_excludes, symmetric_ranges, not_mode,
        )
      }
    }
    i += 1
  }
  if stdin_mode {
    let input = decode_bytes(read_all_stdin())
    let mut stdin_end_of_options = false
    let mut stdin_pathspec_mode = false
    let mut stdin_not_mode = false
    for line_view in input.split("\n") {
      let line = trim_string(line_view.to_string())
      if line.length() == 0 || line.has_prefix("#") {
        continue
      }
      if stdin_pathspec_mode {
        pathspecs.push(line)
        continue
      }
      if stdin_end_of_options {
        saw_revision_input = true
        log_push_revision_input(
          line, revs, range_excludes, symmetric_ranges, stdin_not_mode,
        )
        continue
      }
      if line == "--" {
        stdin_pathspec_mode = true
        continue
      }
      if line == "--end-of-options" {
        stdin_end_of_options = true
        continue
      }
      if line == "--not" {
        stdin_not_mode = !stdin_not_mode
        continue
      }
      if line == "--all" {
        all_refs = true
        saw_revision_input = true
        continue
      }
      if line == "--branches" {
        branch_patterns.push("*")
        saw_revision_input = true
        continue
      }
      if line == "--glob" {
        raise @bitcore.GitError::InvalidObject(
          "Option '--glob' requires a value",
        )
      }
      if line.has_prefix("--branches=") {
        branch_patterns.push(
          String::unsafe_substring(line, start=11, end=line.length()),
        )
        saw_revision_input = true
        continue
      }
      if line.has_prefix("--glob=") {
        log_append_glob_targets(
          rfs,
          git_dir,
          String::unsafe_substring(line, start=7, end=line.length()),
          revs,
        )
        saw_revision_input = true
        continue
      }
      if line.has_prefix("-") && !line.has_prefix("^") {
        raise @bitcore.GitError::InvalidObject(
          "invalid option '" + line + "' in --stdin mode",
        )
      }
      saw_revision_input = true
      log_push_revision_input(
        line, revs, range_excludes, symmetric_ranges, stdin_not_mode,
      )
    }
  }
  if graph && no_walk {
    raise @bitcore.GitError::InvalidObject(
      "options '--graph' and '--no-walk' cannot be used together",
    )
  }
  if graph && reverse {
    raise @bitcore.GitError::InvalidObject(
      "options '--graph' and '--reverse' cannot be used together",
    )
  }
  if graph && walk_reflogs {
    raise @bitcore.GitError::InvalidObject(
      "options '--graph' and '--walk-reflogs' cannot be used together",
    )
  }
  let grep_pattern_type = resolve_grep_pattern_type(
    rfs, git_dir, grep_pattern_type_override,
  )
  let abbrev_len = log_resolve_abbrev_length(
    rfs, git_dir, abbrev_len_override, no_abbrev,
  )
  let abbrev_commit = log_resolve_abbrev_commit(
    rfs, git_dir, abbrev_commit_override,
  )
  let has_commit_filters = log_has_diff_filter(
      diff_filter_include, diff_filter_exclude,
    ) ||
    pathspecs.length() > 0 ||
    grep_patterns.length() > 0 ||
    author_patterns.length() > 0 ||
    committer_patterns.length() > 0
  log_validate_reflog_grep_options(walk_reflogs, grep_reflog_patterns)
  if ignore_missing &&
    saw_revision_input &&
    range_excludes.length() == 0 &&
    symmetric_ranges.length() == 0 {
    let explicit_targets = log_resolve_targets(
      rfs,
      git_dir,
      revs,
      branch_patterns,
      false,
      default_head=false,
      ignore_missing=true,
    )
    if explicit_targets.length() == 0 {
      return
    }
  }
  if walk_reflogs {
    let targets = log_collect_reflog_targets(
      rfs, git_dir, revs, branch_patterns,
    )
    let normalized_reflog_format = match format {
      Some(raw_fmt) if raw_fmt.has_prefix("tformat:") =>
        Some(string_slice_from(raw_fmt, 8))
      Some(raw_fmt) if raw_fmt.has_prefix("format:") =>
        Some(string_slice_from(raw_fmt, 7))
      Some(raw_fmt) => Some(raw_fmt)
      None => None
    }
    let reflog_oneline = match normalized_reflog_format {
      Some(raw_fmt) => raw_fmt == "oneline"
      None => oneline
    }
    let reflog_pretty_color_enabled = match normalized_reflog_format {
      Some(fmt) if fmt.contains("%C") =>
        log_resolve_pretty_color_enabled(
          git_dir,
          pretty_color_cli_mode,
          log_stdout_is_tty(),
        )
      _ => false
    }
    let reflog_object_git_dir = log_resolve_common_git_dir(rfs, git_dir)
    let reflog_db = @bitlib.ObjectDb::load_lazy(rfs, reflog_object_git_dir)
    let mut emitted = 0
    for target in targets {
      if emitted >= max_count {
        break
      }
      let (target_base, explicit_selector) = log_split_reflog_target(target)
      let refname = resolve_log_reflog_refname(rfs, git_dir, target)
      guard refname is Some(actual_refname) else {
        raise @bitcore.GitError::InvalidObject("Unknown revision: " + target)
      }
      let display_ref = if target_base.has_prefix("refs/") {
        shorten_reflog_refname(actual_refname)
      } else {
        target_base
      }
      let entries = @bitrepo.read_reflog(rfs, git_dir, actual_refname)
      let start_index = log_resolve_reflog_start_index(
        entries.length(),
        explicit_selector,
      )
      guard start_index is Some(start_reflog_index) else {
        raise @bitcore.GitError::InvalidObject("Unknown revision: " + target)
      }
      let mut reflog_index = start_reflog_index
      while reflog_index < entries.length() && emitted < max_count {
        let entry = entries[entries.length() - 1 - reflog_index]
        if !log_grep_patterns_match(
            entry.message,
            grep_reflog_patterns,
            grep_pattern_type,
            grep_ignore_case,
            all_match,
          ) {
          reflog_index += 1
          continue
        }
        if !log_commit_matches_text_filters(
            rfs,
            reflog_db,
            entry.new_id,
            grep_patterns,
            grep_pattern_type,
            grep_ignore_case,
            invert_grep,
            all_match,
            author_patterns,
            committer_patterns,
          ) {
          reflog_index += 1
          continue
        }
        let gd = log_format_reflog_selector(
          display_ref,
          reflog_index,
          entry.timestamp,
          entry.timezone,
          explicit_selector,
          date_format,
        )
        if reflog_oneline {
          let rendered = log_abbrev_hex(entry.new_id.to_hex(), abbrev_len) +
            " " +
            gd +
            ": " +
            entry.message
          log_emit_output(rendered, true, line_prefix)
          emitted += 1
          reflog_index += 1
          continue
        }
        if format is None {
          match
            log_load_entry(
              reflog_db,
              rfs,
              git_dir,
              entry.new_id,
              show_stat || show_patch || show_raw,
            ) {
            Some(log_entry) => {
              log_emit_default_commit_entry(
                log_entry,
                {},
                abbrev_commit,
                abbrev_len,
                date_format,
                line_prefix,
                show_stat,
                show_patch,
                show_raw,
                raw_detect_renames,
                detect_copies,
                rfs,
                git_dir,
                reflog_db,
                reflog_selector=Some(gd),
                reflog_identity=Some(entry.author + " <" + entry.email + ">"),
                reflog_message=Some(entry.message),
              )
              if (show_stat || show_patch || show_raw) &&
                reflog_index + 1 < entries.length() &&
                emitted + 1 < max_count {
                log_emit_output("", true, line_prefix)
              }
              emitted += 1
              reflog_index += 1
              continue
            }
            None => ()
          }
        }
        let rendered = match normalized_reflog_format {
          Some(fmt) =>
            match reflog_db.get(rfs, entry.new_id) {
              Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit => {
                let info = @bitcore.parse_commit(obj.data)
                let parents = log_resolve_parents(
                  rfs,
                  git_dir,
                  entry.new_id,
                  info.parents,
                )
                let commit_data = parse_commit_format_data(
                  entry.new_id,
                  obj.data,
                  info.tree,
                  parents,
                  {},
                  abbrev_len~,
                  date_format~,
                  reflog_selector_short=Some(gd),
                  reflog_selector=Some(gd),
                  reflog_message=Some(entry.message),
                  reflog_author_name=Some(entry.author),
                  reflog_author_email=Some(entry.email),
                  pretty_color_enabled=reflog_pretty_color_enabled,
                )
                format_commit_string(fmt, commit_data)
              }
              _ =>
                if fmt == "%H" {
                  entry.new_id.to_hex()
                } else {
                  format_reflog_entry(Some(fmt), gd, entry.message)
                }
            }
          None => format_reflog_entry(None, gd, entry.message)
        }
        log_emit_output(rendered, true, line_prefix)
        emitted += 1
        reflog_index += 1
      }
    }
    return
  }
  if format is Some(raw_fmt) {
    // Strip tformat:/format: prefix
    let (actual_fmt, is_tformat) = if raw_fmt.has_prefix("tformat:") {
      (string_slice_from(raw_fmt, 8), true)
    } else if raw_fmt.has_prefix("format:") {
      (string_slice_from(raw_fmt, 7), false)
    } else if raw_fmt == "oneline" {
      ("%h %s", true)
    } else {
      (raw_fmt, true)
    }
    let pretty_color_enabled = if actual_fmt.contains("%C") {
      log_resolve_pretty_color_enabled(
        git_dir,
        pretty_color_cli_mode,
        log_stdout_is_tty(),
      )
    } else {
      false
    }
    let warn_missing_exclude_decoration = decoration_include_patterns.length() ==
      0 &&
      log_has_missing_exclude_decoration_value(rfs, git_dir)
    if warn_missing_exclude_decoration {
      eprint_line("error: missing value for 'log.excludeDecoration'")
    }
    let decoration_options = log_make_decoration_options(
      rfs,
      git_dir,
      decorate_mode_override,
      decoration_include_patterns,
      decoration_exclude_patterns,
      clear_decorations,
      actual_fmt.contains("%d") || actual_fmt.contains("%D"),
      raw_fmt != "raw",
      simplify_by_decoration,
    )
    let selection_ref_names = if !log_decoration_mode_is_none(
        decoration_options.mode,
      ) ||
      simplify_by_decoration {
      log_build_ref_names(rfs, git_dir, decoration_options)
    } else {
      {}
    }
    let ref_names_map = if !log_decoration_mode_is_none(decoration_options.mode) {
      selection_ref_names
    } else {
      {}
    }
    let db = @bitlib.ObjectDb::load(
      rfs,
      log_resolve_common_git_dir(rfs, git_dir),
    )
    let left_right_markers = if left_right && symmetric_ranges.length() > 0 {
      log_build_left_right_markers(
        fs, rfs, git_dir, symmetric_ranges, ignore_missing,
      )
    } else {
      {}
    }
    let seen : Map[String, Bool] = {}
    let formatted_lines : Array[String] = []
    if no_walk {
      let resolved_targets = log_resolve_targets(
        rfs,
        git_dir,
        revs,
        branch_patterns,
        all_refs,
        default_head=!saw_revision_input,
        ignore_missing~,
      )
      let targets = if no_walk_unsorted {
        resolved_targets
      } else {
        log_sort_targets_by_time(rfs, git_dir, resolved_targets)
      }
      for target in targets {
        if formatted_lines.length() >= max_count {
          break
        }
        let id = target.1
        let hex = id.to_hex()
        if seen.contains(hex) {
          continue
        }
        if !log_commit_matches_text_filters(
            rfs, db, id, grep_patterns, grep_pattern_type, grep_ignore_case, invert_grep,
            all_match, author_patterns, committer_patterns,
          ) {
          continue
        }
        if !log_commit_matches_history_filters(
            rfs, git_dir, db, id, pathspecs, diff_filter_include, diff_filter_exclude,
            detect_renames, detect_copies,
          ) {
          continue
        }
        seen[hex] = true
        let obj = db.get(rfs, id)
        guard obj is Some(o) else { continue }
        let info = @bitcore.parse_commit(o.data)
        let parents = log_resolve_parents(rfs, git_dir, id, info.parents)
        if no_merges && parents.length() > 1 {
          continue
        }
        if simplify_by_decoration &&
          !log_should_emit_simplified_entry(
            selection_ref_names,
            hex,
            parents.length(),
          ) {
          continue
        }
        let commit_data = parse_commit_format_data(
          id,
          o.data,
          info.tree,
          parents,
          ref_names_map,
          abbrev_len~,
          date_format~,
          left_right_marker=match left_right_markers.get(hex) {
            Some(marker) => marker
            None => ""
          },
          pretty_color_enabled~,
        )
        formatted_lines.push(format_commit_string(actual_fmt, commit_data))
      }
    } else {
      let start_targets = log_resolve_targets(
        rfs,
        git_dir,
        revs,
        branch_patterns,
        all_refs,
        default_head=!saw_revision_input,
        ignore_missing~,
      )
      let start_ids : Array[@bitcore.ObjectId] = []
      for target in start_targets {
        start_ids.push(target.1)
      }
      if start_ids.length() == 0 {
        if saw_revision_input {
          return
        }
        start_ids.push(log_resolve_default_head(rfs, git_dir))
      }
      let exclude_ids : Map[String, Bool] = {}
      for spec in range_excludes {
        match @bitrepo.rev_parse(rfs, git_dir, spec) {
          Some(id) => walk_commits_to_map(fs, git_dir, id, exclude_ids)
          None if ignore_missing => ()
          None =>
            raise @bitcore.GitError::InvalidObject("Unknown revision: " + spec)
        }
      }
      for pair in symmetric_ranges {
        let left_spec = pair.0
        let right_spec = pair.1
        match
          (
            @bitrepo.rev_parse(rfs, git_dir, left_spec),
            @bitrepo.rev_parse(rfs, git_dir, right_spec),
          ) {
          (Some(left_id), Some(right_id)) =>
            match log_find_merge_base(rfs, git_dir, left_id, right_id) {
              Some(base_id) =>
                walk_commits_to_map(fs, git_dir, base_id, exclude_ids)
              None => ()
            }
          _ if ignore_missing => ()
          _ =>
            raise @bitcore.GitError::InvalidObject(
              "Unknown revision in symmetric range",
            )
        }
      }
      let entries = log_walk_commits(
        rfs,
        git_dir,
        start_ids,
        exclude_ids,
        if has_commit_filters {
          2147483647
        } else {
          max_count
        },
        since_ts,
        until_ts,
        false,
        first_parent~,
      )
      if reverse {
        entries.rev_in_place()
      }
      for entry in entries {
        let hex = entry.id.to_hex()
        if seen.contains(hex) {
          continue
        }
        if !log_commit_matches_text_filters(
            rfs,
            db,
            entry.id,
            grep_patterns,
            grep_pattern_type,
            grep_ignore_case,
            invert_grep,
            all_match,
            author_patterns,
            committer_patterns,
          ) {
          continue
        }
        if !log_commit_matches_history_filters(
            rfs,
            git_dir,
            db,
            entry.id,
            pathspecs,
            diff_filter_include,
            diff_filter_exclude,
            detect_renames,
            detect_copies,
          ) {
          continue
        }
        seen[hex] = true
        let obj = db.get(rfs, entry.id)
        guard obj is Some(o) else { continue }
        let info = @bitcore.parse_commit(o.data)
        let parents = log_resolve_parents(rfs, git_dir, entry.id, info.parents)
        if no_merges && parents.length() > 1 {
          continue
        }
        if simplify_by_decoration &&
          !log_should_emit_simplified_entry(
            selection_ref_names,
            hex,
            parents.length(),
          ) {
          continue
        }
        let commit_data = parse_commit_format_data(
          entry.id,
          o.data,
          entry.tree,
          parents,
          ref_names_map,
          abbrev_len~,
          date_format~,
          left_right_marker=match left_right_markers.get(hex) {
            Some(marker) => marker
            None => ""
          },
          pretty_color_enabled~,
        )
        formatted_lines.push(format_commit_string(actual_fmt, commit_data))
        if formatted_lines.length() >= max_count {
          break
        }
      }
    }
    if formatted_lines.length() > 0 {
      log_emit_output(formatted_lines.join("\n"), is_tformat, line_prefix)
    }
    return
  }
  // Show subdir-clone info if applicable (only in full format)
  if !oneline {
    match get_subdir_info(fs, git_dir) {
      Some((remote, path, base)) => {
        log_emit_output(
          "# subdir-clone: \{path} from \{remote}",
          true,
          line_prefix,
        )
        log_emit_output("# base: \{base[:7].to_string()}", true, line_prefix)
        log_emit_output("", true, line_prefix)
      }
      None => ()
    }
  }
  if decoration_include_patterns.length() == 0 &&
    log_has_missing_exclude_decoration_value(rfs, git_dir) {
    eprint_line("error: missing value for 'log.excludeDecoration'")
  }
  let decoration_options = log_make_decoration_options(
    rfs, git_dir, decorate_mode_override, decoration_include_patterns, decoration_exclude_patterns,
    clear_decorations, false, true, simplify_by_decoration,
  )
  let show_decorations = !log_decoration_mode_is_none(decoration_options.mode)
  // Determine whether we need the new walk path
  let need_walk = all_refs ||
    show_decorations ||
    decoration_include_patterns.length() > 0 ||
    decoration_exclude_patterns.length() > 0 ||
    clear_decorations ||
    simplify_by_decoration ||
    pathspecs.length() > 0 ||
    show_raw ||
    no_merges ||
    abbrev_commit ||
    abbrev_len != 7 ||
    log_has_diff_filter(diff_filter_include, diff_filter_exclude) ||
    grep_patterns.length() > 0 ||
    grep_reflog_patterns.length() > 0 ||
    author_patterns.length() > 0 ||
    committer_patterns.length() > 0 ||
    saw_revision_input ||
    source ||
    revs.length() > 0 ||
    range_excludes.length() > 0 ||
    branch_patterns.length() > 0 ||
    symmetric_ranges.length() > 0
  if graph {
    log_with_graph(
      rfs, git_dir, max_count, oneline, all_refs, show_decorations, since_ts, until_ts,
      revs, range_excludes, first_parent,
    )
  } else if no_walk {
    let resolved_targets = log_resolve_targets(
      rfs,
      git_dir,
      revs,
      branch_patterns,
      all_refs,
      default_head=!saw_revision_input,
      ignore_missing~,
    )
    let targets = if no_walk_unsorted {
      resolved_targets
    } else {
      log_sort_targets_by_time(rfs, git_dir, resolved_targets)
    }
    let selection_ref_names = if show_decorations || simplify_by_decoration {
      log_build_ref_names(rfs, git_dir, decoration_options)
    } else {
      {}
    }
    let ref_names = if show_decorations { selection_ref_names } else { {} }
    let db = @bitlib.ObjectDb::load(rfs, git_dir)
    let seen : Map[String, Bool] = {}
    if oneline {
      let lines : Array[String] = []
      for target in targets {
        if lines.length() >= max_count {
          break
        }
        let id = target.1
        let hex = id.to_hex()
        if seen.contains(hex) {
          continue
        }
        if !log_commit_matches_text_filters(
            rfs, db, id, grep_patterns, grep_pattern_type, grep_ignore_case, invert_grep,
            all_match, author_patterns, committer_patterns,
          ) {
          continue
        }
        if !log_commit_matches_history_filters(
            rfs, git_dir, db, id, pathspecs, diff_filter_include, diff_filter_exclude,
            detect_renames, detect_copies,
          ) {
          continue
        }
        seen[hex] = true
        match log_load_entry(db, rfs, git_dir, id, false) {
          Some(entry) => {
            if no_merges && entry.parent_count > 1 {
              continue
            }
            if simplify_by_decoration &&
              !log_should_emit_simplified_entry(
                selection_ref_names,
                hex,
                entry.parent_count,
              ) {
              continue
            }
            let short = log_abbrev_hex(entry.id.to_hex(), abbrev_len)
            let deco = format_decoration(ref_names, hex)
            let line = if source {
              short + deco + "\t" + target.0 + " " + entry.message
            } else {
              short + deco + " " + entry.message
            }
            lines.push(line)
          }
          None => ()
        }
      }
      if lines.length() > 0 {
        log_emit_output(lines.join("\n"), true, line_prefix)
      }
    } else {
      for target in targets {
        let id = target.1
        let hex = id.to_hex()
        if seen.contains(hex) {
          continue
        }
        if !log_commit_matches_text_filters(
            rfs, db, id, grep_patterns, grep_pattern_type, grep_ignore_case, invert_grep,
            all_match, author_patterns, committer_patterns,
          ) {
          continue
        }
        if !log_commit_matches_history_filters(
            rfs, git_dir, db, id, pathspecs, diff_filter_include, diff_filter_exclude,
            detect_renames, detect_copies,
          ) {
          continue
        }
        seen[hex] = true
        match
          log_load_entry(
            db,
            rfs,
            git_dir,
            id,
            show_stat || show_patch || show_raw,
          ) {
          Some(entry) => {
            if no_merges && entry.parent_count > 1 {
              continue
            }
            if simplify_by_decoration &&
              !log_should_emit_simplified_entry(
                selection_ref_names,
                hex,
                entry.parent_count,
              ) {
              continue
            }
            let deco = format_decoration(ref_names, hex)
            let header_hex = if abbrev_commit {
              log_abbrev_hex(entry.id.to_hex(), abbrev_len)
            } else {
              entry.id.to_hex()
            }
            log_emit_output("commit " + header_hex + deco, true, line_prefix)
            log_emit_output("Author: " + entry.author, true, line_prefix)
            let date_str = format_date_by_mode(
              entry.timestamp,
              log_extract_author_tz(entry.author),
              date_format,
            )
            log_emit_output("Date:   " + date_str, true, line_prefix)
            log_emit_output("", true, line_prefix)
            log_emit_output("    " + entry.message, true, line_prefix)
            log_emit_output("", true, line_prefix)
            if show_stat || show_patch {
              let diff_files = @bitdiff.diff_trees(
                rfs,
                git_dir,
                entry.parent_tree,
                entry.tree,
                db~,
              )
              if show_stat {
                let stat_lines = @bitdiff.diff_stat(diff_files)
                for line in stat_lines {
                  log_emit_output(line, true, line_prefix)
                }
                log_emit_output("", true, line_prefix)
              }
              if show_patch {
                let patch_lines = @bitdiff.diff_text(diff_files)
                for line in patch_lines {
                  log_emit_output(line, true, line_prefix)
                }
                log_emit_output("", true, line_prefix)
              }
            }
            if show_raw {
              let raw_results = log_collect_raw_results(
                rfs,
                db,
                entry.parent_tree,
                entry.tree,
                raw_detect_renames,
                detect_copies,
              )
              for raw_result in raw_results {
                log_emit_output(
                  log_format_raw_result(raw_result, abbrev_len),
                  true,
                  line_prefix,
                )
              }
              log_emit_output("", true, line_prefix)
            }
          }
          None => ()
        }
      }
    }
  } else if need_walk {
    let start_targets = log_resolve_targets(
      rfs,
      git_dir,
      revs,
      branch_patterns,
      all_refs,
      default_head=!saw_revision_input,
      ignore_missing~,
    )
    // Build start_ids from explicit targets
    let start_ids : Array[@bitcore.ObjectId] = []
    for target in start_targets {
      start_ids.push(target.1)
    }
    // Build exclude_ids from range_excludes
    let exclude_ids : Map[String, Bool] = {}
    for spec in range_excludes {
      match @bitrepo.rev_parse(rfs, git_dir, spec) {
        Some(id) => walk_commits_to_map(fs, git_dir, id, exclude_ids)
        None if ignore_missing => ()
        None =>
          raise @bitcore.GitError::InvalidObject("Unknown revision: " + spec)
      }
    }
    for pair in symmetric_ranges {
      let left_spec = pair.0
      let right_spec = pair.1
      match
        (
          @bitrepo.rev_parse(rfs, git_dir, left_spec),
          @bitrepo.rev_parse(rfs, git_dir, right_spec),
        ) {
        (Some(left_id), Some(right_id)) =>
          match log_find_merge_base(rfs, git_dir, left_id, right_id) {
            Some(base_id) =>
              walk_commits_to_map(fs, git_dir, base_id, exclude_ids)
            None => ()
          }
        _ if ignore_missing => ()
        _ =>
          raise @bitcore.GitError::InvalidObject(
            "Unknown revision in symmetric range",
          )
      }
    }
    // Default to HEAD
    if start_ids.length() == 0 {
      if saw_revision_input {
        return
      }
      start_ids.push(log_resolve_default_head(rfs, git_dir))
    }
    let selection_ref_names = if show_decorations || simplify_by_decoration {
      log_build_ref_names(rfs, git_dir, decoration_options)
    } else {
      {}
    }
    let ref_names = if show_decorations { selection_ref_names } else { {} }
    let source_names = if source {
      log_build_commit_sources(
        rfs,
        git_dir,
        start_targets,
        exclude_ids,
        first_parent~,
      )
    } else {
      {}
    }
    let walk_db = @bitlib.ObjectDb::load(
      rfs,
      log_resolve_common_git_dir(rfs, git_dir),
    )
    let left_right_markers = if left_right && symmetric_ranges.length() > 0 {
      log_build_left_right_markers(
        fs, rfs, git_dir, symmetric_ranges, ignore_missing,
      )
    } else {
      {}
    }
    let entries = log_walk_commits(
      rfs,
      git_dir,
      start_ids,
      exclude_ids,
      if has_commit_filters {
        2147483647
      } else {
        max_count
      },
      since_ts,
      until_ts,
      show_stat || show_patch || show_raw,
      first_parent~,
    )
    if reverse {
      entries.rev_in_place()
    }
    if oneline {
      let mut emitted = 0
      for entry in entries {
        if emitted >= max_count {
          break
        }
        if no_merges && entry.parent_count > 1 {
          continue
        }
        if simplify_by_decoration &&
          !log_should_emit_simplified_entry(
            selection_ref_names,
            entry.id.to_hex(),
            entry.parent_count,
          ) {
          continue
        }
        if !log_commit_matches_text_filters(
            rfs,
            walk_db,
            entry.id,
            grep_patterns,
            grep_pattern_type,
            grep_ignore_case,
            invert_grep,
            all_match,
            author_patterns,
            committer_patterns,
          ) {
          continue
        }
        if !log_commit_matches_history_filters(
            rfs,
            git_dir,
            walk_db,
            entry.id,
            pathspecs,
            diff_filter_include,
            diff_filter_exclude,
            detect_renames,
            detect_copies,
          ) {
          continue
        }
        let short = log_abbrev_hex(entry.id.to_hex(), abbrev_len)
        let deco = format_decoration(ref_names, entry.id.to_hex())
        let marker_prefix = match left_right_markers.get(entry.id.to_hex()) {
          Some(marker) => marker + " "
          None => ""
        }
        let line = if source {
          match source_names.get(entry.id.to_hex()) {
            Some(name) =>
              marker_prefix + short + deco + "\t" + name + " " + entry.message
            None => marker_prefix + short + deco + " " + entry.message
          }
        } else {
          marker_prefix + short + deco + " " + entry.message
        }
        log_emit_output(line, true, line_prefix)
        emitted += 1
      }
    } else {
      let mut emitted = 0
      for entry in entries {
        if emitted >= max_count {
          break
        }
        if no_merges && entry.parent_count > 1 {
          continue
        }
        if simplify_by_decoration &&
          !log_should_emit_simplified_entry(
            selection_ref_names,
            entry.id.to_hex(),
            entry.parent_count,
          ) {
          continue
        }
        if !log_commit_matches_text_filters(
            rfs,
            walk_db,
            entry.id,
            grep_patterns,
            grep_pattern_type,
            grep_ignore_case,
            invert_grep,
            all_match,
            author_patterns,
            committer_patterns,
          ) {
          continue
        }
        if !log_commit_matches_history_filters(
            rfs,
            git_dir,
            walk_db,
            entry.id,
            pathspecs,
            diff_filter_include,
            diff_filter_exclude,
            detect_renames,
            detect_copies,
          ) {
          continue
        }
        let deco = format_decoration(ref_names, entry.id.to_hex())
        let header_hex = if abbrev_commit {
          log_abbrev_hex(entry.id.to_hex(), abbrev_len)
        } else {
          entry.id.to_hex()
        }
        let marker_prefix = match left_right_markers.get(entry.id.to_hex()) {
          Some(marker) => marker + " "
          None => ""
        }
        log_emit_output(
          "commit " + marker_prefix + header_hex + deco,
          true,
          line_prefix,
        )
        log_emit_output("Author: " + entry.author, true, line_prefix)
        let date_str = format_date_by_mode(
          entry.timestamp,
          log_extract_author_tz(entry.author),
          date_format,
        )
        log_emit_output("Date:   " + date_str, true, line_prefix)
        log_emit_output("", true, line_prefix)
        log_emit_output("    " + entry.message, true, line_prefix)
        log_emit_output("", true, line_prefix)
        if show_stat || show_patch {
          let diff_files = @bitdiff.diff_trees(
            rfs,
            git_dir,
            entry.parent_tree,
            entry.tree,
            db=walk_db,
          )
          if show_stat {
            let stat_lines = @bitdiff.diff_stat(diff_files)
            for line in stat_lines {
              log_emit_output(line, true, line_prefix)
            }
            log_emit_output("", true, line_prefix)
          }
          if show_patch {
            let patch_lines = @bitdiff.diff_text(diff_files)
            for line in patch_lines {
              log_emit_output(line, true, line_prefix)
            }
            log_emit_output("", true, line_prefix)
          }
        }
        if show_raw {
          let raw_results = log_collect_raw_results(
            rfs,
            walk_db,
            entry.parent_tree,
            entry.tree,
            raw_detect_renames,
            detect_copies,
          )
          for raw_result in raw_results {
            log_emit_output(
              log_format_raw_result(raw_result, abbrev_len),
              true,
              line_prefix,
            )
          }
          log_emit_output("", true, line_prefix)
        }
        emitted += 1
      }
    }
  } else if oneline {
    // Fast path: simple HEAD walk
    ignore(log_resolve_default_head(rfs, git_dir))
    let lines = @bitlib.log_head_oneline(
      fs,
      git_dir,
      max_count~,
      since=since_ts,
      until=until_ts,
    )
    if reverse {
      lines.rev_in_place()
    }
    for line in lines {
      log_emit_output(line, true, line_prefix)
    }
  } else {
    // Fast path: simple HEAD walk (full format)
    ignore(log_resolve_default_head(rfs, git_dir))
    let entries = @bitlib.log_head(
      fs,
      git_dir,
      max_count~,
      since=since_ts,
      until=until_ts,
      include_parent_tree=show_stat || show_patch,
    )
    if reverse {
      entries.rev_in_place()
    }
    let log_db = if show_stat || show_patch {
      Some(
        @bitlib.ObjectDb::load(rfs, log_resolve_common_git_dir(rfs, git_dir)),
      )
    } else {
      None
    }
    for entry in entries {
      log_emit_output("commit " + entry.id.to_hex(), true, line_prefix)
      log_emit_output("Author: " + entry.author, true, line_prefix)
      let date_str = format_date_by_mode(
        entry.timestamp,
        log_extract_author_tz(entry.author),
        date_format,
      )
      log_emit_output("Date:   " + date_str, true, line_prefix)
      log_emit_output("", true, line_prefix)
      log_emit_output("    " + entry.message, true, line_prefix)
      log_emit_output("", true, line_prefix)
      if show_stat || show_patch {
        let diff_files = @bitdiff.diff_trees(
          rfs,
          git_dir,
          entry.parent_tree,
          entry.tree,
          db=log_db.unwrap(),
        )
        if show_stat {
          let stat_lines = @bitdiff.diff_stat(diff_files)
          for line in stat_lines {
            log_emit_output(line, true, line_prefix)
          }
          log_emit_output("", true, line_prefix)
        }
        if show_patch {
          let patch_lines = @bitdiff.diff_text(diff_files)
          for line in patch_lines {
            log_emit_output(line, true, line_prefix)
          }
          log_emit_output("", true, line_prefix)
        }
      }
    }
  }
}

///|
async fn handle_whatchanged(args : Array[String]) -> Unit raise Error {
  let forwarded : Array[String] = []
  let mut acknowledged = false
  let mut show_help = false
  for arg in args {
    match arg {
      "--i-still-use-this" => acknowledged = true
      "-h" | "--help" => show_help = true
      _ => forwarded.push(arg)
    }
  }
  if show_help {
    show_simple_command_help(
      "git whatchanged --i-still-use-this [<options>] [<revision-range>] [--] [<pathspec>...]",
      summary="Show raw commit history without merges.",
    )
    return
  }
  if !acknowledged {
    @stdio.stderr.write(
      "'git whatchanged' is nominated for removal.\n\nhint: You can replace 'git whatchanged <opts>' with:\nhint:\tgit log <opts> --raw --no-merges\nhint: Or make an alias:\nhint:\tgit config set --global alias.whatchanged 'log --raw --no-merges'\n\nIf you still use this command, here's what you can do:\n\n- read https://git-scm.com/docs/BreakingChanges.html\n- check if anyone has discussed this on the mailing\n  list and if they came up with something that can\n  help you: https://lore.kernel.org/git/?q=git%20whatchanged\n- send an email to <git@vger.kernel.org> to let us\n  know that you still use this command and were unable\n  to determine a suitable replacement\n\nfatal: refusing to run without --i-still-use-this\n",
    )
    @sys.exit(128)
  }
  let log_args : Array[String] = ["--raw", "--no-merges"]
  log_args.append(forwarded)
  handle_log(log_args)
}

///|
struct LogWalkEntry {
  id : @bitcore.ObjectId
  message : String
  author : String
  timestamp : Int64
  tree : @bitcore.ObjectId
  parent_tree : @bitcore.ObjectId?
  parent_count : Int
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
  first_parent? : Bool = false,
) -> Array[LogWalkEntry] raise Error {
  let db = @bitlib.ObjectDb::load(rfs, log_resolve_common_git_dir(rfs, git_dir))
  let result : Array[LogWalkEntry] = []
  let visited : Map[String, Bool] = {}
  // Priority queue: (timestamp, id) sorted desc by timestamp
  // Use insertion-sorted array
  let queue : Array[(Int64, @bitcore.ObjectId)] = []
  for id in start_ids {
    let hex = id.to_hex()
    if !visited.contains(hex) && !exclude_ids.contains(hex) {
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
    let parents = log_resolve_parents(rfs, git_dir, id, info.parents)
    // Add parents to queue (limited to first parent if --first-parent)
    let parents_to_walk = if first_parent && parents.length() > 0 {
      [parents[0]]
    } else {
      parents
    }
    for parent in parents_to_walk {
      let phex = parent.to_hex()
      if !visited.contains(phex) && !exclude_ids.contains(phex) {
        visited[phex] = true
        let pts = log_get_commit_timestamp(db, rfs, parent)
        log_queue_insert(queue, (pts, parent))
      }
    }
    // Build LogWalkEntry
    let entry = log_parse_entry_from_obj(
      id,
      o.data,
      info.tree,
      parents.length(),
    )
    // Apply since/until filters using parsed timestamp
    if entry.timestamp > until_ts {
      continue // newer than until, skip but keep walking
    }
    if entry.timestamp < since_ts {
      continue // older than since, skip but keep walking for branches
    }
    let parent_tree : @bitcore.ObjectId? = if include_parent_tree &&
      parents.length() > 0 {
      match db.get(rfs, parents[0]) {
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
    let ts = @string.parse_int64(ts_str) catch { _ => 0L }
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
  parent_count : Int,
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
  { id, message, author, timestamp, tree, parent_tree: None, parent_count }
}

///|
fn log_load_entry(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  id : @bitcore.ObjectId,
  include_parent_tree : Bool,
) -> LogWalkEntry? raise Error {
  let obj = db.get(rfs, id)
  guard obj is Some(o) else { return None }
  let info = @bitcore.parse_commit(o.data)
  let parents = log_resolve_parents(rfs, git_dir, id, info.parents)
  let entry = log_parse_entry_from_obj(id, o.data, info.tree, parents.length())
  let parent_tree : @bitcore.ObjectId? = if include_parent_tree &&
    parents.length() > 0 {
    match db.get(rfs, parents[0]) {
      Some(parent_obj) => {
        let parent_info = @bitcore.parse_commit(parent_obj.data)
        Some(parent_info.tree)
      }
      None => None
    }
  } else {
    None
  }
  Some({ ..entry, parent_tree, })
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
  revs : Array[String],
  range_excludes : Array[String],
  first_parent : Bool,
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
  } else if revs.length() == 0 {
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
  // Resolve positional revs and add to starts
  for rev in revs {
    match @bitrepo.rev_parse(rfs, git_dir, rev) {
      Some(id) => starts.push(id)
      None => raise @bitcore.GitError::InvalidObject("Unknown revision: " + rev)
    }
  }
  // Default to HEAD if nothing specified
  if starts.length() == 0 {
    match @bitrepo.rev_parse(rfs, git_dir, "HEAD") {
      Some(id) => starts.push(id)
      None => return
    }
  }
  // Build exclude_ids from range_excludes
  let exclude_ids : Map[String, Bool] = {}
  for spec in range_excludes {
    match @bitrepo.rev_parse(rfs, git_dir, spec) {
      Some(id) => walk_commits_to_map(OsFs::new(), git_dir, id, exclude_ids)
      None =>
        raise @bitcore.GitError::InvalidObject("Unknown revision: " + spec)
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
    if exclude_ids.contains(hex) {
      continue
    }
    let obj = db.get(rfs, current)
    match obj {
      Some(o) => {
        let info = @bitcore.parse_commit(o.data)
        // Add parents to queue (limited to first parent if --first-parent)
        let parents_to_walk : Array[@bitcore.ObjectId] = if first_parent &&
          info.parents.length() > 0 {
          [info.parents[0]]
        } else {
          info.parents
        }
        for i, parent in parents_to_walk {
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
        if parents_to_walk.length() == 0 && col < active_columns.length() {
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
