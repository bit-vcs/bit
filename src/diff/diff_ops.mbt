///| Git diff helpers (extracted package)

///|
pub enum DiffKind {
  Added
  Modified
  Deleted
}

///|
pub struct DiffFile {
  path : String
  kind : DiffKind
  old_content : Bytes?
  new_content : Bytes?
  old_mode : Int?
  new_mode : Int?
}

///|
/// Diff working tree against index (default `git diff`).
pub async fn diff_worktree(
  fs : &@git.RepoFileSystem,
  root : String,
) -> Array[DiffFile] raise @git.GitError {
  let profile = profile_enabled()
  let mut t0 = profile_start(profile)
  let git_dir = @git.join_path(root, ".git")
  let autocrlf = read_autocrlf_setting(fs, git_dir)
  let index_entries = @gitlib.read_index_entries(fs, git_dir)
  t0 = profile_lap(profile, "diff_worktree read_index_entries", t0)
  let db = @gitlib.ObjectDb::load_lazy(fs, git_dir)
  t0 = profile_lap(profile, "diff_worktree load_db", t0)
  let cached_files = @ignore.working_files_cache(root)
  let cache_map : Map[String, Bool] = {}
  let mut cache_ready = false
  match cached_files {
    Some(files) => {
      cache_ready = true
      for p in files {
        cache_map[p] = true
      }
    }
    None => ()
  }
  let out : Array[DiffFile] = []
  for entry in index_entries {
    let path = entry.path
    if is_gitlink_mode_int(entry.mode) {
      continue
    }
    if cache_ready && not(cache_map.contains(path)) {
      let ignored = @ignore.is_ignored_path(fs, root, path, false)
      if not(ignored) {
        let old = diff_read_blob(db, fs, entry.id)
        // Skip if blob not found (e.g., submodule)
        if old is Some(_) {
          out.push({
            path,
            kind: DiffKind::Deleted,
            old_content: old,
            new_content: None,
            old_mode: Some(entry.mode),
            new_mode: None,
          })
        }
        continue
      }
    }
    let abs = @git.join_path(root, path)
    match @gitio.worktree_entry_meta(fs, abs) {
      None => {
        let old = diff_read_blob(db, fs, entry.id)
        // Skip if blob not found (e.g., submodule)
        if old is Some(_) {
          out.push({
            path,
            kind: DiffKind::Deleted,
            old_content: old,
            new_content: None,
            old_mode: Some(entry.mode),
            new_mode: None,
          })
        }
      }
      Some(info) => {
        let mut content_changed = false
        let mode_changed = info.mode != entry.mode
        let mut old_content : Bytes? = None
        let mut new_content : Bytes? = None
        match info.kind {
          @gitio.WorktreeKindMeta::Regular => {
            let mut stat_matches = false
            match info.size {
              Some(sz) =>
                match info.mtime_sec {
                  Some(ms) =>
                    match info.mtime_nsec {
                      Some(mn) =>
                        if entry.mtime_sec != 0 || entry.mtime_nsec != 0 {
                          stat_matches = sz == entry.size &&
                            ms == entry.mtime_sec &&
                            mn == entry.mtime_nsec
                        }
                      None => ()
                    }
                  None => ()
                }
              None => ()
            }
            if not(mode_changed) && stat_matches {
              content_changed = false
            } else {
              let content = fs.read_file(abs)
              let normalized = normalize_worktree_content(content, autocrlf)
              let id = @git.hash_blob(normalized)
              content_changed = id != entry.id
              if content_changed {
                let old = diff_read_blob(db, fs, entry.id)
                if old is Some(_) {
                  old_content = old
                  new_content = Some(normalized)
                }
              }
            }
          }
          @gitio.WorktreeKindMeta::Symlink => {
            let mut stat_matches = false
            match info.mtime_sec {
              Some(ms) =>
                match info.mtime_nsec {
                  Some(mn) =>
                    if entry.mtime_sec != 0 || entry.mtime_nsec != 0 {
                      stat_matches = ms == entry.mtime_sec &&
                        mn == entry.mtime_nsec
                    }
                  None => ()
                }
              None => ()
            }
            if not(mode_changed) && stat_matches {
              content_changed = false
            } else {
              match @gitio.read_symlink_target_path(abs) {
                Some(target) => {
                  let bytes = @utf8.encode(target)
                  let id = @git.hash_blob(bytes)
                  content_changed = id != entry.id
                  if content_changed {
                    let old = diff_read_blob(db, fs, entry.id)
                    if old is Some(_) {
                      old_content = old
                      new_content = Some(bytes)
                    }
                  }
                }
                None => ()
              }
            }
          }
        }
        if content_changed && old_content is None {
          continue
        }
        if content_changed || mode_changed {
          out.push({
            path,
            kind: DiffKind::Modified,
            old_content,
            new_content,
            old_mode: Some(entry.mode),
            new_mode: Some(info.mode),
          })
        }
      }
    }
  }
  t0 = profile_lap(profile, "diff_worktree scan_entries", t0)
  out.sort_by((a, b) => String::compare(a.path, b.path))
  ignore(profile_lap(profile, "diff_worktree sort", t0))
  out
}

///|
/// Diff index against HEAD (`git diff --cached`).
pub fn diff_index(
  fs : &@git.RepoFileSystem,
  root : String,
) -> Array[DiffFile] raise @git.GitError {
  let git_dir = @git.join_path(root, ".git")
  let index_entries = @gitlib.read_index_entries(fs, git_dir)
  let index_map : Map[String, @gitlib.IndexEntry] = {}
  for e in index_entries {
    index_map[e.path] = e
  }
  let head_entries = diff_read_head_entries(fs, git_dir)
  let db = @gitlib.ObjectDb::load_lazy(fs, git_dir)
  let out : Array[DiffFile] = []
  for item in index_map.to_array() {
    let (path, entry) = item
    match head_entries.get(path) {
      None => {
        let new = diff_read_blob(db, fs, entry.id)
        // Skip if blob not found (e.g., submodule)
        if new is Some(_) {
          out.push({
            path,
            kind: DiffKind::Added,
            old_content: None,
            new_content: new,
            old_mode: None,
            new_mode: Some(entry.mode),
          })
        }
      }
      Some(h) =>
        if h.id != entry.id || h.mode != entry.mode {
          let content_changed = h.id != entry.id
          let mut old : Bytes? = None
          let mut new : Bytes? = None
          if content_changed {
            old = diff_read_blob(db, fs, h.id)
            new = diff_read_blob(db, fs, entry.id)
            // Skip if either blob not found (e.g., submodule)
            if old is None || new is None {
              continue
            }
          }
          out.push({
            path,
            kind: DiffKind::Modified,
            old_content: old,
            new_content: new,
            old_mode: Some(h.mode),
            new_mode: Some(entry.mode),
          })
        }
    }
  }
  for item in head_entries.to_array() {
    let (path, h) = item
    if not(index_map.contains(path)) {
      let old = diff_read_blob(db, fs, h.id)
      // Skip if blob not found (e.g., submodule)
      if old is Some(_) {
        out.push({
          path,
          kind: DiffKind::Deleted,
          old_content: old,
          new_content: None,
          old_mode: Some(h.mode),
          new_mode: None,
        })
      }
    }
  }
  out.sort_by((a, b) => String::compare(a.path, b.path))
  out
}

///|
/// Format diff as unified text.
pub fn diff_text(files : Array[DiffFile]) -> Array[String] {
  let lines : Array[String] = []
  for f in files {
    lines.push("diff --git a/\{f.path} b/\{f.path}")
    diff_emit_modes(lines, f)
    match f.kind {
      DiffKind::Added => {
        diff_emit_index_line(lines, None, f.new_content, None)
        lines.push("--- /dev/null")
        lines.push("+++ b/\{f.path}")
        diff_emit_unified_hunk(lines, None, f.new_content)
      }
      DiffKind::Deleted => {
        diff_emit_index_line(lines, f.old_content, None, None)
        lines.push("--- a/\{f.path}")
        lines.push("+++ /dev/null")
        diff_emit_unified_hunk(lines, f.old_content, None)
      }
      DiffKind::Modified => {
        let mode = match (f.old_mode, f.new_mode) {
          (Some(old), Some(new)) if old == new => Some(new)
          _ => None
        }
        diff_emit_index_line(lines, f.old_content, f.new_content, mode)
        lines.push("--- a/\{f.path}")
        lines.push("+++ b/\{f.path}")
        diff_emit_unified_hunk(lines, f.old_content, f.new_content)
      }
    }
  }
  lines
}

///|
fn diff_blob_short_id(data : Bytes) -> String {
  let hex = @git.hash_blob(data).to_hex()
  String::unsafe_substring(hex, start=0, end=7)
}

///|
fn diff_emit_index_line(
  out : Array[String],
  old_content : Bytes?,
  new_content : Bytes?,
  mode : Int?,
) -> Unit {
  let old_short = match old_content {
    Some(data) => diff_blob_short_id(data)
    None => "0000000"
  }
  let new_short = match new_content {
    Some(data) => diff_blob_short_id(data)
    None => "0000000"
  }
  if old_short == "0000000" && new_short == "0000000" {
    return
  }
  let mut line = "index \{old_short}..\{new_short}"
  match mode {
    Some(file_mode) => line += " " + mode_to_string(file_mode)
    None => ()
  }
  out.push(line)
}

///|
fn diff_emit_unified_hunk(
  out : Array[String],
  old_content : Bytes?,
  new_content : Bytes?,
) -> Unit {
  guard old_content is Some(_) || new_content is Some(_) else { return }
  let old_lines = match old_content {
    Some(data) => diff_split_lines_no_trailing_empty(data)
    None => []
  }
  let new_lines = match new_content {
    Some(data) => diff_split_lines_no_trailing_empty(data)
    None => []
  }
  if old_lines.length() == 0 && new_lines.length() == 0 {
    return
  }
  let old_start = if old_lines.length() == 0 { 0 } else { 1 }
  let new_start = if new_lines.length() == 0 { 0 } else { 1 }
  let old_range = diff_format_range(old_start, old_lines.length())
  let new_range = diff_format_range(new_start, new_lines.length())
  out.push("@@ -\{old_range} +\{new_range} @@")
  for line in old_lines {
    out.push("-" + line)
  }
  for line in new_lines {
    out.push("+" + line)
  }
}

///|
fn diff_format_range(start : Int, count : Int) -> String {
  if count == 0 {
    "\{start},0"
  } else if count == 1 {
    start.to_string()
  } else {
    "\{start},\{count}"
  }
}

///|
fn diff_split_lines_no_trailing_empty(data : Bytes) -> Array[String] {
  let text = @utf8.decode_lossy(data[:])
  let lines : Array[String] = []
  for line_view in text.split("\n") {
    lines.push(line_view.to_string())
  }
  if text.has_suffix("\n") &&
    lines.length() > 0 &&
    lines[lines.length() - 1].length() == 0 {
    ignore(lines.pop())
  }
  lines
}

///|
fn diff_emit_modes(out : Array[String], f : DiffFile) -> Unit {
  match f.kind {
    DiffKind::Added =>
      match f.new_mode {
        Some(mode) => out.push("new file mode " + mode_to_string(mode))
        None => ()
      }
    DiffKind::Deleted =>
      match f.old_mode {
        Some(mode) => out.push("deleted file mode " + mode_to_string(mode))
        None => ()
      }
    DiffKind::Modified =>
      match (f.old_mode, f.new_mode) {
        (Some(old), Some(new)) if old != new => {
          out.push("old mode " + mode_to_string(old))
          out.push("new mode " + mode_to_string(new))
        }
        _ => ()
      }
  }
}

///|
/// Format diff as stat summary (like git diff --stat).
pub fn diff_stat(files : Array[DiffFile]) -> Array[String] {
  let lines : Array[String] = []
  let mut total_add = 0
  let mut total_del = 0
  let mut max_name_len = 0
  for f in files {
    if f.path.length() > max_name_len {
      max_name_len = f.path.length()
    }
  }
  for f in files {
    let (add, del) = count_line_changes(f.old_content, f.new_content)
    total_add = total_add + add
    total_del = total_del + del
    let total = add + del
    let bar_len = if total > 50 { 50 } else { total }
    let add_bar = "+".repeat(if total > 0 { add * bar_len / total } else { 0 })
    let del_bar = "-".repeat(if total > 0 { del * bar_len / total } else { 0 })
    let padding = " ".repeat(max_name_len - f.path.length())
    lines.push(" \{f.path}\{padding} | \{total} \{add_bar}\{del_bar}")
  }
  if files.length() > 0 {
    let files_changed = files.length()
    lines.push(
      " \{files_changed} file(s) changed, \{total_add} insertions(+), \{total_del} deletions(-)",
    )
  }
  lines
}

///|
fn count_line_changes(old : Bytes?, new : Bytes?) -> (Int, Int) {
  let old_lines = match old {
    Some(data) => count_lines(data)
    None => 0
  }
  let new_lines = match new {
    Some(data) => count_lines(data)
    None => 0
  }
  if new_lines >= old_lines {
    (new_lines - old_lines, 0)
  } else {
    (0, old_lines - new_lines)
  }
}

///|
fn count_lines(data : Bytes) -> Int {
  let mut count = 0
  for b in data {
    if b == b'\n' {
      count = count + 1
    }
  }
  if data.length() > 0 && data[data.length() - 1] != b'\n' {
    count = count + 1
  }
  count
}

///|
fn diff_read_blob(
  db : @gitlib.ObjectDb,
  fs : &@git.RepoFileSystem,
  id : @git.ObjectId,
) -> Bytes? raise @git.GitError {
  let obj = db.get(fs, id)
  match obj {
    None => None // Object might be in a submodule or unavailable
    Some(o) =>
      if o.obj_type != @git.ObjectType::Blob {
        None // Submodule entries point to commits, not blobs
      } else {
        Some(o.data)
      }
  }
}

///|
priv struct DiffHeadEntry {
  id : @git.ObjectId
  mode : Int
}

///|
fn diff_read_head_entries(
  fs : &@git.RepoFileSystem,
  git_dir : String,
) -> Map[String, DiffHeadEntry] raise @git.GitError {
  let result : Map[String, DiffHeadEntry] = {}
  let head = @gitlib.resolve_head_commit(fs, git_dir)
  match head {
    None => return result
    Some(commit_id) => {
      let db = @gitlib.ObjectDb::load(fs, git_dir)
      let commit_obj = db.get(fs, commit_id)
      match commit_obj {
        None => return result
        Some(obj) => {
          if obj.obj_type != @git.ObjectType::Commit {
            raise @git.GitError::InvalidObject("Object is not a commit")
          }
          let info = @git.parse_commit(obj.data)
          diff_collect_tree(db, fs, info.tree, "", result)
        }
      }
    }
  }
  result
}

///|
fn diff_collect_tree(
  db : @gitlib.ObjectDb,
  fs : &@git.RepoFileSystem,
  tree_id : @git.ObjectId,
  prefix : String,
  out : Map[String, DiffHeadEntry],
) -> Unit raise @git.GitError {
  let tree_obj = db.get(fs, tree_id)
  match tree_obj {
    None => raise @git.GitError::InvalidObject("Missing tree object")
    Some(obj) => {
      if obj.obj_type != @git.ObjectType::Tree {
        raise @git.GitError::InvalidObject("Object is not a tree")
      }
      let entries = @git.parse_tree(obj.data)
      for entry in entries {
        let path = if prefix.length() == 0 {
          entry.name
        } else {
          prefix + "/" + entry.name
        }
        if diff_is_tree_mode(entry.mode) {
          diff_collect_tree(db, fs, entry.id, path, out)
        } else {
          out[path] = { id: entry.id, mode: worktree_parse_octal(entry.mode) }
        }
      }
    }
  }
}

///|
fn diff_is_tree_mode(mode : String) -> Bool {
  mode == "40000" || mode == "040000"
}

///|
/// Diff two trees by their ObjectIds. Returns DiffFile array.
pub fn diff_trees(
  fs : &@git.RepoFileSystem,
  git_dir : String,
  old_tree : @git.ObjectId?,
  new_tree : @git.ObjectId,
) -> Array[DiffFile] raise @git.GitError {
  let db = @gitlib.ObjectDb::load(fs, git_dir)
  let out : Array[DiffFile] = []
  let old_entries : Map[String, DiffHeadEntry] = {}
  let new_entries : Map[String, DiffHeadEntry] = {}
  match old_tree {
    Some(ot) => diff_collect_tree(db, fs, ot, "", old_entries)
    None => ()
  }
  diff_collect_tree(db, fs, new_tree, "", new_entries)
  // Added and modified
  for path, entry in new_entries {
    match old_entries.get(path) {
      None => {
        let new_content = diff_read_blob(db, fs, entry.id)
        if new_content is Some(_) {
          out.push({
            path,
            kind: DiffKind::Added,
            old_content: None,
            new_content,
            old_mode: None,
            new_mode: Some(entry.mode),
          })
        }
      }
      Some(old_entry) =>
        if old_entry.id != entry.id || old_entry.mode != entry.mode {
          let old_content = diff_read_blob(db, fs, old_entry.id)
          let new_content = diff_read_blob(db, fs, entry.id)
          out.push({
            path,
            kind: DiffKind::Modified,
            old_content,
            new_content,
            old_mode: Some(old_entry.mode),
            new_mode: Some(entry.mode),
          })
        }
    }
  }
  // Deleted
  for path, entry in old_entries {
    if not(new_entries.contains(path)) {
      let old_content = diff_read_blob(db, fs, entry.id)
      if old_content is Some(_) {
        out.push({
          path,
          kind: DiffKind::Deleted,
          old_content,
          new_content: None,
          old_mode: Some(entry.mode),
          new_mode: None,
        })
      }
    }
  }
  out.sort_by(fn(a, b) { String::compare(a.path, b.path) })
  out
}

///|
fn is_gitlink_mode_int(mode : Int) -> Bool {
  mode == 0o160000
}

///|
fn default_file_mode() -> Int {
  33188 // 0o100644
}

///|
fn mode_to_string(mode : Int) -> String {
  if mode == default_file_mode() {
    "100644"
  } else {
    to_octal_string(mode)
  }
}

///|
fn to_octal_string(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let digits : Array[Char] = []
  let mut v = value
  while v > 0 {
    let d = v % 8
    digits.push((d + '0'.to_int()).unsafe_to_char())
    v = v / 8
  }
  let rev = digits.rev()
  let sb = StringBuilder::new()
  for c in rev {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn worktree_parse_octal(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c < '0' || c > '7' {
      continue
    }
    result = result * 8 + (c.to_int() - '0'.to_int())
  }
  result
}

///|
priv enum AutoCrlf {
  Off
  Input
  On
}

///|
fn read_autocrlf_setting(
  fs : &@git.RepoFileSystem,
  git_dir : String,
) -> AutoCrlf {
  let mut value : AutoCrlf? = None
  match @gitio.env_get("HOME") {
    None => ()
    Some(home) => {
      let candidates : Array[String] = []
      if @gitio.env_get("XDG_CONFIG_HOME") is Some(base) {
        candidates.push(base + "/git/config")
      }
      candidates.push(home + "/.gitconfig")
      for path in candidates {
        if fs.is_file(path) {
          value = read_autocrlf_from_config(fs, path)
          break
        }
      }
    }
  }
  let local_path = @git.join_path(git_dir, "config")
  if fs.is_file(local_path) {
    match read_autocrlf_from_config(fs, local_path) {
      Some(v) => value = Some(v)
      None => ()
    }
  }
  match value {
    Some(v) => v
    None => AutoCrlf::Off
  }
}

///|
fn read_autocrlf_from_config(
  fs : &@git.RepoFileSystem,
  path : String,
) -> AutoCrlf? {
  let bytes = fs.read_file(path) catch { _ => return None }
  let content = @utf8.decode_lossy(bytes[:])
  parse_autocrlf_from_content(content)
}

///|
fn parse_autocrlf_from_content(content : String) -> AutoCrlf? {
  let mut section = ""
  let mut value : AutoCrlf? = None
  for line_view in content.split("\n") {
    let line = line_view.trim().to_string()
    if line.length() == 0 {
      continue
    }
    if line.has_prefix("#") || line.has_prefix(";") {
      continue
    }
    if line.has_prefix("[") && line.has_suffix("]") {
      let inner = String::unsafe_substring(line, start=1, end=line.length() - 1)
      let inner_trim = inner.trim().to_string()
      let section_name = match inner_trim.find(" ") {
        Some(i) => String::unsafe_substring(inner_trim, start=0, end=i)
        None => inner_trim
      }
      section = section_name.to_lower()
      continue
    }
    if section != "core" {
      continue
    }
    match line.find("=") {
      None => ()
      Some(idx) => {
        let key = String::unsafe_substring(line, start=0, end=idx)
          .trim()
          .to_string()
          .to_lower()
        if key != "autocrlf" {
          continue
        }
        let raw_value = String::unsafe_substring(
            line,
            start=idx + 1,
            end=line.length(),
          )
          .trim()
          .to_string()
          .to_lower()
        value = raw_value |> parse_autocrlf_value |> Some
      }
    }
  }
  value
}

///|
fn parse_autocrlf_value(value : String) -> AutoCrlf {
  match value {
    "true" | "yes" | "1" => AutoCrlf::On
    "input" => AutoCrlf::Input
    _ => AutoCrlf::Off
  }
}

///|
fn normalize_worktree_content(content : Bytes, autocrlf : AutoCrlf) -> Bytes {
  match autocrlf {
    Off => content
    Input | On =>
      if is_binary_bytes(content) {
        content
      } else {
        normalize_crlf_to_lf(content)
      }
  }
}

///|
fn is_binary_bytes(content : Bytes) -> Bool {
  let limit = if content.length() > 8000 { 8000 } else { content.length() }
  for i in 0..<limit {
    if content[i] == b'\x00' {
      return true
    }
  }
  false
}

///|
fn normalize_crlf_to_lf(content : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  let mut changed = false
  while i < content.length() {
    if content[i] == b'\r' &&
      i + 1 < content.length() &&
      content[i + 1] == b'\n' {
      out.push(b'\n')
      i += 2
      changed = true
      continue
    }
    out.push(content[i])
    i += 1
  }
  if not(changed) {
    return content
  }
  Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
}

///|
fn profile_enabled() -> Bool {
  match @gitio.env_get("BIT_PROFILE") {
    Some(v) => v != "" && v != "0"
    None => false
  }
}

///|
fn profile_start(enabled : Bool) -> @bench.Timestamp? {
  if enabled {
    Some(@bench.monotonic_clock_start())
  } else {
    None
  }
}

///|
fn profile_lap(
  enabled : Bool,
  label : String,
  start : @bench.Timestamp?,
) -> @bench.Timestamp? {
  if not(enabled) {
    return start
  }
  match start {
    Some(ts) => {
      let elapsed_us = @bench.monotonic_clock_end(ts)
      let elapsed_ms = elapsed_us / 1000.0
      println("\{label}: \{elapsed_ms}ms")
      Some(@bench.monotonic_clock_start())
    }
    None => Some(@bench.monotonic_clock_start())
  }
}
