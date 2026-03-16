///|
async fn delegate_reflog_to_real_git(
  args : Array[String],
  cwd : String,
) -> Unit {
  let argv : Array[String] = ["reflog"]
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
fn reflog_show_builtin_supports_args(args : Array[String]) -> Bool {
  let mut saw_refname = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--no-abbrev-commit"
      | "-i"
      | "--regexp-ignore-case"
      | "-F"
      | "--fixed-strings"
      | "-E"
      | "--extended-regexp"
      | "-P"
      | "--perl-regexp"
      | "--basic-regexp" => i += 1
      "-n" | "--max-count" | "--grep" => {
        if i + 1 >= args.length() {
          return false
        }
        i += 2
      }
      _ if arg.has_prefix("--max-count=") || arg.has_prefix("--grep=") => i += 1
      _ if reflog_parse_short_max_count(arg) is Some(_) => i += 1
      "--" => return false
      _ if arg.has_prefix("-") => return false
      _ => {
        if saw_refname || arg.contains("@{") {
          return false
        }
        saw_refname = true
        i += 1
      }
    }
  }
  true
}

///|
fn reflog_requires_real_git(args : Array[String]) -> Bool {
  if args.length() == 0 {
    return false
  }
  match args[0] {
    "show" => not(reflog_show_builtin_supports_args(collect_args(args, 1)))
    "exists" => false
    "expire" => not(reflog_expire_builtin_supports_args(collect_args(args, 1)))
    "delete" | "drop" | "write" => false
    "list" => true
    _ => not(reflog_show_builtin_supports_args(args))
  }
}

///|
fn reflog_expire_builtin_supports_args(args : Array[String]) -> Bool {
  if args.length() == 0 {
    return false
  }
  for arg in args {
    if arg.has_prefix("-") || arg.contains("@{") {
      return false
    }
  }
  true
}

///|
fn reflog_glob_match(pattern : String, text : String) -> Bool {
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
fn reflog_expire_mode_supported(mode : String) -> Bool {
  let normalized = mode.trim().to_lower()
  normalized == "now" || normalized == "never" || normalized == "false"
}

///|
fn reflog_expire_mode_for_ref(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> String? {
  let content = @bitlib.read_config_content(rfs, git_dir)
  let blocks = @bitlib.parse_config_blocks(content)
  let mut global_mode : String? = None
  let mut pattern_mode : String? = None
  for block in blocks {
    guard block.section is Some(section) else { continue }
    if section != "gc" {
      continue
    }
    for line in block.lines {
      match @bitlib.parse_config_kv(line) {
        Some((key, value)) if key == "reflogexpire" =>
          match block.name {
            Some(pattern) =>
              if reflog_glob_match(pattern, refname) {
                pattern_mode = Some(value)
              }
            None => global_mode = Some(value)
          }
        _ => ()
      }
    }
  }
  match pattern_mode {
    Some(_) => pattern_mode
    None => global_mode
  }
}

///|
fn reflog_builtin_expire_refs(
  fs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  refs : Array[String],
) -> Bool raise Error {
  let normalized_refs : Array[String] = []
  let modes : Array[String] = []
  for refname_arg in refs {
    let normalized = normalize_reflog_refname(rfs, git_dir, refname_arg)
    if not(reflog_ref_exists_or_resolves(rfs, git_dir, normalized)) {
      raise @bitcore.GitError::InvalidObject(
        "error: reflog could not be found: '\{refname_arg}'",
      )
    }
    let mode = reflog_expire_mode_for_ref(rfs, git_dir, normalized)
    guard mode is Some(raw_mode) else { return false }
    if not(reflog_expire_mode_supported(raw_mode)) {
      return false
    }
    normalized_refs.push(normalized)
    modes.push(raw_mode.trim().to_string().to_lower())
  }
  for i in 0..<normalized_refs.length() {
    if modes[i] == "now" {
      let reflog_path = if normalized_refs[i] == "HEAD" {
        git_dir + "/logs/HEAD"
      } else {
        git_dir + "/logs/" + normalized_refs[i]
      }
      if rfs.is_file(reflog_path) {
        fs.write_string(reflog_path, "")
      }
    }
  }
  true
}

///|
priv struct ReflogShowArgs {
  refname : String
  no_abbrev_commit : Bool
  max_count : Int?
  grep_patterns : Array[String]
  grep_pattern_type_override : GrepPatternType?
  grep_ignore_case : Bool
}

///|
async fn handle_reflog(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let wfs : &@bitcore.FileSystem = fs
  let empty_grep_patterns : Array[String] = []
  if reflog_requires_real_git(args) {
    delegate_reflog_to_real_git(args, root)
    return
  }
  if args.length() == 0 {
    // Default to show HEAD
    show_reflog(
      rfs,
      git_dir,
      "HEAD",
      "HEAD",
      false,
      None,
      empty_grep_patterns,
      GrepPatternType::Basic,
      false,
    )
    return
  }
  let subcmd = args[0]
  let rest : Array[String] = []
  for i in 1..<args.length() {
    rest.push(args[i])
  }
  match subcmd {
    "show" => {
      let parsed = parse_reflog_show_args(rest)
      let grep_pattern_type = resolve_grep_pattern_type(
        rfs,
        git_dir,
        parsed.grep_pattern_type_override,
      )
      let refname = normalize_reflog_refname(rfs, git_dir, parsed.refname)
      show_reflog(
        rfs,
        git_dir,
        refname,
        parsed.refname,
        parsed.no_abbrev_commit,
        parsed.max_count,
        parsed.grep_patterns,
        grep_pattern_type,
        parsed.grep_ignore_case,
      )
    }
    "exists" => {
      if rest.length() != 1 || (rest[0].has_prefix("-") && rest[0] != "-") {
        @stdio.stderr.write("usage: git reflog exists <ref>")
        @sys.exit(129)
      }
      let ref_arg = rest[0]
      // Handle ref@{N} format: extract ref name
      let refname = match ref_arg.find("@{") {
        Some(at_idx) => {
          let base = String::unsafe_substring(ref_arg, start=0, end=at_idx)
          normalize_reflog_refname(rfs, git_dir, base)
        }
        None => normalize_reflog_refname(rfs, git_dir, ref_arg)
      }
      if @bitrepo.reflog_exists(rfs, git_dir, refname) {
        @sys.exit(0)
      } else {
        @sys.exit(1)
      }
    }
    "delete" | "drop" => {
      if rest.length() == 0 {
        @stdio.stderr.write("usage: git reflog delete <ref>@{<n>}")
        @sys.exit(1)
      }
      let ref_arg = rest[rest.length() - 1]
      // Parse ref@{N} format
      match ref_arg.find("@{") {
        Some(at_idx) => {
          let base = String::unsafe_substring(ref_arg, start=0, end=at_idx)
          let refname = normalize_reflog_refname(rfs, git_dir, base)
          // Extract N from @{N}
          let closing = ref_arg.find("}")
          guard closing is Some(close_idx) else {
            eprint_line("fatal: invalid reflog entry: \{ref_arg}")
            @sys.exit(1)
            return
          }
          let n_str = String::unsafe_substring(
            ref_arg, start=at_idx + 2, end=close_idx,
          )
          let n = @strconv.parse_int(n_str) catch {
            _ => {
              eprint_line("fatal: invalid reflog entry index: \{n_str}")
              @sys.exit(1)
              return
            }
          }
          reflog_delete_entry(wfs, rfs, git_dir, refname, n)
        }
        None => {
          // No @{N} — delete entire reflog
          let refname = normalize_reflog_refname(rfs, git_dir, ref_arg)
          @bitrepo.delete_reflog(wfs, rfs, git_dir, refname)
        }
      }
    }
    "write" => {
      // Ensure reflog file exists for the given ref (or HEAD)
      let ref_arg = if rest.length() > 0 { rest[0] } else { "HEAD" }
      let refname = normalize_reflog_refname(rfs, git_dir, ref_arg)
      @bitrepo.create_reflog(wfs, rfs, git_dir, refname)
    }
    "expire" =>
      try {
        if not(reflog_builtin_expire_refs(wfs, rfs, git_dir, rest)) {
          delegate_reflog_to_real_git(args, root)
        }
      } catch {
        err =>
          match err {
            @bitcore.GitError::InvalidObject(msg) =>
              if msg.has_prefix("error: reflog could not be found: ") {
                @stdio.stderr.write(msg + "\n")
                @sys.exit(255)
              } else {
                raise err
              }
            _ => raise err
          }
      }
    _ => {
      let show_args : Array[String] = []
      show_args.push(subcmd)
      show_args.append(rest)
      let parsed = parse_reflog_show_args(show_args)
      let grep_pattern_type = resolve_grep_pattern_type(
        rfs,
        git_dir,
        parsed.grep_pattern_type_override,
      )
      let refname = normalize_reflog_refname(rfs, git_dir, parsed.refname)
      // Treat as a ref name for show
      show_reflog(
        rfs,
        git_dir,
        refname,
        parsed.refname,
        parsed.no_abbrev_commit,
        parsed.max_count,
        parsed.grep_patterns,
        grep_pattern_type,
        parsed.grep_ignore_case,
      )
    }
  }
}

///|
async fn show_reflog(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  refname : String,
  display_refname : String,
  no_abbrev_commit : Bool,
  max_count : Int?,
  grep_patterns : Array[String],
  grep_pattern_type : GrepPatternType,
  grep_ignore_case : Bool,
) -> Unit raise Error {
  let entries = @bitrepo.read_reflog(fs, git_dir, refname)
  if entries.length() == 0 && refname == "HEAD" {
    // Some pure commit paths may not materialize logs/HEAD.
    // Fall back to HEAD history so `reflog --grep` semantics remain usable.
    let fallback_max_count = match max_count {
      Some(limit) => limit
      None => 64
    }
    let commits = @bitlib.log_head(fs, git_dir, max_count=fallback_max_count)
    let mut fallback_index = 0
    let mut printed = 0
    for entry in commits {
      if reflog_limit_reached(max_count, printed) {
        break
      }
      let message = "commit: " + entry.message
      if not(
          grep_patterns_match_message(
            message, grep_patterns, grep_pattern_type, grep_ignore_case,
          ),
        ) {
        continue
      }
      let sha = if no_abbrev_commit {
        entry.id.to_hex()
      } else {
        String::unsafe_substring(entry.id.to_hex(), start=0, end=7)
      }
      print_line("\{sha} \{display_refname}@{\{fallback_index}}: \{message}")
      fallback_index += 1
      printed += 1
    }
    return
  }
  // Show in reverse order (newest first)
  let len = entries.length()
  let mut printed = 0
  for i in 0..<len {
    if reflog_limit_reached(max_count, printed) {
      break
    }
    let idx = len - 1 - i
    let entry = entries[idx]
    if not(
        grep_patterns_match_message(
          entry.message,
          grep_patterns,
          grep_pattern_type,
          grep_ignore_case,
        ),
      ) {
      continue
    }
    let sha = if no_abbrev_commit {
      entry.new_id.to_hex()
    } else {
      String::unsafe_substring(entry.new_id.to_hex(), start=0, end=7)
    }
    print_line("\{sha} \{display_refname}@{\{i}}: \{entry.message}")
    printed += 1
  }
}

///|
fn parse_reflog_show_args(args : Array[String]) -> ReflogShowArgs {
  let mut refname = "HEAD"
  let mut no_abbrev_commit = false
  let mut max_count : Int? = None
  let mut has_refname = false
  let grep_patterns : Array[String] = []
  let mut grep_pattern_type_override : GrepPatternType? = None
  let mut grep_ignore_case = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--" {
      break
    }
    match arg {
      "--no-abbrev-commit" => no_abbrev_commit = true
      "-n" | "--max-count" if i + 1 < args.length() => {
        max_count = parse_reflog_max_count_value(args[i + 1])
        i += 1
      }
      _ if arg.has_prefix("--max-count=") =>
        max_count = parse_reflog_max_count_value(
          String::unsafe_substring(arg, start=12, end=arg.length()),
        )
      _ if reflog_parse_short_max_count(arg) is Some(limit) =>
        max_count = Some(limit)
      "--grep" if i + 1 < args.length() => {
        grep_patterns.push(args[i + 1])
        i += 1
      }
      _ if arg.has_prefix("--grep=") =>
        grep_patterns.push(
          String::unsafe_substring(arg, start=7, end=arg.length()),
        )
      "-i" | "--regexp-ignore-case" => grep_ignore_case = true
      "-F" | "--fixed-strings" =>
        grep_pattern_type_override = Some(GrepPatternType::Fixed)
      "-E" | "--extended-regexp" =>
        grep_pattern_type_override = Some(GrepPatternType::Extended)
      "-P" | "--perl-regexp" =>
        grep_pattern_type_override = Some(GrepPatternType::Perl)
      "--basic-regexp" =>
        grep_pattern_type_override = Some(GrepPatternType::Basic)
      _ if arg.has_prefix("-") => ()
      _ =>
        if not(has_refname) {
          refname = arg
          has_refname = true
        }
    }
    i += 1
  }
  {
    refname,
    no_abbrev_commit,
    max_count,
    grep_patterns,
    grep_pattern_type_override,
    grep_ignore_case,
  }
}

///|
fn normalize_reflog_refname(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> String raise @bitcore.GitError {
  if refname == "HEAD" {
    return refname
  }
  let normalized = @bitlib.normalize_repo_path(refname) catch {
    _ => raise @bitcore.GitError::InvalidObject("invalid refname: " + refname)
  }
  if reflog_ref_exists_or_resolves(fs, git_dir, normalized) {
    return normalized
  }
  if normalized.has_prefix("heads/") ||
    normalized.has_prefix("tags/") ||
    normalized.has_prefix("remotes/") {
    return "refs/" + normalized
  }
  let branch_ref = "refs/heads/" + normalized
  if reflog_ref_exists_or_resolves(fs, git_dir, branch_ref) {
    return branch_ref
  }
  let remote_ref = "refs/remotes/" + normalized
  if reflog_ref_exists_or_resolves(fs, git_dir, remote_ref) {
    return remote_ref
  }
  let tag_ref = "refs/tags/" + normalized
  if reflog_ref_exists_or_resolves(fs, git_dir, tag_ref) {
    return tag_ref
  }
  normalized
}

///|
fn reflog_ref_exists_or_resolves(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Bool raise @bitcore.GitError {
  if @bitrepo.reflog_exists(fs, git_dir, refname) {
    return true
  }
  @bitlib.resolve_ref(fs, git_dir, refname) is Some(_)
}

///|
fn parse_reflog_max_count_value(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }
  for c in value {
    if c < '0' || c > '9' {
      return None
    }
  }
  Some(@strconv.parse_int(value) catch { _ => return None })
}

///|
fn reflog_parse_short_max_count(arg : String) -> Int? {
  if arg.length() <= 1 || not(arg.has_prefix("-")) {
    return None
  }
  parse_reflog_max_count_value(
    String::unsafe_substring(arg, start=1, end=arg.length()),
  )
}

///|
fn reflog_limit_reached(max_count : Int?, printed : Int) -> Bool {
  match max_count {
    Some(limit) => printed >= limit
    None => false
  }
}

///|
/// Delete a specific reflog entry by index (newest-first order).
async fn reflog_delete_entry(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  refname : String,
  index : Int,
) -> Unit raise Error {
  let entries = @bitrepo.read_reflog(rfs, git_dir, refname)
  let len = entries.length()
  if len == 0 {
    eprint_line("fatal: no reflog for '\{refname}'")
    @sys.exit(1)
    return
  }
  // Index 0 = newest = last entry in the array
  let array_idx = len - 1 - index
  if array_idx < 0 || array_idx >= len {
    eprint_line("fatal: reflog entry \{refname}@{\{index}} does not exist")
    @sys.exit(1)
    return
  }
  // Rebuild reflog without the deleted entry
  let reflog_path = @bitlib.get_reflog_path(git_dir, refname)
  let content = @utf8.decode_lossy(rfs.read_file(reflog_path)[:])
  let lines : Array[String] = []
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    if line.length() > 0 {
      lines.push(line)
    }
  }
  if array_idx >= lines.length() {
    eprint_line("fatal: reflog entry \{refname}@{\{index}} does not exist")
    @sys.exit(1)
    return
  }
  let new_lines : Array[String] = []
  for i in 0..<lines.length() {
    if i != array_idx {
      new_lines.push(lines[i])
    }
  }
  let new_content = if new_lines.length() > 0 {
    new_lines.join("\n") + "\n"
  } else {
    ""
  }
  wfs.write_string(reflog_path, new_content)
}

///|
