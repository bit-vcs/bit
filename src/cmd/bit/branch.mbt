///|
/// Branch handlers: branch, checkout, switch, reset, rebase, stash, cherry-pick
async fn handle_branch(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = if rfs.is_file(git_dir) {
    @bitlib.resolve_gitdir(rfs, git_dir)
  } else {
    git_dir
  }
  let mut list_mode = true
  let mut new_branch : String? = None
  let mut delete_branch : String? = None
  let mut rename_from : String? = None
  let mut rename_to : String? = None
  let mut rename_current = false
  let mut rename_force = false
  let mut force_delete = false
  let mut force_create = false
  let mut show_all = false
  let mut show_remotes = false
  let mut verbose = false
  let mut column_mode : String? = None
  let mut set_upstream_to : String? = None
  let mut track_upstream = false
  let mut start_point : String? = None
  let mut merged_filter : String? = None
  let mut no_merged_filter : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-m" | "-M" => {
        rename_force = arg == "-M"
        list_mode = false
        let mut base = i + 1
        if base < args.length() &&
          (args[base] == "-f" || args[base] == "--force") {
          rename_force = true
          base += 1
        }
        if base + 1 < args.length() {
          rename_from = Some(args[base])
          rename_to = Some(args[base + 1])
          i = base + 2
          continue
        }
        if base < args.length() {
          rename_current = true
          rename_to = Some(args[base])
          i = base + 1
          continue
        }
        @stdio.stderr.write("error: branch name required\n")
        @sys.exit(128)
        return
      }
      "-d" | "--delete" if i + 1 < args.length() => {
        delete_branch = Some(args[i + 1])
        list_mode = false
        i += 2
        continue
      }
      "-D" if i + 1 < args.length() => {
        force_delete = true
        delete_branch = Some(args[i + 1])
        list_mode = false
        i += 2
        continue
      }
      "-f" | "--force" => force_create = true
      "-a" | "--all" => show_all = true
      "-r" | "--remotes" => show_remotes = true
      "-v" | "--verbose" => verbose = true
      "--column" => column_mode = Some("always")
      "--no-column" => column_mode = Some("never")
      _ if arg.has_prefix("--column=") =>
        column_mode = Some(
          String::unsafe_substring(arg, start=9, end=arg.length()),
        )
      "-t" | "--track" => {
        track_upstream = true
        list_mode = false
        i += 1
        continue
      }
      "--set-upstream-to" if i + 1 < args.length() => {
        set_upstream_to = Some(args[i + 1])
        list_mode = false
        i += 2
        continue
      }
      _ if arg.has_prefix("--set-upstream-to=") => {
        let value = String::unsafe_substring(arg, start=18, end=arg.length())
        set_upstream_to = Some(value)
        list_mode = false
        i += 1
        continue
      }
      "--merged" if i + 1 < args.length() && !(args[i + 1].has_prefix("-")) => {
        merged_filter = Some(args[i + 1])
        i += 2
        continue
      }
      "--merged" => merged_filter = Some("HEAD")
      "--no-merged" if i + 1 < args.length() && !(args[i + 1].has_prefix("-")) => {
        no_merged_filter = Some(args[i + 1])
        i += 2
        continue
      }
      "--no-merged" => no_merged_filter = Some("HEAD")
      _ if arg.has_prefix("--merged=") =>
        merged_filter = Some(
          String::unsafe_substring(arg, start=9, end=arg.length()),
        )
      _ if arg.has_prefix("--no-merged=") =>
        no_merged_filter = Some(
          String::unsafe_substring(arg, start=12, end=arg.length()),
        )
      _ if !(arg.has_prefix("-")) => {
        if new_branch is None {
          new_branch = Some(arg)
        } else if start_point is None {
          start_point = Some(arg)
        }
        list_mode = false
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("branch", arg)
      _ => ()
    }
    i += 1
  }
  let config_path = git_dir + "/config"
  let column_ui = branch_last_config_value(fs, config_path, "column", "ui")
  let column_branch = branch_last_config_value(
    fs, config_path, "column", "branch",
  )
  let (column_active, column_dense, explicit_column_enabled) = branch_resolve_column_mode(
    column_mode, verbose, column_ui, column_branch,
  )
  if verbose && explicit_column_enabled {
    @stdio.stderr.write(
      "fatal: options '--column' and '--verbose' cannot be used together\n",
    )
    @sys.exit(128)
    return
  }
  match set_upstream_to {
    Some(upstream) => {
      let branch_name = match new_branch {
        Some(n) => n
        None => get_current_branch(fs, git_dir)
      }
      let mut remote_name = "origin"
      let mut merge_ref = upstream
      if upstream.has_prefix("refs/") {
        merge_ref = upstream
      } else {
        match upstream.find("/") {
          Some(idx) => {
            remote_name = String::unsafe_substring(upstream, start=0, end=idx)
            let name = String::unsafe_substring(
              upstream,
              start=idx + 1,
              end=upstream.length(),
            )
            merge_ref = normalize_local_branch_ref(name)
          }
          None => merge_ref = normalize_local_branch_ref(upstream)
        }
      }
      @bitlib.set_config_key(
        fs, fs, git_dir, "branch", branch_name, "remote", remote_name,
      )
      @bitlib.set_config_key(
        fs, fs, git_dir, "branch", branch_name, "merge", merge_ref,
      )
      return
    }
    None => ()
  }
  match delete_branch {
    Some(name) => {
      @bitlib.delete_branch(fs, fs, root, name, force=force_delete)
      print_line("Deleted branch \{name}")
    }
    None =>
      match rename_from {
        Some(from_name) =>
          match rename_to {
            Some(to_name) =>
              if from_name == to_name {
                ()
              } else {
                let (author, email, timestamp, timezone) = branch_get_committer_identity()
                @bitlib.rename_branch(
                  fs,
                  fs,
                  root,
                  from_name,
                  to_name,
                  force=rename_force,
                  author~,
                  email~,
                  timestamp~,
                  timezone~,
                )
              }
            None => ()
          }
        None =>
          if rename_current {
            match rename_to {
              Some(to_name) => {
                let current = get_current_branch(fs, git_dir)
                if current != to_name {
                  let (author, email, timestamp, timezone) = branch_get_committer_identity()
                  @bitlib.rename_branch(
                    fs,
                    fs,
                    root,
                    current,
                    to_name,
                    force=rename_force,
                    author~,
                    email~,
                    timestamp~,
                    timezone~,
                  )
                }
              }
              None => ()
            }
          } else {
            match new_branch {
              Some(name) => {
                if name == "HEAD" {
                  @stdio.stderr.write(
                    "fatal: 'HEAD' is not a valid branch name",
                  )
                  @sys.exit(1)
                }
                let refname = normalize_local_branch_ref(name)
                if !(force_create) &&
                  @bitlib.resolve_ref(fs, git_dir, refname) is Some(_) {
                  @stdio.stderr.write(
                    "fatal: a branch named '\{name}' already exists",
                  )
                  @sys.exit(1)
                }
                match start_point {
                  Some(sp) => {
                    let commit_id = branch_resolve_start_point(fs, git_dir, sp)
                    guard commit_id is Some(id) else {
                      raise @bitcore.GitError::InvalidObject(
                        "unknown revision: \{sp}",
                      )
                    }
                    @bitlib.create_branch_at(
                      fs,
                      fs,
                      root,
                      name,
                      id,
                      start_point=Some(sp),
                    )
                  }
                  None => @bitlib.create_branch(fs, fs, root, name)
                }
                if track_upstream {
                  let upstream = match start_point {
                    Some(sp) => sp
                    None => "origin/" + name
                  }
                  let mut remote_name = "origin"
                  let mut merge_ref = upstream
                  if upstream.has_prefix("refs/") {
                    merge_ref = upstream
                  } else {
                    match upstream.find("/") {
                      Some(idx) => {
                        remote_name = String::unsafe_substring(
                          upstream,
                          start=0,
                          end=idx,
                        )
                        let up_name = String::unsafe_substring(
                          upstream,
                          start=idx + 1,
                          end=upstream.length(),
                        )
                        merge_ref = normalize_local_branch_ref(up_name)
                      }
                      None => merge_ref = normalize_local_branch_ref(upstream)
                    }
                  }
                  @bitlib.set_config_key(
                    fs, fs, git_dir, "branch", name, "remote", remote_name,
                  )
                  @bitlib.set_config_key(
                    fs, fs, git_dir, "branch", name, "merge", merge_ref,
                  )
                }
              }
              None =>
                if list_mode {
                  // List local branches
                  if !(show_remotes) {
                    if merged_filter is Some(_) || no_merged_filter is Some(_) {
                      branch_list_with_merge_filter(
                        fs, git_dir, verbose, merged_filter, no_merged_filter,
                      )
                    } else {
                      let lines = if verbose {
                        @bitlib.list_branches_verbose(fs, git_dir)
                      } else {
                        @bitlib.list_branches_text(fs, git_dir)
                      }
                      let output_lines = if column_active && !(verbose) {
                        branch_format_columns(
                          lines,
                          branch_term_columns(),
                          dense=column_dense,
                        )
                      } else {
                        lines
                      }
                      for line in output_lines {
                        print_line(line)
                      }
                    }
                  }
                  // List remote branches
                  if show_all || show_remotes {
                    let remotes = @bitlib.list_remote_branches(fs, git_dir)
                    for line in remotes {
                      print_line(line)
                    }
                  }
                }
            }
          }
      }
  }
}

///|
async fn branch_list_with_merge_filter(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  verbose : Bool,
  merged_filter : String?,
  no_merged_filter : String?,
) -> Unit raise Error {
  let (head, branches) = @bitlib.list_branches(fs, git_dir)
  // Resolve target commit for merged/no-merged check
  let target_id : @bitcore.ObjectId? = match merged_filter {
    Some(spec) =>
      if spec == "HEAD" {
        @bitlib.resolve_head_commit(fs, git_dir)
      } else {
        @bitrepo.rev_parse(fs, git_dir, spec)
      }
    None =>
      match no_merged_filter {
        Some(spec) =>
          if spec == "HEAD" {
            @bitlib.resolve_head_commit(fs, git_dir)
          } else {
            @bitrepo.rev_parse(fs, git_dir, spec)
          }
        None => @bitlib.resolve_head_commit(fs, git_dir)
      }
  }
  guard target_id is Some(tid) else { return }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  // Find max name length for verbose padding
  let mut max_len = 0
  if verbose {
    for b in branches {
      if b.name.length() > max_len {
        max_len = b.name.length()
      }
    }
  }
  for b in branches {
    let is_merged = @bitlib.is_ancestor_of(fs, git_dir, b.id, tid)
    let should_show = match (merged_filter, no_merged_filter) {
      (Some(_), _) => is_merged
      (_, Some(_)) => !(is_merged)
      _ => true
    }
    if !(should_show) {
      continue
    }
    if verbose {
      let marker = match head {
        @bitlib.HeadRef::Branch(name) =>
          if name == b.name {
            "* "
          } else {
            "  "
          }
        @bitlib.HeadRef::Detached(_) => "  "
      }
      let short_hash = string_slice_to(b.id.to_hex(), 7)
      let subject = branch_get_commit_subject(db, fs, b.id)
      let padded_name = branch_pad_right(b.name, max_len)
      print_line("\{marker}\{padded_name} \{short_hash} \{subject}")
    } else {
      let mark = if b.current { "*" } else { " " }
      print_line("\{mark} \{b.name}")
    }
  }
}

///|
fn branch_get_commit_subject(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> String {
  let obj = db.get(fs, id) catch { _ => return "" }
  match obj {
    None => ""
    Some(o) => {
      if o.obj_type != @bitcore.ObjectType::Commit {
        return ""
      }
      let text = @utf8.decode_lossy(o.data[:])
      let mut in_header = true
      for line_view in text.split("\n") {
        let line = line_view.to_string()
        if in_header {
          if line.length() == 0 {
            in_header = false
          }
          continue
        }
        if line.length() > 0 {
          return line
        }
      }
      ""
    }
  }
}

///|
fn branch_pad_right(s : String, width : Int) -> String {
  if s.length() >= width {
    return s
  }
  let buf = StringBuilder::new()
  buf.write_string(s)
  for i = s.length(); i < width; i = i + 1 {
    buf.write_char(' ')
  }
  buf.to_string()
}

///|
fn branch_last_config_value(
  fs : &@bitcore.RepoFileSystem,
  config_path : String,
  section : String,
  key : String,
) -> String? {
  let values = @bitlib.read_config_values(fs, config_path, section, key)
  values.last()
}

///|
fn branch_parse_column_tokens(value : String) -> Array[String] {
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
fn branch_apply_column_mode(
  enabled_state : String,
  dense : Bool,
  value : String,
) -> (String, Bool) raise @bitcore.GitError {
  let mut next_enabled_state = enabled_state
  let mut next_dense = dense
  let mut saw_enable = false
  let mut saw_layout = false
  for token in branch_parse_column_tokens(value) {
    match token {
      "always" | "yes" => {
        next_enabled_state = "enabled"
        saw_enable = true
      }
      "never" | "no" => {
        next_enabled_state = "disabled"
        saw_enable = true
      }
      "auto" => {
        next_enabled_state = "auto"
        saw_enable = true
      }
      "column" => saw_layout = true
      "dense" => next_dense = true
      "nodense" => next_dense = false
      _ =>
        raise @bitcore.GitError::InvalidObject("unsupported option '\{token}'")
    }
  }
  if saw_layout && !(saw_enable) {
    next_enabled_state = "enabled"
  }
  (next_enabled_state, next_dense)
}

///|
fn branch_resolve_column_mode(
  cli_mode : String?,
  verbose : Bool,
  column_ui : String?,
  column_branch : String?,
) -> (Bool, Bool, Bool) raise @bitcore.GitError {
  let mut enabled_state = "disabled"
  let mut dense = false
  if !(verbose) {
    match column_ui {
      Some(value) => {
        let (next_enabled_state, next_dense) = branch_apply_column_mode(
          enabled_state, dense, value,
        )
        enabled_state = next_enabled_state
        dense = next_dense
      }
      None => ()
    }
    match column_branch {
      Some(value) => {
        let (next_enabled_state, next_dense) = branch_apply_column_mode(
          enabled_state, dense, value,
        )
        enabled_state = next_enabled_state
        dense = next_dense
      }
      None => ()
    }
  }
  let mut explicit_column_enabled = false
  match cli_mode {
    Some(value) => {
      let (next_enabled_state, next_dense) = branch_apply_column_mode(
        enabled_state, dense, value,
      )
      enabled_state = next_enabled_state
      dense = next_dense
      explicit_column_enabled = enabled_state == "enabled"
    }
    None => ()
  }
  (enabled_state == "enabled", dense, explicit_column_enabled)
}

///|
fn branch_term_columns() -> Int {
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
fn branch_column_linear_index(rows : Int, cols : Int, x : Int, y : Int) -> Int {
  ignore(cols)
  x * rows + y
}

///|
fn branch_column_widths(
  lengths : Array[Int],
  rows : Int,
  cols : Int,
) -> Array[Int] {
  let widths = Array::make(cols, 0)
  for x in 0..<cols {
    let mut width = 0
    for y in 0..<rows {
      let idx = branch_column_linear_index(rows, cols, x, y)
      if idx < lengths.length() {
        width = width.max(lengths[idx])
      }
    }
    widths[x] = width
  }
  widths
}

///|
fn branch_format_columns(
  items : Array[String],
  term_columns : Int,
  dense? : Bool = false,
) -> Array[String] {
  let lines : Array[String] = []
  if items.length() == 0 {
    return lines
  }
  let padding = 1
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
      let next_widths = branch_column_widths(lengths, next_rows, next_cols)
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
    widths = branch_column_widths(lengths, rows, cols)
  }
  for y in 0..<rows {
    let mut line = ""
    for x in 0..<cols {
      let idx = branch_column_linear_index(rows, cols, x, y)
      if idx >= items.length() {
        break
      }
      line += items[idx]
      let newline = x == cols - 1 || idx + rows >= items.length()
      if !(newline) {
        let cell_width = widths[x] + padding
        line += " ".repeat(cell_width - lengths[idx])
      }
    }
    lines.push(line)
  }
  lines
}

///|
fn branch_parse_merge_base_specs(spec : String) -> (String, String)? {
  match spec.find("...") {
    Some(idx) => {
      let left = String::unsafe_substring(spec, start=0, end=idx)
      let right = String::unsafe_substring(
        spec,
        start=idx + 3,
        end=spec.length(),
      )
      Some(
        (
          if left.length() == 0 {
            "HEAD"
          } else {
            left
          },
          if right.length() == 0 {
            "HEAD"
          } else {
            right
          },
        ),
      )
    }
    None => None
  }
}

///|
async fn branch_resolve_start_point(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> @bitcore.ObjectId? raise Error {
  match branch_parse_merge_base_specs(spec) {
    Some((left_spec, right_spec)) => {
      let left_id = @bitrepo.rev_parse(fs, git_dir, left_spec)
      let right_id = @bitrepo.rev_parse(fs, git_dir, right_spec)
      match (left_id, right_id) {
        (Some(left), Some(right)) =>
          rev_parse_find_merge_base(fs, git_dir, left, right)
        _ => None
      }
    }
    None => @bitrepo.rev_parse(fs, git_dir, spec)
  }
}

///|
fn branch_get_committer_identity() -> (String, String, Int64, String) {
  let name = match @sys.get_env_var("GIT_COMMITTER_NAME") {
    Some(n) => n
    None => @sys.get_env_var("USER").unwrap_or("Unknown")
  }
  let email = match @sys.get_env_var("GIT_COMMITTER_EMAIL") {
    Some(e) => e
    None =>
      match @sys.get_env_var("USER") {
        Some(u) => u + "@localhost"
        None => "unknown@localhost"
      }
  }
  let timestamp = get_commit_timestamp()
  let timezone = get_commit_timezone()
  (name, email, timestamp, timezone)
}

///|
fn normalize_local_branch_ref(name : String) -> String raise @bitcore.GitError {
  let normalized = @bitlib.normalize_repo_path(name) catch {
    _ => raise @bitcore.GitError::InvalidObject("invalid branch name: " + name)
  }
  if normalized.has_prefix("refs/heads/") {
    normalized
  } else {
    "refs/heads/" + normalized
  }
}
