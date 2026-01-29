///| Ref resolution helpers (rev-parse/show-ref)

///|
pub fn rev_parse(
  fs : &@git.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> @git.ObjectId? raise @git.GitError {
  if spec == "HEAD" {
    return resolve_head_commit(fs, git_dir)
  }
  if spec.has_prefix("refs/") {
    return resolve_ref(fs, git_dir, spec)
  }
  if spec.length() == 40 {
    match @git.ObjectId::from_hex(spec) {
      id => return Some(id)
    }
  }
  match resolve_ref(fs, git_dir, "refs/heads/" + spec) {
    Some(id) => return Some(id)
    None => ()
  }
  match resolve_ref(fs, git_dir, "refs/tags/" + spec) {
    Some(id) => return Some(id)
    None => ()
  }
  None
}

///|
/// List all refs (loose + packed).
pub fn show_ref(
  fs : &@git.RepoFileSystem,
  git_dir : String,
) -> Array[(String, @git.ObjectId)] raise @git.GitError {
  let out : Map[String, @git.ObjectId] = {}
  let refs_dir = join_path(git_dir, "refs")
  if fs.is_dir(refs_dir) {
    ref_collect_loose(fs, refs_dir, "refs", out)
  }
  let packed = join_path(git_dir, "packed-refs")
  if fs.is_file(packed) {
    ref_collect_packed(fs, packed, out)
  }
  let result : Array[(String, @git.ObjectId)] = []
  for item in out.to_array() {
    let (name, id) = item
    result.push((name, id))
  }
  result.sort_by(fn(a, b) { String::compare(a.0, b.0) })
  result
}

///|
/// Format like `git show-ref` output.
pub fn show_ref_text(
  fs : &@git.RepoFileSystem,
  git_dir : String,
) -> Array[String] raise @git.GitError {
  let refs = show_ref(fs, git_dir)
  let lines : Array[String] = []
  for item in refs {
    let (name, id) = item
    lines.push("\{id.to_hex()} \{name}")
  }
  lines
}

///|
fn ref_collect_loose(
  fs : &@git.RepoFileSystem,
  dir : String,
  prefix : String,
  out : Map[String, @git.ObjectId],
) -> Unit raise @git.GitError {
  let entries = fs.readdir(dir)
  for name in entries {
    let path = join_path(dir, name)
    let rel = if prefix == "" { name } else { prefix + "/" + name }
    if fs.is_dir(path) {
      ref_collect_loose(fs, path, rel, out)
    } else if fs.is_file(path) {
      let line = ref_read_line(fs, path)
      out[rel] = @git.ObjectId::from_hex(line)
    }
  }
}

///|
fn ref_collect_packed(
  fs : &@git.RepoFileSystem,
  packed_path : String,
  out : Map[String, @git.ObjectId],
) -> Unit raise @git.GitError {
  let text = @utf8.decode_lossy(fs.read_file(packed_path)[:])
  for line_view in text.split("\n") {
    let line = ref_trim_line(line_view.to_string())
    if line.length() == 0 {
      continue
    }
    if line.has_prefix("#") || line.has_prefix("^") {
      continue
    }
    let space = line.find(" ")
    match space {
      None => continue
      Some(idx) => {
        if idx + 1 >= line.length() {
          continue
        }
        let id_hex = String::unsafe_substring(line, start=0, end=idx)
        let name = String::unsafe_substring(
          line,
          start=idx + 1,
          end=line.length(),
        )
        if not(out.contains(name)) {
          out[name] = @git.ObjectId::from_hex(id_hex)
        }
      }
    }
  }
}

///|
fn ref_read_line(
  fs : &@git.RepoFileSystem,
  path : String,
) -> String raise @git.GitError {
  let text = @utf8.decode_lossy(fs.read_file(path)[:])
  for line_view in text.split("\n") {
    let line = ref_trim_line(line_view.to_string())
    if line.length() > 0 {
      return line
    }
  }
  raise @git.GitError::InvalidObject("Empty ref: \{path}")
}

///|
fn ref_trim_line(line : String) -> String {
  let mut s = line
  if s.has_suffix("\r") {
    s = String::unsafe_substring(s, start=0, end=s.length() - 1)
  }
  s
}
