///|
/// Filesystem backend: one file per key under a root directory.
///
/// Two uses. It lets the WAL be exercised against real IO rather than only a
/// map, and it gives a single-node deployment that needs no bucket at all.
///
/// **Single-writer only.** Its compare-and-swap is a read-then-write with no
/// lock, so it is safe for one process and not for several. `supports_cas`
/// answers `true` because the preconditions really are enforced — against
/// concurrent writers on the same directory, use a real object store.
pub struct FsStore {
  fs : &@types.FileSystem
  rfs : &@types.RepoFileSystem
  root : String
}

///|
pub fn FsStore::new(
  fs : &@types.FileSystem,
  rfs : &@types.RepoFileSystem,
  root : String,
) -> FsStore {
  { fs, rfs, root }
}

///|
fn path_join(a : String, b : String) -> String {
  if a.length() == 0 {
    b
  } else if a[a.length() - 1] == '/' {
    a + b
  } else {
    a + "/" + b
  }
}

///|
/// Reject keys that could escape the root. Keys come from callers, but a WAL
/// key is eventually derived from a repository name that came off the wire.
fn check_key(key : String) -> Unit raise @bit.GitError {
  if key.length() == 0 {
    raise @bit.GitError::IoError("empty object key")
  }
  if key.has_prefix("/") || key.contains("//") {
    raise @bit.GitError::IoError("malformed object key: \{key}")
  }
  if key == ".." ||
    key.has_prefix("../") ||
    key.contains("/../") ||
    key.has_suffix("/..") {
    raise @bit.GitError::IoError("object key escapes the store root: \{key}")
  }
}

///|
fn FsStore::path_of(self : FsStore, key : String) -> String raise @bit.GitError {
  check_key(key)
  path_join(self.root, key)
}

///|
/// Create the directories a key's file needs.
fn FsStore::ensure_parent(
  self : FsStore,
  path : String,
) -> Unit raise @bit.GitError {
  let mut cut = -1
  for i in 0..<path.length() {
    if path[i] == '/' {
      cut = i
    }
  }
  if cut > 0 {
    self.fs.mkdir_p(String::unsafe_substring(path, start=0, end=cut))
  }
}

///|
fn FsStore::read_opt(
  self : FsStore,
  key : String,
) -> Bytes? raise @bit.GitError {
  let path = self.path_of(key)
  if !self.rfs.is_file(path) {
    return None
  }
  Some(self.rfs.read_file(path))
}

///|
/// Walk every file under `dir`, appending keys relative to the store root.
fn FsStore::walk(
  self : FsStore,
  dir : String,
  prefix_len : Int,
  out : Array[String],
) -> Unit raise @bit.GitError {
  if !self.rfs.is_dir(dir) {
    return
  }
  let names = self.rfs.readdir(dir)
  names.sort_by((a, b) => lex_compare(a, b))
  for name in names {
    if name == "." || name == ".." {
      continue
    }
    let child = path_join(dir, name)
    if self.rfs.is_dir(child) {
      self.walk(child, prefix_len, out)
    } else if self.rfs.is_file(child) {
      out.push(
        String::unsafe_substring(child, start=prefix_len, end=child.length()),
      )
    }
  }
}

///|
pub impl ObjectStore for FsStore with fn get(self, key) {
  match self.read_opt(key) {
    Some(body) => GetOutcome::Found(body, mem_etag(body))
    None => GetOutcome::Missing
  }
}

///|
pub impl ObjectStore for FsStore with fn get_range(self, key, range) {
  match self.read_opt(key) {
    Some(body) => GetOutcome::Found(mem_slice(body, range), mem_etag(body))
    None => GetOutcome::Missing
  }
}

///|
pub impl ObjectStore for FsStore with fn get_if_none_match(self, key, etag) {
  match self.read_opt(key) {
    Some(body) => {
      let current = mem_etag(body)
      if current == etag {
        GetOutcome::NotModified
      } else {
        GetOutcome::Found(body, current)
      }
    }
    None => GetOutcome::Missing
  }
}

///|
pub impl ObjectStore for FsStore with fn put(self, key, body, condition) {
  let existing = self.read_opt(key)
  let allowed = match condition {
    Unconditional => true
    IfNotExists => existing is None
    IfMatch(expected) =>
      match existing {
        Some(current) => mem_etag(current) == expected
        None => false
      }
  }
  if !allowed {
    return PutOutcome::NotApplied
  }
  let path = self.path_of(key)
  self.ensure_parent(path)
  self.fs.write_file(path, body) catch {
    // The write may have partially landed, so the caller has to re-read.
    _ => return PutOutcome::Unknown
  }
  PutOutcome::Applied(mem_etag(body))
}

///|
pub impl ObjectStore for FsStore with fn delete(self, key) {
  let path = self.path_of(key)
  if self.rfs.is_file(path) {
    self.fs.remove_file(path) catch {
      _ => ()
    }
  }
}

///|
pub impl ObjectStore for FsStore with fn list(self, prefix, after) {
  let all : Array[String] = []
  let root_len = if self.root.has_suffix("/") {
    self.root.length()
  } else {
    self.root.length() + 1
  }
  self.walk(self.root, root_len, all)
  all.sort_by((a, b) => lex_compare(a, b))
  let entries : Array[ObjEntry] = []
  for key in all {
    if !key.has_prefix(prefix) {
      continue
    }
    if after != "" && !lex_lt(after, key) {
      continue
    }
    let body = match self.read_opt(key) {
      Some(b) => b
      None => continue
    }
    entries.push({ key, size: body.length().to_int64(), etag: mem_etag(body) })
  }
  { entries, next: None }
}

///|
pub impl ObjectStore for FsStore with fn supports_cas(_self) {
  true
}
