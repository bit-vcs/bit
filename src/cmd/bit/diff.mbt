///| Miscellaneous handlers: diff, merge, tag, rm, mv, config, sparse-checkout, rev-parse, cat-file, ls-files, hash-object, ls-tree, write-tree, show-ref, update-ref, symbolic-ref

///|
fn find_git_dir(fs : OsFs) -> String {
  // Check GIT_DIR environment variable first
  if @sys.get_env_var("GIT_DIR") is Some(dir) {
    if fs.is_dir(dir) || fs.is_file(dir) {
      return dir
    }
  }
  // Check if current directory is a .git directory (bare repo or inside .git)
  let cwd = get_work_root()
  if fs.is_file(cwd + "/config") &&
    fs.is_file(cwd + "/HEAD") &&
    fs.is_dir(cwd + "/refs") {
    return cwd
  }
  // Check for .git subdirectory
  if fs.is_dir(cwd + "/.git") || fs.is_file(cwd + "/.git") {
    return cwd + "/.git"
  }
  // Walk up parent directories to find a bare repo or .git directory
  let mut current = cwd
  let mut last = ""
  while true {
    let parent = parent_dir(current)
    let next = if parent.length() == 0 { "." } else { parent }
    if next == current || next == last {
      break
    }
    last = current
    current = next
    // Check for bare repo
    if fs.is_file(current + "/config") &&
      fs.is_file(current + "/HEAD") &&
      fs.is_dir(current + "/refs") {
      return current
    }
    // Check for .git subdirectory
    if fs.is_dir(current + "/.git") || fs.is_file(current + "/.git") {
      return current + "/.git"
    }
  }
  // Fallback: assume .git in cwd
  cwd + "/.git"
}

///|
fn get_config_override(key : String) -> String? {
  let overrides = @sys.get_env_var("GIT_CONFIG_OVERRIDES")
  match overrides {
    Some(data) => {
      let mut found : String? = None
      for line_view in data.split("\n") {
        let line = line_view.to_string()
        match line.find("=") {
          Some(eq_idx) => {
            let k = String::unsafe_substring(line, start=0, end=eq_idx)
            // Case-insensitive comparison for config keys
            if k.to_lower() == key.to_lower() {
              found = Some(
                String::unsafe_substring(
                  line,
                  start=eq_idx + 1,
                  end=line.length(),
                ),
              )
            }
          }
          None => ()
        }
      }
      found
    }
    None => None
  }
}

///|
fn resolve_real_git_for_diff() -> String {
  match @sys.get_env_var("SHIM_REAL_GIT") {
    Some(path) =>
      if path.length() > 0 {
        path
      } else {
        @sys.get_env_var("GIT_SHIM_REAL_GIT").unwrap_or("/usr/bin/git")
      }
    None => @sys.get_env_var("GIT_SHIM_REAL_GIT").unwrap_or("/usr/bin/git")
  }
}

///|
async fn delegate_diff_to_real_git(args : Array[String]) -> Unit {
  let real_git = resolve_real_git_for_diff()
  let argv : Array[String] = ["diff"]
  for arg in args {
    argv.push(arg)
  }
  let code = @process.run(
    real_git,
    argv,
    inherit_env=true,
    stdin=@stdio.stdin,
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  @sys.exit(code)
}

///|
fn diff_last_config_value(
  fs : &@bitcore.RepoFileSystem,
  config_path : String,
  section : String,
  key : String,
) -> String? {
  let values = @bitlib.read_config_values(fs, config_path, section, key)
  values.last()
}

///|
fn diff_parse_bool_config(value : String) -> Bool? {
  match value.trim().to_string().to_lower() {
    "true" | "yes" | "on" | "1" => Some(true)
    "false" | "no" | "off" | "0" => Some(false)
    _ => None
  }
}

///|
fn diff_noprefix_enabled_from_config(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Bool {
  match get_config_override("diff.noprefix") {
    Some(value) => diff_parse_bool_config(value).unwrap_or(false)
    None => {
      let config_path = git_dir + "/config"
      match diff_last_config_value(fs, config_path, "diff", "noprefix") {
        Some(value) => diff_parse_bool_config(value).unwrap_or(false)
        None => false
      }
    }
  }
}

///|
fn diff_need_real_git(
  _fs : &@bitcore.RepoFileSystem,
  _git_dir : String,
) -> Bool {
  false
}

///|
fn diff_get_external_command(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> String? {
  match @sys.get_env_var("GIT_EXTERNAL_DIFF") {
    Some(value) if value.trim().length() > 0 =>
      return Some(value.trim().to_string())
    _ => ()
  }
  match get_config_override("diff.external") {
    Some(value) if value.trim().length() > 0 =>
      return Some(value.trim().to_string())
    _ => ()
  }
  let config_path = git_dir + "/config"
  match diff_last_config_value(fs, config_path, "diff", "external") {
    Some(value) if value.trim().length() > 0 => Some(value.trim().to_string())
    _ => None
  }
}

///|
async fn diff_run_external(
  external_cmd : String,
  root : String,
  files : Array[@bitdiff.DiffFile],
) -> Unit raise Error {
  let zero_oid = diff_index_zero_oid_hex()
  let ts = get_current_timestamp().to_string()
  let mut counter = 0
  for file in files {
    let path = file.path
    let old_mode = diff_index_mode_string(file.old_mode)
    let new_mode = diff_index_mode_string(file.new_mode)
    let old_hex = diff_index_content_oid_string(file.old_content)
    let new_hex = diff_index_content_oid_string(file.new_content)
    // Create temp files for old and new content
    let tmp_base = "/tmp/bit-ext-diff-" + ts + "-" + counter.to_string()
    counter += 1
    let old_tmp = match file.kind {
      @bitdiff.DiffKind::Added => "/dev/null"
      _ => {
        let tmp_path = tmp_base + "-old"
        match file.old_content {
          Some(bytes) =>
            @fs.write_bytes_to_file(tmp_path, bytes) catch {
              err => raise io_error(err)
            }
          None =>
            @fs.write_bytes_to_file(tmp_path, Bytes::new(0)) catch {
              err => raise io_error(err)
            }
        }
        tmp_path
      }
    }
    let new_tmp = match file.kind {
      @bitdiff.DiffKind::Deleted => "/dev/null"
      _ => {
        let tmp_path = tmp_base + "-new"
        match file.new_content {
          Some(bytes) =>
            @fs.write_bytes_to_file(tmp_path, bytes) catch {
              err => raise io_error(err)
            }
          None =>
            @fs.write_bytes_to_file(tmp_path, Bytes::new(0)) catch {
              err => raise io_error(err)
            }
        }
        tmp_path
      }
    }
    let old_hex_arg = match file.kind {
      @bitdiff.DiffKind::Added => zero_oid
      _ => old_hex
    }
    let new_hex_arg = match file.kind {
      @bitdiff.DiffKind::Deleted => zero_oid
      _ => new_hex
    }
    let old_mode_arg = match file.kind {
      @bitdiff.DiffKind::Added => "000000"
      _ => old_mode
    }
    let new_mode_arg = match file.kind {
      @bitdiff.DiffKind::Deleted => "000000"
      _ => new_mode
    }
    // Run external diff program; exit code is ignored (git behavior)
    let _code = @process.run(
      external_cmd,
      [
        path, old_tmp, old_hex_arg, old_mode_arg, new_tmp, new_hex_arg, new_mode_arg,
      ],
      inherit_env=true,
      cwd=root,
      stdin=@stdio.stdin,
      stdout=@stdio.stdout,
      stderr=@stdio.stderr,
    )
    // Clean up temp files
    if old_tmp != "/dev/null" {
      @fs.remove_file(old_tmp) catch {
        _ => ()
      }
    }
    if new_tmp != "/dev/null" {
      @fs.remove_file(new_tmp) catch {
        _ => ()
      }
    }
  }
}

///|
fn diff_trim_relative_value(value : String) -> String {
  let mut out = value.trim().to_string()
  if out.has_prefix("./") {
    out = String::unsafe_substring(out, start=2, end=out.length())
  }
  while out.has_prefix("/") {
    out = String::unsafe_substring(out, start=1, end=out.length())
  }
  while out.has_suffix("/") && out.length() > 0 {
    out = String::unsafe_substring(out, start=0, end=out.length() - 1)
  }
  if out == "." {
    ""
  } else {
    out
  }
}

///|
fn diff_current_relative_prefix(root : String) -> String {
  let cwd = diff_effective_cwd(root)
  let root_norm = normalize_path(root)
  let cwd_norm = normalize_path(cwd)
  if cwd_norm == root_norm || not(is_path_prefix(cwd_norm, root_norm)) {
    return ""
  }
  let mut suffix = String::unsafe_substring(
    cwd_norm,
    start=root_norm.length(),
    end=cwd_norm.length(),
  )
  if suffix.has_prefix("/") {
    suffix = String::unsafe_substring(suffix, start=1, end=suffix.length())
  }
  diff_trim_relative_value(suffix)
}

///|
fn diff_effective_cwd(root : String) -> String {
  match @sys.get_env_var("GIT_SHIM_CWD") {
    Some(dir) => dir
    None =>
      match @sys.get_env_var("GIT_SHIM_PWD") {
        Some(dir) => dir
        None =>
          match @env.current_dir() {
            Some(dir) => dir
            None => root
          }
      }
  }
}

///|
fn diff_relative_enabled_from_config(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Bool {
  match get_config_override("diff.relative") {
    Some(value) => diff_parse_bool_config(value).unwrap_or(false)
    None => {
      let config_path = git_dir + "/config"
      match diff_last_config_value(fs, config_path, "diff", "relative") {
        Some(value) => diff_parse_bool_config(value).unwrap_or(false)
        None => false
      }
    }
  }
}

///|
fn diff_resolve_relative_prefix(
  fs : &@bitcore.RepoFileSystem,
  git_dir : String,
  root : String,
  relative_spec : String?,
  relative_disabled : Bool,
) -> String? {
  if relative_disabled {
    return None
  }
  match relative_spec {
    Some(spec) =>
      if spec.length() == 0 {
        Some(diff_current_relative_prefix(root))
      } else {
        Some(diff_trim_relative_value(spec))
      }
    None =>
      if diff_relative_enabled_from_config(fs, git_dir) {
        Some(diff_current_relative_prefix(root))
      } else {
        None
      }
  }
}

///|
fn diff_apply_relative_path(path : String, prefix : String) -> String? {
  let trimmed = diff_trim_relative_value(prefix)
  if trimmed.length() == 0 {
    return Some(path)
  }
  if not(path.has_prefix(trimmed)) {
    return None
  }
  let mut rest = String::unsafe_substring(
    path,
    start=trimmed.length(),
    end=path.length(),
  )
  if rest.has_prefix("/") {
    rest = String::unsafe_substring(rest, start=1, end=rest.length())
  }
  if rest.length() == 0 {
    None
  } else {
    Some(rest)
  }
}

///|
fn diff_apply_relative_files(
  files : Array[@bitdiff.DiffFile],
  prefix : String?,
) -> Array[@bitdiff.DiffFile] {
  match prefix {
    None => files
    Some(prefix) => {
      let out : Array[@bitdiff.DiffFile] = []
      for file in files {
        match diff_apply_relative_path(file.path, prefix) {
          Some(path) =>
            out.push({
              path,
              kind: file.kind,
              old_content: file.old_content,
              new_content: file.new_content,
              old_mode: file.old_mode,
              new_mode: file.new_mode,
            })
          None => ()
        }
      }
      out
    }
  }
}

///|
struct DiffOutputSelection {
  mut patch : Bool
  mut patch_explicit : Bool
  mut name_only : Bool
  mut name_status : Bool
  mut raw : Bool
  mut numstat : Bool
  mut stat : Bool
  mut shortstat : Bool
  mut summary : Bool
  mut dirstat : Bool
  mut dirstat_by_file : Bool
  mut dirstat_cumulative : Bool
  mut compact_summary : Bool
}

///|
fn diff_default_output_selection() -> DiffOutputSelection {
  {
    patch: true,
    patch_explicit: false,
    name_only: false,
    name_status: false,
    raw: false,
    numstat: false,
    stat: false,
    shortstat: false,
    summary: false,
    dirstat: false,
    dirstat_by_file: false,
    dirstat_cumulative: false,
    compact_summary: false,
  }
}

///|
fn diff_clear_output_selection(selection : DiffOutputSelection) -> Unit {
  selection.patch = false
  selection.patch_explicit = false
  selection.name_only = false
  selection.name_status = false
  selection.raw = false
  selection.numstat = false
  selection.stat = false
  selection.shortstat = false
  selection.summary = false
  selection.dirstat = false
  selection.dirstat_by_file = false
  selection.dirstat_cumulative = false
  selection.compact_summary = false
}

///|
fn diff_enable_nonexclusive_output(selection : DiffOutputSelection) -> Unit {
  selection.patch = selection.patch_explicit
  selection.name_only = false
  selection.name_status = false
}

///|
fn diff_select_name_only(selection : DiffOutputSelection) -> Unit {
  diff_clear_output_selection(selection)
  selection.name_only = true
}

///|
fn diff_select_name_status(selection : DiffOutputSelection) -> Unit {
  diff_clear_output_selection(selection)
  selection.name_status = true
}

///|
fn diff_is_tolerated_unimplemented_option(arg : String) -> Bool {
  arg == "--find-copies-harder"
}

///|
async fn diff_print_usage() -> Unit {
  eprint_line("usage: git diff [<options>] [<commit>] [--] [<path>...]")
}

///|
async fn diff_print_no_index_usage() -> Unit {
  eprint_line("usage: git diff --no-index [<options>] <path> <path>")
}

///|
fn diff_strip_horizontal_whitespace(content : Bytes?) -> Bytes? {
  match content {
    None => None
    Some(data) => {
      let out : Array[Byte] = []
      for b in data {
        if b != 0x20 && b != 0x09 && b != 0x0d {
          out.push(b)
        }
      }
      Some(Bytes::from_array(out))
    }
  }
}

///|
fn diff_ignore_all_space_equal(old : Bytes?, new : Bytes?) -> Bool {
  diff_strip_horizontal_whitespace(old) == diff_strip_horizontal_whitespace(new)
}

///|
fn diff_filter_ignore_all_space(
  files : Array[@bitdiff.DiffFile],
) -> Array[@bitdiff.DiffFile] {
  let out : Array[@bitdiff.DiffFile] = []
  for file in files {
    let mode_changed = file.old_mode != file.new_mode
    if mode_changed ||
      not(diff_ignore_all_space_equal(file.old_content, file.new_content)) {
      out.push(file)
    }
  }
  out
}

///|
struct DiffCheckIssue {
  path : String
  line : Int
  message : String
}

///|
fn diff_trim_trailing_newline(line : String) -> String {
  if line.has_suffix("\n") {
    String::unsafe_substring(line, start=0, end=line.length() - 1)
  } else {
    line
  }
}

///|
fn diff_line_has_trailing_whitespace(line : String) -> Bool {
  let body = diff_trim_trailing_newline(line)
  if body.length() == 0 {
    return false
  }
  let last = body[body.length() - 1]
  last == ' ' || last == '\t'
}

///|
fn diff_gitattributes_pattern_matches(path : String, pattern : String) -> Bool {
  if pattern == path {
    return true
  }
  if pattern.has_prefix("*.") {
    return path.has_suffix(
      String::unsafe_substring(pattern, start=1, end=pattern.length()),
    )
  }
  match pattern.find("*") {
    Some(idx) => {
      let prefix = String::unsafe_substring(pattern, start=0, end=idx)
      let suffix = String::unsafe_substring(
        pattern,
        start=idx + 1,
        end=pattern.length(),
      )
      path.has_prefix(prefix) &&
      path.has_suffix(suffix) &&
      path.length() >= prefix.length() + suffix.length()
    }
    None => false
  }
}

///|
fn diff_conflict_marker_size(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  path : String,
) -> Int {
  let attr_path = root + "/.gitattributes"
  if not(fs.is_file(attr_path)) {
    return 7
  }
  let content = @utf8.decode_lossy(
    (fs.read_file(attr_path) catch { _ => Bytes::default() })[:],
  )
  let mut size = 7
  for line_view in content.split("\n") {
    let line = line_view.to_string().trim().to_string()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let words : Array[String] = []
    for token_view in line.split(" ") {
      let token = token_view.to_string().trim().to_string()
      if token.length() > 0 {
        words.push(token)
      }
    }
    if words.length() < 2 ||
      not(diff_gitattributes_pattern_matches(path, words[0])) {
      continue
    }
    for i in 1..<words.length() {
      let word = words[i]
      if word.has_prefix("conflict-marker-size=") {
        let raw = String::unsafe_substring(word, start=21, end=word.length())
        let parsed = @strconv.parse_int(raw) catch { _ => 7 }
        if parsed > 0 {
          size = parsed
        }
      }
    }
  }
  size
}

///|
fn diff_is_conflict_marker_line(
  line : String,
  marker : UInt16,
  size : Int,
) -> Bool {
  let body = diff_trim_trailing_newline(line)
  if body.length() < size {
    return false
  }
  for i in 0..<size {
    if body[i] != marker {
      return false
    }
  }
  if body.length() > size && body[size] == marker {
    return false
  }
  body.length() == size || body[size] == ' ' || body[size] == '\t'
}

///|
fn diff_collect_check_issues_for_file(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  file : @bitdiff.DiffFile,
) -> Array[DiffCheckIssue] {
  let new_lines = match file.new_content {
    Some(data) => diff_split_lines_preserve_newline(data)
    None => return []
  }
  let old_lines = match file.old_content {
    Some(data) => diff_split_lines_preserve_newline(data)
    None => []
  }
  let edits = diff_myers_lines(old_lines, new_lines)
  let marker_size = diff_conflict_marker_size(fs, root, file.path)
  let issues : Array[DiffCheckIssue] = []
  for edit in edits {
    match edit {
      Insert(idx) => {
        let line = new_lines[idx]
        if diff_line_has_trailing_whitespace(line) {
          issues.push({
            path: file.path,
            line: idx + 1,
            message: "trailing whitespace.",
          })
        }
        if diff_is_conflict_marker_line(line, '<', marker_size) ||
          diff_is_conflict_marker_line(line, '>', marker_size) ||
          diff_is_conflict_marker_line(line, '=', marker_size) {
          issues.push({
            path: file.path,
            line: idx + 1,
            message: "leftover conflict marker",
          })
        }
      }
      _ => ()
    }
  }
  issues
}

///|
fn diff_collect_check_issues(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  files : Array[@bitdiff.DiffFile],
) -> Array[DiffCheckIssue] {
  let issues : Array[DiffCheckIssue] = []
  for file in files {
    for issue in diff_collect_check_issues_for_file(fs, root, file) {
      issues.push(issue)
    }
  }
  issues
}

///|
priv enum DiffLineEditOp {
  Keep
  Delete(Int)
  Insert(Int)
}

///|
fn diff_split_lines_preserve_newline(data : Bytes) -> Array[String] {
  if data.length() == 0 {
    return []
  }
  let text = @utf8.decode_lossy(data[:])
  let parts : Array[String] = []
  for part_view in text.split("\n") {
    parts.push(part_view.to_string())
  }
  let lines : Array[String] = []
  let last = parts.length() - 1
  for i in 0..<parts.length() {
    let part = parts[i]
    if i < last {
      lines.push(part + "\n")
    } else if part.length() > 0 {
      lines.push(part)
    }
  }
  lines
}

///|
fn diff_myers_lines(
  old : Array[String],
  new : Array[String],
) -> Array[DiffLineEditOp] {
  let n = old.length()
  let m = new.length()
  if n == 0 && m == 0 {
    return []
  }
  if n == 0 {
    return Array::makei(m, fn(j) { DiffLineEditOp::Insert(j) })
  }
  if m == 0 {
    return Array::makei(n, fn(i) { DiffLineEditOp::Delete(i) })
  }
  let max = n + m
  let size = 2 * max + 1
  let v : Array[Int] = Array::make(size, 0)
  let traces : Array[Array[Int]] = []
  let mut found = false
  let mut final_d = 0
  for d = 0; d <= max; d = d + 1 {
    traces.push(v.copy())
    for k = -d; k <= d; k = k + 2 {
      let idx = k + max
      let mut x = if k == -d || (k != d && v[idx - 1] < v[idx + 1]) {
        v[idx + 1]
      } else {
        v[idx - 1] + 1
      }
      let mut y = x - k
      while x < n && y < m && old[x] == new[y] {
        x += 1
        y += 1
      }
      v[idx] = x
      if x >= n && y >= m {
        final_d = d
        found = true
        break
      }
    }
    if found {
      break
    }
  }
  let edits : Array[DiffLineEditOp] = []
  let mut cx = n
  let mut cy = m
  for d = final_d; d > 0; d = d - 1 {
    let prev_v = traces[d]
    let k = cx - cy
    let idx = k + max
    let prev_k = if k == -d || (k != d && prev_v[idx - 1] < prev_v[idx + 1]) {
      k + 1
    } else {
      k - 1
    }
    let prev_x = prev_v[prev_k + max]
    let prev_y = prev_x - prev_k
    while cx > prev_x && cy > prev_y {
      cx = cx - 1
      cy = cy - 1
      edits.push(DiffLineEditOp::Keep)
    }
    if cx > prev_x {
      cx = cx - 1
      edits.push(DiffLineEditOp::Delete(cx))
    } else if cy > prev_y {
      cy = cy - 1
      edits.push(DiffLineEditOp::Insert(cy))
    }
  }
  while cx > 0 && cy > 0 {
    cx = cx - 1
    cy = cy - 1
    edits.push(DiffLineEditOp::Keep)
  }
  edits.rev()
}

///|
fn diff_line_byte_length(line : String) -> Int {
  @utf8.encode(line[:]).length()
}

///|
fn diff_count_changed_line_bytes(old : Bytes?, new : Bytes?) -> (Int, Int) {
  let old_lines = match old {
    Some(data) => diff_split_lines_preserve_newline(data)
    None => []
  }
  let new_lines = match new {
    Some(data) => diff_split_lines_preserve_newline(data)
    None => []
  }
  let edits = diff_myers_lines(old_lines, new_lines)
  let mut deleted_bytes = 0
  let mut inserted_bytes = 0
  for edit in edits {
    match edit {
      DiffLineEditOp::Keep => ()
      DiffLineEditOp::Delete(idx) =>
        deleted_bytes += diff_line_byte_length(old_lines[idx])
      DiffLineEditOp::Insert(idx) =>
        inserted_bytes += diff_line_byte_length(new_lines[idx])
    }
  }
  (inserted_bytes, deleted_bytes)
}

///|
fn diff_count_line_changes(old : Bytes?, new : Bytes?) -> (Int, Int) {
  let old_lines = match old {
    Some(data) => diff_split_lines_preserve_newline(data)
    None => []
  }
  let new_lines = match new {
    Some(data) => diff_split_lines_preserve_newline(data)
    None => []
  }
  let edits = diff_myers_lines(old_lines, new_lines)
  let mut add = 0
  let mut del = 0
  for edit in edits {
    match edit {
      DiffLineEditOp::Keep => ()
      DiffLineEditOp::Delete(_) => del += 1
      DiffLineEditOp::Insert(_) => add += 1
    }
  }
  (add, del)
}

///|
fn diff_format_numstat(files : Array[@bitdiff.DiffFile]) -> Array[String] {
  let lines : Array[String] = []
  for file in files {
    let (add, del) = diff_count_line_changes(file.old_content, file.new_content)
    lines.push("\{add}\t\{del}\t\{file.path}")
  }
  lines
}

///|
fn diff_format_shortstat(files : Array[@bitdiff.DiffFile]) -> Array[String] {
  let lines : Array[String] = []
  if files.length() == 0 {
    return lines
  }
  let summary : Array[String] = []
  let mut total_add = 0
  let mut total_del = 0
  for file in files {
    let (add, del) = diff_count_line_changes(file.old_content, file.new_content)
    total_add += add
    total_del += del
  }
  if files.length() == 1 {
    summary.push("1 file changed")
  } else {
    summary.push("\{files.length()} files changed")
  }
  if total_add > 0 {
    if total_add == 1 {
      summary.push("1 insertion(+)")
    } else {
      summary.push("\{total_add} insertions(+)")
    }
  }
  if total_del > 0 {
    if total_del == 1 {
      summary.push("1 deletion(-)")
    } else {
      summary.push("\{total_del} deletions(-)")
    }
  }
  lines.push(" " + summary.join(", "))
  lines
}

///|
fn diff_format_stat_label(
  file : @bitdiff.DiffFile,
  compact_summary : Bool,
) -> String {
  if not(compact_summary) {
    return file.path
  }
  let suffix = match file.kind {
    @bitdiff.DiffKind::Added =>
      match file.new_mode {
        Some(mode) if mode == 0o100755 => " (new +x)"
        _ => " (new)"
      }
    @bitdiff.DiffKind::Deleted => " (gone)"
    @bitdiff.DiffKind::Modified =>
      match (file.old_mode, file.new_mode) {
        (Some(old_mode), Some(new_mode)) if old_mode != new_mode =>
          if old_mode == 0o100644 && new_mode == 0o100755 {
            " (mode +x)"
          } else if old_mode == 0o100755 && new_mode == 0o100644 {
            " (mode -x)"
          } else {
            " (mode \{diff_index_mode_string(Some(old_mode))} => \{diff_index_mode_string(Some(new_mode))})"
          }
        _ => ""
      }
  }
  file.path + suffix
}

///|
fn diff_format_stat(
  files : Array[@bitdiff.DiffFile],
  compact_summary? : Bool = false,
) -> Array[String] {
  let lines : Array[String] = []
  let mut max_name_len = 0
  for file in files {
    let label = diff_format_stat_label(file, compact_summary)
    if label.length() > max_name_len {
      max_name_len = label.length()
    }
  }
  for file in files {
    let (add, del) = diff_count_line_changes(file.old_content, file.new_content)
    let total = add + del
    let bar_len = if total > 50 { 50 } else { total }
    let add_bar = "+".repeat(if total > 0 { add * bar_len / total } else { 0 })
    let del_bar = "-".repeat(if total > 0 { del * bar_len / total } else { 0 })
    let label = diff_format_stat_label(file, compact_summary)
    let padding = " ".repeat(max_name_len - label.length())
    lines.push(" \{label}\{padding} | \{total} \{add_bar}\{del_bar}")
  }
  for line in diff_format_shortstat(files) {
    lines.push(line)
  }
  lines
}

///|
fn diff_format_summary(files : Array[@bitdiff.DiffFile]) -> Array[String] {
  let lines : Array[String] = []
  for file in files {
    match file.kind {
      @bitdiff.DiffKind::Added =>
        lines.push(
          " create mode \{diff_index_mode_string(file.new_mode)} \{file.path}",
        )
      @bitdiff.DiffKind::Deleted =>
        lines.push(
          " delete mode \{diff_index_mode_string(file.old_mode)} \{file.path}",
        )
      @bitdiff.DiffKind::Modified =>
        match (file.old_mode, file.new_mode) {
          (Some(old_mode), Some(new_mode)) if old_mode != new_mode =>
            lines.push(
              " mode change \{diff_index_mode_string(Some(old_mode))} => \{diff_index_mode_string(Some(new_mode))} \{file.path}",
            )
          _ => ()
        }
    }
  }
  lines
}

///|
fn diff_dirstat_dirs(path : String, cumulative : Bool) -> Array[String] {
  let parts : Array[String] = []
  for part_view in path.split("/") {
    parts.push(part_view.to_string())
  }
  if parts.length() <= 1 {
    return []
  }
  let dirs : Array[String] = []
  let mut prefix = ""
  let last_dir_index = parts.length() - 2
  for i in 0..<(parts.length() - 1) {
    prefix += parts[i] + "/"
    if cumulative || i == last_dir_index {
      dirs.push(prefix)
    }
  }
  dirs
}

///|
fn diff_format_dirstat_percent(value : Int, total : Int) -> String {
  if total <= 0 {
    return "   0.0"
  }
  let tenths = (value * 1000 + total / 2) / total
  let whole = tenths / 10
  let frac = tenths % 10
  let raw = "\{whole}.\{frac}"
  if raw.length() >= 6 {
    raw
  } else {
    " ".repeat(6 - raw.length()) + raw
  }
}

///|
fn diff_format_dirstat(
  files : Array[@bitdiff.DiffFile],
  by_file? : Bool = false,
  cumulative? : Bool = false,
) -> Array[String] {
  let lines : Array[String] = []
  let weights : Map[String, Int] = {}
  let mut total = 0
  for file in files {
    let file_weight = if by_file {
      1
    } else {
      let (inserted_bytes, deleted_bytes) = diff_count_changed_line_bytes(
        file.old_content,
        file.new_content,
      )
      inserted_bytes + deleted_bytes
    }
    if file_weight <= 0 {
      continue
    }
    total += file_weight
    let dirs = diff_dirstat_dirs(file.path, cumulative)
    if dirs.length() == 0 {
      continue
    }
    for dir in dirs {
      match weights.get(dir) {
        Some(current) => weights[dir] = current + file_weight
        None => weights[dir] = file_weight
      }
    }
  }
  if total <= 0 {
    return lines
  }
  let items : Array[(String, Int)] = []
  for dir, weight in weights {
    let percent_tenths = (weight * 1000 + total / 2) / total
    if percent_tenths < 30 {
      continue
    }
    items.push((dir, weight))
  }
  items.sort_by(fn(a, b) {
    if a.1 == b.1 {
      String::compare(a.0, b.0)
    } else {
      b.1 - a.1
    }
  })
  for item in items {
    let (dir, weight) = item
    lines.push("\{diff_format_dirstat_percent(weight, total)}% \{dir}")
  }
  lines
}

///|
fn diff_collect_output_lines(
  files : Array[@bitdiff.DiffFile],
  output : DiffOutputSelection,
  context_lines : Int,
  extra_name_only_paths : Array[String],
) -> Array[String] {
  let lines : Array[String] = []
  if output.name_only {
    for file in files {
      lines.push(file.path)
    }
    for path in extra_name_only_paths {
      lines.push(path)
    }
    return lines
  }
  if output.name_status {
    for file in files {
      let status = match file.kind {
        @bitdiff.DiffKind::Added => "A"
        @bitdiff.DiffKind::Modified => "M"
        @bitdiff.DiffKind::Deleted => "D"
      }
      lines.push("\{status}\t\{file.path}")
    }
    return lines
  }
  if output.raw {
    for file in files {
      lines.push(format_diff_index_line_from_diff_file(file))
    }
  }
  if output.numstat {
    for line in diff_format_numstat(files) {
      lines.push(line)
    }
  }
  if output.stat {
    for line in diff_format_stat(files, compact_summary=output.compact_summary) {
      lines.push(line)
    }
  }
  if output.shortstat {
    for line in diff_format_shortstat(files) {
      lines.push(line)
    }
  }
  if output.dirstat {
    for
      line in diff_format_dirstat(
        files,
        by_file=output.dirstat_by_file,
        cumulative=output.dirstat_cumulative,
      ) {
      lines.push(line)
    }
  }
  if output.summary {
    for line in diff_format_summary(files) {
      lines.push(line)
    }
  }
  if output.patch {
    let patch_lines = @bitdiff.diff_text(files, context_lines~)
    if lines.length() > 0 && patch_lines.length() > 0 {
      lines.push("")
    }
    for line in patch_lines {
      lines.push(line)
    }
  }
  lines
}

///|
fn diff_extra_unmerged_name_only_paths(
  unmerged_paths : Map[String, Bool],
  displayed_files : Array[@bitdiff.DiffFile],
  filters : Array[String],
  relative_prefix : String?,
) -> Array[String] {
  let displayed : Map[String, Bool] = {}
  for file in displayed_files {
    displayed[file.path] = true
  }
  let extra : Array[String] = []
  for path, _ in unmerged_paths {
    if not(diff_path_matches_filters(path, filters)) {
      continue
    }
    let display_path = match relative_prefix {
      Some(prefix) => diff_apply_relative_path(path, prefix)
      None => Some(path)
    }
    match display_path {
      Some(name) if displayed.contains(name) => extra.push(name)
      _ => ()
    }
  }
  extra.sort()
  extra
}

///|
fn is_gitlink_mode_for_diff(mode : Int) -> Bool {
  mode == 0o160000
}

///|
fn looks_like_cached_diff_revision(token : String) -> Bool {
  token == "HEAD" ||
  token == "@" ||
  token.has_prefix("HEAD^") ||
  token.has_prefix("HEAD~")
}

///|
fn diff_is_existing_path(fs : OsFs, root : String, candidate : String) -> Bool {
  let candidate_abs = root + "/" + candidate
  fs.is_file(candidate_abs) || fs.is_dir(candidate_abs)
}

///|
fn diff_resolve_cli_path(root : String, candidate : String) -> String {
  if candidate == "-" || candidate == "/dev/null" || candidate.has_prefix("/") {
    candidate
  } else {
    normalize_path(diff_effective_cwd(root) + "/" + candidate)
  }
}

///|
fn diff_is_existing_fs_path(
  fs : OsFs,
  root : String,
  candidate : String,
) -> Bool {
  let resolved = diff_resolve_cli_path(root, candidate)
  resolved == "-" ||
  resolved == "/dev/null" ||
  fs.is_file(resolved) ||
  fs.is_dir(resolved)
}

///|
fn diff_no_index_trim_path(path : String) -> String {
  if path.length() > 1 && path.has_suffix("/") {
    String::unsafe_substring(path, start=0, end=path.length() - 1)
  } else {
    path
  }
}

///|
fn diff_no_index_operand_exists(
  fs : OsFs,
  root : String,
  path : String,
) -> Bool {
  let clean = diff_no_index_trim_path(diff_resolve_cli_path(root, path))
  clean == "-" || clean == "/dev/null" || fs.is_file(clean) || fs.is_dir(clean)
}

///|
fn diff_should_auto_no_index(
  fs : OsFs,
  root : String,
  path_a : String,
  path_b : String,
) -> Bool {
  if not(
      diff_no_index_operand_exists(fs, root, path_a) &&
      diff_no_index_operand_exists(fs, root, path_b),
    ) {
    return false
  }
  path_a.has_prefix("../") ||
  path_b.has_prefix("../") ||
  path_a.has_prefix("/") ||
  path_b.has_prefix("/") ||
  path_a.has_prefix("./") ||
  path_b.has_prefix("./")
}

///|
fn diff_extract_leading_revisions(
  fs : OsFs,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  args : Array[String],
  max_revs : Int,
) -> (Array[String], Array[String]) raise Error {
  let revs : Array[String] = []
  let rest : Array[String] = []
  let mut idx = 0
  while idx < args.length() && revs.length() < max_revs {
    let candidate = args[idx]
    if diff_is_existing_path(fs, root, candidate) ||
      @bitrepo.rev_parse(rfs, git_dir, candidate) is None {
      break
    }
    revs.push(candidate)
    idx += 1
  }
  for i in idx..<args.length() {
    rest.push(args[i])
  }
  (revs, rest)
}

///|
fn diff_has_dirty_submodules(
  fs : OsFs,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  filters : Array[String],
) -> Bool raise Error {
  let index_entries = @bitlib.read_index_entries(rfs, git_dir)
  for entry in index_entries {
    if not(is_gitlink_mode_for_diff(entry.mode)) {
      continue
    }
    if filters.length() > 0 &&
      not(
        filters
        .iter()
        .any(fn(filter) { ls_files_pathspec_matches(entry.path, filter) }),
      ) {
      continue
    }
    let sub_root = root + "/" + entry.path
    if not(fs.is_dir(sub_root)) {
      continue
    }
    let sub_git_dir = resolve_git_dir(rfs, sub_root)
    let sub_head = @bitlib.resolve_head_commit(rfs, sub_git_dir) catch {
      _ => None
    }
    match sub_head {
      Some(sub_head) => if sub_head != entry.id { return true }
      None => ()
    }
  }
  false
}

///|
async fn handle_diff(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  check_and_exit_unsupported_attrs(root)
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  if diff_need_real_git(rfs, git_dir) {
    delegate_diff_to_real_git(args)
    return
  }
  let repo_git_dir = resolve_submodule_common_git_dir(rfs, git_dir)
  let mut submodule_mode = false
  let mut range_spec : String? = None
  let mut cached = false
  let output = diff_default_output_selection()
  let mut quiet = false
  let mut exit_code = false
  let mut check_mode = false
  let mut context_lines = 3
  let mut no_index = false
  let mut parse_options = true
  let mut ref_target : String? = None
  let mut relative_spec : String? = None
  let mut relative_disabled = false
  let mut ignore_all_space = false
  let paths : Array[String] = []
  for arg in args {
    if parse_options && arg == "--" {
      parse_options = false
      continue
    }
    if arg == "--submodule" || arg.has_prefix("--submodule=") {
      submodule_mode = true
    }
    if parse_options {
      match arg {
        "-" => paths.push(arg)
        "--cached" | "--staged" => cached = true
        "--stat" => {
          diff_enable_nonexclusive_output(output)
          output.stat = true
          output.compact_summary = false
        }
        "--shortstat" => {
          diff_enable_nonexclusive_output(output)
          output.shortstat = true
        }
        "--summary" => {
          diff_enable_nonexclusive_output(output)
          output.summary = true
        }
        "--name-only" => diff_select_name_only(output)
        "--name-status" => diff_select_name_status(output)
        "--raw" => {
          diff_enable_nonexclusive_output(output)
          output.raw = true
        }
        "--numstat" => {
          diff_enable_nonexclusive_output(output)
          output.numstat = true
        }
        "--no-abbrev" => ()
        "-p" | "--patch" => {
          diff_enable_nonexclusive_output(output)
          output.patch_explicit = true
          output.patch = true
        }
        "-s" | "--no-patch" => diff_clear_output_selection(output)
        "--patch-with-raw" => {
          diff_enable_nonexclusive_output(output)
          output.patch_explicit = true
          output.patch = true
          output.raw = true
        }
        "--patch-with-stat" => {
          diff_enable_nonexclusive_output(output)
          output.patch_explicit = true
          output.patch = true
          output.stat = true
          output.compact_summary = false
        }
        "--compact-summary" => {
          diff_enable_nonexclusive_output(output)
          output.stat = true
          output.compact_summary = true
        }
        "--dirstat" => {
          diff_enable_nonexclusive_output(output)
          output.dirstat = true
          output.dirstat_by_file = false
        }
        "--cumulative" => {
          diff_enable_nonexclusive_output(output)
          output.dirstat = true
          output.dirstat_cumulative = true
        }
        "--dirstat-by-file" => {
          diff_enable_nonexclusive_output(output)
          output.dirstat = true
          output.dirstat_by_file = true
        }
        "--quiet" => {
          quiet = true
          exit_code = true
        }
        "--exit-code" => exit_code = true
        "--check" => check_mode = true
        "-w" | "--ignore-all-space" => ignore_all_space = true
        "--no-index" => no_index = true
        "--relative" => {
          relative_disabled = false
          relative_spec = Some("")
        }
        "--no-relative" => {
          relative_disabled = true
          relative_spec = None
        }
        "--submodule" => ()
        _ if arg.has_prefix("--submodule=") => ()
        _ if arg.has_prefix("--dirstat=") => {
          diff_enable_nonexclusive_output(output)
          output.dirstat = true
          let spec = String::unsafe_substring(arg, start=10, end=arg.length())
          let spec_lower = spec.to_lower()
          if spec_lower.contains("files") {
            output.dirstat_by_file = true
          }
          if spec_lower.contains("cumulative") {
            output.dirstat_cumulative = true
          }
          if spec_lower.contains("noncumulative") {
            output.dirstat_cumulative = false
          }
        }
        _ if arg.has_prefix("--dirstat-by-file=") => {
          diff_enable_nonexclusive_output(output)
          output.dirstat = true
          output.dirstat_by_file = true
          let spec = String::unsafe_substring(arg, start=18, end=arg.length())
          let spec_lower = spec.to_lower()
          if spec_lower.contains("cumulative") {
            output.dirstat_cumulative = true
          }
          if spec_lower.contains("noncumulative") {
            output.dirstat_cumulative = false
          }
        }
        _ if arg.has_prefix("--relative=") => {
          relative_disabled = false
          relative_spec = Some(
            String::unsafe_substring(arg, start=11, end=arg.length()),
          )
        }
        _ if arg.has_prefix("-U") && arg.length() > 2 => {
          let num_str = string_slice_from(arg, 2)
          context_lines = @strconv.parse_int(num_str)
        }
        _ if arg.has_prefix("--unified=") => {
          let num_str = string_slice_from(arg, 10)
          context_lines = @strconv.parse_int(num_str)
        }
        _ if not(arg.has_prefix("-")) =>
          if not(no_index) &&
            not(diff_is_existing_fs_path(fs, root, arg)) &&
            (arg.contains("^!") || arg.contains("..")) {
            if range_spec is None {
              range_spec = Some(arg)
            }
          } else if cached &&
            ref_target is None &&
            looks_like_cached_diff_revision(arg) {
            ref_target = Some(arg)
          } else {
            paths.push(arg)
          }
        "-M" | "--find-renames" | "-C" | "--find-copies" => ()
        _ if arg.has_prefix("-M") || arg.has_prefix("--find-renames=") ||
          arg.has_prefix("-C") || arg.has_prefix("--find-copies=") => ()
        _ if arg.has_prefix("--") =>
          if diff_is_tolerated_unimplemented_option(arg) {
            warn_unimplemented_arg("diff", arg)
          } else {
            diff_print_usage()
            @sys.exit(129)
          }
        _ if arg.has_prefix("-") => warn_unimplemented_arg("diff", arg)
        _ => ()
      }
    } else if not(no_index) &&
      not(diff_is_existing_fs_path(fs, root, arg)) &&
      (arg.contains("^!") || arg.contains("..")) {
      if range_spec is None {
        range_spec = Some(arg)
      }
    } else if cached &&
      ref_target is None &&
      looks_like_cached_diff_revision(arg) {
      ref_target = Some(arg)
    } else {
      paths.push(arg)
    }
  }
  let relative_prefix = diff_resolve_relative_prefix(
    rfs, git_dir, root, relative_spec, relative_disabled,
  )
  let path_args = if no_index || range_spec is Some(_) {
    paths
  } else if cached {
    match ref_target {
      Some(_) => paths
      None => {
        let (revs, rest) = diff_extract_leading_revisions(
          fs, rfs, root, git_dir, paths, 1,
        )
        if revs.length() == 1 {
          ref_target = Some(revs[0])
          rest
        } else {
          paths
        }
      }
    }
  } else if ref_target is None {
    let (revs, rest) = diff_extract_leading_revisions(
      fs, rfs, root, git_dir, paths, 2,
    )
    if revs.length() == 1 {
      ref_target = Some(revs[0])
      rest
    } else if revs.length() == 2 {
      range_spec = Some(revs[0] + ".." + revs[1])
      rest
    } else {
      paths
    }
  } else {
    paths
  }
  if not(no_index) &&
    range_spec is None &&
    ref_target is None &&
    path_args.length() >= 2 &&
    diff_should_auto_no_index(fs, root, path_args[0], path_args[1]) {
    no_index = true
  }
  // Handle --no-index: compare two files/directories without git context
  if no_index {
    if path_args.length() < 2 {
      diff_print_no_index_usage()
      @sys.exit(129)
    }
    let no_index_path_a = diff_no_index_trim_path(path_args[0])
    let no_index_path_b = diff_no_index_trim_path(path_args[1])
    let no_index_abs_a = diff_no_index_trim_path(
      diff_resolve_cli_path(root, no_index_path_a),
    )
    let no_index_abs_b = diff_no_index_trim_path(
      diff_resolve_cli_path(root, no_index_path_b),
    )
    let no_index_filters : Array[String] = []
    for i in 2..<path_args.length() {
      no_index_filters.push(path_args[i])
    }
    let no_prefix = diff_noprefix_enabled_from_config(rfs, git_dir)
    let path_a_is_dir = fs.is_dir(no_index_abs_a)
    let path_b_is_dir = fs.is_dir(no_index_abs_b)
    if no_index_filters.length() > 0 && not(path_a_is_dir && path_b_is_dir) {
      diff_print_no_index_usage()
      @sys.exit(129)
    }
    let entries = diff_apply_relative_no_index_entries(
      diff_filter_no_index_entries(
        diff_no_index(
          fs, no_index_abs_a, no_index_abs_b, no_index_path_a, no_index_path_b,
        ),
        no_index_path_a,
        no_index_path_b,
        no_index_filters,
      ),
      relative_prefix,
    )
    if not(quiet) {
      for
        line in diff_collect_no_index_output_lines(
          entries, output, context_lines, no_prefix,
        ) {
        print_line(line)
      }
    }
    if entries.length() > 0 {
      @sys.exit(1)
    }
    return
  }
  // Handle subdir-clone diff with upstream ref
  match (ref_target, get_subdir_info(fs, git_dir)) {
    (Some(refspec), Some((_, subdir_path, _))) => {
      handle_subdir_diff(
        fs,
        root,
        git_dir,
        refspec,
        subdir_path,
        output.stat || output.shortstat || output.dirstat || output.summary,
        output.name_only,
        output.name_status,
      ) catch {
        err => raise err
      }
      if exit_code {
        // `handle_subdir_diff` writes output directly; use diff result as conservative signal.
        let files = if cached {
          @bitdiff.diff_index(fs, root)
        } else {
          @bitdiff.diff_worktree(fs, root)
        }
        if files.length() > 0 {
          @sys.exit(1)
        }
      }
      return
    }
    _ => ()
  }
  let all_files = match range_spec {
    Some(spec) => {
      if submodule_mode {
        let handled = try_handle_submodule_range_diff(
          fs, root, git_dir, repo_git_dir, spec,
        )
        if handled {
          return
        }
      }
      let db = @bitlib.ObjectDb::load(rfs, repo_git_dir)
      match resolve_submodule_diff_range(db, rfs, repo_git_dir, spec) {
        Some((old_id, new_id)) => {
          let old_tree = resolve_diff_tree_id(db, rfs, old_id)
          let new_tree = resolve_diff_tree_id(db, rfs, new_id)
          match (old_tree, new_tree) {
            (Some(ot), Some(nt)) =>
              @bitdiff.diff_trees(rfs, repo_git_dir, Some(ot), nt, db~)
            _ =>
              raise @bitcore.GitError::InvalidObject(
                "unsupported diff range: " + spec,
              )
          }
        }
        None =>
          raise @bitcore.GitError::InvalidObject(
            "unsupported diff range: " + spec,
          )
      }
    }
    None =>
      if cached {
        match ref_target {
          Some(spec) => diff_cached_against_ref(fs, rfs, root, git_dir, spec)
          None => @bitdiff.diff_index(fs, root)
        }
      } else {
        match ref_target {
          Some(spec) => diff_cached_against_ref(fs, rfs, root, git_dir, spec)
          None => @bitdiff.diff_worktree(fs, root)
        }
      }
  }
  let normalized_path_args = normalize_ls_tree_filters(
    path_args,
    compute_cwd_prefix(root),
  )
  // Filter by paths if specified
  let files = if normalized_path_args.length() > 0 {
    all_files
    .iter()
    .filter(fn(f) {
      normalized_path_args
      .iter()
      .any(fn(filter) { ls_files_pathspec_matches(f.path, filter) })
    })
    .collect()
  } else {
    all_files
  }
  let files = if ignore_all_space {
    diff_filter_ignore_all_space(files)
  } else {
    files
  }
  let display_files = diff_apply_relative_files(files, relative_prefix)
  // If an external diff program is configured, use it instead of built-in output
  match diff_get_external_command(rfs, git_dir) {
    Some(ext_cmd) if not(check_mode) && not(quiet) => {
      diff_run_external(ext_cmd, root, files)
      if exit_code && display_files.length() > 0 {
        @sys.exit(1)
      }
      return
    }
    _ => ()
  }
  let check_issues = if check_mode {
    diff_collect_check_issues(rfs, root, files)
  } else {
    []
  }
  let has_dirty_submodules = submodule_mode &&
    exit_code &&
    not(cached) &&
    range_spec is None &&
    diff_has_dirty_submodules(fs, rfs, root, git_dir, normalized_path_args)
  if check_mode {
    for issue in check_issues {
      print_line("\{issue.path}:\{issue.line}: \{issue.message}")
    }
  } else if not(quiet) {
    let extra_unmerged = if output.name_only &&
      not(cached) &&
      ref_target is None &&
      range_spec is None {
      diff_extra_unmerged_name_only_paths(
        @bitlib.read_unmerged_paths(rfs, git_dir),
        display_files,
        normalized_path_args,
        relative_prefix,
      )
    } else {
      []
    }
    for
      line in diff_collect_output_lines(
        display_files, output, context_lines, extra_unmerged,
      ) {
      print_line(line)
    }
  }
  if check_mode {
    if check_issues.length() > 0 {
      @sys.exit(if exit_code { 3 } else { 2 })
    }
    if exit_code && (display_files.length() > 0 || has_dirty_submodules) {
      @sys.exit(1)
    }
    return
  }
  if exit_code && (display_files.length() > 0 || has_dirty_submodules) {
    @sys.exit(1)
  }
}

///|
async fn handle_diff_files(args : Array[String]) -> Unit raise Error {
  let mut exit_code = false
  let mut quiet = false
  let mut name_only = false
  let mut name_status = false
  let mut ignore_submodules = false
  let mut delegate_to_diff = false
  let mut no_patch_only = false
  let mut parse_options = true
  let filters : Array[String] = []
  for arg in args {
    if parse_options && arg == "--" {
      parse_options = false
      continue
    }
    if parse_options {
      match arg {
        "--exit-code" => exit_code = true
        "--quiet" => {
          quiet = true
          exit_code = true
        }
        "--name-only" => name_only = true
        "--name-status" => name_status = true
        "--ignore-submodules" => ignore_submodules = true
        "-p" | "--patch" | "--patch-with-raw" | "--patch-with-stat" |
        "--raw" | "--stat" | "--shortstat" | "--summary" | "--numstat" |
        "--dirstat" | "--cumulative" | "--dirstat-by-file" |
        "--compact-summary" => {
          delegate_to_diff = true
          no_patch_only = false
        }
        "-s" | "--no-patch" => {
          no_patch_only = true
          delegate_to_diff = false
        }
        _ if arg.has_prefix("--ignore-submodules=") =>
          ignore_submodules = not(
            String::unsafe_substring(arg, start=20, end=arg.length())
            .trim()
            .to_lower() ==
            "none",
          )
        _ if not(arg.has_prefix("-")) => filters.push(arg)
        _ => ()
      }
    } else {
      filters.push(arg)
    }
  }
  // When output format flags beyond raw/name-only/name-status are present,
  // delegate to handle_diff which handles all format combinations.
  if delegate_to_diff {
    handle_diff(args)
    return
  }
  let root = get_work_root()
  let fs = OsFs::new()
  let git_dir = resolve_git_dir(fs, root)
  let changes = diff_filter_raw_submodule_changes(
    diff_collect_raw_changes_against_index(fs, root, git_dir, filters),
    ignore_submodules,
  )
  if changes.length() > 0 {
    if exit_code {
      @sys.exit(1)
    }
    if not(quiet) && not(no_patch_only) {
      if name_only {
        for change in changes {
          print_line(change.path)
        }
      } else if name_status {
        for change in changes {
          print_line(change.status + "\t" + change.path)
        }
      } else {
        for change in changes {
          print_line(diff_format_raw_worktree_change(change))
        }
      }
    }
    return
  }
  if ignore_submodules {
    return
  }
  if no_patch_only {
    return
  }
  handle_diff(args)
}

///|
async fn handle_diff_index(args : Array[String]) -> Unit raise Error {
  let mut exit_code = false
  let mut quiet = false
  let mut name_only = false
  let mut cached = false
  let mut delegate_to_diff = false
  let mut no_patch_only = false
  let mut parse_options = true
  let mut treeish : String? = None
  let filters : Array[String] = []
  for arg in args {
    if parse_options && arg == "--" {
      parse_options = false
      continue
    }
    if parse_options {
      match arg {
        "--exit-code" => exit_code = true
        "--quiet" => {
          quiet = true
          exit_code = true
        }
        "--name-only" => name_only = true
        "--raw" => ()
        "--cached" => cached = true
        "-p" | "--patch" | "--patch-with-raw" | "--patch-with-stat" |
        "--stat" | "--shortstat" | "--summary" | "--numstat" |
        "--dirstat" | "--cumulative" | "--dirstat-by-file" |
        "--compact-summary" | "-M" | "--find-renames" => {
          delegate_to_diff = true
          no_patch_only = false
        }
        "-s" | "--no-patch" => {
          no_patch_only = true
          delegate_to_diff = false
        }
        _ if arg.has_prefix("-M") || arg.has_prefix("--find-renames=") => {
          delegate_to_diff = true
          no_patch_only = false
        }
        _ if arg.has_prefix("-") => ()
        _ =>
          if treeish is None {
            treeish = Some(arg)
          } else {
            filters.push(arg)
          }
      }
    } else {
      filters.push(arg)
    }
  }
  // When patch/stat/rename flags are present, delegate to handle_diff
  // which supports full unified diff output.
  if delegate_to_diff {
    // Build args for handle_diff: insert the treeish if present
    let diff_args : Array[String] = []
    if cached {
      diff_args.push("--cached")
    }
    for arg in args {
      diff_args.push(arg)
    }
    handle_diff(diff_args)
    return
  }
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let target = treeish.unwrap_or("HEAD")
  if not(cached) {
    let changes = diff_collect_raw_changes_against_tree(
      fs, rfs, root, git_dir, target, filters,
    )
    let has_changes = changes.length() > 0
    if not(quiet) && not(no_patch_only) {
      if name_only {
        for change in changes {
          print_line(change.path)
        }
      } else {
        for change in changes {
          print_line(diff_format_raw_worktree_change(change))
        }
      }
    }
    if exit_code && has_changes {
      @sys.exit(1)
    }
    return
  }
  let staged_all = diff_cached_against_ref(fs, rfs, root, git_dir, target)
  let staged : Array[@bitdiff.DiffFile] = []
  let staged_paths : Map[String, Bool] = {}
  for file in staged_all {
    if diff_path_matches_filters(file.path, filters) {
      staged.push(file)
      staged_paths[file.path] = true
    }
  }
  let stale_all = if cached {
    []
  } else {
    collect_diff_index_stale_entries(fs, root, filters)
  }
  let stale : Array[@bitlib.IndexEntry] = []
  for entry in stale_all {
    if not(staged_paths.contains(entry.path)) {
      stale.push(entry)
    }
  }
  let has_changes = staged.length() > 0 || stale.length() > 0
  if not(quiet) && not(no_patch_only) {
    if name_only {
      for file in staged {
        print_line(file.path)
      }
      for entry in stale {
        print_line(entry.path)
      }
    } else {
      for file in staged {
        print_line(
          format_diff_index_line_from_diff_file(
            file,
            worktree_compare=not(cached),
          ),
        )
      }
      for entry in stale {
        print_line(format_diff_index_line_from_entry(entry))
      }
    }
  }
  if exit_code && has_changes {
    @sys.exit(1)
  }
}

///|
priv struct DiffWorktreeObserved {
  mode : Int?
  id : @bitcore.ObjectId?
}

///|
priv struct DiffRawWorktreeChange {
  path : String
  status : String
  old_mode : Int?
  old_id : @bitcore.ObjectId?
  new_mode : Int?
}

///|
fn diff_mode_kind(mode : Int) -> Int {
  if mode == 0o120000 {
    0o120000
  } else if mode == 0o160000 {
    0o160000
  } else {
    0o100000
  }
}

///|
fn diff_raw_worktree_change(
  path : String,
  old_mode : Int?,
  old_id : @bitcore.ObjectId?,
  observed : DiffWorktreeObserved,
) -> DiffRawWorktreeChange? {
  match (old_mode, observed.mode) {
    (None, None) => None
    (Some(mode), None) =>
      Some({ path, status: "D", old_mode: Some(mode), old_id, new_mode: None })
    (None, Some(mode)) =>
      Some({
        path,
        status: "A",
        old_mode: None,
        old_id: None,
        new_mode: Some(mode),
      })
    (Some(old_mode), Some(new_mode)) => {
      let same_kind = diff_mode_kind(old_mode) == diff_mode_kind(new_mode)
      let same_id = match (old_id, observed.id) {
        (Some(old_id), Some(new_id)) => old_id == new_id
        (None, None) => true
        _ => false
      }
      if same_kind && old_mode == new_mode && same_id {
        None
      } else {
        Some({
          path,
          status: if same_kind {
            "M"
          } else {
            "T"
          },
          old_mode: Some(old_mode),
          old_id,
          new_mode: Some(new_mode),
        })
      }
    }
  }
}

///|
fn diff_format_raw_worktree_change(change : DiffRawWorktreeChange) -> String {
  let old_mode = diff_index_mode_string(change.old_mode)
  let new_mode = diff_index_mode_string(change.new_mode)
  let old_oid = match change.old_id {
    Some(id) => id.to_hex()
    None => diff_index_zero_oid_hex()
  }
  let new_oid = diff_index_zero_oid_hex()
  ":\{old_mode} \{new_mode} \{old_oid} \{new_oid} \{change.status}\t\{change.path}"
}

///|
fn diff_push_change_sorted(
  changes : Array[DiffRawWorktreeChange],
  change : DiffRawWorktreeChange,
) -> Unit {
  let mut insert_at = changes.length()
  for i = 0; i < changes.length(); i = i + 1 {
    if String::lexical_compare(change.path, changes[i].path) < 0 {
      insert_at = i
      break
    }
  }
  changes.insert(insert_at, change)
}

///|
fn diff_filter_raw_submodule_changes(
  changes : Array[DiffRawWorktreeChange],
  ignore_submodules : Bool,
) -> Array[DiffRawWorktreeChange] {
  if not(ignore_submodules) {
    return changes
  }
  let filtered : Array[DiffRawWorktreeChange] = []
  for change in changes {
    let is_gitlink = match (change.old_mode, change.new_mode) {
      (Some(0o160000), _) => true
      (_, Some(0o160000)) => true
      _ => false
    }
    if not(is_gitlink) {
      filtered.push(change)
    }
  }
  filtered
}

///|
async fn diff_observe_worktree_path(
  fs : OsFs,
  root : String,
  git_dir : String,
  path : String,
) -> DiffWorktreeObserved raise Error {
  let root_abs = ls_files_repo_root_abs(root)
  if rm_has_symlink_leading_path(path, root_abs, fn(abs : String) {
      @bitio.read_symlink_target_path(abs) is Some(_)
    }) {
    return { mode: None, id: None }
  }
  let abs = root + "/" + path
  let autocrlf = @bitlib.read_autocrlf_setting(fs, git_dir)
  match @bitio.worktree_entry(fs, abs) {
    Some(entry) =>
      match entry.kind {
        @bitio.WorktreeKind::Regular => {
          let content = fs.read_file(abs)
          let attrs = @bitlib.resolve_eol_attrs(fs, root, path)
          let normalized = @bitlib.clean_for_storage(content, attrs, autocrlf)
          {
            mode: Some(entry.mode),
            id: Some(
              @bitcore.hash_object_content(
                @bitcore.ObjectType::Blob,
                normalized,
              ),
            ),
          }
        }
        @bitio.WorktreeKind::Symlink(target~) => {
          let bytes = @utf8.encode(target)
          {
            mode: Some(entry.mode),
            id: Some(
              @bitcore.hash_object_content(@bitcore.ObjectType::Blob, bytes),
            ),
          }
        }
      }
    None =>
      if fs.is_dir(abs) {
        let sub_git = abs + "/.git"
        if fs.is_file(sub_git) || fs.is_dir(sub_git) {
          let sub_git_dir = @bitlib.resolve_gitdir(fs, sub_git)
          {
            mode: Some(0o160000),
            id: @bitlib.resolve_head_commit(fs, sub_git_dir),
          }
        } else {
          { mode: None, id: None }
        }
      } else {
        { mode: None, id: None }
      }
  }
}

///|
async fn diff_collect_raw_changes_against_index(
  fs : OsFs,
  root : String,
  git_dir : String,
  filters : Array[String],
) -> Array[DiffRawWorktreeChange] raise Error {
  let entries = @bitlib.read_index_entries(fs, git_dir)
  let changes : Array[DiffRawWorktreeChange] = []
  for entry in entries {
    if not(diff_path_matches_filters(entry.path, filters)) {
      continue
    }
    // Match git's stat-based behavior: when the index has zero stat data
    // (e.g. after read-tree), report files as modified without hashing.
    // git diff-files never rehashes; it only checks the stat cache.
    let stat_invalid = entry.mtime_sec == 0 && entry.mtime_nsec == 0
    if stat_invalid {
      let abs = root + "/" + entry.path
      let meta = @bitio.lstat_entry_meta(abs)
      if meta is Some(_) {
        diff_push_change_sorted(
          changes,
          {
            path: entry.path,
            status: "M",
            old_mode: Some(entry.mode),
            old_id: Some(entry.id),
            new_mode: Some(entry.mode),
          },
        )
      } else {
        diff_push_change_sorted(
          changes,
          {
            path: entry.path,
            status: "D",
            old_mode: Some(entry.mode),
            old_id: Some(entry.id),
            new_mode: None,
          },
        )
      }
      continue
    }
    let observed = diff_observe_worktree_path(fs, root, git_dir, entry.path)
    match
      diff_raw_worktree_change(
        entry.path,
        Some(entry.mode),
        Some(entry.id),
        observed,
      ) {
      Some(change) => diff_push_change_sorted(changes, change)
      None => ()
    }
  }
  changes
}

///|
async fn diff_collect_raw_changes_against_tree(
  fs : OsFs,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  spec : String,
  filters : Array[String],
) -> Array[DiffRawWorktreeChange] raise Error {
  let target = @bitrepo.rev_parse(rfs, git_dir, spec)
  guard target is Some(target_id) else {
    raise @bitcore.GitError::InvalidObject(
      "unknown revision or path not in the working tree: " + spec,
    )
  }
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let old_tree = resolve_diff_tree_id(db, rfs, target_id)
  guard old_tree is Some(old_tree_id) else {
    raise @bitcore.GitError::InvalidObject("object is not a tree-ish: " + spec)
  }
  let tree_entries = @bitlib.collect_tree_files(db, rfs, old_tree_id)
  let index_entries = @bitlib.read_index_entries(rfs, git_dir)
  let seen : Map[String, Bool] = {}
  let paths : Array[String] = []
  for entry in tree_entries {
    let path = entry.0
    if diff_path_matches_filters(path, filters) && not(seen.contains(path)) {
      seen[path] = true
      paths.push(path)
    }
  }
  for entry in index_entries {
    let path = entry.path
    if diff_path_matches_filters(path, filters) && not(seen.contains(path)) {
      seen[path] = true
      paths.push(path)
    }
  }
  let changes : Array[DiffRawWorktreeChange] = []
  for path in paths {
    let old = tree_entries.get(path)
    let observed = diff_observe_worktree_path(fs, root, git_dir, path)
    match
      diff_raw_worktree_change(
        path,
        old.map(e => e.mode),
        old.map(e => e.id),
        observed,
      ) {
      Some(change) => diff_push_change_sorted(changes, change)
      None => ()
    }
  }
  changes
}

///|
async fn collect_diff_index_stale_entries(
  fs : OsFs,
  root : String,
  filters : Array[String],
) -> Array[@bitlib.IndexEntry] raise Error {
  let git_dir = resolve_git_dir(fs, root)
  let entries = @bitlib.read_index_entries(fs, git_dir)
  let stale : Array[@bitlib.IndexEntry] = []
  for entry in entries {
    if not(diff_path_matches_filters(entry.path, filters)) {
      continue
    }
    if is_gitlink_mode_for_diff(entry.mode) {
      continue
    }
    let mut is_stale = entry.mtime_sec == 0 && entry.mtime_nsec == 0
    if not(is_stale) {
      let abs = root + "/" + entry.path
      let mtime_result : Result[(Int64, Int), Error] = try? @asyncfs.mtime(
        abs,
        follow_symlink=false,
      )
      match mtime_result {
        Ok((sec, nsec)) =>
          if sec.to_int() != entry.mtime_sec || nsec != entry.mtime_nsec {
            is_stale = true
          }
        Err(_) => is_stale = true
      }
      if not(is_stale) && entry.mode != 0o120000 {
        let size_result : Result[Bytes, Error] = try? fs.read_file(abs)
        match size_result {
          Ok(content) => if content.length() != entry.size { is_stale = true }
          Err(_) => ()
        }
      }
    }
    if is_stale {
      stale.push(entry)
    }
  }
  stale
}

///|
fn diff_path_matches_filters(path : String, filters : Array[String]) -> Bool {
  if filters.length() == 0 {
    return true
  }
  filters.iter().any(p => path == p || path.has_prefix(p + "/"))
}

///|
fn format_diff_index_line_from_diff_file(
  file : @bitdiff.DiffFile,
  worktree_compare? : Bool = false,
) -> String {
  let status = match file.kind {
    @bitdiff.DiffKind::Added => "A"
    @bitdiff.DiffKind::Modified => "M"
    @bitdiff.DiffKind::Deleted => "D"
  }
  let old_mode = diff_index_mode_string(file.old_mode)
  let new_mode = diff_index_mode_string(file.new_mode)
  let old_oid = diff_index_content_oid_string(file.old_content)
  let new_oid = if worktree_compare {
    diff_index_zero_oid_hex()
  } else {
    diff_index_content_oid_string(file.new_content)
  }
  ":\{old_mode} \{new_mode} \{old_oid} \{new_oid} \{status}\t\{file.path}"
}

///|
fn format_diff_index_line_from_entry(entry : @bitlib.IndexEntry) -> String {
  let mode = diff_index_mode_string(Some(entry.mode))
  let old_oid = entry.id.to_hex()
  let new_oid = diff_index_zero_oid_hex()
  ":\{mode} \{mode} \{old_oid} \{new_oid} M\t\{entry.path}"
}

///|
fn diff_index_content_oid_string(content : Bytes?) -> String {
  match content {
    Some(bytes) =>
      @bitcore.hash_object_content(@bitcore.ObjectType::Blob, bytes).to_hex()
    None => diff_index_zero_oid_hex()
  }
}

///|
fn diff_index_zero_oid_hex() -> String {
  "0000000000000000000000000000000000000000"
}

///|
fn diff_index_mode_string(mode : Int?) -> String {
  match mode {
    Some(value) => {
      let octal = diff_index_to_octal(value)
      if octal.length() >= 6 {
        octal
      } else {
        "0".repeat(6 - octal.length()) + octal
      }
    }
    None => "000000"
  }
}

///|
fn diff_index_to_octal(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let digits : Array[Char] = []
  let mut v = if value < 0 { -value } else { value }
  while v > 0 {
    let d = v % 8
    digits.push((d + '0'.to_int()).unsafe_to_char())
    v = v / 8
  }
  let rev = digits.rev()
  let sb = StringBuilder::new()
  if value < 0 {
    sb.write_char('-')
  }
  for digit in rev {
    sb.write_char(digit)
  }
  sb.to_string()
}

///|
fn diff_cached_against_ref(
  fs : OsFs,
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  spec : String,
) -> Array[@bitdiff.DiffFile] raise Error {
  ignore(root)
  let target = @bitrepo.rev_parse(rfs, git_dir, spec)
  guard target is Some(target_id) else {
    raise @bitcore.GitError::InvalidObject(
      "unknown revision or path not in the working tree: " + spec,
    )
  }
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let old_tree = resolve_diff_tree_id(db, rfs, target_id)
  guard old_tree is Some(old_tree_id) else {
    raise @bitcore.GitError::InvalidObject("object is not a tree-ish: " + spec)
  }
  let index_entries = @bitlib.read_index_entries(rfs, git_dir)
  let index_tree = @bitlib.write_tree_from_index(
    fs,
    rfs,
    git_dir,
    index_entries,
    missing_ok=true,
  )
  @bitdiff.diff_trees(rfs, git_dir, Some(old_tree_id), index_tree, db~)
}

///|
fn resolve_diff_tree_id(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> @bitcore.ObjectId? {
  let mut current = id
  for _ in 0..<8 {
    let obj = db.get(rfs, current) catch { _ => return None }
    guard obj is Some(o) else { return None }
    match o.obj_type {
      @bitcore.ObjectType::Tree => return Some(current)
      @bitcore.ObjectType::Commit => {
        let commit = @bitcore.parse_commit(o.data) catch { _ => return None }
        return Some(commit.tree)
      }
      @bitcore.ObjectType::Tag => {
        let parsed = parse_tag_object(decode_bytes(o.data)) catch { _ => None }
        guard parsed is Some(target) else { return None }
        current = target
      }
      _ => return None
    }
  }
  None
}

///|
async fn try_handle_submodule_range_diff(
  fs : OsFs,
  root : String,
  git_dir : String,
  repo_git_dir : String,
  spec : String,
) -> Bool raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let db = @bitlib.ObjectDb::load(rfs, repo_git_dir)
  guard resolve_submodule_diff_range(db, rfs, repo_git_dir, spec)
    is Some((old_commit, new_commit)) else {
    return false
  }
  let old_entries = @bitlib.collect_tree_files_from_commit(db, rfs, old_commit)
  let new_entries = @bitlib.collect_tree_files_from_commit(db, rfs, new_commit)
  let changes : Array[(String, @bitcore.ObjectId, @bitcore.ObjectId)] = []
  for item in new_entries.to_array() {
    let (path, new_entry) = item
    if not(is_gitlink_mode_for_diff(new_entry.mode)) {
      continue
    }
    match old_entries.get(path) {
      Some(old_entry) =>
        if is_gitlink_mode_for_diff(old_entry.mode) &&
          old_entry.id != new_entry.id {
          changes.push((path, old_entry.id, new_entry.id))
        }
      None => ()
    }
  }
  if changes.length() == 0 {
    return false
  }
  let submodules = parse_gitmodules(rfs, root)
  let mut handled = false
  for item in changes {
    let (path, old_id, new_id) = item
    let submodule_name = resolve_submodule_name_for_path(submodules, path)
    let subjects = collect_submodule_diff_subjects(
      fs, root, git_dir, repo_git_dir, path, submodule_name, old_id, new_id,
    )
    if subjects.length() == 0 {
      continue
    }
    print_line("Submodule \{path} \{old_id.to_hex()}..\{new_id.to_hex()}:")
    for subject in subjects {
      print_line("  > \{subject}")
    }
    handled = true
  }
  handled
}

///|
fn resolve_submodule_diff_range(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> (@bitcore.ObjectId, @bitcore.ObjectId)? raise Error {
  if spec.has_suffix("^!") && spec.length() > 2 {
    let target_ref = String::unsafe_substring(
      spec,
      start=0,
      end=spec.length() - 2,
    )
    let end_id = @bitrepo.rev_parse(rfs, git_dir, target_ref)
    guard end_id is Some(new_id) else { return None }
    guard db.get(rfs, new_id) is Some(obj) else { return None }
    if obj.obj_type != @bitcore.ObjectType::Commit {
      return None
    }
    let info = @bitcore.parse_commit(obj.data)
    if info.parents.length() == 0 {
      return None
    }
    return Some((info.parents[0], new_id))
  }
  match spec.find("..") {
    Some(idx) => {
      let start_ref = String::unsafe_substring(spec, start=0, end=idx)
      let end_ref = String::unsafe_substring(
        spec,
        start=idx + 2,
        end=spec.length(),
      )
      if start_ref.length() == 0 {
        return None
      }
      let start_id = @bitrepo.rev_parse(rfs, git_dir, start_ref)
      let end_id = @bitrepo.rev_parse(
        rfs,
        git_dir,
        if end_ref.length() == 0 {
          "HEAD"
        } else {
          end_ref
        },
      )
      guard start_id is Some(old_id) && end_id is Some(new_id) else {
        return None
      }
      Some((old_id, new_id))
    }
    None => None
  }
}

///|
fn resolve_submodule_name_for_path(
  submodules : Array[SubmoduleInfo],
  path : String,
) -> String {
  for sub in submodules {
    if sub.path == path {
      return sub.name
    }
  }
  path
}

///|
fn collect_submodule_diff_subjects(
  fs : OsFs,
  root : String,
  git_dir : String,
  repo_git_dir : String,
  path : String,
  submodule_name : String,
  old_id : @bitcore.ObjectId,
  new_id : @bitcore.ObjectId,
) -> Array[String] raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let candidates = resolve_submodule_git_dir_candidates(
    rfs, root, git_dir, repo_git_dir, path, submodule_name,
  )
  for sub_git_dir in candidates {
    let commits = collect_commits_in_range(rfs, sub_git_dir, old_id, new_id) catch {
      _ => []
    }
    if commits.length() == 0 {
      continue
    }
    let db = @bitlib.ObjectDb::load(rfs, sub_git_dir) catch { _ => continue }
    let subjects : Array[String] = []
    for commit_id in commits {
      match db.get(rfs, commit_id) {
        Some(obj) =>
          if obj.obj_type == @bitcore.ObjectType::Commit {
            let message = extract_commit_message(obj.data)
            let subject = get_first_line(message)
            if subject.length() > 0 {
              subjects.push(subject)
            }
          }
        None => ()
      }
    }
    if subjects.length() > 0 {
      return subjects
    }
  }
  []
}

///|
fn resolve_submodule_git_dir_candidates(
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  repo_git_dir : String,
  path : String,
  submodule_name : String,
) -> Array[String] {
  let candidates : Array[String] = []
  let worktree_git = root + "/" + path + "/.git"
  if rfs.is_file(worktree_git) {
    let resolved = @bitlib.resolve_gitdir(rfs, worktree_git)
    candidates.push(resolved)
  } else if rfs.is_dir(worktree_git) {
    candidates.push(worktree_git)
  }
  let linked_modules = git_dir + "/modules/" + submodule_name
  if rfs.is_dir(linked_modules) && not(candidates.contains(linked_modules)) {
    candidates.push(linked_modules)
  }
  let common_modules = repo_git_dir + "/modules/" + submodule_name
  if rfs.is_dir(common_modules) && not(candidates.contains(common_modules)) {
    candidates.push(common_modules)
  }
  candidates
}

///|
struct DiffNoIndexEntry {
  file : @bitdiff.DiffFile
  old_path : String
  new_path : String
  suppress_index : Bool
}

///|
fn diff_no_index_format_rename_path(
  old_path : String,
  new_path : String,
) -> String {
  let mut prefix = 0
  let max_prefix = if old_path.length() < new_path.length() {
    old_path.length()
  } else {
    new_path.length()
  }
  while prefix < max_prefix && old_path[prefix] == new_path[prefix] {
    prefix += 1
  }
  let mut suffix = 0
  while suffix < old_path.length() - prefix &&
        suffix < new_path.length() - prefix &&
        old_path[old_path.length() - suffix - 1] ==
        new_path[new_path.length() - suffix - 1] {
    suffix += 1
  }
  let prefix_text = String::unsafe_substring(old_path, start=0, end=prefix)
  let suffix_text = String::unsafe_substring(
    old_path,
    start=old_path.length() - suffix,
    end=old_path.length(),
  )
  let old_mid = String::unsafe_substring(
    old_path,
    start=prefix,
    end=old_path.length() - suffix,
  )
  let new_mid = String::unsafe_substring(
    new_path,
    start=prefix,
    end=new_path.length() - suffix,
  )
  prefix_text + "{" + old_mid + " => " + new_mid + "}" + suffix_text
}

///|
fn diff_no_index_display_path(entry : DiffNoIndexEntry) -> String {
  match entry.file.kind {
    @bitdiff.DiffKind::Added => entry.new_path
    @bitdiff.DiffKind::Deleted => entry.old_path
    @bitdiff.DiffKind::Modified =>
      if entry.old_path == entry.new_path {
        entry.old_path
      } else {
        diff_no_index_format_rename_path(entry.old_path, entry.new_path)
      }
  }
}

///|
fn diff_no_index_patch_header_paths(
  entry : DiffNoIndexEntry,
) -> (String, String) {
  match entry.file.kind {
    @bitdiff.DiffKind::Added => (entry.new_path, entry.new_path)
    @bitdiff.DiffKind::Deleted => (entry.old_path, entry.old_path)
    @bitdiff.DiffKind::Modified => (entry.old_path, entry.new_path)
  }
}

///|
fn diff_no_index_patch_label(
  path : String,
  side : String,
  no_prefix : Bool,
) -> String {
  if no_prefix {
    path
  } else {
    side + "/" + path
  }
}

///|
fn diff_no_index_should_suppress_index(entry : DiffNoIndexEntry) -> Bool {
  entry.suppress_index
}

///|
fn diff_no_index_match_path(
  entry : DiffNoIndexEntry,
  path_a : String,
  path_b : String,
) -> String {
  let clean_a = diff_no_index_trim_path(path_a)
  let clean_b = diff_no_index_trim_path(path_b)
  let source = match entry.file.kind {
    @bitdiff.DiffKind::Added => entry.new_path
    @bitdiff.DiffKind::Deleted => entry.old_path
    @bitdiff.DiffKind::Modified =>
      if entry.old_path != "/dev/null" {
        entry.old_path
      } else {
        entry.new_path
      }
  }
  let prefixes = [clean_a, clean_b]
  for prefix in prefixes {
    if source == prefix {
      return ""
    }
    if prefix.length() > 0 && source.has_prefix(prefix + "/") {
      return String::unsafe_substring(
        source,
        start=prefix.length() + 1,
        end=source.length(),
      )
    }
  }
  source
}

///|
fn diff_no_index_entry_matches_filters(
  entry : DiffNoIndexEntry,
  path_a : String,
  path_b : String,
  filters : Array[String],
) -> Bool raise Error {
  if filters.length() == 0 {
    return true
  }
  let match_path = diff_no_index_match_path(entry, path_a, path_b)
  let mut selected = false
  let mut saw_positive = false
  for filter in filters {
    if filter.has_prefix("/") {
      raise @bitcore.GitError::InvalidObject("absolute pathspec not supported")
    }
    let (_raw, is_exclude, _is_icase) = parse_pathspec_magic(filter)
    let matched = ls_files_pathspec_matches(match_path, filter)
    if is_exclude {
      if matched {
        return false
      }
    } else {
      saw_positive = true
      if matched {
        selected = true
      }
    }
  }
  if saw_positive {
    selected
  } else {
    true
  }
}

///|
fn diff_filter_no_index_entries(
  entries : Array[DiffNoIndexEntry],
  path_a : String,
  path_b : String,
  filters : Array[String],
) -> Array[DiffNoIndexEntry] raise Error {
  let out : Array[DiffNoIndexEntry] = []
  for entry in entries {
    if diff_no_index_entry_matches_filters(entry, path_a, path_b, filters) {
      out.push(entry)
    }
  }
  out
}

///|
fn diff_no_index_relative_path(path : String, prefix : String) -> String? {
  if path == "-" || path == "/dev/null" {
    return Some(path)
  }
  diff_apply_relative_path(path, prefix)
}

///|
fn diff_apply_relative_no_index_entries(
  entries : Array[DiffNoIndexEntry],
  prefix : String?,
) -> Array[DiffNoIndexEntry] {
  match prefix {
    None => entries
    Some(prefix) => {
      let out : Array[DiffNoIndexEntry] = []
      for entry in entries {
        match diff_apply_relative_path(entry.file.path, prefix) {
          Some(file_path) =>
            match
              (
                diff_no_index_relative_path(entry.old_path, prefix),
                diff_no_index_relative_path(entry.new_path, prefix),
              ) {
              (Some(old_path), Some(new_path)) =>
                out.push({
                  file: {
                    path: file_path,
                    kind: entry.file.kind,
                    old_content: entry.file.old_content,
                    new_content: entry.file.new_content,
                    old_mode: entry.file.old_mode,
                    new_mode: entry.file.new_mode,
                  },
                  old_path,
                  new_path,
                  suppress_index: entry.suppress_index,
                })
              _ => ()
            }
          None => ()
        }
      }
      out
    }
  }
}

///|
fn diff_no_index_patch_lines(
  entries : Array[DiffNoIndexEntry],
  context_lines : Int,
  no_prefix : Bool,
) -> Array[String] {
  let lines : Array[String] = []
  for entry in entries {
    let patch_lines = @bitdiff.diff_text([entry.file], context_lines~)
    let mut replaced_old = false
    let mut replaced_new = false
    let (header_old_path, header_new_path) = diff_no_index_patch_header_paths(
      entry,
    )
    let header_old_label = diff_no_index_patch_label(
      header_old_path, "a", no_prefix,
    )
    let header_new_label = diff_no_index_patch_label(
      header_new_path, "b", no_prefix,
    )
    let old_label = diff_no_index_patch_label(entry.old_path, "a", no_prefix)
    let new_label = diff_no_index_patch_label(entry.new_path, "b", no_prefix)
    let mode_only = match entry.file.kind {
      @bitdiff.DiffKind::Modified =>
        entry.file.old_content is None && entry.file.new_content is None
      _ => false
    }
    for i, line in patch_lines {
      if i == 0 {
        lines.push("diff --git \{header_old_label} \{header_new_label}")
      } else if line.has_prefix("index ") {
        if not(diff_no_index_should_suppress_index(entry)) {
          lines.push(line)
        }
      } else if not(replaced_old) && line.has_prefix("--- ") {
        replaced_old = true
        if mode_only {
          continue
        }
        let old_line = match entry.file.kind {
          @bitdiff.DiffKind::Added => "--- /dev/null"
          _ => "--- \{old_label}"
        }
        lines.push(old_line)
      } else if not(replaced_new) && line.has_prefix("+++ ") {
        replaced_new = true
        if mode_only {
          continue
        }
        let new_line = match entry.file.kind {
          @bitdiff.DiffKind::Deleted => "+++ /dev/null"
          _ => "+++ \{new_label}"
        }
        lines.push(new_line)
      } else if mode_only && line.has_prefix("@@ ") {
        continue
      } else {
        lines.push(line)
      }
    }
  }
  lines
}

///|
fn diff_collect_no_index_output_lines(
  entries : Array[DiffNoIndexEntry],
  output : DiffOutputSelection,
  context_lines : Int,
  no_prefix : Bool,
) -> Array[String] {
  let files : Array[@bitdiff.DiffFile] = []
  for entry in entries {
    files.push(entry.file)
  }
  let lines : Array[String] = []
  if output.name_only {
    for entry in entries {
      lines.push(diff_no_index_display_path(entry))
    }
    return lines
  }
  if output.name_status {
    for entry in entries {
      let status = match entry.file.kind {
        @bitdiff.DiffKind::Added => "A"
        @bitdiff.DiffKind::Modified => "M"
        @bitdiff.DiffKind::Deleted => "D"
      }
      lines.push("\{status}\t\{diff_no_index_display_path(entry)}")
    }
    return lines
  }
  if output.raw {
    for file in files {
      lines.push(format_diff_index_line_from_diff_file(file))
    }
  }
  if output.numstat {
    for entry in entries {
      let (add, del) = diff_count_line_changes(
        entry.file.old_content,
        entry.file.new_content,
      )
      lines.push("\{add}\t\{del}\t\{diff_no_index_display_path(entry)}")
    }
  }
  if output.stat {
    for line in diff_format_stat(files, compact_summary=output.compact_summary) {
      lines.push(line)
    }
  }
  if output.shortstat {
    for line in diff_format_shortstat(files) {
      lines.push(line)
    }
  }
  if output.dirstat {
    for
      line in diff_format_dirstat(
        files,
        by_file=output.dirstat_by_file,
        cumulative=output.dirstat_cumulative,
      ) {
      lines.push(line)
    }
  }
  if output.summary {
    for line in diff_format_summary(files) {
      lines.push(line)
    }
  }
  if output.patch {
    let patch_lines = diff_no_index_patch_lines(
      entries, context_lines, no_prefix,
    )
    if lines.length() > 0 && patch_lines.length() > 0 {
      lines.push("")
    }
    for line in patch_lines {
      lines.push(line)
    }
  }
  lines
}

///|
async fn diff_no_index_is_named_pipe(abs_path : String) -> Bool {
  if abs_path == "-" || abs_path == "/dev/null" {
    return false
  }
  let code = @process.run(
    "sh",
    ["-c", "test -p \"$1\"", "sh", abs_path],
    inherit_env=true,
  )
  code == 0
}

///|
async fn diff_no_index_is_file_like(fs : OsFs, abs_path : String) -> Bool {
  abs_path == "-" ||
  abs_path == "/dev/null" ||
  fs.is_file(abs_path) ||
  diff_no_index_is_named_pipe(abs_path) ||
  (
    @bitio.read_symlink_target_path(abs_path) is Some(_) &&
    not(fs.is_dir(abs_path))
  )
}

///|
async fn diff_no_index_uses_stream_read(fs : OsFs, abs_path : String) -> Bool {
  abs_path == "-" ||
  diff_no_index_is_named_pipe(abs_path) ||
  (
    @bitio.read_symlink_target_path(abs_path) is Some(_) &&
    not(fs.is_file(abs_path)) &&
    not(fs.is_dir(abs_path))
  )
}

///|
async fn diff_no_index_read_path(
  fs : OsFs,
  abs_path : String,
) -> Bytes raise Error {
  if abs_path == "-" {
    return read_all_stdin()
  }
  if diff_no_index_uses_stream_read(fs, abs_path) {
    let (code, stdout) = @process.collect_stdout(
      "sh",
      ["-c", "cat \"$1\"", "sh", abs_path],
      inherit_env=true,
    )
    if code != 0 {
      raise @bitcore.GitError::InvalidObject(
        "diff failed: unable to read " + abs_path,
      )
    }
    let text = stdout.text() catch {
      _ =>
        raise @bitcore.GitError::InvalidObject(
          "diff failed: unable to decode " + abs_path,
        )
    }
    return @utf8.encode(text.to_string_view())
  }
  fs.read_file(abs_path)
}

///|
async fn diff_no_index(
  fs : OsFs,
  abs_a : String,
  abs_b : String,
  display_a : String,
  display_b : String,
) -> Array[DiffNoIndexEntry] raise Error {
  let out : Array[DiffNoIndexEntry] = []
  let clean_abs_a = diff_no_index_trim_path(abs_a)
  let clean_abs_b = diff_no_index_trim_path(abs_b)
  let clean_display_a = diff_no_index_trim_path(display_a)
  let clean_display_b = diff_no_index_trim_path(display_b)
  let a_is_pipe = diff_no_index_is_named_pipe(clean_abs_a)
  let b_is_pipe = diff_no_index_is_named_pipe(clean_abs_b)
  let a_is_file = diff_no_index_is_file_like(fs, clean_abs_a)
  let b_is_file = diff_no_index_is_file_like(fs, clean_abs_b)
  if clean_abs_a == "-" && fs.is_dir(clean_abs_b) {
    raise @bitcore.GitError::InvalidObject(
      "fatal: cannot compare stdin to a directory",
    )
  } else if fs.is_dir(clean_abs_a) && clean_abs_b == "-" {
    raise @bitcore.GitError::InvalidObject(
      "fatal: cannot compare stdin to a directory",
    )
  } else if a_is_pipe && fs.is_dir(clean_abs_b) {
    raise @bitcore.GitError::InvalidObject(
      "fatal: cannot compare a named pipe to a directory",
    )
  } else if fs.is_dir(clean_abs_a) && b_is_pipe {
    raise @bitcore.GitError::InvalidObject(
      "fatal: cannot compare a named pipe to a directory",
    )
  }
  if clean_abs_a == "/dev/null" && b_is_file {
    let content = diff_no_index_read_path(fs, clean_abs_b)
    let suppress_index = diff_no_index_uses_stream_read(fs, clean_abs_b)
    out.push({
      file: {
        path: clean_display_b,
        kind: @bitdiff.DiffKind::Added,
        old_content: None,
        new_content: Some(content),
        old_mode: None,
        new_mode: Some(0o100644),
      },
      old_path: "/dev/null",
      new_path: clean_display_b,
      suppress_index,
    })
  } else if a_is_file && clean_abs_b == "/dev/null" {
    let content = diff_no_index_read_path(fs, clean_abs_a)
    let suppress_index = diff_no_index_uses_stream_read(fs, clean_abs_a)
    out.push({
      file: {
        path: clean_display_a,
        kind: @bitdiff.DiffKind::Deleted,
        old_content: Some(content),
        new_content: None,
        old_mode: Some(0o100644),
        new_mode: None,
      },
      old_path: clean_display_a,
      new_path: "/dev/null",
      suppress_index,
    })
  } else if a_is_file && b_is_file {
    let suppress_index = diff_no_index_uses_stream_read(fs, clean_abs_a) ||
      diff_no_index_uses_stream_read(fs, clean_abs_b)
    if clean_abs_a == "-" || clean_abs_b == "-" {
      let content_a = diff_no_index_read_path(fs, clean_abs_a)
      let content_b = diff_no_index_read_path(fs, clean_abs_b)
      diff_no_index_push_file(
        out,
        content_a,
        content_b,
        clean_display_a,
        clean_display_b,
        if clean_abs_a == "-" {
          0o100644
        } else {
          diff_no_index_file_mode(fs, clean_abs_a)
        },
        if clean_abs_b == "-" {
          0o100644
        } else {
          diff_no_index_file_mode(fs, clean_abs_b)
        },
        suppress_index~,
      )
    } else {
      diff_no_index_file(
        fs, out, clean_abs_a, clean_abs_b, clean_display_a, clean_display_b,
      )
    }
  } else if fs.is_dir(clean_abs_a) && fs.is_dir(clean_abs_b) {
    diff_no_index_dirs(
      fs, out, clean_abs_a, clean_abs_b, clean_display_a, clean_display_b,
    )
  } else if a_is_file && fs.is_dir(clean_abs_b) {
    // Compare file against same-named file in directory
    let basename = match clean_display_a.rev_find("/") {
      Some(idx) =>
        String::unsafe_substring(
          clean_display_a,
          start=idx + 1,
          end=clean_display_a.length(),
        )
      None => clean_display_a
    }
    let target_abs = clean_abs_b + "/" + basename
    if fs.is_file(target_abs) {
      diff_no_index_file(
        fs,
        out,
        clean_abs_a,
        target_abs,
        clean_display_a,
        clean_display_b + "/" + basename,
      )
    }
  } else if fs.is_dir(clean_abs_a) && b_is_file {
    let basename = match clean_display_b.rev_find("/") {
      Some(idx) =>
        String::unsafe_substring(
          clean_display_b,
          start=idx + 1,
          end=clean_display_b.length(),
        )
      None => clean_display_b
    }
    let target_abs = clean_abs_a + "/" + basename
    if fs.is_file(target_abs) {
      diff_no_index_file(
        fs,
        out,
        target_abs,
        clean_abs_b,
        clean_display_a + "/" + basename,
        clean_display_b,
      )
    }
  }
  out
}

///|
fn diff_no_index_file_mode(fs : OsFs, abs_path : String) -> Int {
  if abs_path == "-" || abs_path == "/dev/null" {
    return 0o100644
  }
  if @bitio.read_symlink_target_path(abs_path) is Some(_) &&
    not(fs.is_file(abs_path)) &&
    not(fs.is_dir(abs_path)) {
    return 0o100644
  }
  ignore(fs)
  match @bitio.lstat_entry_meta(abs_path) {
    Some(info) => info.mode
    None => 0o100644
  }
}

///|
fn diff_no_index_push_file(
  out : Array[DiffNoIndexEntry],
  content_a : Bytes,
  content_b : Bytes,
  display_a : String,
  display_b : String,
  mode_a : Int,
  mode_b : Int,
  suppress_index? : Bool = false,
) -> Unit {
  let id_a = @bitcore.hash_blob(content_a)
  let id_b = @bitcore.hash_blob(content_b)
  if id_a != id_b || mode_a != mode_b {
    // Use display_b as the canonical path for diff header
    let path = if display_a == display_b { display_a } else { display_b }
    out.push({
      file: {
        path,
        kind: @bitdiff.DiffKind::Modified,
        old_content: if id_a != id_b {
          Some(content_a)
        } else {
          None
        },
        new_content: if id_a != id_b {
          Some(content_b)
        } else {
          None
        },
        old_mode: Some(mode_a),
        new_mode: Some(mode_b),
      },
      old_path: display_a,
      new_path: display_b,
      suppress_index,
    })
  }
}

///|
async fn diff_no_index_file(
  fs : OsFs,
  out : Array[DiffNoIndexEntry],
  abs_a : String,
  abs_b : String,
  display_a : String,
  display_b : String,
) -> Unit raise Error {
  let content_a = diff_no_index_read_path(fs, abs_a)
  let content_b = diff_no_index_read_path(fs, abs_b)
  let suppress_index = diff_no_index_uses_stream_read(fs, abs_a) ||
    diff_no_index_uses_stream_read(fs, abs_b)
  diff_no_index_push_file(
    out,
    content_a,
    content_b,
    display_a,
    display_b,
    diff_no_index_file_mode(fs, abs_a),
    diff_no_index_file_mode(fs, abs_b),
    suppress_index~,
  )
}

///|
async fn diff_no_index_push_dir_entries(
  fs : OsFs,
  out : Array[DiffNoIndexEntry],
  dir : String,
  base : String,
  add_entries : Bool,
) -> Unit raise Error {
  let items = fs.readdir(dir) catch { _ => [] }
  items.sort()
  for name in items {
    if name == "." || name == ".." || name == ".git" {
      continue
    }
    let path = dir + "/" + name
    let rel = base + "/" + name
    if fs.is_dir(path) {
      diff_no_index_push_dir_entries(fs, out, path, rel, add_entries)
    } else {
      let content = diff_no_index_read_path(fs, path)
      if add_entries {
        out.push({
          file: {
            path: rel,
            kind: @bitdiff.DiffKind::Added,
            old_content: None,
            new_content: Some(content),
            old_mode: None,
            new_mode: Some(diff_no_index_file_mode(fs, path)),
          },
          old_path: "/dev/null",
          new_path: rel,
          suppress_index: false,
        })
      } else {
        out.push({
          file: {
            path: rel,
            kind: @bitdiff.DiffKind::Deleted,
            old_content: Some(content),
            new_content: None,
            old_mode: Some(diff_no_index_file_mode(fs, path)),
            new_mode: None,
          },
          old_path: rel,
          new_path: "/dev/null",
          suppress_index: false,
        })
      }
    }
  }
}

///|
async fn diff_no_index_dirs(
  fs : OsFs,
  out : Array[DiffNoIndexEntry],
  dir_a : String,
  dir_b : String,
  base_a : String,
  base_b : String,
) -> Unit raise Error {
  let items_a = fs.readdir(dir_a) catch { _ => [] }
  let items_b = fs.readdir(dir_b) catch { _ => [] }
  let set_a : Map[String, Bool] = {}
  let set_b : Map[String, Bool] = {}
  let all_names : Array[String] = []
  for name in items_a {
    if name == "." || name == ".." || name == ".git" {
      continue
    }
    set_a[name] = true
    all_names.push(name)
  }
  for name in items_b {
    if name == "." || name == ".." || name == ".git" {
      continue
    }
    set_b[name] = true
    if not(set_a.contains(name)) {
      all_names.push(name)
    }
  }
  all_names.sort()
  for name in all_names {
    let path_a = dir_a + "/" + name
    let path_b = dir_b + "/" + name
    let rel_a = base_a + "/" + name
    let rel_b = base_b + "/" + name
    let in_a = set_a.contains(name)
    let in_b = set_b.contains(name)
    if in_a && in_b {
      if fs.is_file(path_a) && fs.is_file(path_b) {
        diff_no_index_file(fs, out, path_a, path_b, rel_a, rel_b)
      } else if fs.is_dir(path_a) && fs.is_dir(path_b) {
        diff_no_index_dirs(fs, out, path_a, path_b, rel_a, rel_b)
      } else if fs.is_file(path_a) && fs.is_dir(path_b) {
        let content = diff_no_index_read_path(fs, path_a)
        out.push({
          file: {
            path: rel_a,
            kind: @bitdiff.DiffKind::Deleted,
            old_content: Some(content),
            new_content: None,
            old_mode: Some(diff_no_index_file_mode(fs, path_a)),
            new_mode: None,
          },
          old_path: rel_a,
          new_path: "/dev/null",
          suppress_index: false,
        })
        diff_no_index_push_dir_entries(fs, out, path_b, rel_b, true)
      } else if fs.is_dir(path_a) && fs.is_file(path_b) {
        diff_no_index_push_dir_entries(fs, out, path_a, rel_a, false)
        let content = diff_no_index_read_path(fs, path_b)
        out.push({
          file: {
            path: rel_b,
            kind: @bitdiff.DiffKind::Added,
            old_content: None,
            new_content: Some(content),
            old_mode: None,
            new_mode: Some(diff_no_index_file_mode(fs, path_b)),
          },
          old_path: "/dev/null",
          new_path: rel_b,
          suppress_index: false,
        })
      }
    } else if in_a && not(in_b) {
      if fs.is_file(path_a) {
        let content = diff_no_index_read_path(fs, path_a)
        out.push({
          file: {
            path: rel_a,
            kind: @bitdiff.DiffKind::Deleted,
            old_content: Some(content),
            new_content: None,
            old_mode: Some(0o100644),
            new_mode: None,
          },
          old_path: rel_a,
          new_path: "/dev/null",
          suppress_index: false,
        })
      } else if fs.is_dir(path_a) {
        diff_no_index_push_dir_entries(fs, out, path_a, rel_a, false)
      }
    } else if not(in_a) && in_b {
      if fs.is_file(path_b) {
        let content = diff_no_index_read_path(fs, path_b)
        out.push({
          file: {
            path: rel_b,
            kind: @bitdiff.DiffKind::Added,
            old_content: None,
            new_content: Some(content),
            old_mode: None,
            new_mode: Some(0o100644),
          },
          old_path: "/dev/null",
          new_path: rel_b,
          suppress_index: false,
        })
      } else if fs.is_dir(path_b) {
        diff_no_index_push_dir_entries(fs, out, path_b, rel_b, true)
      }
    }
  }
}

///|
