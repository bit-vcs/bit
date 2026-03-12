///|
async fn handle_grep(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let mut show_line_numbers = false
  let mut show_column = false
  let mut show_full_name = false
  let mut show_break = false
  let mut show_heading = false
  let mut show_function = false
  let mut whole_function = false
  let mut ignore_case = false
  let mut color_mode = "never"
  let mut quiet = false
  let mut files_only = false
  let mut files_without_match = false
  let mut count_only = false
  let mut only_matching = false
  let mut invert_match = false
  let mut cached = false
  let mut no_index = false
  let mut search_untracked = false
  let mut null_terminated = false
  let mut word_regexp = false
  let mut max_count = -1
  let mut max_depth = -1
  let mut exclude_standard = false
  let mut before_context = 0
  let mut after_context = 0
  let patterns : Array[String] = []
  let expr_tokens : Array[@bitgrep.GrepExprToken] = []
  let mut use_expr = false
  let mut pattern_type_override : @bitgrep.GrepPatternType? = None
  let mut treeish : String? = None
  let paths : Array[String] = []
  let mut options_terminated = false
  let mut pathspec_only = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if pathspec_only {
      paths.push(arg)
      i += 1
      continue
    }
    if options_terminated {
      if use_expr && grep_expr_expects_pattern(expr_tokens) {
        grep_push_expr_pattern(expr_tokens, arg)
      } else if not(use_expr) && patterns.length() == 0 {
        grep_append_pattern(patterns, expr_tokens, use_expr, arg)
      } else if arg == "--" {
        pathspec_only = true
      } else {
        paths.push(arg)
      }
      i += 1
      continue
    }
    match arg {
      "--" => {
        options_terminated = true
        i += 1
      }
      "-n" | "--line-number" => {
        show_line_numbers = true
        i += 1
      }
      "--column" => {
        show_column = true
        i += 1
      }
      "--full-name" => {
        show_full_name = true
        i += 1
      }
      "--break" => {
        show_break = true
        i += 1
      }
      "--color" => {
        color_mode = "always"
        i += 1
      }
      _ if arg.has_prefix("--color=") => {
        let value = String::unsafe_substring(arg, start=8, end=arg.length())
          .trim()
          .to_lower()
        color_mode = match value {
          "never" | "false" | "no" | "off" => "never"
          _ => "always"
        }
        i += 1
      }
      "--heading" => {
        show_heading = true
        i += 1
      }
      "-p" | "--show-function" => {
        show_function = true
        i += 1
      }
      "-W" | "--function-context" => {
        show_function = true
        whole_function = true
        i += 1
      }
      "-z" => {
        null_terminated = true
        i += 1
      }
      "--no-index" => {
        no_index = true
        i += 1
      }
      "--untracked" => {
        search_untracked = true
        i += 1
      }
      "--exclude-standard" => {
        exclude_standard = true
        i += 1
      }
      "--no-exclude-standard" => {
        exclude_standard = false
        i += 1
      }
      "-i" | "--ignore-case" => {
        ignore_case = true
        i += 1
      }
      "-w" | "--word-regexp" => {
        word_regexp = true
        i += 1
      }
      "-l" | "--files-with-matches" | "--name-only" => {
        files_only = true
        i += 1
      }
      "-L" | "--files-without-match" => {
        files_without_match = true
        i += 1
      }
      "-q" | "--quiet" | "--silent" => {
        quiet = true
        i += 1
      }
      "-c" | "--count" => {
        count_only = true
        i += 1
      }
      "-o" | "--only-matching" => {
        only_matching = true
        i += 1
      }
      "-v" | "--invert-match" => {
        invert_match = true
        i += 1
      }
      "--cached" => {
        cached = true
        i += 1
      }
      "-C" if i + 1 < args.length() => {
        let value = grep_parse_context_length(args[i + 1])
        before_context = value
        after_context = value
        i += 2
      }
      "-A" if i + 1 < args.length() => {
        after_context = grep_parse_context_length(args[i + 1])
        i += 2
      }
      _ if arg.has_prefix("-A") && arg.length() > 2 => {
        after_context = grep_parse_context_length(
          String::unsafe_substring(arg, start=2, end=arg.length()),
        )
        i += 1
      }
      "-B" if i + 1 < args.length() => {
        before_context = grep_parse_context_length(args[i + 1])
        i += 2
      }
      _ if arg.has_prefix("-B") && arg.length() > 2 => {
        before_context = grep_parse_context_length(
          String::unsafe_substring(arg, start=2, end=arg.length()),
        )
        i += 1
      }
      _ if arg.has_prefix("-C") && arg.length() > 2 => {
        let value = grep_parse_context_length(
          String::unsafe_substring(arg, start=2, end=arg.length()),
        )
        before_context = value
        after_context = value
        i += 1
      }
      "--context" if i + 1 < args.length() => {
        let value = grep_parse_context_length(args[i + 1])
        before_context = value
        after_context = value
        i += 2
      }
      "--after-context" if i + 1 < args.length() => {
        after_context = grep_parse_context_length(args[i + 1])
        i += 2
      }
      _ if arg.has_prefix("--after-context=") => {
        after_context = grep_parse_context_length(
          String::unsafe_substring(arg, start=16, end=arg.length()),
        )
        i += 1
      }
      "--before-context" if i + 1 < args.length() => {
        before_context = grep_parse_context_length(args[i + 1])
        i += 2
      }
      _ if arg.has_prefix("--before-context=") => {
        before_context = grep_parse_context_length(
          String::unsafe_substring(arg, start=17, end=arg.length()),
        )
        i += 1
      }
      _ if arg.has_prefix("--context=") => {
        let value = grep_parse_context_length(
          String::unsafe_substring(arg, start=10, end=arg.length()),
        )
        before_context = value
        after_context = value
        i += 1
      }
      "--and" => {
        if not(use_expr) {
          grep_move_patterns_to_expr_tokens(patterns, expr_tokens)
          use_expr = true
        }
        expr_tokens.push(@bitgrep.GrepExprToken::And)
        i += 1
      }
      "--or" => {
        if not(use_expr) {
          grep_move_patterns_to_expr_tokens(patterns, expr_tokens)
          use_expr = true
        }
        expr_tokens.push(@bitgrep.GrepExprToken::Or)
        i += 1
      }
      "--not" => {
        if not(use_expr) {
          grep_move_patterns_to_expr_tokens(patterns, expr_tokens)
          use_expr = true
        }
        expr_tokens.push(@bitgrep.GrepExprToken::Not)
        i += 1
      }
      "--no-recursive" => {
        max_depth = 0
        i += 1
      }
      "--max-count" if i + 1 < args.length() => {
        max_count = grep_parse_max_count(args[i + 1])
        i += 2
      }
      "--max-count" =>
        raise @bitcore.GitError::InvalidObject(
          "fatal: option '--max-count' requires a value",
        )
      _ if arg.has_prefix("--max-count=") => {
        let value = String::unsafe_substring(arg, start=12, end=arg.length())
        max_count = grep_parse_max_count(value)
        i += 1
      }
      "-m" if i + 1 < args.length() => {
        max_count = grep_parse_max_count(args[i + 1])
        i += 2
      }
      "-m" =>
        raise @bitcore.GitError::InvalidObject(
          "fatal: option '-m' requires a value",
        )
      _ if arg.has_prefix("-m") && arg.length() > 2 => {
        let value = String::unsafe_substring(arg, start=2, end=arg.length())
        max_count = grep_parse_max_count(value)
        i += 1
      }
      "--recursive" => i += 1
      "--max-depth" if i + 1 < args.length() => {
        max_depth = @strconv.parse_int(args[i + 1]) catch {
          _ =>
            raise @bitcore.GitError::InvalidObject(
              "fatal: invalid max count: " + args[i + 1],
            )
        }
        i += 2
      }
      _ if arg.has_prefix("--max-depth=") => {
        let value = String::unsafe_substring(arg, start=12, end=arg.length())
        max_depth = @strconv.parse_int(value) catch {
          _ =>
            raise @bitcore.GitError::InvalidObject(
              "fatal: invalid max count: " + value,
            )
        }
        i += 1
      }
      "-F" | "--fixed-strings" => {
        pattern_type_override = Some(@bitgrep.GrepPatternType::Fixed)
        i += 1
      }
      "-Fi" | "-iF" => {
        ignore_case = true
        pattern_type_override = Some(@bitgrep.GrepPatternType::Fixed)
        i += 1
      }
      "-E" | "--extended-regexp" => {
        pattern_type_override = Some(@bitgrep.GrepPatternType::Extended)
        i += 1
      }
      "-G" => {
        pattern_type_override = Some(@bitgrep.GrepPatternType::Basic)
        i += 1
      }
      "-P" | "--perl-regexp" => {
        pattern_type_override = Some(@bitgrep.GrepPatternType::Perl)
        i += 1
      }
      "--basic-regexp" => {
        pattern_type_override = Some(@bitgrep.GrepPatternType::Basic)
        i += 1
      }
      "-e" if i + 1 < args.length() => {
        grep_append_pattern(patterns, expr_tokens, use_expr, args[i + 1])
        i += 2
      }
      "-e" => raise @bitcore.GitError::InvalidObject("fatal: no pattern given")
      _ if arg.has_prefix("-e") => {
        grep_append_pattern(
          patterns,
          expr_tokens,
          use_expr,
          String::unsafe_substring(arg, start=2, end=arg.length()),
        )
        i += 1
      }
      "-f" if i + 1 < args.length() => {
        grep_append_patterns_from_file(
          fs,
          root,
          args[i + 1],
          patterns,
          expr_tokens,
          use_expr,
        ) catch {
          err if @async.is_cancellation_error(err) => raise err
          err => raise err
        }
        i += 2
      }
      "-f" => raise @bitcore.GitError::InvalidObject("fatal: no pattern given")
      _ if arg.has_prefix("-f") => {
        let file = String::unsafe_substring(arg, start=2, end=arg.length())
        grep_append_patterns_from_file(
          fs, root, file, patterns, expr_tokens, use_expr,
        ) catch {
          err if @async.is_cancellation_error(err) => raise err
          err => raise err
        }
        i += 1
      }
      "--threads" if i + 1 < args.length() => i += 2
      _ if arg.has_prefix("--threads=") => i += 1
      "(" | "\\(" => {
        if not(use_expr) {
          grep_move_patterns_to_expr_tokens(patterns, expr_tokens)
          use_expr = true
        }
        grep_push_expr_lparen(expr_tokens)
        i += 1
      }
      ")" | "\\)" => {
        if not(use_expr) {
          grep_move_patterns_to_expr_tokens(patterns, expr_tokens)
          use_expr = true
        }
        expr_tokens.push(@bitgrep.GrepExprToken::RParen)
        i += 1
      }
      _ if not(arg.has_prefix("-")) => {
        if use_expr && grep_expr_expects_pattern(expr_tokens) {
          grep_push_expr_pattern(expr_tokens, arg)
        } else if not(use_expr) && patterns.length() == 0 {
          grep_append_pattern(patterns, expr_tokens, use_expr, arg)
        } else if no_index &&
          treeish is None &&
          grep_has_future_pathspec_separator(args, i + 1) &&
          grep_token_is_treeish(fs, git_dir, arg) {
          treeish = Some(arg)
        } else if not(no_index) &&
          treeish is None &&
          paths.length() == 0 &&
          (
            grep_token_is_treeish(fs, git_dir, arg) ||
            grep_has_future_pathspec_separator(args, i + 1)
          ) {
          treeish = Some(arg)
        } else {
          paths.push(arg)
        }
        i += 1
      }
      _ if arg.has_prefix("-") => {
        warn_unimplemented_arg("grep", arg)
        i += 1
      }
      _ => i += 1
    }
  }
  if no_index && treeish is Some(_) {
    eprint_line("fatal: option '--no-index' cannot be used with revs")
    @sys.exit(128)
  }
  guard patterns.length() > 0 || use_expr else {
    raise @bitcore.GitError::InvalidObject("fatal: no pattern given")
  }
  let pattern_type = @bitgrep.resolve_grep_pattern_type(
    fs,
    git_dir,
    pattern_type_override,
    get_config_override("grep.patterntype"),
  )
  if pattern_type == @bitgrep.GrepPatternType::Perl {
    raise @bitcore.GitError::InvalidObject(
      "fatal: cannot use Perl-compatible regexes when not compiled with USE_LIBPCRE",
    )
  }
  let expr = if use_expr {
    let value = @bitgrep.parse_grep_expr(expr_tokens)
    @bitgrep.validate_grep_expr(value, pattern_type)
    value
  } else {
    @bitgrep.validate_grep_patterns(patterns, pattern_type)
    match @bitgrep.grep_or_expr_from_patterns(patterns) {
      Some(value) => value
      None => raise @bitcore.GitError::InvalidObject("fatal: no pattern given")
    }
  }
  let color_spec = grep_resolve_color_spec(fs, git_dir, color_mode)
  let search_root = if no_index {
    normalize_path(grep_get_invocation_cwd(root))
  } else {
    root
  }
  let resolved_paths = if no_index {
    grep_resolve_no_index_paths(fs, search_root, paths)
  } else {
    grep_resolve_input_paths(root, paths)
  }
  let raw_matches = match treeish {
    Some(spec) =>
      @bitgrep.search_treeish_expr(
        fs,
        git_dir,
        spec,
        expr,
        resolved_paths,
        pattern_type~,
        ignore_case~,
        invert_match~,
        word_regexp~,
        max_depth~,
      )
    None =>
      if no_index {
        @bitgrep.search_plain_worktree_expr(
          fs,
          search_root,
          expr,
          resolved_paths,
          pattern_type~,
          ignore_case~,
          invert_match~,
          word_regexp~,
          max_depth~,
          exclude_standard~,
        )
      } else if cached {
        @bitgrep.search_index_expr(
          fs,
          git_dir,
          expr,
          resolved_paths,
          pattern_type~,
          ignore_case~,
          invert_match~,
          word_regexp~,
          max_depth~,
        )
      } else if search_untracked {
        grep_merge_file_matches(
          @bitgrep.search_tracked_worktree_expr(
            fs,
            git_dir,
            root,
            expr,
            resolved_paths,
            pattern_type~,
            ignore_case~,
            invert_match~,
            word_regexp~,
            max_depth~,
          ),
          @bitgrep.search_untracked_worktree_expr(
            fs,
            git_dir,
            root,
            expr,
            resolved_paths,
            pattern_type~,
            ignore_case~,
            invert_match~,
            word_regexp~,
            max_depth~,
          ),
        )
      } else {
        @bitgrep.search_tracked_worktree_expr(
          fs,
          git_dir,
          root,
          expr,
          resolved_paths,
          pattern_type~,
          ignore_case~,
          invert_match~,
          word_regexp~,
          max_depth~,
        )
      }
  }
  let matches = grep_limit_file_matches(raw_matches, max_count)
  if quiet && not(files_without_match) {
    if matches.length() > 0 {
      return
    }
    @sys.exit(1)
  }
  if files_without_match {
    let candidates = match treeish {
      Some(spec) =>
        @bitgrep.list_treeish_candidate_paths(
          fs,
          git_dir,
          spec,
          resolved_paths,
          max_depth~,
        )
      None =>
        if no_index {
          @bitgrep.list_plain_worktree_candidate_paths(
            fs,
            search_root,
            resolved_paths,
            max_depth~,
            exclude_standard~,
          )
        } else if cached {
          @bitgrep.list_index_candidate_paths(
            fs,
            git_dir,
            resolved_paths,
            max_depth~,
          )
        } else if search_untracked {
          grep_merge_candidate_paths(
            @bitgrep.list_tracked_worktree_candidate_paths(
              fs,
              git_dir,
              resolved_paths,
              max_depth~,
            ),
            @bitgrep.list_untracked_worktree_candidate_paths(
              fs,
              git_dir,
              root,
              resolved_paths,
              max_depth~,
            ),
          )
        } else {
          @bitgrep.list_tracked_worktree_candidate_paths(
            fs,
            git_dir,
            resolved_paths,
            max_depth~,
          )
        }
    }
    let matched : Map[String, Bool] = {}
    for file_match in matches {
      matched[file_match.path] = true
    }
    let mut had_output = false
    for path in candidates {
      if matched.contains(path) {
        continue
      }
      had_output = true
      let display_path = grep_format_output_path_raw(
        search_root, treeish, path, show_full_name,
      )
      if not(quiet) {
        grep_print_path_atom(display_path, null_terminated)
      }
    }
    if quiet {
      if had_output {
        return
      }
      @sys.exit(1)
    }
    if not(had_output) {
      @sys.exit(1)
    }
    return
  }
  let mut printed_any = false
  for file_match in matches {
    let file_path = grep_format_output_path(
      search_root,
      treeish,
      file_match.path,
      show_full_name,
      null_terminated,
    )
    let match_count = file_match.matches.length()
    if files_only {
      grep_print_path_atom(file_path, null_terminated)
    } else if count_only {
      print_line("\{file_path}:\{match_count}")
    } else if only_matching {
      if show_break && printed_any {
        print_line("")
      }
      if show_heading {
        print_line(grep_color_wrap(file_path, color_spec.filename))
      }
      grep_print_only_matching(
        file_path, expr, file_match, pattern_type, ignore_case, word_regexp, show_line_numbers,
        show_column, show_heading, color_spec,
      )
      printed_any = true
    } else if whole_function {
      if printed_any {
        if show_break {
          print_line("")
        } else if not(show_heading) {
          print_line(grep_color_wrap("--", color_spec.separator))
        }
      }
      if show_heading {
        print_line(grep_color_wrap(file_path, color_spec.filename))
      }
      grep_print_whole_function_match(
        fs, search_root, git_dir, treeish, cached, file_match, show_line_numbers,
        show_column, show_heading, expr, pattern_type, ignore_case, word_regexp,
        color_spec, file_path,
      )
      printed_any = true
    } else if before_context > 0 || after_context > 0 {
      if printed_any {
        if show_break {
          print_line("")
        } else if not(show_heading) {
          print_line(grep_color_wrap("--", color_spec.separator))
        }
      }
      if show_heading {
        print_line(grep_color_wrap(file_path, color_spec.filename))
      }
      grep_print_file_match_with_context(
        fs, search_root, git_dir, treeish, cached, file_match, show_line_numbers,
        show_column, before_context, after_context, show_heading, show_function,
        expr, pattern_type, ignore_case, word_regexp, color_spec, file_path,
      )
      printed_any = true
    } else {
      if show_break && printed_any {
        print_line("")
      }
      if show_heading {
        print_line(grep_color_wrap(file_path, color_spec.filename))
      }
      if show_function {
        grep_print_file_match_with_context(
          fs, search_root, git_dir, treeish, cached, file_match, show_line_numbers,
          show_column, 0, 0, show_heading, true, expr, pattern_type, ignore_case,
          word_regexp, color_spec, file_path,
        )
      } else {
        for item in file_match.matches {
          let num = item.line_number
          let col = item.column
          let line = item.line
          grep_print_match_line(
            file_path, num, col, line, show_line_numbers, show_column, show_heading,
            ':', expr, pattern_type, ignore_case, word_regexp, color_spec,
          )
        }
      }
      printed_any = true
    }
  }
  if matches.length() == 0 {
    @sys.exit(1)
  }
}

///|
fn grep_limit_file_matches(
  matches : Array[@bitgrep.GrepFileMatch],
  max_count : Int,
) -> Array[@bitgrep.GrepFileMatch] {
  if max_count < 0 {
    return matches
  }
  let limited : Array[@bitgrep.GrepFileMatch] = []
  for file_match in matches {
    if max_count == 0 {
      continue
    }
    if file_match.matches.length() <= max_count {
      limited.push(file_match)
      continue
    }
    let truncated : Array[@bitgrep.GrepLineMatch] = []
    for i in 0..<max_count {
      truncated.push(file_match.matches[i])
    }
    limited.push({ path: file_match.path, matches: truncated })
  }
  limited
}

///|
async fn grep_append_patterns_from_file(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  file : String,
  patterns : Array[String],
  expr_tokens : Array[@bitgrep.GrepExprToken],
  use_expr : Bool,
) -> Unit raise Error {
  let content = if file == "-" {
    decode_bytes(read_all_stdin())
  } else {
    let path = grep_resolve_pattern_file_path(root, file)
    @utf8.decode_lossy(fs.read_file(path)[:])
  }
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    if line == "" {
      continue
    }
    grep_append_single_pattern(patterns, expr_tokens, use_expr, line)
  }
}

///|
fn grep_resolve_pattern_file_path(root : String, file : String) -> String {
  if file.has_prefix("/") {
    file
  } else {
    grep_get_invocation_cwd(root) + "/" + file
  }
}

///|
fn grep_get_invocation_cwd(root : String) -> String {
  match @sys.get_env_var("GIT_SHIM_CWD") {
    Some(dir) => dir
    None =>
      match @sys.get_env_var("GIT_SHIM_PWD") {
        Some(dir) => dir
        None => @env.current_dir().unwrap_or(root)
      }
  }
}

///|
fn grep_token_is_treeish(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  token : String,
) -> Bool {
  (@bitrepo.rev_parse(fs, git_dir, token) catch { _ => None }) is Some(_)
}

///|
fn grep_has_future_pathspec_separator(
  args : Array[String],
  start : Int,
) -> Bool {
  let mut i = start
  while i < args.length() {
    if args[i] == "--" {
      return true
    }
    i += 1
  }
  false
}

///|
fn grep_append_pattern(
  patterns : Array[String],
  expr_tokens : Array[@bitgrep.GrepExprToken],
  use_expr : Bool,
  pattern : String,
) -> Unit {
  if pattern.contains("\n") {
    let mut appended = false
    for line_view in pattern.split("\n") {
      let line = line_view.to_string()
      if line == "" {
        continue
      }
      grep_append_single_pattern(patterns, expr_tokens, use_expr, line)
      appended = true
    }
    if appended {
      return
    }
  }
  grep_append_single_pattern(patterns, expr_tokens, use_expr, pattern)
}

///|
fn grep_append_single_pattern(
  patterns : Array[String],
  expr_tokens : Array[@bitgrep.GrepExprToken],
  use_expr : Bool,
  pattern : String,
) -> Unit {
  if use_expr {
    grep_push_expr_pattern(expr_tokens, pattern)
  } else {
    patterns.push(pattern)
  }
}

///|
fn grep_move_patterns_to_expr_tokens(
  patterns : Array[String],
  expr_tokens : Array[@bitgrep.GrepExprToken],
) -> Unit {
  for pattern in patterns {
    grep_push_expr_pattern(expr_tokens, pattern)
  }
}

///|
fn grep_push_expr_pattern(
  expr_tokens : Array[@bitgrep.GrepExprToken],
  pattern : String,
) -> Unit {
  if grep_expr_needs_operator(expr_tokens) {
    expr_tokens.push(@bitgrep.GrepExprToken::Or)
  }
  expr_tokens.push(@bitgrep.GrepExprToken::Pattern(pattern))
}

///|
fn grep_push_expr_lparen(expr_tokens : Array[@bitgrep.GrepExprToken]) -> Unit {
  if grep_expr_needs_operator(expr_tokens) {
    expr_tokens.push(@bitgrep.GrepExprToken::Or)
  }
  expr_tokens.push(@bitgrep.GrepExprToken::LParen)
}

///|
fn grep_expr_needs_operator(
  expr_tokens : Array[@bitgrep.GrepExprToken],
) -> Bool {
  if expr_tokens.length() == 0 {
    return false
  }
  match expr_tokens[expr_tokens.length() - 1] {
    @bitgrep.GrepExprToken::Pattern(_) | @bitgrep.GrepExprToken::RParen => true
    _ => false
  }
}

///|
fn grep_expr_expects_pattern(
  expr_tokens : Array[@bitgrep.GrepExprToken],
) -> Bool {
  if expr_tokens.length() == 0 {
    return true
  }
  match expr_tokens[expr_tokens.length() - 1] {
    @bitgrep.GrepExprToken::And
    | @bitgrep.GrepExprToken::Or
    | @bitgrep.GrepExprToken::Not
    | @bitgrep.GrepExprToken::LParen => true
    _ => false
  }
}

///|
fn grep_parse_context_length(value : String) -> Int raise Error {
  let parsed = @strconv.parse_int(value) catch {
    _ =>
      raise @bitcore.GitError::InvalidObject(
        "fatal: invalid context length argument: " + value,
      )
  }
  if parsed < 0 {
    raise @bitcore.GitError::InvalidObject(
      "fatal: invalid context length argument: " + value,
    )
  }
  parsed
}

///|
fn grep_parse_max_count(value : String) -> Int raise Error {
  @strconv.parse_int(value) catch {
    _ =>
      raise @bitcore.GitError::InvalidObject(
        "fatal: invalid max count: " + value,
      )
  }
}

///|
struct GrepColorSpec {
  filename : String
  linenumber : String
  selected : String
  context : String
  function_color : String
  match_selected : String
  match_context : String
  separator : String
}

///|
fn grep_resolve_color_spec(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  color_mode : String,
) -> GrepColorSpec raise Error {
  if color_mode != "always" {
    return {
      filename: "",
      linenumber: "",
      selected: "",
      context: "",
      function_color: "",
      match_selected: "",
      match_context: "",
      separator: "",
    }
  }
  let match_default = grep_resolve_color_value(fs, git_dir, "color.grep.match")
  let match_selected = match
    grep_resolve_color_value(fs, git_dir, "color.grep.matchselected") {
    Some(value) => value
    None =>
      match match_default {
        Some(value) => value
        None => ""
      }
  }
  let match_context = match
    grep_resolve_color_value(fs, git_dir, "color.grep.matchcontext") {
    Some(value) => value
    None =>
      match match_default {
        Some(value) => value
        None => ""
      }
  }
  {
    filename: grep_resolve_color_value(fs, git_dir, "color.grep.filename").unwrap_or(
      "",
    ),
    linenumber: grep_resolve_color_value(fs, git_dir, "color.grep.linenumber").unwrap_or(
      "",
    ),
    selected: grep_resolve_color_value(fs, git_dir, "color.grep.selected").unwrap_or(
      "",
    ),
    context: grep_resolve_color_value(fs, git_dir, "color.grep.context").unwrap_or(
      "",
    ),
    function_color: grep_resolve_color_value(fs, git_dir, "color.grep.function").unwrap_or(
      "",
    ),
    match_selected,
    match_context,
    separator: grep_resolve_color_value(fs, git_dir, "color.grep.separator").unwrap_or(
      "",
    ),
  }
}

///|
fn grep_resolve_color_value(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  key : String,
) -> String? raise Error {
  let raw = match get_config_override(key) {
    Some(value) => Some(value)
    None => get_config_value(fs, git_dir + "/config", key, None, false)
  }
  match raw {
    Some(value) => grep_parse_color_value(value)
    None => None
  }
}

///|
fn grep_parse_color_value(value : String) -> String? {
  let trimmed = trim_string(value).to_lower()
  if trimmed == "" || trimmed == "normal" || trimmed == "reset" {
    return Some("")
  }
  let tokens : Array[String] = []
  for token_view in trimmed.split(" ") {
    let token = token_view.to_string()
    if token != "" {
      tokens.push(token)
    }
  }
  let codes : Array[String] = []
  let mut saw_foreground = false
  for token in tokens {
    match token {
      "bold" => codes.push("1")
      "black"
      | "red"
      | "green"
      | "yellow"
      | "blue"
      | "magenta"
      | "cyan"
      | "white" => {
        let base = match token {
          "black" => 30
          "red" => 31
          "green" => 32
          "yellow" => 33
          "blue" => 34
          "magenta" => 35
          "cyan" => 36
          _ => 37
        }
        if saw_foreground {
          codes.push((base + 10).to_string())
        } else {
          codes.push(base.to_string())
          saw_foreground = true
        }
      }
      _ => return None
    }
  }
  if codes.length() == 0 {
    Some("")
  } else {
    let joined = codes.join(";")
    Some("\u001b[\{joined}m")
  }
}

///|
fn grep_color_wrap(text : String, color : String) -> String {
  if color == "" || text == "" {
    text
  } else {
    color + text + "\u001b[m"
  }
}

///|
fn grep_line_color_for_sign(color_spec : GrepColorSpec, sign : Char) -> String {
  match sign {
    ':' => color_spec.selected
    '-' => color_spec.context
    '=' => color_spec.function_color
    _ => ""
  }
}

///|
fn grep_match_color_for_sign(color_spec : GrepColorSpec, sign : Char) -> String {
  match sign {
    ':' => color_spec.match_selected
    '-' => color_spec.match_context
    '=' => color_spec.match_selected
    _ => ""
  }
}

///|
fn grep_colorize_line(
  line : String,
  spans : Array[@bitgrep.GrepMatchSpan],
  line_color : String,
  match_color : String,
) -> String {
  if spans.length() == 0 {
    return grep_color_wrap(line, line_color)
  }
  let ordered = spans.copy()
  ordered.sort_by((a, b) => Int::compare(a.start_column, b.start_column))
  let out = StringBuilder::new()
  let mut cursor = 0
  for span in ordered {
    let start = span.start_column - 1
    let end = span.end_column
    if start > cursor {
      out.write_string(
        grep_color_wrap(
          String::unsafe_substring(line, start=cursor, end=start),
          line_color,
        ),
      )
    }
    if end > start {
      out.write_string(
        grep_color_wrap(
          String::unsafe_substring(line, start~, end~),
          match_color,
        ),
      )
    }
    if end > cursor {
      cursor = end
    }
  }
  if cursor < line.length() {
    out.write_string(
      grep_color_wrap(
        String::unsafe_substring(line, start=cursor, end=line.length()),
        line_color,
      ),
    )
  }
  out.to_string()
}

///|
fn grep_build_prefix(
  file_path : String,
  line_number : Int,
  column : Int,
  show_line_numbers : Bool,
  show_column : Bool,
  show_heading : Bool,
  sign : Char,
  color_spec : GrepColorSpec,
) -> String {
  let sep = sign.to_string()
  let out = StringBuilder::new()
  if not(show_heading) {
    out.write_string(grep_color_wrap(file_path, color_spec.filename))
    out.write_string(grep_color_wrap(sep, color_spec.separator))
  }
  if show_line_numbers {
    out.write_string(
      grep_color_wrap(line_number.to_string(), color_spec.linenumber),
    )
    out.write_string(grep_color_wrap(sep, color_spec.separator))
  }
  if show_column {
    out.write_string(grep_color_wrap(column.to_string(), color_spec.linenumber))
    out.write_string(grep_color_wrap(sep, color_spec.separator))
  }
  out.to_string()
}

///|
async fn grep_print_file_match_with_context(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  treeish : String?,
  cached : Bool,
  file_match : @bitgrep.GrepFileMatch,
  show_line_numbers : Bool,
  show_column : Bool,
  before_context : Int,
  after_context : Int,
  show_heading : Bool,
  show_function : Bool,
  expr : @bitgrep.GrepExpr,
  pattern_type : @bitgrep.GrepPatternType,
  ignore_case : Bool,
  word_regexp : Bool,
  color_spec : GrepColorSpec,
  display_path : String,
) -> Unit raise Error {
  let content = grep_load_content_for_match(
    fs,
    root,
    git_dir,
    treeish,
    cached,
    file_match.path,
  )
  let lines = grep_split_content_lines(content)
  let function_spec = grep_resolve_function_context_spec(
    fs,
    root,
    git_dir,
    file_match.path,
  )
  let matched_columns : Map[Int, Int] = {}
  for item in file_match.matches {
    if not(matched_columns.contains(item.line_number)) {
      matched_columns[item.line_number] = item.column
    }
  }
  let ranges : Array[(Int, Int)] = []
  for item in file_match.matches {
    let range_start = if item.line_number - before_context > 1 {
      item.line_number - before_context
    } else {
      1
    }
    let range_end = if item.line_number + after_context < lines.length() {
      item.line_number + after_context
    } else {
      lines.length()
    }
    if ranges.length() == 0 {
      ranges.push((range_start, range_end))
      continue
    }
    let last_index = ranges.length() - 1
    let (last_start, last_end) = ranges[last_index]
    if range_start <= last_end + 1 {
      let merged_end = if range_end > last_end { range_end } else { last_end }
      ranges[last_index] = (last_start, merged_end)
    } else {
      ranges.push((range_start, range_end))
    }
  }
  let mut first_range = true
  for i in 0..<ranges.length() {
    let (range_start, range_end) = ranges[i]
    let function_line = if show_function {
      let mut first_match_line : Int? = None
      for item in file_match.matches {
        if item.line_number >= range_start && item.line_number <= range_end {
          first_match_line = Some(item.line_number)
          break
        }
      }
      match first_match_line {
        Some(line_number) =>
          grep_find_function_context_line(
            lines,
            1,
            line_number,
            function_spec.header_pattern,
          )
        None => None
      }
    } else {
      None
    }
    if not(first_range) {
      print_line(grep_color_wrap("--", color_spec.separator))
    }
    first_range = false
    match function_line {
      Some(function_line_number) if function_line_number < range_start =>
        grep_print_context_line(
          display_path,
          function_line_number,
          lines[function_line_number - 1],
          show_line_numbers,
          show_heading,
          '=',
          color_spec,
        )
      _ => ()
    }
    for line_number in range_start..<(range_end + 1) {
      let line = lines[line_number - 1]
      match matched_columns.get(line_number) {
        Some(column) =>
          grep_print_match_line(
            display_path, line_number, column, line, show_line_numbers, show_column,
            show_heading, ':', expr, pattern_type, ignore_case, word_regexp, color_spec,
          )
        None => {
          let sign = match function_line {
            Some(function_line_number) if function_line_number == line_number =>
              '='
            _ => '-'
          }
          grep_print_context_line(
            display_path, line_number, line, show_line_numbers, show_heading, sign,
            color_spec,
          )
        }
      }
    }
  }
}

///|
struct GrepFunctionContextSpec {
  header_pattern : String?
  include_leading_comments : Bool
}

///|
async fn grep_print_whole_function_match(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  treeish : String?,
  cached : Bool,
  file_match : @bitgrep.GrepFileMatch,
  show_line_numbers : Bool,
  show_column : Bool,
  show_heading : Bool,
  expr : @bitgrep.GrepExpr,
  pattern_type : @bitgrep.GrepPatternType,
  ignore_case : Bool,
  word_regexp : Bool,
  color_spec : GrepColorSpec,
  display_path : String,
) -> Unit raise Error {
  let content = grep_load_content_for_match(
    fs,
    root,
    git_dir,
    treeish,
    cached,
    file_match.path,
  )
  let lines = grep_split_content_lines(content)
  let function_spec = grep_resolve_function_context_spec(
    fs,
    root,
    git_dir,
    file_match.path,
  )
  let printed_ranges : Array[(Int, Int)] = []
  for item in file_match.matches {
    let range = grep_compute_whole_function_range(
      lines,
      item.line_number,
      function_spec,
    )
    if printed_ranges.length() == 0 {
      printed_ranges.push(range)
      continue
    }
    let last_index = printed_ranges.length() - 1
    let (last_start, last_end) = printed_ranges[last_index]
    let (range_start, range_end) = range
    if range_start <= last_end + 1 {
      let merged_end = if range_end > last_end { range_end } else { last_end }
      printed_ranges[last_index] = (last_start, merged_end)
    } else {
      printed_ranges.push(range)
    }
  }
  let matched_columns : Map[Int, Int] = {}
  for item in file_match.matches {
    if not(matched_columns.contains(item.line_number)) {
      matched_columns[item.line_number] = item.column
    }
  }
  let mut first_range = true
  for i in 0..<printed_ranges.length() {
    let (range_start, range_end) = printed_ranges[i]
    if not(first_range) {
      print_line(grep_color_wrap("--", color_spec.separator))
    }
    first_range = false
    let header_line = grep_find_function_context_line(
      lines,
      range_start,
      range_end,
      function_spec.header_pattern,
    )
    for line_number in range_start..<(range_end + 1) {
      let line = lines[line_number - 1]
      match matched_columns.get(line_number) {
        Some(column) =>
          grep_print_match_line(
            display_path, line_number, column, line, show_line_numbers, show_column,
            show_heading, ':', expr, pattern_type, ignore_case, word_regexp, color_spec,
          )
        None => {
          let sign = match header_line {
            Some(function_line_number) if function_line_number == line_number =>
              '='
            _ => '-'
          }
          grep_print_context_line(
            display_path, line_number, line, show_line_numbers, show_heading, sign,
            color_spec,
          )
        }
      }
    }
  }
}

///|
fn grep_resolve_function_context_spec(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  path : String,
) -> GrepFunctionContextSpec {
  match @bitlib.resolve_diff_driver(fs, root, path) {
    Some(diff_driver) => {
      let (funcname, xfuncname) = @bitlib.read_diff_function_patterns(
        fs, git_dir, diff_driver,
      )
      match xfuncname {
        Some(pattern) =>
          { header_pattern: Some(pattern), include_leading_comments: true }
        None =>
          match funcname {
            Some(pattern) =>
              { header_pattern: Some(pattern), include_leading_comments: false }
            None => { header_pattern: None, include_leading_comments: false }
          }
      }
    }
    None => { header_pattern: None, include_leading_comments: false }
  }
}

///|
fn grep_find_function_context_line(
  lines : Array[String],
  range_start : Int,
  match_line : Int,
  header_pattern : String?,
) -> Int? {
  let mut line_number = match_line
  while line_number >= range_start {
    let line = lines[line_number - 1]
    if grep_is_function_context_line(line, header_pattern) {
      return Some(line_number)
    }
    line_number -= 1
  }
  None
}

///|
fn grep_is_function_context_line(
  line : String,
  header_pattern : String?,
) -> Bool {
  match header_pattern {
    Some(pattern) =>
      @bitgrep.grep_message_matches_pattern(
        line,
        pattern,
        @bitgrep.GrepPatternType::Extended,
        false,
      )
    None => grep_is_default_function_context_line(line)
  }
}

///|
fn grep_is_default_function_context_line(line : String) -> Bool {
  let trimmed = trim_string(line)
  if trimmed == "" {
    return false
  }
  if line.has_prefix(" ") || line.has_prefix("\t") || trimmed.has_prefix("#") {
    return false
  }
  trimmed.contains("(") && trimmed.contains(")")
}

///|
fn grep_compute_whole_function_range(
  lines : Array[String],
  match_line : Int,
  function_spec : GrepFunctionContextSpec,
) -> (Int, Int) {
  match
    grep_find_function_context_line(
      lines,
      1,
      match_line,
      function_spec.header_pattern,
    ) {
    Some(header_line) => {
      let range_start = if function_spec.include_leading_comments {
        grep_extend_header_to_leading_comments(lines, header_line)
      } else {
        header_line
      }
      let next_header = grep_find_next_function_context_line(
        lines,
        header_line + 1,
        function_spec.header_pattern,
      )
      let range_end = match next_header {
        Some(line_number) => {
          let next_block_start = if function_spec.include_leading_comments {
            grep_extend_header_to_leading_comments(lines, line_number)
          } else {
            line_number
          }
          if next_block_start <= range_start {
            range_start
          } else {
            grep_trim_blank_range_end(lines, next_block_start - 1, range_start)
          }
        }
        None => grep_trim_blank_range_end(lines, lines.length(), range_start)
      }
      (range_start, range_end)
    }
    None =>
      (
        grep_find_paragraph_start(lines, match_line),
        grep_find_paragraph_end(lines, match_line),
      )
  }
}

///|
fn grep_find_next_function_context_line(
  lines : Array[String],
  start_line : Int,
  header_pattern : String?,
) -> Int? {
  let mut line_number = start_line
  while line_number <= lines.length() {
    if grep_is_function_context_line(lines[line_number - 1], header_pattern) {
      return Some(line_number)
    }
    line_number += 1
  }
  None
}

///|
fn grep_find_paragraph_start(lines : Array[String], line_number : Int) -> Int {
  let mut current = line_number
  while current > 1 {
    if trim_string(lines[current - 2]) == "" {
      break
    }
    current -= 1
  }
  current
}

///|
fn grep_find_paragraph_end(lines : Array[String], line_number : Int) -> Int {
  let mut current = line_number
  while current < lines.length() && trim_string(lines[current]) != "" {
    current += 1
  }
  grep_trim_blank_range_end(lines, current, line_number)
}

///|
fn grep_trim_blank_range_end(
  lines : Array[String],
  end_line : Int,
  minimum_line : Int,
) -> Int {
  let mut current = end_line
  while current > minimum_line && trim_string(lines[current - 1]) == "" {
    current -= 1
  }
  current
}

///|
fn grep_extend_header_to_leading_comments(
  lines : Array[String],
  header_line : Int,
) -> Int {
  let mut current = header_line
  while current > 1 {
    let prev = trim_string(lines[current - 2])
    if prev == "" || not(prev.has_prefix("#")) {
      break
    }
    current -= 1
  }
  current
}

///|
async fn grep_print_match_line(
  file_path : String,
  line_number : Int,
  column : Int,
  line : String,
  show_line_numbers : Bool,
  show_column : Bool,
  show_heading : Bool,
  sign : Char,
  expr : @bitgrep.GrepExpr,
  pattern_type : @bitgrep.GrepPatternType,
  ignore_case : Bool,
  word_regexp : Bool,
  color_spec : GrepColorSpec,
) -> Unit {
  let prefix = grep_build_prefix(
    file_path, line_number, column, show_line_numbers, show_column, show_heading,
    sign, color_spec,
  )
  let spans = @bitgrep.grep_collect_expr_match_spans(
    line,
    expr,
    pattern_type,
    ignore_case,
    word_regexp~,
  )
  let rendered = grep_colorize_line(
    line,
    spans,
    grep_line_color_for_sign(color_spec, sign),
    grep_match_color_for_sign(color_spec, sign),
  )
  print_line(prefix + rendered)
}

///|
async fn grep_print_context_line(
  file_path : String,
  line_number : Int,
  line : String,
  show_line_numbers : Bool,
  show_heading : Bool,
  sign : Char,
  color_spec : GrepColorSpec,
) -> Unit {
  let prefix = grep_build_prefix(
    file_path, line_number, 0, show_line_numbers, false, show_heading, sign, color_spec,
  )
  print_line(
    prefix + grep_color_wrap(line, grep_line_color_for_sign(color_spec, sign)),
  )
}

///|
async fn grep_print_only_matching(
  file_path : String,
  expr : @bitgrep.GrepExpr,
  file_match : @bitgrep.GrepFileMatch,
  pattern_type : @bitgrep.GrepPatternType,
  ignore_case : Bool,
  word_regexp : Bool,
  show_line_numbers : Bool,
  show_column : Bool,
  show_heading : Bool,
  color_spec : GrepColorSpec,
) -> Unit {
  for item in file_match.matches {
    let mut rest = item.line
    let mut column = item.column
    while rest != "" {
      let next = @bitgrep.grep_eval_expr(
        rest,
        expr,
        pattern_type,
        ignore_case,
        word_regexp~,
      )
      guard next.matched else { break }
      let span = match next.span {
        Some(value) => value
        None => break
      }
      if span.end_column < span.start_column {
        break
      }
      let matched = grep_extract_span(rest, span)
      let prefix = grep_build_prefix(
        file_path,
        item.line_number,
        column,
        show_line_numbers,
        show_column,
        show_heading,
        ':',
        color_spec,
      )
      print_line(prefix + grep_color_wrap(matched, color_spec.match_selected))
      column += span.end_column
      if span.end_column >= rest.length() {
        break
      }
      rest = String::unsafe_substring(
        rest,
        start=span.end_column,
        end=rest.length(),
      )
    }
  }
}

///|
fn grep_load_content_for_match(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  treeish : String?,
  cached : Bool,
  display_path : String,
) -> String raise Error {
  match treeish {
    Some(spec) =>
      grep_load_object_content(
        fs,
        git_dir,
        spec + ":" + grep_lookup_path(spec, display_path),
      )
    None =>
      if cached {
        grep_load_object_content(fs, git_dir, ":" + display_path)
      } else {
        @utf8.decode_lossy(fs.read_file(root + "/" + display_path)[:])
      }
  }
}

///|
fn grep_load_object_content(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> String raise Error {
  let oid = match @bitrepo.rev_parse(fs, git_dir, spec) {
    Some(value) => value
    None =>
      raise @bitcore.GitError::InvalidObject(
        "fatal: ambiguous argument '" + spec + "': unknown revision or path",
      )
  }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let obj = match db.get(fs, oid) {
    Some(value) => value
    None =>
      raise @bitcore.GitError::InvalidObject(
        "fatal: bad object " + oid.to_hex(),
      )
  }
  @utf8.decode_lossy(obj.data[:])
}

///|
fn grep_lookup_path(spec : String, display_path : String) -> String {
  let prefix = spec + ":"
  if display_path.has_prefix(prefix) {
    String::unsafe_substring(
      display_path,
      start=prefix.length(),
      end=display_path.length(),
    )
  } else {
    display_path
  }
}

///|
async fn grep_print_path_atom(path : String, null_terminated : Bool) -> Unit {
  if null_terminated {
    print_str(path + "\u0000")
  } else {
    print_line(path)
  }
}

///|
fn grep_format_output_path(
  root : String,
  treeish : String?,
  file_path : String,
  show_full_name : Bool,
  null_terminated : Bool,
) -> String {
  match treeish {
    Some(spec) => {
      let repo_path = grep_lookup_path(spec, file_path)
      let shown_path = if show_full_name {
        repo_path
      } else {
        grep_make_path_relative_to_invocation(root, repo_path)
      }
      let formatted_path = if null_terminated {
        shown_path
      } else {
        quote_origin_path(shown_path)
      }
      spec + ":" + formatted_path
    }
    None => {
      let shown_path = if show_full_name {
        file_path
      } else {
        grep_make_path_relative_to_invocation(root, file_path)
      }
      if null_terminated {
        shown_path
      } else {
        quote_origin_path(shown_path)
      }
    }
  }
}

///|
fn grep_format_output_path_raw(
  root : String,
  treeish : String?,
  file_path : String,
  show_full_name : Bool,
) -> String {
  match treeish {
    Some(spec) => {
      let repo_path = grep_lookup_path(spec, file_path)
      let shown_path = if show_full_name {
        repo_path
      } else {
        grep_make_path_relative_to_invocation(root, repo_path)
      }
      spec + ":" + shown_path
    }
    None =>
      if show_full_name {
        file_path
      } else {
        grep_make_path_relative_to_invocation(root, file_path)
      }
  }
}

///|
fn grep_resolve_input_paths(
  root : String,
  paths : Array[String],
) -> Array[String] {
  if paths.length() == 0 {
    return match grep_invocation_repo_relative_path(root) {
      Some(prefix) if prefix != "" => [prefix]
      _ => []
    }
  }
  let resolved : Array[String] = []
  for path in paths {
    resolved.push(grep_resolve_input_path(root, path))
  }
  resolved
}

///|
async fn grep_resolve_no_index_paths(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  paths : Array[String],
) -> Array[String] raise Error {
  let normalized_root = normalize_path(root)
  let resolved : Array[String] = []
  for raw_path in paths {
    let abs_path = if raw_path.has_prefix("/") {
      normalize_path(raw_path)
    } else {
      normalize_path(root + "/" + raw_path)
    }
    let exists = fs.is_file(abs_path) || fs.is_dir(abs_path)
    if not(exists) {
      eprint_line("fatal: no such path in the working tree: '" + raw_path + "'")
      @sys.exit(128)
    }
    if not(grep_path_is_within_root(normalized_root, abs_path)) {
      eprint_line("fatal: '" + raw_path + "' is outside the directory tree")
      @sys.exit(128)
    }
    if abs_path == normalized_root {
      resolved.push(".")
    } else {
      resolved.push(
        String::unsafe_substring(
          abs_path,
          start=normalized_root.length() + 1,
          end=abs_path.length(),
        ),
      )
    }
  }
  resolved
}

///|
fn grep_path_is_within_root(root : String, path : String) -> Bool {
  path == root || path.has_prefix(root + "/")
}

///|
fn grep_merge_file_matches(
  primary : Array[@bitgrep.GrepFileMatch],
  secondary : Array[@bitgrep.GrepFileMatch],
) -> Array[@bitgrep.GrepFileMatch] {
  let merged : Array[@bitgrep.GrepFileMatch] = []
  let seen : Map[String, Bool] = {}
  for item in primary {
    merged.push(item)
    seen[item.path] = true
  }
  for item in secondary {
    if seen.contains(item.path) {
      continue
    }
    merged.push(item)
  }
  merged.sort_by((a, b) => String::lexical_compare(a.path, b.path))
  merged
}

///|
fn grep_merge_candidate_paths(
  primary : Array[String],
  secondary : Array[String],
) -> Array[String] {
  let merged : Array[String] = []
  let seen : Map[String, Bool] = {}
  for path in primary {
    merged.push(path)
    seen[path] = true
  }
  for path in secondary {
    if seen.contains(path) {
      continue
    }
    merged.push(path)
  }
  merged.sort_by((a, b) => String::lexical_compare(a, b))
  merged
}

///|
fn grep_resolve_input_path(root : String, path : String) -> String {
  if path.has_prefix("/") {
    return path
  }
  match grep_invocation_repo_relative_path(root) {
    Some(prefix) =>
      if prefix == "" {
        path
      } else {
        grep_resolve_repo_relative_path(prefix, path)
      }
    None => path
  }
}

///|
fn grep_make_path_relative_to_invocation(
  root : String,
  path : String,
) -> String {
  match grep_invocation_repo_relative_path(root) {
    Some(prefix) =>
      if prefix == "" {
        path
      } else {
        grep_relative_repo_path(prefix, path)
      }
    None => path
  }
}

///|
fn grep_invocation_repo_relative_path(root : String) -> String? {
  let cwd = grep_get_invocation_cwd(root)
  let normalized_root = normalize_path(root)
  let normalized_cwd = normalize_path(cwd)
  if normalized_cwd == normalized_root {
    return Some("")
  }
  let root_prefix = normalized_root + "/"
  if not(normalized_cwd.has_prefix(root_prefix)) {
    return None
  }
  Some(
    String::unsafe_substring(
      normalized_cwd,
      start=root_prefix.length(),
      end=normalized_cwd.length(),
    ),
  )
}

///|
fn grep_resolve_repo_relative_path(base : String, path : String) -> String {
  let parts = grep_split_path_segments(base)
  for segment in grep_split_path_segments(path) {
    match segment {
      "." => ()
      ".." => if parts.length() > 0 { ignore(parts.pop()) }
      _ => parts.push(segment)
    }
  }
  grep_join_path_segments(parts)
}

///|
fn grep_relative_repo_path(base : String, path : String) -> String {
  let base_parts = grep_split_path_segments(base)
  let path_parts = grep_split_path_segments(path)
  let mut common = 0
  while common < base_parts.length() &&
        common < path_parts.length() &&
        base_parts[common] == path_parts[common] {
    common += 1
  }
  let out : Array[String] = []
  for _ in common..<base_parts.length() {
    out.push("..")
  }
  for i in common..<path_parts.length() {
    out.push(path_parts[i])
  }
  if out.length() == 0 {
    "."
  } else {
    grep_join_path_segments(out)
  }
}

///|
fn grep_split_path_segments(path : String) -> Array[String] {
  let out : Array[String] = []
  for segment_view in path.split("/") {
    let segment = segment_view.to_string()
    if segment == "" {
      continue
    }
    out.push(segment)
  }
  out
}

///|
fn grep_join_path_segments(parts : Array[String]) -> String {
  let out = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      out.write_char('/')
    }
    out.write_string(parts[i])
  }
  out.to_string()
}

///|
fn grep_split_content_lines(content : String) -> Array[String] {
  let lines : Array[String] = []
  for line_view in content.split("\n") {
    lines.push(line_view.to_string())
  }
  if content.has_suffix("\n") &&
    lines.length() > 0 &&
    lines[lines.length() - 1] == "" {
    ignore(lines.pop())
  }
  lines
}

///|
fn grep_extract_span(line : String, span : @bitgrep.GrepMatchSpan) -> String {
  String::unsafe_substring(
    line,
    start=span.start_column - 1,
    end=span.end_column,
  )
}

///|
