///| git check-ignore - check gitignore rules

///|
async fn handle_check_ignore(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let mut verbose = false
  let mut quiet = false
  let mut use_stdin = false
  let mut nul_terminated = false
  let mut non_matching = false
  let positional : Array[String] = []
  let mut past_dashdash = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if past_dashdash {
      positional.push(arg)
      i += 1
      continue
    }
    match arg {
      "-v" | "--verbose" => verbose = true
      "-q" | "--quiet" => quiet = true
      "--stdin" => use_stdin = true
      "-z" => nul_terminated = true
      "-n" | "--non-matching" => non_matching = true
      "--no-index" => ()
      "-h" | "--help" => {
        show_simple_command_help(
          "git check-ignore [<options>] <pathname>...",
          summary="Check whether paths are excluded by .gitignore.",
        )
        return
      }
      "--" => past_dashdash = true
      _ if arg.has_prefix("-") => warn_unimplemented_arg("check-ignore", arg)
      _ => positional.push(arg)
    }
    i += 1
  }
  // non-matching requires verbose
  if non_matching && !(verbose) {
    eprint_line("fatal: -n / --non-matching is only valid with -v")
    @sys.exit(128)
    return
  }
  let paths : Array[String] = []
  paths.append(positional)
  // Read paths from stdin if --stdin
  if use_stdin {
    let data = read_all_stdin()
    let text = decode_bytes(data)
    let sep = if nul_terminated { "\u0000" } else { "\n" }
    for part_view in text.split(sep) {
      let part = part_view.to_string()
      if part.length() > 0 {
        paths.push(part)
      }
    }
  }
  if paths.length() == 0 && !(use_stdin) {
    eprint_line("usage: git check-ignore [<options>] <pathname>...")
    @sys.exit(128)
    return
  }
  // Load ignore rules
  let root = get_work_root()
  let git_dir = find_git_dir(fs)
  let line_sep = if nul_terminated { "\u0000" } else { "\n" }
  let mut had_match = false
  for path in paths {
    // Normalize path: strip leading ./ if present
    let normalized = if path.has_prefix("./") {
      String::unsafe_substring(path, start=2, end=path.length())
    } else {
      path
    }
    // Build matcher with all relevant .gitignore files
    let path_matcher = @ignore.Matcher::new()
    // Root .gitignore
    let root_ignore = root + "/.gitignore"
    if fs.is_file(root_ignore) {
      let content = decode_bytes(
        fs.read_file(root_ignore) catch {
          _ => Bytes::default()
        },
      )
      path_matcher.add_rules("", content)
    }
    // .git/info/exclude
    let exclude_path = git_dir + "/info/exclude"
    if fs.is_file(exclude_path) {
      let content = decode_bytes(
        fs.read_file(exclude_path) catch {
          _ => Bytes::default()
        },
      )
      path_matcher.add_rules("", content)
    }
    // Load intermediate .gitignore files
    let segments = check_ignore_split_path(normalized)
    let mut base = ""
    let seg_limit = segments.length() - 1
    for j in 0..<seg_limit {
      base = if base == "" { segments[j] } else { base + "/" + segments[j] }
      let dir_ignore = root + "/" + base + "/.gitignore"
      if fs.is_file(dir_ignore) {
        let content = decode_bytes(
          fs.read_file(dir_ignore) catch {
            _ => Bytes::default()
          },
        )
        path_matcher.add_rules(base, content)
      }
    }
    let is_dir = fs.is_dir(root + "/" + normalized)
    let ignored = path_matcher.is_ignored(normalized, is_dir)
    if ignored {
      had_match = true
      if !(quiet) {
        if verbose {
          // Verbose: show which rule matched
          let match_info = check_ignore_find_rule(
            fs, root, git_dir, normalized, is_dir,
          )
          print_str(
            match_info.0 +
            ":" +
            match_info.1.to_string() +
            ":" +
            match_info.2 +
            "\t" +
            path +
            line_sep,
          )
        } else {
          print_str(path + line_sep)
        }
      }
    } else if non_matching && verbose {
      // Show non-matching path with :: prefix
      print_str("::\t" + path + line_sep)
    }
  }
  if !(had_match) {
    @sys.exit(1)
  }
}

///|
fn check_ignore_split_path(path : String) -> Array[String] {
  let out : Array[String] = []
  for part_view in path.split("/") {
    let part = part_view.to_string()
    if part.length() > 0 {
      out.push(part)
    }
  }
  out
}

///|
fn check_ignore_find_rule(
  fs : OsFs,
  root : String,
  git_dir : String,
  rel_path : String,
  is_dir : Bool,
) -> (String, Int, String) {
  // Check .gitignore files in order, find the last matching rule
  let mut last_source = ""
  let mut last_linenum = 0
  let mut last_pattern = ""
  // Check root .gitignore
  let root_result = check_ignore_scan_file(
    fs,
    root + "/.gitignore",
    ".gitignore",
    "",
    rel_path,
    is_dir,
  )
  if root_result.1 > 0 {
    last_source = root_result.0
    last_linenum = root_result.1
    last_pattern = root_result.2
  }
  // Check .git/info/exclude
  let exclude_file = git_dir + "/info/exclude"
  let excl_result = check_ignore_scan_file(
    fs, exclude_file, exclude_file, "", rel_path, is_dir,
  )
  if excl_result.1 > 0 {
    last_source = excl_result.0
    last_linenum = excl_result.1
    last_pattern = excl_result.2
  }
  // Check intermediate .gitignore files
  let segments = check_ignore_split_path(rel_path)
  let mut base = ""
  let seg_limit = segments.length() - 1
  for j in 0..<seg_limit {
    base = if base == "" { segments[j] } else { base + "/" + segments[j] }
    let dir_result = check_ignore_scan_file(
      fs,
      root + "/" + base + "/.gitignore",
      base + "/.gitignore",
      base,
      rel_path,
      is_dir,
    )
    if dir_result.1 > 0 {
      last_source = dir_result.0
      last_linenum = dir_result.1
      last_pattern = dir_result.2
    }
  }
  (last_source, last_linenum, last_pattern)
}

///|
fn check_ignore_scan_file(
  fs : OsFs,
  file_path : String,
  source_name : String,
  base : String,
  rel_path : String,
  is_dir : Bool,
) -> (String, Int, String) {
  let mut result_source = ""
  let mut result_linenum = 0
  let mut result_pattern = ""
  if !(fs.is_file(file_path)) {
    return (result_source, result_linenum, result_pattern)
  }
  let content = decode_bytes(
    fs.read_file(file_path) catch {
      _ => return (result_source, result_linenum, result_pattern)
    },
  )
  let mut linenum = 0
  for line_view in content.split("\n") {
    linenum += 1
    let mut line = line_view.to_string()
    if line.has_suffix("\r") {
      line = String::unsafe_substring(line, start=0, end=line.length() - 1)
    }
    let trimmed = line.trim().to_string()
    if trimmed.length() == 0 || trimmed.has_prefix("#") {
      continue
    }
    // Test if this single rule matches
    let matcher = @ignore.Matcher::new()
    matcher.add_rules(base, line)
    if matcher.is_ignored(rel_path, is_dir) {
      result_source = source_name
      result_linenum = linenum
      result_pattern = trimmed
    }
  }
  (result_source, result_linenum, result_pattern)
}
