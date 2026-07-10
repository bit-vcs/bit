///| Pack handlers: rev-list, verify-pack, unpack-objects, bundle

///|
fn rev_list_config_get(
  git_dir : String,
  dotted_key : String,
  section : String,
  key : String,
) -> String? {
  match get_config_override(dotted_key) {
    Some(value) => {
      let trimmed = trim_string(value)
      if trimmed.length() > 0 {
        Some(trimmed)
      } else {
        None
      }
    }
    None => bit_config_get(git_dir, section, key)
  }
}

///|
fn rev_list_resolve_output_encoding(git_dir : String) -> String {
  match
    rev_list_config_get(
      git_dir, "i18n.logOutputEncoding", "i18n", "logOutputEncoding",
    ) {
    Some(value) => value
    None =>
      rev_list_config_get(
        git_dir, "i18n.commitEncoding", "i18n", "commitEncoding",
      ).unwrap_or("UTF-8")
  }
}

///|
async fn rev_list_write_text(
  text : String,
  output_encoding : String,
) -> Unit raise Error {
  let encoded = reset_convert_encoding(
    @utf8.encode(text),
    "UTF-8",
    output_encoding,
  )
  @stdio.stdout.write(encoded)
}

///|
async fn handle_rev_list(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  check_commit_graph_paranoia(fs, git_dir)
  let mut max_count : Int? = None
  let mut max_count_oldest : Int? = None
  let mut skip_count = 0
  let mut count_only = false
  let mut objects = false
  let mut indexed_objects = false
  let mut indexed_objects_negated = false
  let mut quiet = false
  let mut reverse = false
  let mut first_parent = false
  let mut all = false
  let mut stdin = false
  let mut test_bitmap = false
  let mut use_bitmap = false
  let mut no_object_names = false
  let mut format : String? = None
  let mut pretty_color_cli_mode : String? = None
  let mut topo_order = false
  let mut author_date_order = false
  let date_order = false
  let mut parents = false
  let mut header = false
  let mut use_nul = false
  let mut boundary = false
  let mut left_right = false
  let mut left_only = false
  let mut right_only = false
  let mut cherry_pick = false
  let mut cherry_mark = false
  let mut max_parents : Int? = None
  let mut min_parents : Int? = None
  let mut graph = false
  let mut no_walk = false
  let mut maximal_only = false
  let refs : Array[String] = []
  let excludes : Array[String] = []
  let symmetric_ranges : Array[(String, String)] = []
  let rev_list_exclude_patterns : Array[String] = []
  let mut had_ref_source = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-n" | "--max-count" if i + 1 < args.length() => {
        max_count = Some(rev_list_parse_int_or_die(args[i + 1]))
        i += 2
        continue
      }
      "--max-count-oldest" if i + 1 < args.length() => {
        max_count_oldest = Some(rev_list_parse_int_or_die(args[i + 1]))
        i += 2
        continue
      }
      "--count" => count_only = true
      "--objects" | "--objects-edge" => objects = true
      "--indexed-objects" => indexed_objects = true
      "--quiet" | "-q" => quiet = true
      "--reverse" => reverse = true
      "--ancestry-path" => () // Ignored for now
      "--topo-order" => topo_order = true
      "--author-date-order" => author_date_order = true
      "--date-order" => ignore(date_order) // date order is now default
      "--parents" => parents = true
      "--header" => header = true
      "-z" => use_nul = true
      "--boundary" => boundary = true
      "--left-right" => left_right = true
      "--left-only" => left_only = true
      "--right-only" => right_only = true
      "--cherry-pick" => cherry_pick = true
      "--cherry-mark" => cherry_mark = true
      "--cherry" => {
        cherry_mark = true
        right_only = true
        max_parents = Some(1)
      }
      "--no-walk" | "--no-walk=sorted" | "--no-walk=unsorted" => no_walk = true
      "--do-walk" => no_walk = false
      "--maximal-only" => maximal_only = true
      "--merges" => min_parents = Some(2)
      "--no-merges" => max_parents = Some(1)
      "--min-parents" if i + 1 < args.length() => {
        min_parents = Some(rev_list_parse_int_or_die(args[i + 1]))
        i += 2
        continue
      }
      "--max-parents" if i + 1 < args.length() => {
        max_parents = Some(rev_list_parse_int_or_die(args[i + 1]))
        i += 2
        continue
      }
      _ if arg.has_prefix("--min-parents=") =>
        min_parents = Some(
          rev_list_parse_int_or_die(
            String::unsafe_substring(arg, start=14, end=arg.length()),
          ),
        )
      _ if arg.has_prefix("--max-parents=") =>
        max_parents = Some(
          rev_list_parse_int_or_die(
            String::unsafe_substring(arg, start=14, end=arg.length()),
          ),
        )
      "--graph" => graph = true
      "--no-min-parents" => min_parents = None
      "--no-max-parents" => max_parents = None
      // Negative values for min/max-parents mean "no limit" (infinity)
      // This is handled after parsing by converting negative to None
      "--first-parent" => first_parent = true
      "--all" => all = true
      "--branches" => {
        had_ref_source = true
        rev_list_add_typed_refs(
          fs, git_dir, "refs/heads/", "", rev_list_exclude_patterns, refs,
        )
      }
      "--tags" => {
        had_ref_source = true
        rev_list_add_typed_refs(
          fs, git_dir, "refs/tags/", "", rev_list_exclude_patterns, refs,
        )
      }
      "--remotes" => {
        had_ref_source = true
        rev_list_add_typed_refs(
          fs, git_dir, "refs/remotes/", "", rev_list_exclude_patterns, refs,
        )
      }
      _ if arg.has_prefix("--branches=") => {
        had_ref_source = true
        rev_list_add_typed_refs(
          fs,
          git_dir,
          "refs/heads/",
          String::unsafe_substring(arg, start=11, end=arg.length()),
          rev_list_exclude_patterns,
          refs,
        )
      }
      _ if arg.has_prefix("--tags=") => {
        had_ref_source = true
        rev_list_add_typed_refs(
          fs,
          git_dir,
          "refs/tags/",
          String::unsafe_substring(arg, start=7, end=arg.length()),
          rev_list_exclude_patterns,
          refs,
        )
      }
      _ if arg.has_prefix("--remotes=") => {
        had_ref_source = true
        rev_list_add_typed_refs(
          fs,
          git_dir,
          "refs/remotes/",
          String::unsafe_substring(arg, start=10, end=arg.length()),
          rev_list_exclude_patterns,
          refs,
        )
      }
      _ if arg.has_prefix("--exclude=") => {
        let pattern = String::unsafe_substring(arg, start=10, end=arg.length())
        rev_list_exclude_patterns.push(pattern)
      }
      _ if arg.has_prefix("--glob=") => {
        had_ref_source = true
        let pattern = String::unsafe_substring(arg, start=7, end=arg.length())
        rev_list_add_glob_refs(fs, git_dir, pattern, refs)
      }
      "--glob" if i + 1 < args.length() => {
        had_ref_source = true
        rev_list_add_glob_refs(fs, git_dir, args[i + 1], refs)
        i += 2
        continue
      }
      "--glob" => {
        eprint_line("fatal: Option '--glob' requires a value")
        @sys.exit(128)
      }
      "--stdin" => stdin = true
      "--test-bitmap" => test_bitmap = true
      "--use-bitmap-index" => use_bitmap = true
      "--no-use-bitmap-index" | "--ignore-missing" | "--in-commit-order" => ()
      "--no-object-names" => no_object_names = true
      "--object-names" => no_object_names = false
      "--color" | "--color=always" => pretty_color_cli_mode = Some("always")
      "--color=auto" => pretty_color_cli_mode = Some("auto")
      "--no-color" | "--color=never" => pretty_color_cli_mode = Some("never")
      _ if arg.has_prefix("--format=") =>
        format = Some(String::unsafe_substring(arg, start=9, end=arg.length()))
      "--skip" if i + 1 < args.length() => {
        skip_count = rev_list_parse_int_or_die(args[i + 1])
        i += 2
        continue
      }
      "--skip" => {
        eprint_line("fatal: option '--skip' requires a value")
        @sys.exit(128)
      }
      "--not" => {
        // Next refs are excludes until another --not
        i += 1
        while i < args.length() {
          let next = args[i]
          if next == "--not" {
            break
          }
          if next == "--indexed-objects" {
            indexed_objects = true
            indexed_objects_negated = true
          } else if next == "--branches" {
            let branch_refs = @bitrepo.show_ref(fs, git_dir) catch { _ => [] }
            for item in branch_refs {
              if item.0.has_prefix("refs/heads/") {
                excludes.push(item.0)
              }
            }
          } else if next == "--tags" {
            let tag_refs = @bitrepo.show_ref(fs, git_dir) catch { _ => [] }
            for item in tag_refs {
              if item.0.has_prefix("refs/tags/") {
                excludes.push(item.0)
              }
            }
          } else if next == "--remotes" {
            let remote_refs = @bitrepo.show_ref(fs, git_dir) catch { _ => [] }
            for item in remote_refs {
              if item.0.has_prefix("refs/remotes/") {
                excludes.push(item.0)
              }
            }
          } else if next.has_prefix("--glob=") {
            let pattern = String::unsafe_substring(
              next,
              start=7,
              end=next.length(),
            )
            rev_list_add_glob_refs(fs, git_dir, pattern, excludes)
          } else if !next.has_prefix("-") {
            excludes.push(next)
          }
          i += 1
        }
        continue
      }
      _ if arg.has_prefix("--max-count=") => {
        let val = String::unsafe_substring(arg, start=12, end=arg.length())
        max_count = Some(rev_list_parse_int_or_die(val))
      }
      _ if arg.has_prefix("--max-count-oldest=") => {
        let val = String::unsafe_substring(arg, start=19, end=arg.length())
        max_count_oldest = Some(rev_list_parse_int_or_die(val))
      }
      _ if arg.has_prefix("--skip=") => {
        let val = String::unsafe_substring(arg, start=7, end=arg.length())
        skip_count = rev_list_parse_int_or_die(val)
      }
      _ if arg.has_prefix("-n") && arg.length() > 2 => {
        let val = String::unsafe_substring(arg, start=2, end=arg.length())
        max_count = Some(rev_list_parse_int_or_die(val))
      }
      _ if rev_list_is_short_max_count_arg(arg) => {
        let val = String::unsafe_substring(arg, start=1, end=arg.length())
        max_count = Some(rev_list_parse_int_or_die(val))
      }
      _ if rev_list_is_long_numeric_option(arg) => {
        eprint_line("fatal: unrecognized argument: " + arg)
        @sys.exit(128)
      }
      _ if arg.has_prefix("^") =>
        excludes.push(String::unsafe_substring(arg, start=1, end=arg.length()))
      _ if !arg.has_prefix("-") && arg.contains("..") => {
        // Handle A..B (equivalent to ^A B) and A...B (symmetric difference)
        let dot_pos = rev_list_find_range_dots(arg)
        match dot_pos {
          Some((pos, is_symmetric)) => {
            let left = String::unsafe_substring(arg, start=0, end=pos)
            let right_start = if is_symmetric { pos + 3 } else { pos + 2 }
            let right = String::unsafe_substring(
              arg,
              start=right_start,
              end=arg.length(),
            )
            let left_ref = if left.length() == 0 { "HEAD" } else { left }
            let right_ref = if right.length() == 0 { "HEAD" } else { right }
            if is_symmetric {
              // A...B = A B ^merge-base(A,B)
              refs.push(left_ref)
              refs.push(right_ref)
              symmetric_ranges.push((left_ref, right_ref))
              // merge-base exclusion will be computed after resolution
            } else {
              // A..B = ^A B
              excludes.push(left_ref)
              refs.push(right_ref)
            }
          }
          None => refs.push(arg)
        }
      }
      _ if !arg.has_prefix("-") =>
        // Handle ^@, ^!, ^-N parent suffixes
        if arg.has_suffix("^@") {
          // commit^@ = all parents of commit
          let base = String::unsafe_substring(
            arg,
            start=0,
            end=arg.length() - 2,
          )
          refs.push(base + "^@")
        } else if arg.has_suffix("^!") {
          // commit^! = commit ^commit^1 ^commit^2 ...
          let base = String::unsafe_substring(
            arg,
            start=0,
            end=arg.length() - 2,
          )
          refs.push(base + "^!")
        } else if arg.contains("^-") {
          // commit^-N = commit^N..commit (parent exclusion range)
          let caret_pos = arg.rev_find("^-")
          match caret_pos {
            Some(pos) => {
              let base = String::unsafe_substring(arg, start=0, end=pos)
              let suffix = String::unsafe_substring(
                arg,
                start=pos + 2,
                end=arg.length(),
              )
              if suffix.length() == 0 {
                // ^- means ^-1 (first parent)
                excludes.push(base + "^1")
                refs.push(base)
              } else {
                let n = @string.parse_int(suffix) catch { _ => -1 }
                if n > 0 {
                  excludes.push(base + "^" + n.to_string())
                  refs.push(base)
                } else {
                  // Invalid: garbage after ^-
                  eprint_line("fatal: invalid parent exclusion: '\{arg}'")
                  @sys.exit(128)
                }
              }
            }
            None => refs.push(arg)
          }
        } else {
          refs.push(arg)
        }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("rev-list", arg)
      _ => ()
    }
    i += 1
  }
  // Read from stdin if requested
  if stdin {
    let input = decode_bytes(read_all_stdin())
    let mut stdin_not_mode = false
    let mut stdin_end_of_options = false
    for line_view in input.split("\n") {
      let line = trim_string(line_view.to_owned())
      if line.length() == 0 || line.has_prefix("#") {
        continue
      }
      // After --end-of-options, treat everything as a ref
      if stdin_end_of_options {
        if stdin_not_mode {
          excludes.push(line)
        } else {
          refs.push(line)
        }
        continue
      }
      if line == "--not" {
        stdin_not_mode = !stdin_not_mode
      } else if line == "--all" {
        all = true
      } else if line == "--branches" {
        let branch_refs = @bitrepo.show_ref(fs, git_dir) catch { _ => [] }
        for item in branch_refs {
          if item.0.has_prefix("refs/heads/") {
            if stdin_not_mode {
              excludes.push(item.0)
            } else {
              refs.push(item.0)
            }
          }
        }
      } else if line == "--tags" {
        let tag_refs = @bitrepo.show_ref(fs, git_dir) catch { _ => [] }
        for item in tag_refs {
          if item.0.has_prefix("refs/tags/") {
            if stdin_not_mode {
              excludes.push(item.0)
            } else {
              refs.push(item.0)
            }
          }
        }
      } else if line == "--remotes" {
        let remote_refs = @bitrepo.show_ref(fs, git_dir) catch { _ => [] }
        for item in remote_refs {
          if item.0.has_prefix("refs/remotes/") {
            if stdin_not_mode {
              excludes.push(item.0)
            } else {
              refs.push(item.0)
            }
          }
        }
      } else if line.has_prefix("--glob=") {
        let pattern = String::unsafe_substring(line, start=7, end=line.length())
        if stdin_not_mode {
          rev_list_add_glob_refs(fs, git_dir, pattern, excludes)
        } else {
          rev_list_add_glob_refs(fs, git_dir, pattern, refs)
        }
      } else if line == "--glob" {
        eprint_line("fatal: Option '--glob' requires a value")
        @sys.exit(128)
      } else if line.has_prefix("--no-walk=") {
        let val = String::unsafe_substring(line, start=10, end=line.length())
        if val != "sorted" && val != "unsorted" {
          eprint_line("error: invalid argument to --no-walk")
          eprint_line("fatal: invalid option '\{line}' in --stdin mode")
          @sys.exit(128)
        }
      } else if line == "--end-of-options" {
        stdin_end_of_options = true
      } else if line == "--" {
        () // pathspec separator, ignore
      } else if line.has_prefix("-") && !line.has_prefix("^") {
        // Unknown option in stdin mode
        eprint_line("fatal: invalid option '\{line}' in --stdin mode")
        @sys.exit(128)
      } else if line.has_prefix("^") {
        excludes.push(
          String::unsafe_substring(line, start=1, end=line.length()),
        )
      } else if stdin_not_mode {
        excludes.push(line)
      } else {
        refs.push(line)
      }
    }
  }
  // --graph --no-walk is forbidden
  if graph && no_walk {
    eprint_line(
      "fatal: options '--graph' and '--no-walk' cannot be used together",
    )
    @sys.exit(1)
  }
  // If --all, add all refs including detached HEAD
  if all {
    let all_refs = @bitrepo.show_ref(fs, git_dir)
    for item in all_refs {
      let (name, _) = item
      if !rev_list_ref_excluded(name, rev_list_exclude_patterns) {
        refs.push(name)
      }
    }
    // For detached HEAD: only add if HEAD doesn't point to a branch
    // and no exclude patterns are active (git --all doesn't include HEAD separately)
    if rev_list_exclude_patterns.length() == 0 {
      let head_ref = @bitlib.read_head_ref(fs, git_dir)
      match head_ref {
        @bitlib.HeadRef::Detached(_) => refs.push("HEAD")
        _ => ()
      }
    }
  }
  // Note: --exclude patterns are applied at the point of ref addition
  // (--all, --branches, --tags, --remotes, --glob) so no post-filter needed
  // If no refs specified and no explicit ref source was given, default to HEAD
  if refs.length() == 0 &&
    excludes.length() == 0 &&
    !indexed_objects &&
    !stdin &&
    !all &&
    !had_ref_source &&
    rev_list_exclude_patterns.length() == 0 {
    refs.push("HEAD")
  }
  ignore(graph)
  ignore(no_walk)
  // Handle --test-bitmap
  if test_bitmap {
    rev_list_test_bitmap(fs, git_dir)
    return
  }
  // Resolve starting commits (deduplicate)
  let start_ids : Array[@bitcore.ObjectId] = []
  let start_seen : Map[String, Bool] = {}
  for spec in refs {
    match @bitrepo.rev_parse(fs, git_dir, spec) {
      Some(id) => {
        let hex = id.to_hex()
        if id != @bitcore.ObjectId::zero() && !start_seen.contains(hex) {
          start_seen[hex] = true
          start_ids.push(id)
        }
      }
      None => ()
    }
  }
  // Resolve exclude commits
  let exclude_ids : Map[String, Bool] = {}
  for spec in excludes {
    match @bitrepo.rev_parse(fs, git_dir, spec) {
      Some(id) =>
        // Walk the exclude commit and all its ancestors
        walk_commits_to_map(fs, git_dir, id, exclude_ids)
      None => ()
    }
  }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  for pair in symmetric_ranges {
    match
      (
        @bitrepo.rev_parse(fs, git_dir, pair.0),
        @bitrepo.rev_parse(fs, git_dir, pair.1),
      ) {
      (Some(left_id), Some(right_id)) => {
        let left_commit = rev_list_peel_to_commit(db, fs, left_id).unwrap_or(
          left_id,
        )
        let right_commit = rev_list_peel_to_commit(db, fs, right_id).unwrap_or(
          right_id,
        )
        let bases = @bitlib.merge_base_all(db, fs, left_commit, right_commit)
        for base in bases {
          walk_commits_to_map(fs, git_dir, base, exclude_ids)
        }
      }
      _ => ()
    }
  }
  let left_right_markers = if (
      left_right || left_only || right_only || cherry_pick || cherry_mark
    ) &&
    symmetric_ranges.length() > 0 {
    rev_list_build_left_right_markers(fs, git_dir, db, symmetric_ranges)
  } else {
    {}
  }
  let visited : Map[String, Bool] = {}
  let result : Array[@bitcore.ObjectId] = []
  // BFS/DFS traversal — collect ALL reachable commits, then sort/slice
  let queue : Array[@bitcore.ObjectId] = []
  for id in start_ids {
    queue.push(id)
  }
  while queue.length() > 0 {
    let id = queue.unsafe_pop()
    let hex = id.to_hex()
    if visited.contains(hex) || exclude_ids.contains(hex) {
      continue
    }
    visited[hex] = true
    result.push(id)
    // Get commit and add parents
    match rev_list_load_commit_info(db, fs, id) {
      Some(info) =>
        if first_parent && info.parents.length() > 0 {
          if !visited.contains(info.parents[0].to_hex()) {
            queue.push(info.parents[0])
          }
        } else {
          for parent in info.parents {
            if !visited.contains(parent.to_hex()) {
              queue.push(parent)
            }
          }
        }
      _ => ()
    }
  }
  // Negative values mean infinity (no limit)
  match min_parents {
    Some(v) => if v < 0 { min_parents = None }
    None => ()
  }
  match max_parents {
    Some(v) => if v < 0 { max_parents = None }
    None => ()
  }
  // Apply parent count filter (--merges, --no-merges, --min/max-parents)
  if min_parents is Some(_) || max_parents is Some(_) {
    let filtered : Array[@bitcore.ObjectId] = []
    for id in result {
      let parent_count = rev_list_commit_parent_count(db, fs, id)
      let min_ok = match min_parents {
        Some(min) => parent_count >= min
        None => true
      }
      let max_ok = match max_parents {
        Some(max) => parent_count <= max
        None => true
      }
      if min_ok && max_ok {
        filtered.push(id)
      }
    }
    result.clear()
    for id in filtered {
      result.push(id)
    }
  }
  let cherry_equal = if cherry_pick || cherry_mark {
    rev_list_build_cherry_equal(db, fs, git_dir, result, left_right_markers)
  } else {
    {}
  }
  if left_only || right_only || cherry_pick {
    let filtered : Array[@bitcore.ObjectId] = []
    for id in result {
      let hex = id.to_hex()
      let marker = left_right_markers.get(hex).unwrap_or("")
      let side_ok = if symmetric_ranges.length() == 0 {
        true
      } else if left_only && right_only {
        false
      } else if left_only {
        marker == "<"
      } else if right_only {
        marker == ">"
      } else {
        true
      }
      let cherry_ok = !(cherry_pick && cherry_equal.contains(hex))
      if side_ok && cherry_ok {
        filtered.push(id)
      }
    }
    result.clear()
    for id in filtered {
      result.push(id)
    }
  }
  // --maximal-only: keep only commits not reachable from any other in result
  if maximal_only {
    let result_ids = result.copy()
    let filtered : Array[@bitcore.ObjectId] = []
    for i2 in 0..<result_ids.length() {
      let candidate = result_ids[i2]
      let mut dominated = false
      for j in 0..<result_ids.length() {
        if i2 == j {
          continue
        }
        if @bitlib.merge_base_is_ancestor(db, fs, candidate, result_ids[j]) {
          dominated = true
          break
        }
      }
      if !dominated {
        filtered.push(candidate)
      }
    }
    result.clear()
    for id in filtered {
      result.push(id)
    }
  }
  // Apply ordering. git defaults to date order (committer timestamp desc).
  if topo_order {
    rev_list_topo_sort(db, fs, result)
  } else if author_date_order {
    rev_list_topo_sort_author_date(db, fs, result)
  } else {
    // Default: date order (same as git's default chronological ordering)
    rev_list_date_sort(db, fs, result)
  }
  // --max-count-oldest=<n>: keep only the N oldest commits. `result` is
  // newest-first here, so the oldest N are its tail; preserve their
  // newest-first relative order, matching git's output order before
  // --reverse is applied.
  match max_count_oldest {
    Some(n) => {
      let keep = if n < 0 { 0 } else { n }
      if result.length() > keep {
        let start = result.length() - keep
        let tail : Array[@bitcore.ObjectId] = []
        for idx in start..<result.length() {
          tail.push(result[idx])
        }
        result.clear()
        for id in tail {
          result.push(id)
        }
      }
    }
    None => ()
  }
  if reverse {
    result.rev_in_place()
  }
  let result_window = rev_list_window(result.length(), skip_count, max_count)
  let sliced_result : Array[@bitcore.ObjectId] = []
  let mut result_idx = result_window.0
  while result_idx < result_window.1 {
    sliced_result.push(result[result_idx])
    result_idx += 1
  }
  let object_ids : Array[(@bitcore.ObjectId, String)] = []
  let indexed_path_ids : Map[String, String] = {}
  if objects {
    let object_seen : Map[String, Bool] = {}
    let indexed_visible_objects = if indexed_objects {
      let index_entries = @bitlib.read_index_entries(fs, git_dir) catch {
        _ => []
      }
      let result = rev_list_collect_index_objects(
        db, fs, git_dir, index_entries,
      )
      for path, id in result.1 {
        indexed_path_ids[path] = id
      }
      result.0
    } else {
      []
    }
    for id in sliced_result {
      object_ids.push((id, ""))
      match rev_list_commit_tree(db, fs, id) {
        Some(tree) =>
          if indexed_objects_negated {
            collect_tree_objects_excluding_index(
              db, fs, tree, object_ids, object_seen, indexed_path_ids,
            )
          } else {
            collect_tree_objects(db, fs, tree, object_ids, object_seen)
          }
        None => ()
      }
    }
    if indexed_objects && !indexed_objects_negated {
      for item in indexed_visible_objects {
        let hex = item.0.to_hex()
        if !object_seen.contains(hex) {
          object_seen[hex] = true
          object_ids.push(item)
        }
      }
    }
  }
  // Output
  if count_only {
    if objects {
      // --count --objects: count all objects including trees/blobs
      print_line((sliced_result.length() + object_ids.length()).to_string())
    } else {
      print_line(sliced_result.length().to_string())
    }
    return
  }
  if quiet {
    return
  }
  // Output commits
  match format {
    Some(raw_fmt) => {
      // Parse tformat:/format: prefix
      let (fmt, use_newline_sep) = if raw_fmt.has_prefix("tformat:") {
        (String::unsafe_substring(raw_fmt, start=8, end=raw_fmt.length()), true)
      } else if raw_fmt.has_prefix("format:") {
        (
          String::unsafe_substring(raw_fmt, start=7, end=raw_fmt.length()),
          false,
        )
      } else {
        (raw_fmt, true)
      }
      let pretty_color_enabled = if fmt.contains("%C") {
        log_resolve_pretty_color_enabled(
          git_dir,
          pretty_color_cli_mode,
          log_stdout_is_tty(),
        )
      } else {
        false
      }
      let ref_names : Map[String, Array[String]] = {}
      let output_encoding = rev_list_resolve_output_encoding(git_dir)
      for idx, id in sliced_result {
        let prefix = rev_list_output_prefix(
          id.to_hex(),
          left_right,
          cherry_mark,
          cherry_equal,
          left_right_markers,
        )
        // Print commit header line
        rev_list_write_text(
          "commit " + prefix + id.to_hex() + "\n",
          output_encoding,
        )
        // Read commit data and format
        match db.get(fs, id) {
          Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit => {
            let info = @bitcore.parse_commit(obj.data)
            let fdata = parse_commit_format_data(
              id,
              obj.data,
              info.tree,
              info.parents,
              ref_names,
              pretty_color_enabled~,
            )
            let formatted = format_commit_string(fmt, fdata)
            rev_list_write_text(formatted, output_encoding)
            if use_newline_sep {
              rev_list_write_text("\n", output_encoding)
            } else if idx < sliced_result.length() - 1 {
              rev_list_write_text("\n", output_encoding)
            }
          }
          _ => ()
        }
      }
    }
    None =>
      for id in sliced_result {
        let buf = StringBuilder::new()
        let hex = id.to_hex()
        buf.write_string(
          rev_list_output_prefix(
            hex, left_right, cherry_mark, cherry_equal, left_right_markers,
          ),
        )
        buf.write_string(hex)
        if parents {
          match rev_list_commit_parents(db, fs, id) {
            Some(parent_ids) =>
              for p in parent_ids {
                buf.write_string(" ")
                buf.write_string(p.to_hex())
              }
            None => ()
          }
        }
        if header {
          // --header: append NUL after commit line, then raw commit content
          @stdio.stdout.write(@utf8.encode(buf.to_string()))
          @stdio.stdout.write(b"\x00")
          match db.get(fs, id) {
            Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit =>
              @stdio.stdout.write(obj.data)
            _ => ()
          }
          @stdio.stdout.write(b"\x00")
        } else if use_nul {
          @stdio.stdout.write(@utf8.encode(buf.to_string()))
          @stdio.stdout.write(b"\x00")
        } else {
          print_line(buf.to_string())
        }
      }
  }
  // Output objects (trees, blobs) if --objects
  if objects {
    let commit_set : Map[String, Bool] = {}
    for r in sliced_result {
      commit_set[r.to_hex()] = true
    }
    for item in object_ids {
      let (id, path) = item
      let hex = id.to_hex()
      if !commit_set.contains(hex) {
        let line = if no_object_names || use_bitmap || path.length() == 0 {
          hex
        } else {
          hex + " " + path
        }
        if use_nul {
          @stdio.stdout.write(@utf8.encode(line))
          @stdio.stdout.write(b"\x00")
        } else {
          print_line(line)
        }
      }
    }
  }
  ignore(boundary)
}

///|
fn rev_list_peel_to_commit(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  id : @bitcore.ObjectId,
) -> @bitcore.ObjectId? {
  let mut current = id
  for _ in 0..<5 {
    let obj = db.get(fs, current) catch { _ => return None }
    guard obj is Some(o) else { return None }
    match o.obj_type {
      @bitcore.ObjectType::Commit => return Some(current)
      @bitcore.ObjectType::Tag =>
        match parse_tag_target(o.data) {
          Some(next) => current = next
          None => return None
        }
      _ => return None
    }
  }
  None
}

///|
fn rev_list_load_commit_info(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> @bitlib.CommitGraphCommitInfo? {
  match db.get_commit_graph_commit(id) {
    Some(info) => return Some(info)
    None => ()
  }
  let obj = db.get(fs, id) catch { _ => return None }
  match obj {
    Some(o) if o.obj_type == @bitcore.ObjectType::Commit => {
      let info = @bitcore.parse_commit(o.data) catch { _ => return None }
      Some({
        tree: info.tree,
        parents: info.parents,
        committer_timestamp: @tar.tar_parse_committer_timestamp(o.data),
      })
    }
    _ => None
  }
}

///|
fn rev_list_commit_parents(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> Array[@bitcore.ObjectId]? {
  match rev_list_load_commit_info(db, fs, id) {
    Some(info) => Some(info.parents)
    None => None
  }
}

///|
fn rev_list_commit_tree(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> @bitcore.ObjectId? {
  match rev_list_load_commit_info(db, fs, id) {
    Some(info) => Some(info.tree)
    None => None
  }
}

///|
fn rev_list_commit_parent_count(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> Int {
  match rev_list_load_commit_info(db, fs, id) {
    Some(info) => info.parents.length()
    None => 0
  }
}

///|
fn rev_list_commit_committer_timestamp(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> Int64 {
  match rev_list_load_commit_info(db, fs, id) {
    Some(info) => info.committer_timestamp
    None => 0L
  }
}

///|
fn rev_list_commit_author_timestamp(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> Int64 {
  let obj = db.get(fs, id) catch { _ => return 0L }
  match obj {
    Some(o) if o.obj_type == @bitcore.ObjectType::Commit =>
      rev_list_extract_author_timestamp(o.data)
    _ => 0L
  }
}

///|
fn rev_list_assign_left_right_marker(
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
fn rev_list_build_left_right_markers(
  fs : OsFs,
  git_dir : String,
  db : @bitlib.ObjectDb,
  symmetric_ranges : Array[(String, String)],
) -> Map[String, String] raise Error {
  let markers : Map[String, String] = {}
  for pair in symmetric_ranges {
    match
      (
        @bitrepo.rev_parse(fs, git_dir, pair.0),
        @bitrepo.rev_parse(fs, git_dir, pair.1),
      ) {
      (Some(left_id), Some(right_id)) => {
        let left_commit = rev_list_peel_to_commit(db, fs, left_id).unwrap_or(
          left_id,
        )
        let right_commit = rev_list_peel_to_commit(db, fs, right_id).unwrap_or(
          right_id,
        )
        let left_seen : Map[String, Bool] = {}
        let right_seen : Map[String, Bool] = {}
        let merge_base_seen : Map[String, Bool] = {}
        walk_commits_to_map(fs, git_dir, left_commit, left_seen)
        walk_commits_to_map(fs, git_dir, right_commit, right_seen)
        let bases = @bitlib.merge_base_all(db, fs, left_commit, right_commit)
        for base in bases {
          walk_commits_to_map(fs, git_dir, base, merge_base_seen)
        }
        for hex in left_seen.keys() {
          if merge_base_seen.contains(hex) {
            continue
          }
          rev_list_assign_left_right_marker(
            markers,
            hex,
            if right_seen.contains(hex) {
              "-"
            } else {
              "<"
            },
          )
        }
        for hex in right_seen.keys() {
          if merge_base_seen.contains(hex) {
            continue
          }
          rev_list_assign_left_right_marker(
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
      _ => ()
    }
  }
  markers
}

///|
fn rev_list_commit_patch_id(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  git_dir : String,
  commit_id : @bitcore.ObjectId,
) -> String? {
  let obj = db.get(fs, commit_id) catch { _ => return None }
  guard obj is Some(o) else { return None }
  if o.obj_type != @bitcore.ObjectType::Commit {
    return None
  }
  let info = @bitcore.parse_commit(o.data) catch { _ => return None }
  let old_tree : @bitcore.ObjectId? = if info.parents.length() > 0 {
    let parent_obj_opt = db.get(fs, info.parents[0]) catch { _ => None }
    match parent_obj_opt {
      Some(parent_obj) if parent_obj.obj_type == @bitcore.ObjectType::Commit => {
        let parent_info = @bitcore.parse_commit(parent_obj.data) catch {
          _ => return None
        }
        Some(parent_info.tree)
      }
      _ => None
    }
  } else {
    None
  }
  let diff_files = @bitdiff.diff_trees(fs, git_dir, old_tree, info.tree, db~) catch {
    _ => return None
  }
  if diff_files.length() == 0 {
    return None
  }
  let patch = @bitdiff.diff_text(diff_files).join("\n")
  let ids = patch_id_compute(patch)
  if ids.length() == 0 {
    None
  } else {
    Some(ids[0].0)
  }
}

///|
fn rev_list_push_patch_bucket(
  buckets : Map[String, Array[String]],
  key : String,
  hex : String,
) -> Unit {
  match buckets.get(key) {
    Some(list) => list.push(hex)
    None => buckets[key] = [hex]
  }
}

///|
fn rev_list_build_cherry_equal(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  git_dir : String,
  commits : Array[@bitcore.ObjectId],
  left_right_markers : Map[String, String],
) -> Map[String, Bool] {
  let left_patches : Map[String, Array[String]] = {}
  let right_patches : Map[String, Array[String]] = {}
  for id in commits {
    let hex = id.to_hex()
    let side = left_right_markers.get(hex).unwrap_or("")
    if side != "<" && side != ">" {
      continue
    }
    match rev_list_commit_patch_id(db, fs, git_dir, id) {
      Some(pid) =>
        if side == "<" {
          rev_list_push_patch_bucket(left_patches, pid, hex)
        } else {
          rev_list_push_patch_bucket(right_patches, pid, hex)
        }
      None => ()
    }
  }
  let equal : Map[String, Bool] = {}
  for pid, left_ids in left_patches {
    match right_patches.get(pid) {
      Some(right_ids) => {
        for hex in left_ids {
          equal[hex] = true
        }
        for hex in right_ids {
          equal[hex] = true
        }
      }
      None => ()
    }
  }
  equal
}

///|
fn rev_list_output_prefix(
  hex : String,
  left_right : Bool,
  cherry_mark : Bool,
  cherry_equal : Map[String, Bool],
  left_right_markers : Map[String, String],
) -> String {
  if cherry_mark && cherry_equal.contains(hex) {
    "="
  } else if left_right {
    left_right_markers.get(hex).unwrap_or("")
  } else if cherry_mark {
    "+"
  } else {
    ""
  }
}

///|
fn rev_list_is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn rev_list_is_short_max_count_arg(arg : String) -> Bool {
  arg.length() > 1 &&
  arg.get_char(0).unwrap() == '-' &&
  !arg.has_prefix("--") &&
  rev_list_is_digit(arg.get_char(1).unwrap())
}

///|
fn rev_list_is_long_numeric_option(arg : String) -> Bool {
  arg.length() > 2 &&
  arg.has_prefix("--") &&
  rev_list_is_digit(arg.get_char(2).unwrap())
}

///|
async fn rev_list_parse_int_or_die(value : String) -> Int raise Error {
  @string.parse_int(value) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => {
      eprint_line("fatal: not an integer: " + value)
      @sys.exit(128)
      0
    }
  }
}

///|
fn rev_list_window(
  length : Int,
  skip_count : Int,
  max_count : Int?,
) -> (Int, Int) {
  @bitlib.rev_list_window(length, skip_count, max_count)
}

///|
fn walk_commits_to_map(
  fs : OsFs,
  git_dir : String,
  start : @bitcore.ObjectId,
  out : Map[String, Bool],
  first_parent? : Bool = false,
) -> Unit {
  let db = @bitlib.ObjectDb::load(fs, git_dir) catch { _ => return () }
  let queue : Array[@bitcore.ObjectId] = [start]
  while queue.length() > 0 {
    let id = queue.unsafe_pop()
    let hex = id.to_hex()
    if out.contains(hex) {
      continue
    }
    out[hex] = true
    match rev_list_commit_parents(db, fs, id) {
      Some(parents) => {
        // For --exclude-first-parent-only the exclusion walk follows only the
        // first parent when crossing a merge.
        let parents_to_walk = if first_parent && parents.length() > 0 {
          [parents[0]]
        } else {
          parents
        }
        for parent in parents_to_walk {
          let phex = parent.to_hex()
          if !out.contains(phex) {
            queue.push(parent)
          }
        }
      }
      None => ()
    }
  }
}

///|
fn collect_tree_objects(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  tree_id : @bitcore.ObjectId,
  out : Array[(@bitcore.ObjectId, String)],
  visited : Map[String, Bool],
  parent_path? : String = "",
) -> Unit {
  let hex = tree_id.to_hex()
  if visited.contains(hex) {
    return ()
  }
  visited[hex] = true
  out.push((tree_id, parent_path))
  let obj = db.get(fs, tree_id) catch { _ => return () }
  match obj {
    Some(o) if o.obj_type == @bitcore.ObjectType::Tree => {
      let entries = @bitcore.parse_tree(o.data) catch { _ => return () }
      for entry in entries {
        let entry_hex = entry.id.to_hex()
        if !visited.contains(entry_hex) {
          let entry_path = if parent_path.length() == 0 {
            entry.name
          } else {
            parent_path + "/" + entry.name
          }
          if entry.mode.has_prefix("40") {
            // Directory - recurse
            collect_tree_objects(
              db,
              fs,
              entry.id,
              out,
              visited,
              parent_path=entry_path,
            )
          } else {
            // File or other
            visited[entry_hex] = true
            out.push((entry.id, entry_path))
          }
        }
      }
    }
    _ => ()
  }
}

///|
fn collect_tree_objects_excluding_index(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  tree_id : @bitcore.ObjectId,
  out : Array[(@bitcore.ObjectId, String)],
  visited : Map[String, Bool],
  indexed_path_ids : Map[String, String],
  parent_path? : String = "",
) -> Unit {
  let hex = tree_id.to_hex()
  if visited.contains(hex) {
    return ()
  }
  match indexed_path_ids.get(parent_path) {
    Some(index_hex) if index_hex == hex => return ()
    _ => ()
  }
  if parent_path.length() > 0 {
    visited[hex] = true
    out.push((tree_id, parent_path))
  }
  let obj = db.get(fs, tree_id) catch { _ => return () }
  match obj {
    Some(o) if o.obj_type == @bitcore.ObjectType::Tree => {
      let entries = @bitcore.parse_tree(o.data) catch { _ => return () }
      for entry in entries {
        let entry_path = if parent_path.length() == 0 {
          entry.name
        } else {
          parent_path + "/" + entry.name
        }
        let entry_hex = entry.id.to_hex()
        if entry.mode.has_prefix("40") {
          collect_tree_objects_excluding_index(
            db,
            fs,
            entry.id,
            out,
            visited,
            indexed_path_ids,
            parent_path=entry_path,
          )
        } else {
          match indexed_path_ids.get(entry_path) {
            Some(index_hex) if index_hex == entry_hex => continue
            _ => ()
          }
          if !visited.contains(entry_hex) {
            visited[entry_hex] = true
            out.push((entry.id, entry_path))
          }
        }
      }
    }
    _ => ()
  }
}

///|
fn rev_list_collect_index_objects(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  git_dir : String,
  entries : Array[@bitlib.IndexEntry],
) -> (Array[(@bitcore.ObjectId, String)], Map[String, String]) raise Error {
  let visible : Array[(@bitcore.ObjectId, String)] = []
  let unique_ids : Map[String, Bool] = {}
  let path_ids : Map[String, String] = {}
  let index_by_path : Map[String, @bitlib.IndexEntry] = {}
  for entry in entries {
    let hex = entry.id.to_hex()
    if rev_list_is_zero_object_id_hex(hex) {
      continue
    }
    index_by_path[entry.path] = entry
    path_ids[entry.path] = hex
    if !unique_ids.contains(hex) {
      unique_ids[hex] = true
      visible.push((entry.id, entry.path))
    }
  }
  let head_id = @bitrepo.rev_parse(fs, git_dir, "HEAD") catch { _ => None }
  match head_id {
    Some(id) =>
      match rev_list_commit_tree(db, fs, id) {
        Some(tree) => {
          let matched_paths : Map[String, Bool] = {}
          ignore(
            rev_list_collect_matching_index_trees(
              db, fs, tree, index_by_path, matched_paths, visible, unique_ids, path_ids,
            ),
          )
        }
        None => ()
      }
    None => ()
  }
  (visible, path_ids)
}

///|
fn rev_list_collect_matching_index_trees(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  tree_id : @bitcore.ObjectId,
  index_by_path : Map[String, @bitlib.IndexEntry],
  matched_paths : Map[String, Bool],
  visible : Array[(@bitcore.ObjectId, String)],
  unique_ids : Map[String, Bool],
  path_ids : Map[String, String],
  parent_path? : String = "",
) -> Bool raise Error {
  let obj = db.get(fs, tree_id)
  match obj {
    Some(o) if o.obj_type == @bitcore.ObjectType::Tree => {
      let entries = @bitcore.parse_tree(o.data) catch { _ => return false }
      for entry in entries {
        let entry_path = if parent_path.length() == 0 {
          entry.name
        } else {
          parent_path + "/" + entry.name
        }
        if entry.mode.has_prefix("40") {
          if !rev_list_collect_matching_index_trees(
              db,
              fs,
              entry.id,
              index_by_path,
              matched_paths,
              visible,
              unique_ids,
              path_ids,
              parent_path=entry_path,
            ) {
            return false
          }
        } else {
          match index_by_path.get(entry_path) {
            Some(index_entry) => {
              if index_entry.id.to_hex() != entry.id.to_hex() {
                return false
              }
              if index_entry.mode != rev_list_tree_mode_to_int(entry.mode) {
                return false
              }
              matched_paths[entry_path] = true
            }
            None => return false
          }
        }
      }
      let hex = tree_id.to_hex()
      path_ids[parent_path] = hex
      if parent_path.length() > 0 && !unique_ids.contains(hex) {
        unique_ids[hex] = true
        visible.push((tree_id, parent_path))
      }
      true
    }
    _ => false
  }
}

///|
fn rev_list_tree_mode_to_int(mode : String) -> Int {
  match mode {
    "100644" => 0o100644
    "100755" => 0o100755
    "120000" => 0o120000
    "160000" => 0o160000
    _ => 0
  }
}

///|
fn rev_list_is_zero_object_id_hex(hex : String) -> Bool {
  @bitcore.ObjectId::is_zero_hex(hex)
}

///|
async fn rev_list_test_bitmap(fs : OsFs, git_dir : String) -> Unit raise Error {
  let pack_dir = git_dir + "/objects/pack"
  // Find bitmap file: check chain first, then monolithic
  let chain_path = pack_dir + "/multi-pack-index.d/multi-pack-index-chain"
  let mut bitmap_data : Bytes? = None
  let mut midx_data : Bytes? = None
  if fs.is_file(chain_path) {
    // Use topmost layer from chain
    let chain_data = fs.read_file(chain_path) catch { _ => Bytes::new(0) }
    let text = midx_bytes_to_string(chain_data, 0, chain_data.length())
    let mut last_hash = ""
    for raw_line in text.split("\n") {
      let line = raw_line.to_owned().trim().to_owned()
      if line.length() > 0 {
        last_hash = line
      }
    }
    if last_hash.length() > 0 {
      let inc_dir = pack_dir + "/multi-pack-index.d"
      let bmp_path = inc_dir + "/multi-pack-index-" + last_hash + ".bitmap"
      let bmp_bytes = midx_try_read_file(fs, bmp_path)
      if bmp_bytes is Some(_) {
        bitmap_data = bmp_bytes
      }
      let midx_path = inc_dir + "/multi-pack-index-" + last_hash + ".midx"
      let md = midx_try_read_file(fs, midx_path)
      if md is Some(_) {
        midx_data = md
      }
    }
  }
  if bitmap_data is None {
    // Try monolithic
    let midx_path = pack_dir + "/multi-pack-index"
    let md = midx_try_read_file(fs, midx_path)
    match md {
      Some(md_bytes) =>
        if md_bytes.length() >= 20 {
          midx_data = Some(md_bytes)
          let checksum_hex = midx_checksum_hex(md_bytes)
          if checksum_hex.length() > 0 {
            let bmp_path = pack_dir +
              "/multi-pack-index-" +
              checksum_hex +
              ".bitmap"
            bitmap_data = midx_try_read_file(fs, bmp_path)
          }
        }
      None => ()
    }
  }
  // Fallback: single-pack bitmap (pack-*.bitmap)
  if bitmap_data is None {
    match find_pack_with_bitmap(fs, pack_dir) {
      Some(pack_name) => {
        let stem = string_slice_to(pack_name, pack_name.length() - 5)
        let bmp_path = pack_dir + "/" + stem + ".bitmap"
        bitmap_data = midx_try_read_file(fs, bmp_path)
      }
      None => ()
    }
  }
  guard bitmap_data is Some(bmp_bytes) else {
    eprint_line("error: could not find bitmap")
    @sys.exit(1)
    return
  }
  ignore(midx_data)
  // Emit GIT_TRACE2_EVENT for load_midx_revindex
  emit_revindex_trace(fs, "midx")
  guard pack_bitmap_parse(bmp_bytes) is Some(bitmap) else {
    eprint_line("error: bitmap structure invalid")
    @sys.exit(1)
    return
  }
  if bitmap.entry_count <= 0 || bitmap.entries.length() == 0 {
    eprint_line("error: bitmap has no entries")
    @sys.exit(1)
    return
  }
  let type_count = bitmap.commit_positions.length() +
    bitmap.tree_positions.length() +
    bitmap.blob_positions.length() +
    bitmap.tag_positions.length()
  let mut reachable_count = 0
  let mut valid = bitmap.version == 1 &&
    bitmap.pack_checksum.length() == 20 &&
    bitmap.entries.length() == bitmap.entry_count &&
    type_count <= bitmap.object_count &&
    (
      (bitmap.options & 4) == 0 ||
      bitmap.name_hashes.length() == bitmap.object_count
    )
  for entry in bitmap.entries {
    reachable_count += entry.positions.length()
    if entry.flags == 0 ||
      entry.object_pos < 0 ||
      entry.object_pos >= bitmap.object_count {
      valid = false
    }
  }
  if !valid || reachable_count == 0 {
    eprint_line("mismatch in bitmap results")
    @sys.exit(1)
    return
  }
  eprint_line("OK!")
}

///|
fn emit_revindex_trace(fs : OsFs, kind : String) -> Unit {
  match @sys.get_env_var("GIT_TRACE2_EVENT") {
    Some(path) => {
      let target = path.trim().to_owned()
      if target.length() == 0 || target == "1" || target == "2" {
        return
      }
      let existing = match midx_try_read_file(fs, target) {
        Some(data) => midx_bytes_to_string(data, 0, data.length())
        None => ""
      }
      let line = "{\"event\":\"data\",\"category\":\"load_midx_revindex\",\"key\":\"source\",\"value\":\"" +
        kind +
        "\"}"
      let next = if existing.length() == 0 {
        line + "\n"
      } else {
        existing + line + "\n"
      }
      fs.write_string(target, next) catch {
        _ => ()
      }
    }
    None => ()
  }
}

///|
/// Find ".." or "..." in a rev-list argument. Returns (position, is_symmetric).
fn rev_list_find_range_dots(arg : String) -> (Int, Bool)? {
  @bitlib.rev_list_find_range_dots(arg)
}

///|
/// Topological sort: children before parents, maintaining BFS order within
/// same depth. Uses Kahn's algorithm.
fn rev_list_topo_sort(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commits : Array[@bitcore.ObjectId],
) -> Unit {
  rev_list_topo_sort_impl(db, rfs, commits, false)
}

///|
/// DFS-based topological sort matching git's --topo-order / --author-date-order.
///
/// Children are emitted before parents. First-parent chains are kept together
/// by always exploring the first parent next (pushed last onto the stack).
///
/// When `use_author_date` is true, tie-breaking among ready commits uses
/// the author timestamp (--author-date-order) instead of the committer
/// timestamp (--topo-order default).
fn rev_list_topo_sort_impl(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commits : Array[@bitcore.ObjectId],
  use_author_date : Bool,
) -> Unit {
  if commits.length() <= 1 {
    return
  }
  // Build commit set and lookup maps
  let commit_set : Map[String, Int] = {} // hex -> index in commits
  for idx, id in commits {
    commit_set[id.to_hex()] = idx
  }
  // Parse all commits: parents and timestamps
  let parents_map : Map[String, Array[String]] = {} // hex -> parent hexes (in set)
  let timestamps : Map[String, Int64] = {} // hex -> sort timestamp
  for id in commits {
    let hex = id.to_hex()
    parents_map[hex] = []
    match rev_list_load_commit_info(db, rfs, id) {
      Some(info) => {
        let ps : Array[String] = []
        for p in info.parents {
          let phex = p.to_hex()
          if commit_set.contains(phex) {
            ps.push(phex)
          }
        }
        parents_map[hex] = ps
        timestamps[hex] = if use_author_date {
          rev_list_commit_author_timestamp(db, rfs, id)
        } else {
          info.committer_timestamp
        }
      }
      _ => timestamps[hex] = 0L
    }
  }
  // Build in-degree: number of children in the result set for each commit.
  // A commit's in-degree is incremented for each other commit that lists it
  // as a parent.
  let in_degree : Map[String, Int] = {}
  for id in commits {
    in_degree[id.to_hex()] = 0
  }
  for id in commits {
    let hex = id.to_hex()
    match parents_map.get(hex) {
      Some(ps) =>
        for phex in ps {
          in_degree[phex] = in_degree.get(phex).unwrap_or(0) + 1
        }
      None => ()
    }
  }
  // Collect tip commits (in-degree 0 = no children in set).
  // Sort by timestamp descending so the newest tip is processed first.
  let tips : Array[String] = []
  for id in commits {
    let hex = id.to_hex()
    if in_degree.get(hex).unwrap_or(0) == 0 {
      tips.push(hex)
    }
  }
  // Sort tips by timestamp ascending so that when pushed onto the stack
  // the newest (highest timestamp) ends up on top.
  tips.sort_by(fn(a, b) {
    let ta = timestamps.get(a).unwrap_or(0L)
    let tb = timestamps.get(b).unwrap_or(0L)
    if ta < tb {
      -1
    } else if ta > tb {
      1
    } else {
      0
    }
  })
  // DFS using a stack. Push tips so newest is on top.
  let stack : Array[String] = []
  for hex in tips {
    stack.push(hex)
  }
  let emitted : Map[String, Bool] = {}
  let sorted : Array[@bitcore.ObjectId] = []
  while stack.length() > 0 {
    let hex = stack.unsafe_pop()
    if emitted.get(hex).unwrap_or(false) {
      continue
    }
    // Check that all children have been emitted (in-degree should be 0).
    if in_degree.get(hex).unwrap_or(0) > 0 {
      continue
    }
    // Emit this commit
    emitted[hex] = true
    match commit_set.get(hex) {
      Some(idx) => sorted.push(commits[idx])
      None => ()
    }
    // Process parents: decrement their in-degree and push ready ones.
    // Push in reverse order so that the first parent ends up on top of the
    // stack and is processed next, keeping first-parent chains together.
    match parents_map.get(hex) {
      Some(ps) => {
        // Collect parents that become ready (in-degree reaches 0)
        let ready : Array[String] = []
        for phex in ps {
          let deg = in_degree.get(phex).unwrap_or(1) - 1
          in_degree[phex] = deg
          if deg == 0 && !emitted.get(phex).unwrap_or(false) {
            ready.push(phex)
          }
        }
        // Sort ready parents by timestamp ascending so newest ends up
        // on top of the stack (processed first). This matches git's
        // topo-order which processes by timestamp, not first-parent.
        ready.sort_by(fn(a, b) {
          let ta = timestamps.get(a).unwrap_or(0L)
          let tb = timestamps.get(b).unwrap_or(0L)
          if ta < tb {
            -1
          } else if ta > tb {
            1
          } else {
            0
          }
        })
        for phex in ready {
          stack.push(phex)
        }
      }
      None => ()
    }
  }
  // Copy sorted back into commits
  for idx, id in sorted {
    if idx < commits.length() {
      commits[idx] = id
    }
  }
}

///|
/// DFS-based topological sort using author date for tie-breaking
/// (git's --author-date-order).
fn rev_list_topo_sort_author_date(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commits : Array[@bitcore.ObjectId],
) -> Unit {
  rev_list_topo_sort_impl(db, rfs, commits, true)
}

///|
/// Extract author timestamp from raw commit data.
fn rev_list_extract_author_timestamp(data : Bytes) -> Int64 {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("author ") {
      // author Name <email> timestamp timezone
      let mut last_space = -1
      let mut second_last_space = -1
      for i in 0..<line.length() {
        if line.get_char(i).unwrap() == ' ' {
          second_last_space = last_space
          last_space = i
        }
      }
      if second_last_space > 0 {
        let ts_str = String::unsafe_substring(
          line,
          start=second_last_space + 1,
          end=last_space,
        )
        return @string.parse_int64(ts_str) catch { _ => 0L }
      }
    }
  }
  0L
}

///|
/// Sort commits by committer date (newest first).
fn rev_list_date_sort(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commits : Array[@bitcore.ObjectId],
) -> Unit {
  if commits.length() <= 1 {
    return
  }
  let timestamps : Map[String, Int64] = {}
  for id in commits {
    timestamps[id.to_hex()] = rev_list_commit_committer_timestamp(db, rfs, id)
  }
  // Simple insertion sort (stable, preserves order for equal timestamps)
  for i in 1..<commits.length() {
    let key = commits[i]
    let key_ts = timestamps.get(key.to_hex()).unwrap_or(0L)
    let mut j = i - 1
    while j >= 0 && timestamps.get(commits[j].to_hex()).unwrap_or(0L) < key_ts {
      commits[j + 1] = commits[j]
      j -= 1
    }
    commits[j + 1] = key
  }
}

///|
/// Add refs matching a glob pattern (e.g., "refs/heads" matches all branches).
/// Add refs of a specific type with optional pattern filter.
/// prefix: "refs/heads/", "refs/tags/", "refs/remotes/"
/// pattern: glob within the type (e.g., "subspace/*"), empty = all
/// Check if a ref name matches any exclude pattern.
/// Check if a ref name matches any exclude pattern within a namespace.
/// e.g., for prefix "refs/heads/" and pattern "subspace-*",
/// checks if the ref's suffix after prefix matches the pattern.
fn rev_list_ref_excluded_in_namespace(
  name : String,
  prefix : String,
  exclude_patterns : Array[String],
) -> Bool {
  if exclude_patterns.length() == 0 {
    return false
  }
  let suffix = String::unsafe_substring(
    name,
    start=prefix.length(),
    end=name.length(),
  )
  for pat in exclude_patterns {
    let effective = if pat.has_suffix("/") { pat + "*" } else { pat }
    // Try matching against the suffix (within namespace)
    if effective.contains("*") || effective.contains("?") {
      if rev_list_glob_match(effective, suffix) {
        return true
      }
    } else if suffix == effective || suffix.has_prefix(effective + "/") {
      return true
    }
    // Also try full-path match
    let full_pat = if pat.has_prefix("refs/") { pat } else { "refs/" + pat }
    let full_eff = if full_pat.has_suffix("/") {
      full_pat + "*"
    } else {
      full_pat
    }
    if full_eff.contains("*") || full_eff.contains("?") {
      if rev_list_glob_match(full_eff, name) {
        return true
      }
    } else if name == full_eff || name.has_prefix(full_eff + "/") {
      return true
    }
  }
  false
}

///|
fn rev_list_ref_excluded(
  name : String,
  exclude_patterns : Array[String],
) -> Bool {
  for pat in exclude_patterns {
    let full_pat = if pat.has_prefix("refs/") { pat } else { "refs/" + pat }
    let effective = if full_pat.has_suffix("/") {
      full_pat + "*"
    } else {
      full_pat
    }
    if effective.contains("*") || effective.contains("?") {
      if rev_list_glob_match(effective, name) {
        return true
      }
    } else if name == effective || name.has_prefix(effective + "/") {
      return true
    }
  }
  false
}

///|
fn rev_list_add_typed_refs(
  fs : OsFs,
  git_dir : String,
  prefix : String,
  pattern : String,
  exclude_patterns : Array[String],
  out : Array[String],
) -> Unit {
  let all_refs = @bitrepo.show_ref(fs, git_dir) catch { _ => [] }
  for item in all_refs {
    let name = item.0
    if name.has_prefix(prefix) {
      // Check exclude patterns within the typed namespace
      if rev_list_ref_excluded_in_namespace(name, prefix, exclude_patterns) {
        continue
      }
      if pattern.length() == 0 {
        out.push(name)
      } else {
        // Match the part after prefix against the pattern
        let suffix = String::unsafe_substring(
          name,
          start=prefix.length(),
          end=name.length(),
        )
        let full_pattern = if pattern.has_suffix("/") {
          pattern + "*"
        } else {
          pattern
        }
        if full_pattern.contains("*") || full_pattern.contains("?") {
          if rev_list_glob_match(full_pattern, suffix) {
            out.push(name)
          }
        } else if suffix.has_prefix(full_pattern) {
          if full_pattern.length() >= suffix.length() ||
            suffix.get_char(full_pattern.length()) == Some('/') {
            out.push(name)
          }
        }
      }
    }
  }
}

///|
fn rev_list_add_glob_refs(
  fs : OsFs,
  git_dir : String,
  pattern : String,
  out : Array[String],
) -> Unit {
  let all_refs = @bitrepo.show_ref(fs, git_dir) catch { _ => [] }
  // Auto-prepend "refs/" if pattern doesn't start with it (git compat)
  let base_pattern = if pattern.has_prefix("refs/") {
    pattern
  } else {
    "refs/" + pattern
  }
  // Trailing "/" means "everything under" — append "*"
  let full_pattern = if base_pattern.has_suffix("/") {
    base_pattern + "*"
  } else {
    base_pattern
  }
  let has_star = full_pattern.contains("*") || full_pattern.contains("?")
  for item in all_refs {
    let name = item.0
    if has_star {
      if rev_list_glob_match(full_pattern, name) {
        out.push(name)
      }
      // Prefix match with / boundary
    } else if name.has_prefix(full_pattern) {
      if full_pattern.length() >= name.length() ||
        name.get_char(full_pattern.length()) == Some('/') {
        out.push(name)
      }
    }
  }
}

///|
/// Simple glob matching with * wildcard.
fn rev_list_glob_match(pattern : String, text : String) -> Bool {
  @bitlib.rev_list_glob_match(pattern, text)
}

///|
