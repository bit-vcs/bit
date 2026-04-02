///|
async fn handle_rm(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let opts = parse_rm_options(args)
  if opts.pathspec_file_nul && opts.pathspec_from_file is None {
    eprint_line(
      "fatal: the option '--pathspec-file-nul' requires '--pathspec-from-file'",
    )
    @sys.exit(128)
  }
  if opts.pathspec_from_file is Some(_) && opts.paths.length() > 0 {
    eprint_line(
      "fatal: '--pathspec-from-file' and pathspec arguments cannot be used together",
    )
    @sys.exit(128)
  }
  let raw_paths = match opts.pathspec_from_file {
    Some(source) => rm_read_pathspecs(fs, source, opts.pathspec_file_nul)
    None => opts.paths
  }
  if raw_paths.length() == 0 {
    if opts.pathspec_from_file is Some(_) {
      eprint_line("fatal: No pathspec was given. Which files should I remove?")
      @sys.exit(128)
    }
    raise @bitcore.GitError::InvalidObject("No pathspec given")
  }
  let actual_git_dir = resolve_git_dir(fs, root)
  let head_exists = @bitlib.resolve_head_commit(fs, actual_git_dir) is Some(_)
  let entries = @bitlib.read_index_entries(fs, actual_git_dir)
  let cwd_prefix = compute_cwd_prefix(root)
  let root_abs = ls_files_repo_root_abs(root)
  let skip_worktree_paths = @bitlib.read_skip_worktree_paths(fs, actual_git_dir)
  let sparse_patterns = @bitlib.read_sparse_patterns(fs, actual_git_dir) catch {
    _ => []
  }
  let sparse_enabled = @bitlib.is_sparse_checkout_enabled(fs, actual_git_dir) ||
    skip_worktree_paths.to_array().length() > 0
  let (removed_paths, sparse_only_specs, unmatched_specs) = rm_partition_target_paths(
    raw_paths,
    entries,
    opts.recursive,
    sparse_enabled,
    sparse_patterns,
    opts.sparse,
    opts.ignore_unmatch,
    cwd_prefix,
    root_abs,
  )
  if unmatched_specs.length() > 0 {
    eprint_line(
      "fatal: pathspec '\{unmatched_specs[0]}' did not match any files",
    )
    @sys.exit(1)
  }
  if sparse_only_specs.length() > 0 {
    for
      line in rm_sparse_path_error_lines(
        sparse_only_specs,
        rm_should_show_sparse_advice(fs, actual_git_dir),
      ) {
      eprint_line(line)
    }
    @sys.exit(1)
  }
  if opts.cached && !opts.force && head_exists {
    let st = @bitlib.status(fs, root)
    let staged_but_not_head : Map[String, Bool] = {}
    let intent_to_add_paths : Map[String, Bool] = {}
    for entry in entries {
      if entry.intent_to_add {
        intent_to_add_paths[entry.path] = true
      }
    }
    for path in st.staged_added {
      staged_but_not_head[path] = true
    }
    for path in st.staged_modified {
      staged_but_not_head[path] = true
    }
    let unstaged_modified : Map[String, Bool] = {}
    for path in st.unstaged_modified {
      unstaged_modified[path] = true
    }
    for path in removed_paths {
      if intent_to_add_paths.contains(path) {
        continue
      }
      if staged_but_not_head.contains(path) && unstaged_modified.contains(path) {
        raise @bitcore.GitError::InvalidObject(
          "the following file has staged content different from both the file and the HEAD:\n    \{path}",
        )
      }
    }
  }
  if !opts.cached && !opts.force {
    let st = @bitlib.status(fs, root)
    let missing_worktree_paths : Map[String, Bool] = {}
    for path in removed_paths {
      let abs_path = root + "/" + path
      if !fs.is_file(abs_path) && !fs.is_dir(abs_path) {
        missing_worktree_paths[path] = true
      }
    }
    let (both_dirty, staged_only, local_only) = rm_collect_conflict_paths(
      st, removed_paths, missing_worktree_paths, head_exists,
    )
    if both_dirty.length() > 0 ||
      staged_only.length() > 0 ||
      local_only.length() > 0 {
      for
        line in rm_conflict_error_lines(
          both_dirty,
          staged_only,
          local_only,
          rm_should_show_rm_hints(fs, actual_git_dir),
        ) {
        eprint_line(line)
      }
      @sys.exit(1)
    }
  }
  @bitlib.rm_paths(
    fs,
    fs,
    root,
    removed_paths,
    cached=opts.cached,
    force=opts.force,
    recursive=false,
  )
  if !opts.quiet {
    for path in removed_paths {
      print_line("rm " + rm_quote_path(path))
    }
  }
}

///|
struct RmOptions {
  cached : Bool
  force : Bool
  recursive : Bool
  quiet : Bool
  ignore_unmatch : Bool
  sparse : Bool
  pathspec_from_file : String?
  pathspec_file_nul : Bool
  paths : Array[String]
}

///|
fn parse_rm_options(args : Array[String]) -> RmOptions {
  let mut cached = false
  let mut force = false
  let mut recursive = false
  let mut quiet = false
  let mut ignore_unmatch = false
  let mut sparse = false
  let mut pathspec_from_file : String? = None
  let mut pathspec_file_nul = false
  let mut parse_options = true
  let mut pending_value_flag : String? = None
  let paths : Array[String] = []
  for arg in args {
    match pending_value_flag {
      Some(flag) => {
        if flag == "pathspec-from-file" {
          pathspec_from_file = Some(arg)
        }
        pending_value_flag = None
        continue
      }
      None => ()
    }
    if parse_options && arg == "--" {
      parse_options = false
      continue
    }
    if parse_options {
      if arg.has_prefix("-") && !arg.has_prefix("--") && arg.length() > 2 {
        let mut recognized_short_cluster = true
        for i = 1; i < arg.length(); i = i + 1 {
          match arg.get_char(i).unwrap() {
            'f' => force = true
            'r' => recursive = true
            'q' => quiet = true
            _ => {
              recognized_short_cluster = false
              break
            }
          }
        }
        if recognized_short_cluster {
          continue
        }
      }
      match arg {
        "--cached" => cached = true
        "-f" | "--force" => force = true
        "-r" => recursive = true
        "-q" | "--quiet" => quiet = true
        "--ignore-unmatch" => ignore_unmatch = true
        "--sparse" => sparse = true
        "--pathspec-from-file" =>
          pending_value_flag = Some("pathspec-from-file")
        "--pathspec-file-nul" => pathspec_file_nul = true
        _ if arg.has_prefix("--pathspec-from-file=") =>
          pathspec_from_file = Some(
            String::unsafe_substring(arg, start=21, end=arg.length()),
          )
        _ if arg.has_prefix("-") => ()
        _ => paths.push(arg)
      }
    } else {
      paths.push(arg)
    }
  }
  if pending_value_flag is Some("pathspec-from-file") {
    pathspec_from_file = Some("")
  }
  {
    cached,
    force,
    recursive,
    quiet,
    ignore_unmatch,
    sparse,
    pathspec_from_file,
    pathspec_file_nul,
    paths,
  }
}

///|
async fn rm_read_pathspecs(
  fs : &@bitcore.RepoFileSystem,
  source : String,
  use_nul : Bool,
) -> Array[String] raise Error {
  let content = if source == "-" {
    decode_bytes(read_all_stdin())
  } else {
    let path = if source.has_prefix("/") {
      source
    } else {
      add_abs_path(source)
    }
    @utf8.decode_lossy(fs.read_file(path)[:])
  }
  let separator = if use_nul { "\u0000" } else { "\n" }
  let paths : Array[String] = []
  for part_view in content.split(separator) {
    let part = if use_nul {
      part_view.to_string()
    } else {
      trim_string(part_view.to_string())
    }
    if part.length() > 0 {
      paths.push(part)
    }
  }
  paths
}

///|
fn rm_partition_target_paths(
  raw_paths : Array[String],
  entries : Array[@bitlib.IndexEntry],
  recursive : Bool,
  sparse_enabled : Bool,
  sparse_patterns : Array[String],
  allow_sparse : Bool,
  ignore_unmatch : Bool,
  cwd_prefix : String,
  root_abs : String,
) -> (Array[String], Array[String], Array[String]) raise Error {
  let target_paths : Array[String] = []
  let sparse_only_specs : Array[String] = []
  let unmatched_specs : Array[String] = []
  let seen : Map[String, Bool] = {}
  for raw_path in raw_paths {
    let matched = rm_collect_matching_paths(
      raw_path, entries, recursive, cwd_prefix, root_abs,
    )
    if matched.length() == 0 {
      if !ignore_unmatch {
        unmatched_specs.push(raw_path)
      }
      continue
    }
    let dense_matches : Array[String] = []
    let sparse_matches : Array[String] = []
    for path in matched {
      if sparse_enabled &&
        !@bitlib.matches_sparse_pattern(path, sparse_patterns) {
        sparse_matches.push(path)
      } else {
        dense_matches.push(path)
      }
    }
    if !allow_sparse &&
      dense_matches.length() == 0 &&
      sparse_matches.length() > 0 {
      if !ignore_unmatch {
        sparse_only_specs.push(raw_path)
      }
      continue
    }
    let selected = if allow_sparse { matched } else { dense_matches }
    for path in selected {
      if !seen.contains(path) {
        seen[path] = true
        target_paths.push(path)
      }
    }
  }
  (target_paths, sparse_only_specs, unmatched_specs)
}

///|
fn rm_collect_matching_paths(
  raw_path : String,
  entries : Array[@bitlib.IndexEntry],
  recursive : Bool,
  cwd_prefix : String,
  root_abs : String,
) -> Array[String] raise Error {
  let filter = rm_normalize_pathspec_filter(raw_path, cwd_prefix, root_abs)
  if rm_has_symlink_leading_path(filter, root_abs, fn(path : String) {
      @bitio.read_symlink_target_path(path) is Some(_)
    }) {
    return []
  }
  let matched : Array[String] = []
  for entry in entries {
    if rm_entry_matches_filter(entry.path, filter, recursive) {
      matched.push(entry.path)
    }
  }
  matched
}

///|
fn rm_has_symlink_leading_path(
  filter : String,
  root_abs : String,
  is_symlink_path : (String) -> Bool,
) -> Bool {
  let (raw_pattern, _is_exclude, _is_icase) = parse_pathspec_magic(filter)
  let normalized_pattern = if raw_pattern.has_suffix("/") &&
    raw_pattern.length() > 1 {
    String::unsafe_substring(raw_pattern, start=0, end=raw_pattern.length() - 1)
  } else {
    raw_pattern
  }
  if normalized_pattern == "." || normalized_pattern.length() == 0 {
    return false
  }
  let parts : Array[String] = []
  for part_view in normalized_pattern.split("/") {
    parts.push(part_view.to_string())
  }
  if parts.length() < 2 {
    return false
  }
  let mut prefix = ""
  for i = 0; i < parts.length() - 1; i = i + 1 {
    let part = parts[i]
    if part.length() == 0 || rm_path_component_has_wildcard(part) {
      return false
    }
    prefix = if prefix.length() == 0 { part } else { prefix + "/" + part }
    let abs = if root_abs == "/" {
      "/" + prefix
    } else {
      root_abs + "/" + prefix
    }
    if is_symlink_path(abs) {
      return true
    }
  }
  false
}

///|
fn rm_path_component_has_wildcard(component : String) -> Bool {
  component.find("*") is Some(_) ||
  component.find("?") is Some(_) ||
  component.find("[") is Some(_)
}

///|
fn rm_normalize_pathspec_filter(
  raw_path : String,
  cwd_prefix : String,
  root_abs : String,
) -> String raise Error {
  let (raw, is_exclude, is_icase) = parse_pathspec_magic(raw_path)
  let mut clean = raw
  let has_trailing_slash = clean.has_suffix("/") && clean.length() > 1
  if has_trailing_slash {
    clean = String::unsafe_substring(clean, start=0, end=clean.length() - 1)
  }
  let base = if clean == "" || clean == "." {
    cwd_prefix
  } else if clean.has_prefix("/") {
    ls_files_relativize_absolute_filter(clean, root_abs)
  } else if cwd_prefix.length() == 0 {
    clean
  } else {
    cwd_prefix + "/" + clean
  }
  let normalized = normalize_path(base)
  if normalized == ".." || normalized.has_prefix("../") {
    raise @bitcore.GitError::InvalidObject(
      "'\{raw_path}' is outside repository at '\{normalize_path(cwd_prefix)}'",
    )
  }
  let normalized_filter = if normalized == "." || normalized.length() == 0 {
    "."
  } else if has_trailing_slash {
    normalized + "/"
  } else {
    normalized
  }
  compose_pathspec_magic(normalized_filter, is_exclude, is_icase)
}

///|
fn rm_entry_matches_filter(
  path : String,
  filter : String,
  recursive : Bool,
) -> Bool {
  let (raw_pattern, is_exclude, is_icase) = parse_pathspec_magic(filter)
  if is_exclude {
    return false
  }
  let normalized_pattern = if raw_pattern.has_suffix("/") &&
    raw_pattern.length() > 1 {
    String::unsafe_substring(raw_pattern, start=0, end=raw_pattern.length() - 1)
  } else {
    raw_pattern
  }
  if normalized_pattern == "." || normalized_pattern.length() == 0 {
    return true
  }
  if ls_files_filter_has_wildcard(filter) {
    let match_path = if is_icase { path.to_lower() } else { path }
    let match_pattern = if is_icase {
      normalized_pattern.to_lower()
    } else {
      normalized_pattern
    }
    return rm_wildcard_match(match_path, match_pattern)
  }
  let match_path = if is_icase { path.to_lower() } else { path }
  let match_pattern = if is_icase {
    normalized_pattern.to_lower()
  } else {
    normalized_pattern
  }
  match_path == match_pattern ||
  (recursive && match_path.has_prefix(match_pattern + "/"))
}

///|
fn rm_wildcard_match(path : String, pattern : String) -> Bool {
  rm_wildcard_match_impl(pattern.to_array(), 0, path.to_array(), 0)
}

///|
fn rm_wildcard_match_impl(
  pattern : Array[Char],
  pi : Int,
  text : Array[Char],
  ti : Int,
) -> Bool {
  if pi >= pattern.length() {
    return ti >= text.length()
  }
  let current = pattern[pi]
  if current == '*' {
    let mut next_ti = ti
    while true {
      if rm_wildcard_match_impl(pattern, pi + 1, text, next_ti) {
        return true
      }
      if next_ti >= text.length() || text[next_ti] == '/' {
        return false
      }
      next_ti += 1
    }
    false
  } else if current == '?' {
    if ti >= text.length() || text[ti] == '/' {
      false
    } else {
      rm_wildcard_match_impl(pattern, pi + 1, text, ti + 1)
    }
  } else if current == '[' {
    match rm_parse_char_class(pattern, pi) {
      None =>
        if ti < text.length() && text[ti] == current {
          rm_wildcard_match_impl(pattern, pi + 1, text, ti + 1)
        } else {
          false
        }
      Some((class_end, negated, chars)) =>
        if ti >= text.length() || text[ti] == '/' {
          false
        } else {
          let contains = chars.contains(text[ti])
          if contains != negated {
            rm_wildcard_match_impl(pattern, class_end + 1, text, ti + 1)
          } else {
            false
          }
        }
    }
  } else if ti < text.length() && current == text[ti] {
    rm_wildcard_match_impl(pattern, pi + 1, text, ti + 1)
  } else {
    false
  }
}

///|
fn rm_parse_char_class(
  pattern : Array[Char],
  start : Int,
) -> (Int, Bool, Array[Char])? {
  if start + 1 >= pattern.length() {
    return None
  }
  let mut i = start + 1
  let mut negated = false
  if pattern[i] == '!' || pattern[i] == '^' {
    negated = true
    i += 1
  }
  if i >= pattern.length() {
    return None
  }
  let chars : Array[Char] = []
  while i < pattern.length() && pattern[i] != ']' {
    chars.push(pattern[i])
    i += 1
  }
  if i >= pattern.length() || chars.length() == 0 {
    None
  } else {
    Some((i, negated, chars))
  }
}

///|
fn rm_should_show_sparse_advice(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Bool {
  match get_config_override("advice.updateSparsePath") {
    Some(value) => rm_parse_bool(value).unwrap_or(true)
    None =>
      @bitlib.read_config_bool(
        fs,
        git_dir + "/config",
        "advice",
        "updatesparsepath",
      ).unwrap_or(true)
  }
}

///|
fn rm_parse_bool(value : String) -> Bool? {
  let lowered = trim_string(value).to_lower()
  if lowered == "true" || lowered == "yes" || lowered == "on" || lowered == "1" {
    Some(true)
  } else if lowered == "false" ||
    lowered == "no" ||
    lowered == "off" ||
    lowered == "0" {
    Some(false)
  } else {
    None
  }
}

///|
fn rm_sparse_path_error_lines(
  pathspecs : Array[String],
  show_advice : Bool,
) -> Array[String] {
  let lines = [
    "The following paths and/or pathspecs matched paths that exist", "outside of your sparse-checkout definition, so will not be",
    "updated in the index:",
  ]
  for pathspec in pathspecs {
    lines.push(pathspec)
  }
  if show_advice {
    lines.push(
      "hint: If you intend to update such entries, try one of the following:",
    )
    lines.push("hint: * Use the --sparse option.")
    lines.push("hint: * Disable or modify the sparsity rules.")
    lines.push(
      "hint: Disable this message with \"git config set advice.updateSparsePath false\"",
    )
  }
  lines
}

///|
fn rm_should_show_rm_hints(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Bool {
  match get_config_override("advice.rmHints") {
    Some(value) => rm_parse_bool(value).unwrap_or(true)
    None =>
      @bitlib.read_config_bool(fs, git_dir + "/config", "advice", "rmhints").unwrap_or(
        true,
      )
  }
}

///|
fn rm_collect_conflict_paths(
  status : @bitlib.Status,
  removed_paths : Array[String],
  missing_worktree_paths : Map[String, Bool],
  head_exists : Bool,
) -> (Array[String], Array[String], Array[String]) {
  let staged_modified : Map[String, Bool] = {}
  let staged_added : Map[String, Bool] = {}
  let unstaged_modified : Map[String, Bool] = {}
  if head_exists {
    for path in status.staged_modified {
      staged_modified[path] = true
    }
    for path in status.staged_added {
      staged_added[path] = true
    }
  }
  for path in status.unstaged_modified {
    unstaged_modified[path] = true
  }
  let both_dirty : Array[String] = []
  let staged_only : Array[String] = []
  let local_only : Array[String] = []
  for path in removed_paths {
    let has_stage_add = staged_added.contains(path)
    let worktree_missing = missing_worktree_paths.contains(path)
    let has_staged_change = staged_modified.contains(path) ||
      (has_stage_add && !worktree_missing)
    let has_unstaged_change = unstaged_modified.contains(path)
    if has_staged_change && has_unstaged_change {
      both_dirty.push(path)
    } else if has_staged_change {
      staged_only.push(path)
    } else if has_unstaged_change {
      local_only.push(path)
    }
  }
  both_dirty.sort()
  staged_only.sort()
  local_only.sort()
  (both_dirty, staged_only, local_only)
}

///|
fn rm_conflict_error_lines(
  both_dirty : Array[String],
  staged_only : Array[String],
  local_only : Array[String],
  show_hints : Bool,
) -> Array[String] {
  let lines : Array[String] = []
  rm_append_conflict_block(
    lines,
    both_dirty,
    [
      "error: the following file has staged content different from both the", "file and the HEAD:",
    ],
    [
      "error: the following files have staged content different from both the", "file and the HEAD:",
    ],
    Some("(use -f to force removal)"),
    show_hints,
  )
  rm_append_conflict_block(
    lines,
    staged_only,
    ["error: the following file has changes staged in the index:"],
    ["error: the following files have changes staged in the index:"],
    Some("(use --cached to keep the file, or -f to force removal)"),
    show_hints,
  )
  rm_append_conflict_block(
    lines,
    local_only,
    ["error: the following file has local modifications:"],
    ["error: the following files have local modifications:"],
    Some("(use --cached to keep the file, or -f to force removal)"),
    show_hints,
  )
  lines
}

///|
fn rm_append_conflict_block(
  lines : Array[String],
  paths : Array[String],
  singular : Array[String],
  plural : Array[String],
  hint : String?,
  show_hints : Bool,
) -> Unit {
  if paths.length() == 0 {
    return
  }
  let header = if paths.length() == 1 { singular } else { plural }
  for line in header {
    lines.push(line)
  }
  for path in paths {
    lines.push("    " + path)
  }
  if show_hints {
    match hint {
      Some(text) => lines.push(text)
      None => ()
    }
  }
}

///|
fn rm_quote_path(path : String) -> String {
  let b = StringBuilder::new()
  b.write_char('\'')
  for c in path {
    if c == '\'' {
      b.write_string("'\\''")
    } else if c == '\n' {
      b.write_string("\\n")
    } else if c == '\r' {
      b.write_string("\\r")
    } else if c == '\t' {
      b.write_string("\\t")
    } else {
      b.write_char(c)
    }
  }
  b.write_char('\'')
  b.to_string()
}

///|
