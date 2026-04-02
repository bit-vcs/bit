///|
async fn handle_tag(args : Array[String]) -> Unit raise Error {
  let args = tag_expand_short_bundles(args)
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let mut list_mode = false
  let mut explicit_list = false
  let mut delete_mode = false
  let mut annotated = false
  let mut sign_tag = false
  let mut force = false
  let mut ignore_case = false
  let mut create_reflog = false
  let mut edit_message = false
  let mut annotation_lines : Int? = None
  let delete_tags : Array[String] = []
  let mut message : String? = None
  let mut message_file : String? = None
  let mut tag_name : String? = None
  let mut target : String? = None
  let patterns : Array[String] = []
  let trailers : Array[String] = []
  let sort_keys : Array[String] = []
  let points_at : Array[String] = []
  let mut contains : String? = None
  let mut no_contains : String? = None
  let mut merged : String? = None
  let mut no_merged : String? = None
  let mut format : String? = None
  let mut omit_empty = false
  let mut color_mode = ""
  let mut disable_config_sort = false
  let mut column_mode : String? = None
  let mut verify_mode = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    let next_arg = if i + 1 < args.length() { Some(args[i + 1]) } else { None }
    match tag_parse_contains_style_option(arg, next_arg) {
      Some((kind, value, consumed)) => {
        match kind {
          "contains" => contains = Some(value)
          "no_contains" => no_contains = Some(value)
          "invalid" =>
            if value == "--no-with" || value == "--no-without" {
              raise @bitcore.GitError::InvalidObject("unknown option: " + value)
            } else {
              raise @bitcore.GitError::InvalidObject(
                "option '\{value}' requires a value",
              )
            }
          _ => ()
        }
        i += 1 + consumed
        continue
      }
      None => ()
    }
    match arg {
      "-h" => {
        print_line(
          "usage: git tag [-a | -d | -l | -v] [-f] [-i] [-m <msg>] [-s] [<tagname>] [<head>]",
        )
        @sys.exit(129)
        return
      }
      "-l" | "--list" => {
        list_mode = true
        explicit_list = true
      }
      "-d" | "--delete" => delete_mode = true
      "-a" | "--annotate" => annotated = true
      "-f" | "--force" => force = true
      "-i" | "--ignore-case" => ignore_case = true
      "-v" | "--verify" => verify_mode = true
      "--create-reflog" => create_reflog = true
      "-e" | "--edit" => {
        edit_message = true
        annotated = true
      }
      "-n" => {
        annotation_lines = Some(1)
        list_mode = true
        explicit_list = true
      }
      _ if arg.has_prefix("-n") => {
        let value = String::unsafe_substring(arg, start=2, end=arg.length())
        annotation_lines = Some(tag_parse_annotation_lines(value).unwrap_or(1))
        list_mode = true
        explicit_list = true
      }
      "-m" if i + 1 < args.length() => {
        message = Some(args[i + 1])
        annotated = true
        i += 2
        continue
      }
      _ if arg.has_prefix("-m") => {
        message = Some(string_slice_from(arg, 2))
        annotated = true
        i += 1
        continue
      }
      _ if arg.has_prefix("--message=") => {
        message = Some(string_slice_from(arg, 10))
        annotated = true
        i += 1
        continue
      }
      "-F" if i + 1 < args.length() => {
        message_file = Some(args[i + 1])
        annotated = true
        i += 2
        continue
      }
      "-F" =>
        raise @bitcore.GitError::InvalidObject("option '-F' requires a value")
      _ if arg.has_prefix("--file=") => {
        message_file = Some(
          String::unsafe_substring(arg, start=7, end=arg.length()),
        )
        annotated = true
        i += 1
        continue
      }
      "--trailer" if i + 1 < args.length() => {
        trailers.push(tag_normalize_trailer_arg(args[i + 1]))
        annotated = true
        i += 2
        continue
      }
      "--trailer" =>
        raise @bitcore.GitError::InvalidObject(
          "option '--trailer' requires a value",
        )
      _ if arg.has_prefix("--trailer=") => {
        trailers.push(
          tag_normalize_trailer_arg(
            String::unsafe_substring(arg, start=10, end=arg.length()),
          ),
        )
        annotated = true
        i += 1
        continue
      }
      "--sort" if i + 1 < args.length() => {
        sort_keys.push(args[i + 1])
        i += 2
        continue
      }
      "--no-sort" => {
        sort_keys.clear()
        disable_config_sort = true
      }
      _ if arg.has_prefix("--sort=") =>
        sort_keys.push(String::unsafe_substring(arg, start=7, end=arg.length()))
      "--format" if i + 1 < args.length() => {
        format = Some(args[i + 1])
        i += 2
        continue
      }
      _ if arg.has_prefix("--format=") =>
        format = Some(String::unsafe_substring(arg, start=9, end=arg.length()))
      _ if arg.has_prefix("--points-at=") =>
        points_at.push(
          String::unsafe_substring(arg, start=12, end=arg.length()),
        )
      "--points-at" => {
        if i + 1 < args.length() && !args[i + 1].has_prefix("-") {
          points_at.push(args[i + 1])
          i += 2
          continue
        }
        points_at.push("HEAD")
      }
      _ if arg.has_prefix("--merged=") =>
        merged = Some(String::unsafe_substring(arg, start=9, end=arg.length()))
      "--merged" => {
        if i + 1 < args.length() && !args[i + 1].has_prefix("-") {
          merged = Some(args[i + 1])
          i += 2
          continue
        }
        merged = Some("HEAD")
      }
      _ if arg.has_prefix("--no-merged=") =>
        no_merged = Some(
          String::unsafe_substring(arg, start=12, end=arg.length()),
        )
      "--no-merged" => {
        if i + 1 < args.length() && !args[i + 1].has_prefix("-") {
          no_merged = Some(args[i + 1])
          i += 2
          continue
        }
        no_merged = Some("HEAD")
      }
      "--omit-empty" => omit_empty = true
      "--color" | "--color=always" => color_mode = "always"
      "--color=auto" => color_mode = "auto"
      "--no-color" | "--color=never" => color_mode = "never"
      "--column" => {
        if i + 1 < args.length() && !args[i + 1].has_prefix("-") {
          column_mode = Some(args[i + 1])
          i += 2
          continue
        }
        column_mode = Some("always")
      }
      "--no-column" => column_mode = Some("never")
      _ if arg.has_prefix("--column=") =>
        column_mode = Some(
          String::unsafe_substring(arg, start=9, end=arg.length()),
        )
      _ if !arg.has_prefix("-") =>
        if delete_mode {
          delete_tags.push(arg)
        } else if explicit_list {
          patterns.push(arg)
        } else if tag_name is None {
          tag_name = Some(arg)
        } else if target is None {
          target = Some(arg)
        }
      "-s" | "--sign" => {
        annotated = true
        sign_tag = true
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("tag", arg)
      _ => ()
    }
    i += 1
  }
  let list_like = explicit_list ||
    annotation_lines is Some(_) ||
    points_at.length() > 0 ||
    contains is Some(_) ||
    no_contains is Some(_) ||
    merged is Some(_) ||
    no_merged is Some(_) ||
    format is Some(_) ||
    omit_empty ||
    column_mode is Some(_)
  let (column_active, column_row_major, column_dense, explicit_column_enabled) = tag_resolve_column_mode(
    fs,
    git_dir,
    column_mode,
    annotation_lines is None,
  )
  if annotation_lines is Some(_) && explicit_column_enabled {
    raise @bitcore.GitError::InvalidObject(
      "options '--column' and '-n' cannot be used together",
    )
  }
  if list_like &&
    (
      delete_mode ||
      verify_mode ||
      annotated ||
      message is Some(_) ||
      message_file is Some(_) ||
      force ||
      create_reflog
    ) {
    raise @bitcore.GitError::InvalidObject(
      "incompatible options for tag listing",
    )
  }
  // Determine list mode: if no create/delete args, default to list
  if !delete_mode &&
    !annotated &&
    message is None &&
    message_file is None &&
    !force &&
    !verify_mode {
    if tag_name is None {
      list_mode = true
    } else if explicit_list || list_like {
      // -l with pattern: tag_name is actually a pattern
      match tag_name {
        Some(name) => {
          patterns.push(name)
          tag_name = None
        }
        None => ()
      }
      list_mode = true
    }
  }
  if (explicit_list || list_like) && tag_name is Some(name) {
    patterns.push(name)
    tag_name = None
    list_mode = true
  }
  if message is Some(_) && message_file is Some(_) {
    raise @bitcore.GitError::InvalidObject(
      "options '-m' and '-F' cannot be used together",
    )
  }
  if verify_mode {
    let names : Array[String] = []
    match tag_name {
      Some(name) => names.push(name)
      None => ()
    }
    if target is Some(t) {
      names.push(t)
    }
    for name in names {
      let id = @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + name)
      guard id is Some(tag_id) else {
        raise @bitcore.GitError::InvalidObject("tag '\{name}' not found")
      }
      let db = @bitlib.ObjectDb::load(fs, git_dir)
      match db.get(fs, tag_id) {
        Some(obj) if obj.obj_type == @bitcore.ObjectType::Tag => ()
        _ =>
          raise @bitcore.GitError::InvalidObject(
            "cannot verify a non-tag object of type commit",
          )
      }
    }
    raise @bitcore.GitError::InvalidObject(
      "tag signature verification is not supported",
    )
  }
  if delete_mode {
    if delete_tags.length() == 0 {
      return ()
    }
    for name in delete_tags {
      let id = @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + name)
      @bitlib.delete_tag(fs, fs, git_dir, name)
      match id {
        Some(oid) =>
          eprint_line(
            "Deleted tag '\{name}' (was \{string_slice_to(oid.to_hex(), 7)})",
          )
        None => eprint_line("Deleted tag '\{name}'")
      }
    }
    return ()
  }
  if list_mode {
    let db = @bitlib.ObjectDb::load(fs, git_dir)
    let filtered : Array[(String, String, @bitcore.ObjectId)] = []
    for tag in @bitlib.list_tags(fs, git_dir) {
      if patterns.length() > 0 {
        let mut matched = false
        for pattern in patterns {
          if tag_glob_match(pattern, tag, ignore_case) {
            matched = true
            break
          }
        }
        if !matched {
          continue
        }
      }
      let refname = "refs/tags/" + tag
      guard @bitlib.resolve_ref(fs, git_dir, refname) is Some(tag_id) else {
        continue
      }
      if points_at.length() > 0 {
        let mut matches = false
        for target_rev in points_at {
          match @bitrepo.rev_parse(fs, git_dir, target_rev) {
            Some(target_id) =>
              if tag_points_at_object(fs, db, tag_id, target_id) {
                matches = true
                break
              }
            None => ()
          }
        }
        if !matches {
          continue
        }
      }
      filtered.push((tag, refname, tag_id))
    }
    tag_apply_list_filters(
      fs, git_dir, db, filtered, merged, no_merged, contains, no_contains,
    )
    let effective_sort_keys = tag_effective_sort_keys(
      fs, git_dir, sort_keys, disable_config_sort,
    )
    tag_validate_sort_keys(effective_sort_keys)
    let (version_suffixes, missing_version_suffix, missing_version_prerelease) = if effective_sort_keys.any(fn(
          key,
        ) {
          let sort_field = if key.has_prefix("-") {
            String::unsafe_substring(key, start=1, end=key.length())
          } else {
            key
          }
          let normalized = tag_normalize_sort_field(sort_field)
          normalized == "version:refname" || normalized == "v:refname"
        },
      ) {
      tag_versionsort_suffixes(fs, git_dir)
    } else {
      ([], false, false)
    }
    if missing_version_suffix {
      eprint_line("error: missing value for 'versionsort.suffix'")
    }
    if missing_version_prerelease {
      eprint_line("error: missing value for 'versionsort.prereleasesuffix'")
    }
    if effective_sort_keys.length() > 0 {
      filtered.sort_by(fn(a, b) {
        let mut idx = effective_sort_keys.length() - 1
        while idx >= 0 {
          let key = effective_sort_keys[idx]
          let descending = key.has_prefix("-")
          let sort_field = if descending {
            String::unsafe_substring(key, start=1, end=key.length())
          } else {
            key
          }
          let cmp = tag_compare_ref_items(
            fs, git_dir, a, b, sort_field, ignore_case, version_suffixes,
          )
          let adjusted = if descending { -cmp } else { cmp }
          if adjusted != 0 {
            return adjusted
          }
          idx -= 1
        }
        tag_default_compare(a.0, b.0, ignore_case)
      })
    } else {
      filtered.sort_by(fn(a, b) { tag_default_compare(a.0, b.0, ignore_case) })
    }
    match format {
      Some(fmt) => {
        for_each_ref_validate_format(fmt)
        for item in filtered {
          let (_, refname, id) = item
          let line_bytes = for_each_ref_format(
            fs, git_dir, db, fmt, refname, id, "", color_mode, "",
          )
          if omit_empty && line_bytes.length() == 0 {
            continue
          }
          let _ = @stdio.stdout.write_once(
            line_bytes,
            offset=0,
            len=line_bytes.length(),
          )
          let newline : Bytes = b"\n"
          let _ = @stdio.stdout.write_once(newline, offset=0, len=1)
        }
      }
      None =>
        if annotation_lines is Some(lines) {
          for item in filtered {
            tag_print_with_annotation(fs, git_dir, item.0, lines)
          }
        } else if column_active {
          let names = filtered.map(fn(item) { item.0 })
          let lines = if column_row_major {
            tag_format_columns(names, tag_term_columns(), dense=column_dense)
          } else {
            tag_format_columns_with_layout(
              names,
              tag_term_columns(),
              dense=column_dense,
              row_major=false,
            )
          }
          for line in lines {
            print_line(line)
          }
        } else {
          for item in filtered {
            print_line(item.0)
          }
        }
    }
    return ()
  }
  guard tag_name is Some(name) else {
    raise @bitcore.GitError::InvalidObject("tag name required")
  }
  // Prohibit HEAD as tag name
  if name == "HEAD" {
    eprint_line("fatal: 'HEAD' is not a valid tag name")
    @sys.exit(128)
    return
  }
  if !tag_is_valid_name(name) {
    raise @bitcore.GitError::InvalidObject("invalid tag name: " + name)
  }
  // Resolve target (default to HEAD)
  let target_ref = target.unwrap_or("HEAD")
  let resolved_target = @bitrepo.rev_parse(fs, git_dir, target_ref)
  guard resolved_target is Some(id) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{target_ref}")
  }
  if !force && @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + name) is Some(_) {
    raise @bitcore.GitError::InvalidObject("tag '\{name}' already exists")
  }
  let (tag_message, edit_path) = tag_resolve_message(
    fs, root, git_dir, name, annotated, message, message_file, trailers, edit_message,
  )
  if force {
    if @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + name) is Some(_) {
      @bitlib.delete_tag(fs, fs, git_dir, name)
    }
  }
  let tagger = get_committer_string()
  let timestamp = get_commit_timestamp()
  let timezone = get_commit_timezone()
  let tag_algo = signing_repo_hash_algorithm(fs, git_dir)
  let should_sign = sign_tag
  if annotated {
    if should_sign {
      tag_create_signed_annotated_tag(
        fs, git_dir, root, name, id, tag_message, tagger, timestamp, timezone, tag_algo,
      )
    } else {
      @bitlib.create_annotated_tag(
        fs,
        fs,
        git_dir,
        name,
        id,
        tag_message,
        tagger,
        timestamp,
        timezone~,
      )
    }
  } else {
    @bitlib.create_lightweight_tag(fs, fs, git_dir, name, id)
  }
  tag_maybe_append_reflog(
    fs, git_dir, name, id, tagger, timestamp, timezone, create_reflog,
  )
  tag_maybe_print_nested_advice(fs, git_dir, name, target_ref, id)
  match edit_path {
    Some(path) => if fs.is_file(path) { fs.remove_file(path) catch { _ => () } }
    None => ()
  }
}

///|
async fn tag_create_signed_annotated_tag(
  fs : OsFs,
  git_dir : String,
  root : String,
  name : String,
  target : @bitcore.ObjectId,
  message : String,
  tagger : String,
  timestamp : Int64,
  timezone : String,
  algo : @bitobject.HashAlgorithm,
) -> Unit raise Error {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let target_obj = db.get(fs, target)
  guard target_obj is Some(obj) else {
    raise @bitcore.GitError::InvalidObject("unknown object: \{target.to_hex()}")
  }
  let target_type = match obj.obj_type {
    @bitcore.ObjectType::Blob => "blob"
    @bitcore.ObjectType::Tree => "tree"
    @bitcore.ObjectType::Commit => "commit"
    @bitcore.ObjectType::Tag => "tag"
  }
  let tag_content = if message.length() == 0 {
    "object \{target.to_hex()}\ntype \{target_type}\ntag \{name}\ntagger \{tagger} \{timestamp} \{timezone}\n\n"
  } else {
    "object \{target.to_hex()}\ntype \{target_type}\ntag \{name}\ntagger \{tagger} \{timestamp} \{timezone}\n\n\{message}\n"
  }
  let payload = @utf8.encode(tag_content)
  let signature = signing_sign_payload(fs, root, git_dir, payload, None)
  let signed_payload = signing_append_tag_signature(payload, signature)
  let (tag_id, compressed) = @bitobject.create_object_with_algo(
    algo,
    @bitcore.ObjectType::Tag,
    signed_payload,
  )
  @bitlib.write_object_bytes(fs, git_dir, tag_id, compressed)
  let ref_path = git_dir + "/refs/tags/" + name
  fs.mkdir_p(parent_dir(ref_path))
  fs.write_string(ref_path, tag_id.to_hex() + "\n")
}

///|
fn tag_expand_short_bundles(args : Array[String]) -> Array[String] {
  let expanded : Array[String] = []
  for arg in args {
    match tag_expand_short_bundle_arg(arg) {
      Some(tokens) =>
        for token in tokens {
          expanded.push(token)
        }
      None => expanded.push(arg)
    }
  }
  expanded
}

///|
fn tag_expand_short_bundle_arg(arg : String) -> Array[String]? {
  if arg.length() <= 2 || !arg.has_prefix("-") || arg.has_prefix("--") {
    return None
  }
  let chars = arg.to_array()
  let tokens : Array[String] = []
  let mut i = 1
  while i < chars.length() {
    let short = chars[i]
    match short {
      'a' | 'd' | 'e' | 'f' | 'i' | 'l' | 's' | 'v' => {
        tokens.push("-" + short.to_string())
        i += 1
      }
      'n' => {
        if i + 1 < chars.length() {
          let rest = String::from_array(chars[i + 1:])
          if tag_string_is_digits(rest) {
            tokens.push("-n" + rest)
            return Some(tokens)
          } else {
            return None
          }
        }
        tokens.push("-n")
        i += 1
      }
      'm' | 'F' => {
        if i + 1 < chars.length() {
          tokens.push(
            "-" + short.to_string() + String::from_array(chars[i + 1:]),
          )
        } else {
          tokens.push("-" + short.to_string())
        }
        return Some(tokens)
      }
      _ => return None
    }
  }
  Some(tokens)
}

///|
fn tag_string_is_digits(value : String) -> Bool {
  for ch in value.to_array() {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn tag_parse_annotation_lines(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }
  Some(@string.parse_int(value)) catch {
    _ => None
  }
}

///|
fn tag_parse_column_tokens(value : String) -> Array[String] {
  let tokens : Array[String] = []
  for comma_part in value.split(",") {
    let chunk = comma_part.to_string()
    for space_part in chunk.split(" ") {
      let token = space_part.to_string().trim().to_string()
      if token.length() > 0 {
        tokens.push(token)
      }
    }
  }
  tokens
}

///|
fn tag_apply_column_mode(
  enabled_state : String,
  layout : String,
  dense : Bool,
  value : String,
) -> (String, String, Bool) raise Error {
  let mut next_enabled_state = enabled_state
  let mut next_layout = layout
  let mut next_dense = dense
  let mut saw_enable = false
  let mut saw_layout = false
  for token in tag_parse_column_tokens(value) {
    match token {
      "always" => {
        next_enabled_state = "enabled"
        saw_enable = true
      }
      "never" => {
        next_enabled_state = "disabled"
        saw_enable = true
      }
      "auto" => {
        next_enabled_state = "auto"
        saw_enable = true
      }
      "column" => {
        next_layout = "column"
        saw_layout = true
      }
      "row" => {
        next_layout = "row"
        saw_layout = true
      }
      "plain" => {
        next_layout = "plain"
        saw_layout = true
      }
      "dense" => next_dense = true
      "nodense" => next_dense = false
      _ =>
        raise @bitcore.GitError::InvalidObject("unsupported option '\{token}'")
    }
  }
  if saw_layout && !saw_enable {
    next_enabled_state = "enabled"
  }
  (next_enabled_state, next_layout, next_dense)
}

///|
fn tag_resolve_column_mode(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  cli_mode : String?,
  allow_config : Bool,
) -> (Bool, Bool, Bool, Bool) raise Error {
  let mut enabled_state = "disabled"
  let mut layout = "column"
  let mut dense = false
  if allow_config {
    let config_path = git_dir + "/config"
    for value in @bitlib.read_config_values(fs, config_path, "column", "ui") {
      let (next_enabled_state, next_layout, next_dense) = tag_apply_column_mode(
        enabled_state, layout, dense, value,
      )
      enabled_state = next_enabled_state
      layout = next_layout
      dense = next_dense
    }
    for value in @bitlib.read_config_values(fs, config_path, "column", "tag") {
      let (next_enabled_state, next_layout, next_dense) = tag_apply_column_mode(
        enabled_state, layout, dense, value,
      )
      enabled_state = next_enabled_state
      layout = next_layout
      dense = next_dense
    }
  }
  let mut explicit_column_enabled = false
  match cli_mode {
    Some(value) => {
      let (next_enabled_state, next_layout, next_dense) = tag_apply_column_mode(
        enabled_state, layout, dense, value,
      )
      enabled_state = next_enabled_state
      layout = next_layout
      dense = next_dense
      explicit_column_enabled = enabled_state == "enabled"
    }
    None => ()
  }
  (
    enabled_state == "enabled" && layout != "plain",
    layout == "row",
    dense,
    explicit_column_enabled,
  )
}

///|
fn tag_term_columns() -> Int {
  match @sys.get_env_var("COLUMNS") {
    Some(raw) => {
      let parsed = @string.parse_int(raw) catch { _ => 80 }
      if parsed > 1 {
        parsed
      } else {
        2
      }
    }
    None => 80
  }
}

///|
fn tag_column_linear_index(
  rows : Int,
  cols : Int,
  x : Int,
  y : Int,
  row_major? : Bool = true,
) -> Int {
  if row_major {
    y * cols + x
  } else {
    x * rows + y
  }
}

///|
fn tag_column_widths(
  lengths : Array[Int],
  rows : Int,
  cols : Int,
  row_major? : Bool = true,
) -> Array[Int] {
  let widths = Array::make(cols, 0)
  for x in 0..<cols {
    let mut width = 0
    for y in 0..<rows {
      let idx = tag_column_linear_index(rows, cols, x, y, row_major~)
      if idx < lengths.length() {
        width = width.max(lengths[idx])
      }
    }
    widths[x] = width
  }
  widths
}

///|
fn tag_format_columns(
  items : Array[String],
  term_columns : Int,
  dense? : Bool = false,
) -> Array[String] {
  tag_format_columns_with_layout(items, term_columns, dense~, row_major=true)
}

///|
fn tag_format_columns_with_layout(
  items : Array[String],
  term_columns : Int,
  dense? : Bool = false,
  row_major? : Bool = true,
) -> Array[String] {
  let lines : Array[String] = []
  if items.length() == 0 {
    return lines
  }
  let padding = 2
  let lengths : Array[Int] = []
  let mut max_width = 0
  for item in items {
    let width = item.length()
    lengths.push(width)
    max_width = max_width.max(width)
  }
  let initial_width = max_width + padding
  let available_width = if term_columns > 1 { term_columns - 1 } else { 1 }
  let mut cols = available_width / initial_width
  if cols == 0 {
    cols = 1
  }
  let mut rows = items.length() / cols
  if items.length() % cols != 0 {
    rows += 1
  }
  let mut widths = Array::make(cols, max_width)
  if dense {
    while rows > 1 {
      let next_rows = rows - 1
      let mut next_cols = items.length() / next_rows
      if items.length() % next_rows != 0 {
        next_cols += 1
      }
      let next_widths = tag_column_widths(
        lengths,
        next_rows,
        next_cols,
        row_major~,
      )
      let mut total_width = 0
      for width in next_widths {
        total_width += width + padding
      }
      if total_width > available_width {
        break
      }
      rows = next_rows
      cols = next_cols
      widths = next_widths
    }
    widths = tag_column_widths(lengths, rows, cols, row_major~)
  }
  for y in 0..<rows {
    let mut line = ""
    for x in 0..<cols {
      let idx = tag_column_linear_index(rows, cols, x, y, row_major~)
      if idx >= items.length() {
        break
      }
      line += items[idx]
      let newline = if row_major {
        x == cols - 1 || idx == items.length() - 1
      } else {
        idx + rows >= items.length()
      }
      if !newline {
        let cell_width = widths[x] + padding
        line += " ".repeat(cell_width - lengths[idx])
      }
    }
    lines.push(line)
  }
  lines
}

///|
fn tag_normalize_trailer_arg(value : String) -> String raise Error {
  match value.find("=") {
    Some(idx) if idx > 0 => {
      let key = String::unsafe_substring(value, start=0, end=idx)
      let raw_val = String::unsafe_substring(
        value,
        start=idx + 1,
        end=value.length(),
      )
      let key_clean = if key.has_suffix(":") {
        String::unsafe_substring(key, start=0, end=key.length() - 1)
      } else {
        key
      }
      key_clean + ": " + raw_val
    }
    _ =>
      raise @bitcore.GitError::InvalidObject(
        "expected trailer in key=value format",
      )
  }
}

///|
fn tag_apply_trailers(message : String, trailers : Array[String]) -> String {
  if trailers.length() == 0 {
    return message
  }
  if message.length() == 0 {
    return trailers.join("\n")
  }
  let lines : Array[String] = []
  for line_view in message.split("\n") {
    lines.push(line_view.to_string())
  }
  let mut last_nonblank = lines.length() - 1
  while last_nonblank >= 0 && trim_string(lines[last_nonblank]).length() == 0 {
    last_nonblank -= 1
  }
  let need_blank = if last_nonblank >= 0 {
    !commit_is_trailer_line(lines[last_nonblank])
  } else {
    true
  }
  let result = StringBuilder::new()
  result.write_string(message)
  if !message.has_suffix("\n") {
    result.write_char('\n')
  }
  if need_blank {
    result.write_char('\n')
  }
  result.write_string(trailers.join("\n"))
  result.to_string()
}

///|
fn tag_apply_trailers_for_edit(
  message : String,
  trailers : Array[String],
) -> String {
  if trailers.length() == 0 {
    return message
  }
  if message.length() == 0 {
    return "\n" + trailers.join("\n")
  }
  tag_apply_trailers(message, trailers)
}

///|
fn tag_parse_contains_style_option(
  arg : String,
  next_arg : String?,
) -> (String, String, Int)? {
  match arg {
    "--contains" | "--with" =>
      match next_arg {
        Some(next) =>
          if next.has_prefix("-") {
            Some(("invalid", arg, 0))
          } else {
            Some(("contains", next, 1))
          }
        None => Some(("contains", "HEAD", 0))
      }
    _ if arg.has_prefix("--contains=") =>
      Some(
        (
          "contains",
          String::unsafe_substring(arg, start=11, end=arg.length()),
          0,
        ),
      )
    _ if arg.has_prefix("--with=") =>
      Some(
        (
          "contains",
          String::unsafe_substring(arg, start=7, end=arg.length()),
          0,
        ),
      )
    "--no-contains" | "--without" =>
      match next_arg {
        Some(next) =>
          if next.has_prefix("-") {
            Some(("invalid", arg, 0))
          } else {
            Some(("no_contains", next, 1))
          }
        None => Some(("no_contains", "HEAD", 0))
      }
    _ if arg.has_prefix("--no-contains=") =>
      Some(
        (
          "no_contains",
          String::unsafe_substring(arg, start=14, end=arg.length()),
          0,
        ),
      )
    _ if arg.has_prefix("--without=") =>
      Some(
        (
          "no_contains",
          String::unsafe_substring(arg, start=10, end=arg.length()),
          0,
        ),
      )
    "--no-with" | "--no-without" => Some(("invalid", arg, 0))
    _ => None
  }
}

///|
async fn tag_print_with_annotation(
  fs : OsFs,
  git_dir : String,
  name : String,
  lines : Int,
) -> Unit raise Error {
  if lines <= 0 {
    print_line(name)
    return
  }
  let annotation = tag_read_annotation_lines(fs, git_dir, name, lines)
  for line in tag_format_annotation_lines(name, annotation) {
    print_line(line)
  }
}

///|
fn tag_format_annotation_lines(
  name : String,
  annotation : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  if annotation.length() == 0 {
    out.push(pad_right(name, 16))
    return out
  }
  out.push(pad_right(name, 16) + annotation[0])
  for i in 1..<annotation.length() {
    out.push("    " + annotation[i])
  }
  out
}

///|
fn tag_read_annotation_lines(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  name : String,
  max_lines : Int,
) -> Array[String] raise Error {
  let id = @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + name)
  guard id is Some(tag_id) else { return [] }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  match db.get(fs, tag_id) {
    Some(obj) if obj.obj_type == @bitcore.ObjectType::Tag =>
      tag_extract_message_lines(decode_bytes(obj.data), max_lines)
    _ =>
      match tag_peel_to_commit(fs, db, tag_id) {
        Some(commit_id) =>
          match db.get(fs, commit_id) {
            Some(commit_obj) if commit_obj.obj_type ==
              @bitcore.ObjectType::Commit =>
              tag_extract_message_lines(
                decode_bytes(commit_obj.data),
                max_lines,
              )
            _ => []
          }
        None => []
      }
  }
}

///|
fn tag_extract_message_lines(text : String, max_lines : Int) -> Array[String] {
  let split = match text.find("\n\n") {
    Some(idx) =>
      String::unsafe_substring(text, start=idx + 2, end=text.length())
    None => ""
  }
  let out : Array[String] = []
  for line_view in split.split("\n") {
    if out.length() >= max_lines {
      break
    }
    out.push(line_view.to_string())
  }
  while out.length() > 1 && out.last().unwrap_or("").length() == 0 {
    ignore(out.pop())
  }
  out
}

///|
fn tag_default_compare(a : String, b : String, ignore_case : Bool) -> Int {
  if ignore_case {
    tag_lexicographic_compare(a.to_lower(), b.to_lower())
  } else {
    tag_lexicographic_compare(a, b)
  }
}

///|
fn tag_lexicographic_compare(a : String, b : String) -> Int {
  let len = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<len {
    let ca = a[i].to_int()
    let cb = b[i].to_int()
    if ca != cb {
      return if ca < cb { -1 } else { 1 }
    }
  }
  if a.length() < b.length() {
    -1
  } else if a.length() > b.length() {
    1
  } else {
    0
  }
}

///|
fn tag_is_valid_name(name : String) -> Bool {
  let normalized = @bitlib.normalize_repo_path(name) catch { _ => return false }
  if normalized.length() == 0 || normalized == "HEAD" {
    return false
  }
  if normalized.has_prefix(".") || normalized.has_suffix("/") {
    return false
  }
  if normalized.contains("..") ||
    normalized.contains("@{") ||
    normalized.has_suffix(".lock") {
    return false
  }
  let components = normalized.split("/")
  for component_view in components {
    let component = component_view.to_string()
    if component.length() == 0 ||
      component.has_prefix(".") ||
      component.has_suffix(".lock") {
      return false
    }
  }
  for c in normalized {
    if c <= '\u001f' || c == '\u007f' {
      return false
    }
    if c == ' ' ||
      c == '~' ||
      c == '^' ||
      c == ':' ||
      c == '?' ||
      c == '*' ||
      c == '[' ||
      c == '\\' {
      return false
    }
  }
  true
}

///|
async fn tag_resolve_message(
  fs : OsFs,
  root : String,
  git_dir : String,
  name : String,
  annotated : Bool,
  message : String?,
  message_file : String?,
  trailers : Array[String],
  edit_message : Bool,
) -> (String, String?) raise Error {
  let from_args_base = match message {
    Some(text) => tag_cleanup_message(text)
    None =>
      match message_file {
        Some(path) => {
          let raw = if path == "-" {
            decode_bytes(read_all_stdin())
          } else if fs.is_file(path) {
            decode_bytes(fs.read_file(path))
          } else {
            raise @bitcore.GitError::InvalidObject(
              "could not read message file: " + path,
            )
          }
          tag_cleanup_message(raw)
        }
        None => ""
      }
  }
  let should_edit = edit_message ||
    (annotated && message is None && message_file is None)
  if should_edit {
    let initial_message = if from_args_base.length() > 0 {
      Some(tag_apply_trailers(from_args_base, trailers))
    } else {
      match tag_existing_message(fs, git_dir, name) {
        Some(existing) => Some(tag_apply_trailers(existing, trailers))
        None =>
          if trailers.length() > 0 {
            Some(tag_apply_trailers_for_edit("", trailers))
          } else {
            None
          }
      }
    }
    return tag_edit_message(fs, root, initial_message)
  }
  (tag_apply_trailers(from_args_base, trailers), None)
}

///|
async fn tag_edit_message(
  fs : OsFs,
  root : String,
  initial_message : String?,
) -> (String, String?) raise Error {
  let git_dir = resolve_git_dir(fs, root)
  let path = git_dir + "/TAG_EDITMSG"
  fs.write_string(path, tag_edit_buffer_template(initial_message))
  ignore(default_commit_message_editor(path))
  let edited = if fs.is_file(path) {
    decode_bytes(fs.read_file(path))
  } else {
    ""
  }
  match normalize_commit_edit_buffer(edited) {
    Some(message) => (message, Some(path))
    None => raise @bitcore.GitError::InvalidObject("no tag message?")
  }
}

///|
fn tag_edit_buffer_template(initial_message : String?) -> String {
  let sb = StringBuilder::new()
  match initial_message {
    Some(message) =>
      if message.length() > 0 {
        sb.write_string(message)
        if !message.has_suffix("\n") {
          sb.write_string("\n")
        }
        sb.write_string("\n")
      } else {
        sb.write_string("\n")
      }
    None => sb.write_string("\n")
  }
  sb.write_string("# Please enter the tag message for your changes.\n")
  sb.write_string("# Lines starting with '#' will be ignored.\n")
  sb.to_string()
}

///|
fn tag_existing_message(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  name : String,
) -> String? raise Error {
  let id = @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + name)
  guard id is Some(tag_id) else { return None }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  match db.get(fs, tag_id) {
    Some(obj) if obj.obj_type == @bitcore.ObjectType::Tag => {
      let body = tag_extract_message_body(decode_bytes(obj.data))
      if body.length() == 0 {
        None
      } else {
        Some(body)
      }
    }
    _ => None
  }
}

///|
fn tag_extract_message_body(text : String) -> String {
  match text.find("\n\n") {
    Some(idx) => {
      let body = String::unsafe_substring(
        text,
        start=idx + 2,
        end=text.length(),
      )
      if body.has_suffix("\n") {
        String::unsafe_substring(body, start=0, end=body.length() - 1)
      } else {
        body
      }
    }
    None => ""
  }
}

///|
fn tag_cleanup_message(raw : String) -> String {
  let lines : Array[String] = []
  for line_view in raw.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("#") {
      continue
    }
    lines.push(line.trim_end(chars=" \t\r").to_string())
  }
  let compact : Array[String] = []
  let mut previous_blank = false
  for line in lines {
    let blank = line.trim().to_string().length() == 0
    if blank {
      if !previous_blank {
        compact.push("")
      }
      previous_blank = true
    } else {
      compact.push(line)
      previous_blank = false
    }
  }
  let mut start = 0
  while start < compact.length() && compact[start].length() == 0 {
    start += 1
  }
  if start >= compact.length() {
    return ""
  }
  let mut end = compact.length() - 1
  while end >= start && compact[end].length() == 0 {
    end -= 1
  }
  let cleaned : Array[String] = []
  for i in start..<=end {
    cleaned.push(compact[i])
  }
  cleaned.join("\n")
}

///|
fn tag_reflog_message(
  short_id : String,
  subject : String,
  date : String,
) -> String {
  "tag: tagging \{short_id} (\{subject}, \{date})"
}

///|
fn tag_nested_advice_lines(name : String, target_ref : String) -> Array[String] {
  [
    "hint: You have created a nested tag. The object referred to by your new tag is",
    "hint: already a tag. If you meant to tag the object that it points to, use:",
    "hint:",
    "hint: \tgit tag -f \{name} \{target_ref}^{}",
    "hint: Disable this message with \"git config set advice.nestedTag false\"",
  ]
}

///|
async fn tag_maybe_print_nested_advice(
  fs : OsFs,
  git_dir : String,
  name : String,
  target_ref : String,
  target_id : @bitcore.ObjectId,
) -> Unit raise Error {
  guard tag_should_show_nested_advice(fs, git_dir) else { return }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  match db.get(fs, target_id) {
    Some(obj) if obj.obj_type == @bitcore.ObjectType::Tag =>
      for line in tag_nested_advice_lines(name, target_ref) {
        eprint_line(line)
      }
    _ => ()
  }
}

///|
fn tag_should_show_nested_advice(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Bool {
  match get_config_override("advice.nestedTag") {
    Some(value) => tag_parse_bool(value).unwrap_or(true)
    None =>
      @bitlib.read_config_bool(fs, git_dir + "/config", "advice", "nestedtag").unwrap_or(
        true,
      )
  }
}

///|
fn tag_parse_bool(value : String) -> Bool? {
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
fn tag_commit_subject_and_date(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  target : @bitcore.ObjectId,
) -> (String, String) raise Error {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  match db.get(fs, target) {
    Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit => {
      let subject = tag_extract_commit_subject(obj.data)
      let (ts, tz) = tag_extract_commit_committer_time(obj.data)
      (subject, format_timestamp_short(ts, tz))
    }
    _ => ("", format_timestamp_short(0L, "+0000"))
  }
}

///|
fn tag_extract_commit_subject(data : Bytes) -> String {
  let text = decode_bytes(data)
  match text.find("\n\n") {
    Some(idx) => {
      let body = String::unsafe_substring(
        text,
        start=idx + 2,
        end=text.length(),
      )
      for line_view in body.split("\n") {
        let line = line_view.to_string()
        if line.length() > 0 {
          return line
        }
      }
      ""
    }
    None => ""
  }
}

///|
fn tag_extract_commit_committer_time(data : Bytes) -> (Int64, String) {
  let text = decode_bytes(data)
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("committer ") {
      let identity = String::unsafe_substring(line, start=10, end=line.length())
      let tz_idx = identity.rev_find(" ").unwrap_or(identity.length())
      let before_tz = String::unsafe_substring(identity, start=0, end=tz_idx)
      let ts_idx = before_tz.rev_find(" ").unwrap_or(before_tz.length())
      let ts = if ts_idx < before_tz.length() {
        @string.parse_int64(
          String::unsafe_substring(
            before_tz,
            start=ts_idx + 1,
            end=before_tz.length(),
          ),
        ) catch {
          _ => 0L
        }
      } else {
        0L
      }
      let tz = if tz_idx < identity.length() {
        String::unsafe_substring(
          identity,
          start=tz_idx + 1,
          end=identity.length(),
        )
      } else {
        "+0000"
      }
      return (ts, tz)
    }
  }
  (0L, "+0000")
}

///|
fn tag_maybe_append_reflog(
  fs : OsFs,
  git_dir : String,
  name : String,
  target : @bitcore.ObjectId,
  tagger : String,
  timestamp : Int64,
  timezone : String,
  create_reflog : Bool,
) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let wfs : &@bitcore.FileSystem = fs
  let refname = "refs/tags/" + name
  let new_id = @bitlib.resolve_ref(rfs, git_dir, refname).unwrap_or(
    @bitcore.ObjectId::zero(),
  )
  let (_should_log, always) = @bitrepo.should_log_ref(
    rfs, git_dir, refname, false,
  )
  if create_reflog {
    @bitrepo.create_reflog(wfs, rfs, git_dir, refname)
  }
  if !create_reflog && !always && !@bitrepo.reflog_exists(rfs, git_dir, refname) {
    return
  }
  let name_end = tagger.find(" <").unwrap_or(tagger.length())
  let author = String::unsafe_substring(tagger, start=0, end=name_end)
  let email = match tagger.find("<") {
    Some(start) =>
      match tagger.find(">") {
        Some(end) if end > start =>
          String::unsafe_substring(tagger, start=start + 1, end~)
        _ => "unknown"
      }
    None => "unknown"
  }
  let (subject, date) = tag_commit_subject_and_date(rfs, git_dir, target)
  let short_id = String::unsafe_substring(target.to_hex(), start=0, end=7)
  let msg = tag_reflog_message(short_id, subject, date)
  @bitrepo.append_reflog(
    wfs,
    rfs,
    git_dir,
    refname,
    @bitcore.ObjectId::zero(),
    new_id,
    author,
    email,
    timestamp,
    timezone,
    msg,
  )
}

///|
fn tag_points_at_object(
  fs : OsFs,
  db : @bitlib.ObjectDb,
  tag_id : @bitcore.ObjectId,
  target_id : @bitcore.ObjectId,
) -> Bool {
  let target_hex = target_id.to_hex()
  let mut current_id = tag_id
  for _ in 0..<100 {
    if current_id.to_hex() == target_hex {
      return true
    }
    let obj = db.get(fs, current_id) catch { _ => None }
    match obj {
      Some(o) =>
        if o.obj_type == @bitcore.ObjectType::Tag {
          let text = decode_bytes(o.data)
          let mut next_hex = ""
          for line_view in text.split("\n") {
            let line = line_view.to_string()
            if line.has_prefix("object ") {
              next_hex = String::unsafe_substring(
                line,
                start=7,
                end=line.length(),
              )
              break
            }
            if line == "" {
              break
            }
          }
          if next_hex == "" {
            return false
          }
          current_id = @bitcore.ObjectId::from_hex(next_hex) catch {
            _ => return false
          }
        } else {
          return false
        }
      None => return false
    }
  }
  false
}

///|
fn tag_peel_to_commit(
  fs : &@bitcore.RepoFileSystem,
  db : @bitlib.ObjectDb,
  id : @bitcore.ObjectId,
) -> @bitcore.ObjectId? {
  let mut current_id = id
  for _ in 0..<100 {
    let obj = db.get(fs, current_id) catch { _ => None }
    match obj {
      Some(o) =>
        match o.obj_type {
          @bitcore.ObjectType::Commit => return Some(current_id)
          @bitcore.ObjectType::Tag => {
            let text = decode_bytes(o.data)
            let mut next_hex = ""
            for line_view in text.split("\n") {
              let line = line_view.to_string()
              if line.has_prefix("object ") {
                next_hex = String::unsafe_substring(
                  line,
                  start=7,
                  end=line.length(),
                )
                break
              }
              if line == "" {
                break
              }
            }
            if next_hex == "" {
              return None
            }
            current_id = @bitcore.ObjectId::from_hex(next_hex) catch {
              _ => return None
            }
          }
          _ => return None
        }
      None => return None
    }
  }
  None
}

///|
fn tag_is_ancestor(
  fs : OsFs,
  db : @bitlib.ObjectDb,
  ancestor_id : @bitcore.ObjectId,
  descendant_id : @bitcore.ObjectId,
) -> Bool {
  @bitlib.merge_base_is_ancestor(db, fs, ancestor_id, descendant_id) catch {
    _ => false
  }
}

///|
fn tag_apply_list_filters(
  fs : OsFs,
  git_dir : String,
  db : @bitlib.ObjectDb,
  filtered : Array[(String, String, @bitcore.ObjectId)],
  merged : String?,
  no_merged : String?,
  contains : String?,
  no_contains : String?,
) -> Unit raise Error {
  if merged is None &&
    no_merged is None &&
    contains is None &&
    no_contains is None {
    return
  }
  let merged_id = tag_resolve_filter_commit(fs, git_dir, merged)
  let no_merged_id = tag_resolve_filter_commit(fs, git_dir, no_merged)
  let contains_id = tag_resolve_filter_commit(fs, git_dir, contains)
  let no_contains_id = tag_resolve_filter_commit(fs, git_dir, no_contains)
  match (merged_id, no_merged_id) {
    (Some(mid), Some(nmid)) if mid.to_hex() == nmid.to_hex() => {
      filtered.clear()
      return
    }
    _ => ()
  }
  let out : Array[(String, String, @bitcore.ObjectId)] = []
  for item in filtered {
    let (_, _, ref_id) = item
    let commit_id = tag_peel_to_commit(fs, db, ref_id)
    guard commit_id is Some(cid) else { continue }
    match merged_id {
      Some(mid) => if !tag_is_ancestor(fs, db, cid, mid) { continue }
      None => ()
    }
    match no_merged_id {
      Some(mid) => if tag_is_ancestor(fs, db, cid, mid) { continue }
      None => ()
    }
    match contains_id {
      Some(ancestor) => if !tag_is_ancestor(fs, db, ancestor, cid) { continue }
      None => ()
    }
    match no_contains_id {
      Some(ancestor) => if tag_is_ancestor(fs, db, ancestor, cid) { continue }
      None => ()
    }
    out.push(item)
  }
  filtered.clear()
  for item in out {
    filtered.push(item)
  }
}

///|
fn tag_resolve_filter_commit(
  fs : OsFs,
  git_dir : String,
  rev : String?,
) -> @bitcore.ObjectId? raise Error {
  match rev {
    Some(value) => {
      let db = @bitlib.ObjectDb::load(fs, git_dir)
      let resolved = @bitrepo.rev_parse(fs, git_dir, value)
      guard resolved is Some(id) else {
        raise @bitcore.GitError::InvalidObject("unknown revision: \{value}")
      }
      guard tag_peel_to_commit(fs, db, id) is Some(commit_id) else {
        raise @bitcore.GitError::InvalidObject("not a commit object: " + value)
      }
      Some(commit_id)
    }
    None => None
  }
}

///|
fn tag_effective_sort_keys(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  cli_sort_keys : Array[String],
  disable_config_sort : Bool,
) -> Array[String] {
  if cli_sort_keys.length() > 0 {
    return cli_sort_keys
  }
  if disable_config_sort {
    return []
  }
  let config_path = git_dir + "/config"
  match @bitlib.read_config_value(fs, config_path, "tag", "sort") {
    Some(value) if value.length() > 0 => [value]
    _ => []
  }
}

///|
fn tag_validate_sort_keys(sort_keys : Array[String]) -> Unit raise Error {
  for key in sort_keys {
    let sort_field = if key.has_prefix("-") {
      String::unsafe_substring(key, start=1, end=key.length())
    } else {
      key
    }
    if !tag_is_valid_sort_field(sort_field) {
      raise @bitcore.GitError::InvalidObject(
        "unsupported sort specification: " + sort_field,
      )
    }
  }
}

///|
fn tag_is_valid_sort_field(field : String) -> Bool {
  let normalized = tag_normalize_sort_field(field)
  normalized == "refname" ||
  normalized == "refname:short" ||
  normalized == "objecttype" ||
  normalized == "version:refname" ||
  normalized == "v:refname" ||
  normalized.has_prefix("creatordate") ||
  normalized.has_prefix("authordate") ||
  normalized.has_prefix("committerdate") ||
  normalized.has_prefix("taggerdate")
}

///|
fn tag_normalize_sort_field(field : String) -> String {
  match field {
    "tag" => "refname"
    "version:tag" => "version:refname"
    "v:tag" => "v:refname"
    _ => field
  }
}

///|
fn tag_compare_ref_items(
  fs : OsFs,
  git_dir : String,
  a : (String, String, @bitcore.ObjectId),
  b : (String, String, @bitcore.ObjectId),
  field : String,
  ignore_case : Bool,
  version_suffixes : Array[String],
) -> Int {
  let normalized = tag_normalize_sort_field(field)
  match normalized {
    "refname" | "refname:short" | "version:refname" | "v:refname" =>
      tag_sort_compare(a.0, b.0, normalized, ignore_case, version_suffixes~)
    _ =>
      for_each_ref_compare(
        fs,
        git_dir,
        (a.1, a.2),
        (b.1, b.2),
        normalized,
        ignore_case,
      )
  }
}

///|
fn tag_glob_match(pattern : String, text : String, ignore_case : Bool) -> Bool {
  let p = if ignore_case { pattern.to_lower() } else { pattern }
  let t = if ignore_case { text.to_lower() } else { text }
  tag_glob_match_impl(p, t)
}

///|
fn tag_glob_match_impl(pattern : String, text : String) -> Bool {
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
fn tag_sort_compare(
  a : String,
  b : String,
  field : String,
  ignore_case : Bool,
  version_suffixes? : Array[String] = [],
) -> Int {
  match field {
    "refname" | "refname:short" => tag_default_compare(a, b, ignore_case)
    _ if field.has_prefix("version:refname") || field == "v:refname" =>
      if version_suffixes.length() == 0 {
        tag_version_compare(a, b)
      } else {
        tag_version_compare_with_suffixes(a, b, version_suffixes)
      }
    _ => tag_default_compare(a, b, ignore_case)
  }
}

///|
fn tag_version_compare(a : String, b : String) -> Int {
  tag_version_compare_with_suffixes(a, b, [])
}

///|
fn tag_versionsort_parse_config_text(
  text : String,
) -> (Array[String], Array[String], Bool, Bool) {
  let suffix_values : Array[String] = []
  let prerelease_values : Array[String] = []
  let mut missing_suffix = false
  let mut missing_prerelease = false
  let mut in_versionsort = false
  for line_view in text.split("\n") {
    let trimmed = trim_string(line_view.to_string())
    if trimmed.has_prefix("[") && trimmed.has_suffix("]") {
      let section = String::unsafe_substring(
        trimmed,
        start=1,
        end=trimmed.length() - 1,
      )
      in_versionsort = section.to_lower() == "versionsort"
    } else if in_versionsort &&
      trimmed.length() > 0 &&
      !trimmed.has_prefix("#") &&
      !trimmed.has_prefix(";") {
      match trimmed.find("=") {
        Some(idx) => {
          let key = trim_string(
            String::unsafe_substring(trimmed, start=0, end=idx),
          ).to_lower()
          let value = trim_string(
            String::unsafe_substring(
              trimmed,
              start=idx + 1,
              end=trimmed.length(),
            ),
          )
          if key == "suffix" {
            suffix_values.push(value)
          } else if key == "prereleasesuffix" {
            prerelease_values.push(value)
          }
        }
        None => {
          let key = trimmed.to_lower()
          if key == "suffix" {
            missing_suffix = true
          } else if key == "prereleasesuffix" {
            missing_prerelease = true
          }
        }
      }
    }
  }
  (suffix_values, prerelease_values, missing_suffix, missing_prerelease)
}

///|
fn tag_versionsort_suffixes(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> (Array[String], Bool, Bool) {
  let config_path = git_dir + "/config"
  guard fs.is_file(config_path) else { return ([], false, false) }
  let content = fs.read_file(config_path) catch {
    _ => return ([], false, false)
  }
  let (suffix_values, prerelease_values, missing_suffix, missing_prerelease) = tag_versionsort_parse_config_text(
    decode_bytes(content),
  )
  if suffix_values.length() > 0 {
    (suffix_values, missing_suffix, missing_prerelease)
  } else {
    (prerelease_values, missing_suffix, missing_prerelease)
  }
}

///|
fn tag_version_is_digit(code : Int) -> Bool {
  code >= '0'.to_int() && code <= '9'.to_int()
}

///|
fn tag_version_char_kind(code : Int) -> Int {
  if code == '0'.to_int() {
    2
  } else if tag_version_is_digit(code) {
    1
  } else {
    0
  }
}

///|
fn tag_version_char_at(chars : Array[Char], idx : Int) -> Int {
  if idx < chars.length() {
    chars[idx].to_int()
  } else {
    0
  }
}

///|
fn tag_versionsort_starts_with_at(
  name : String,
  suffix : String,
  start : Int,
) -> Bool {
  if start < 0 || start + suffix.length() > name.length() {
    return false
  }
  String::unsafe_substring(name, start~, end=start + suffix.length()) == suffix
}

///|
fn tag_versionsort_best_match(
  name : String,
  suffixes : Array[String],
  off : Int,
) -> Int? {
  let mut conf_pos = -1
  let mut match_start = off
  let mut match_len = -1
  for i in 0..<suffixes.length() {
    let suffix = suffixes[i]
    let suffix_len = suffix.length()
    let start = if suffix_len < off { off - suffix_len } else { 0 }
    let end = if match_len < suffix_len { match_start } else { match_start - 1 }
    let mut pos = start
    while pos <= end {
      if tag_versionsort_starts_with_at(name, suffix, pos) {
        conf_pos = i
        match_start = pos
        match_len = suffix_len
        break
      }
      pos += 1
    }
  }
  if conf_pos >= 0 {
    Some(conf_pos)
  } else {
    None
  }
}

///|
fn tag_versionsort_swap_suffixes(
  s1 : String,
  s2 : String,
  off : Int,
  suffixes : Array[String],
) -> Int? {
  let match1 = tag_versionsort_best_match(s1, suffixes, off)
  let match2 = tag_versionsort_best_match(s2, suffixes, off)
  match (match1, match2) {
    (None, None) => None
    (Some(pos1), Some(pos2)) =>
      if pos1 == pos2 {
        None
      } else {
        Some(pos1 - pos2)
      }
    (Some(_), None) => Some(-1)
    (None, Some(_)) => Some(1)
  }
}

///|
fn tag_version_compare_with_suffixes(
  a : String,
  b : String,
  suffixes : Array[String],
) -> Int {
  if a == b {
    return 0
  }
  let next_state = [0, 3, 9, 0, 3, 3, 0, 6, 6, 0, 6, 9]
  let result_type = [
    2, 2, 2, 2, 3, 2, 2, 2, 2, 2, -1, -1, 1, 3, 3, 1, 3, 3, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 1, 1, -1, 2, 2, -1, 2, 2,
  ]
  let a_chars = a.to_array()
  let b_chars = b.to_array()
  let mut i1 = 1
  let mut i2 = 1
  let mut c1 = tag_version_char_at(a_chars, 0)
  let mut c2 = tag_version_char_at(b_chars, 0)
  let mut state = tag_version_char_kind(c1)
  let mut diff = c1 - c2
  while diff == 0 {
    if c1 == 0 {
      return 0
    }
    state = next_state[state]
    c1 = tag_version_char_at(a_chars, i1)
    c2 = tag_version_char_at(b_chars, i2)
    i1 += 1
    i2 += 1
    state += tag_version_char_kind(c1)
    diff = c1 - c2
  }
  let off = i1 - 1
  match tag_versionsort_swap_suffixes(a, b, off, suffixes) {
    Some(suffix_diff) => return suffix_diff
    None => ()
  }
  let kind2 = tag_version_char_kind(c2)
  let result = result_type[state * 3 + kind2]
  match result {
    2 => diff
    3 => {
      while tag_version_is_digit(tag_version_char_at(a_chars, i1)) {
        if !tag_version_is_digit(tag_version_char_at(b_chars, i2)) {
          return 1
        }
        i1 += 1
        i2 += 1
      }
      if tag_version_is_digit(tag_version_char_at(b_chars, i2)) {
        -1
      } else {
        diff
      }
    }
    _ => result
  }
}

///|
