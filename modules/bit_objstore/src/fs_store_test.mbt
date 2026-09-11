///|
/// Minimal in-memory filesystem, just enough to drive `FsStore`.
///
/// Written here rather than pulled from `bit_io` so this module keeps no
/// dependency it does not need at run time.
struct TinyFs {
  files : Map[String, Bytes]
  dirs : Map[String, Bool]
}

///|
fn TinyFs::new() -> TinyFs {
  let dirs : Map[String, Bool] = Map([])
  dirs["/store"] = true
  { files: Map([]), dirs }
}

///|
fn TinyFs::add_dirs(self : TinyFs, path : String) -> Unit {
  let mut i = 0
  while i < path.length() {
    if path[i] == '/' && i > 0 {
      self.dirs[String::unsafe_substring(path, start=0, end=i)] = true
    }
    i += 1
  }
  self.dirs[path] = true
}

///|
pub impl @types.FileSystem for TinyFs with fn mkdir_p(self, path) {
  self.add_dirs(path)
}

///|
pub impl @types.FileSystem for TinyFs with fn write_file(self, path, content) {
  self.files[path] = content
}

///|
pub impl @types.FileSystem for TinyFs with fn write_string(self, path, content) {
  self.files[path] = @utf8.encode(content)
}

///|
pub impl @types.FileSystem for TinyFs with fn remove_file(self, path) {
  self.files.remove(path)
}

///|
pub impl @types.FileSystem for TinyFs with fn remove_dir(self, path) {
  self.dirs.remove(path)
}

///|
pub impl @types.RepoFileSystem for TinyFs with fn read_file(self, path) {
  match self.files.get(path) {
    Some(body) => body
    None => raise @bit.GitError::IoError("no such file: \{path}")
  }
}

///|
pub impl @types.RepoFileSystem for TinyFs with fn readdir(self, path) {
  let prefix = if path.has_suffix("/") { path } else { path + "/" }
  let names : Map[String, Bool] = Map([])
  for key, _ in self.files {
    if key.has_prefix(prefix) {
      let rest = String::unsafe_substring(
        key,
        start=prefix.length(),
        end=key.length(),
      )
      let name = match rest.find("/") {
        Some(i) => String::unsafe_substring(rest, start=0, end=i)
        None => rest
      }
      names[name] = true
    }
  }
  let out : Array[String] = []
  for name, _ in names {
    out.push(name)
  }
  out
}

///|
pub impl @types.RepoFileSystem for TinyFs with fn is_dir(self, path) {
  if self.files.contains(path) {
    return false
  }
  let prefix = if path.has_suffix("/") { path } else { path + "/" }
  for key, _ in self.files {
    if key.has_prefix(prefix) {
      return true
    }
  }
  self.dirs.contains(path)
}

///|
pub impl @types.RepoFileSystem for TinyFs with fn is_file(self, path) {
  self.files.contains(path)
}

///|
pub impl @types.RepoFileSystem for TinyFs with fn mtime(_self, _path) {
  (0, 0)
}

///|
fn fs_store() -> FsStore {
  let fs = TinyFs::new()
  FsStore::new(fs, fs, "/store")
}

///|
async test "fs store: round trip through real paths" {
  let store = fs_store()
  inspect(store.get("repos/a/b/manifest.json"), content="Missing")
  let put = store.put(
    "repos/a/b/manifest.json",
    text("{}"),
    PutCondition::IfNotExists,
  )
  inspect(put.is_applied(), content="true")
  inspect(body_of(store.get("repos/a/b/manifest.json")), content="{}")
}

///|
async test "fs store: compare-and-swap enforces the expected version" {
  let store = fs_store()
  let first = store.put("m", text("v1"), PutCondition::IfNotExists)
  let etag = match first {
    Applied(e) => e
    _ => "<none>"
  }
  inspect(
    store.put("m", text("v2"), PutCondition::IfMatch("stale")),
    content="NotApplied",
  )
  inspect(body_of(store.get("m")), content="v1")
  inspect(
    store.put("m", text("v2"), PutCondition::IfMatch(etag)).is_applied(),
    content="true",
  )
  inspect(body_of(store.get("m")), content="v2")
}

///|
async test "fs store: create-only write does not clobber" {
  let store = fs_store()
  let _ = store.put("k", text("first"), PutCondition::IfNotExists)
  inspect(
    store.put("k", text("second"), PutCondition::IfNotExists),
    content="NotApplied",
  )
  inspect(body_of(store.get("k")), content="first")
}

///|
async test "fs store: listing walks nested directories in byte order" {
  let store = fs_store()
  for key in ["log/2", "log/10", "log/1", "wal/p.pack", "manifest.json"] {
    let _ = store.put(key, text(key), PutCondition::Unconditional)
  }
  let keys : Array[String] = []
  for entry in store.list("log/", "").entries {
    keys.push(entry.key)
  }
  inspect(keys.join(","), content="log/1,log/10,log/2")
}

///|
async test "fs store: listing resumes after a cursor" {
  let store = fs_store()
  for key in ["log/1", "log/2", "log/3"] {
    let _ = store.put(key, text(key), PutCondition::Unconditional)
  }
  let keys : Array[String] = []
  for entry in store.list("log/", "log/1").entries {
    keys.push(entry.key)
  }
  inspect(keys.join(","), content="log/2,log/3")
}

///|
async test "fs store: range reads slice the file" {
  let store = fs_store()
  let _ = store.put("r", text("0123456789"), PutCondition::Unconditional)
  inspect(body_of(store.get_range("r", { start: 2L, end: 5L })), content="2345")
}

///|
async test "fs store: delete removes the key and is idempotent" {
  let store = fs_store()
  let _ = store.put("d", text("x"), PutCondition::Unconditional)
  store.delete("d")
  store.delete("d")
  inspect(store.get("d"), content="Missing")
}

///|
async test "fs store: keys that would escape the root are refused" {
  let store = fs_store()
  for key in ["../etc/passwd", "a/../../b", "/absolute", "a//b", "..", "a/.."] {
    let rejected = try {
      let _ = store.get(key)
      false
    } catch {
      _ => true
    }
    inspect(rejected, content="true")
  }
}

///|
async test "fs store: a dotted key that does not escape is allowed" {
  let store = fs_store()
  let put = store.put("a/..b/c", text("ok"), PutCondition::Unconditional)
  inspect(put.is_applied(), content="true")
}
