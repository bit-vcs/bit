///| BitDb core implementation

///|
/// Create a new BitDb from an existing BitFs
pub fn BitDb::new(
  node_id : NodeId,
  bitfs : @bitfs.BitFs,
  head : @git.ObjectId,
) -> BitDb {
  {
    node_id,
    bitfs,
    clock: VectorClock::new(),
    head,
    peers: {},
    pending_objects: {},
  }
}

///|
/// Create an empty BitDb
pub fn BitDb::empty(node_id : NodeId, git_dir : String) -> BitDb {
  let bitfs = @bitfs.BitFs::empty(git_dir)
  {
    node_id,
    bitfs,
    clock: VectorClock::new(),
    head: @git.ObjectId::zero(),
    peers: {},
    pending_objects: {},
  }
}

///|
/// Get the current HEAD
pub fn BitDb::head(self : BitDb) -> @git.ObjectId {
  self.head
}

///|
/// Get the node ID
pub fn BitDb::node_id(self : BitDb) -> NodeId {
  self.node_id
}

///|
/// Get the current vector clock
pub fn BitDb::clock(self : BitDb) -> VectorClock {
  self.clock
}

///|
/// Check if there are uncommitted changes
pub fn BitDb::is_dirty(self : BitDb) -> Bool {
  self.bitfs.is_dirty()
}

///|
/// Get value by hierarchical key
/// Key format: "/path/to/key" or "path/to/key"
pub fn BitDb::get(
  self : BitDb,
  backing_fs : &@git.RepoFileSystem,
  key : String,
) -> Bytes? {
  let path = normalize_key(key)
  let result = self.bitfs.read_file(backing_fs, path) catch { _ => return None }
  Some(result)
}

///|
/// Set value by hierarchical key
pub fn BitDb::set(self : BitDb, key : String, value : Bytes) -> Unit {
  let path = normalize_key(key)
  self.bitfs.write_file(path, value)
}

///|
/// Set string value
pub fn BitDb::set_string(self : BitDb, key : String, value : String) -> Unit {
  self.set(
    key,
    Bytes::from_array(value.to_array().map(fn(c) { c.to_int().to_byte() })),
  )
}

///|
/// Delete a key
pub fn BitDb::delete(self : BitDb, key : String) -> Unit {
  let path = normalize_key(key)
  self.bitfs.remove_file(path)
}

///|
/// Check if key exists
pub fn BitDb::has(
  self : BitDb,
  backing_fs : &@git.RepoFileSystem,
  key : String,
) -> Bool {
  let path = normalize_key(key)
  self.bitfs.is_file(backing_fs, path)
}

///|
/// List keys under a prefix (directory)
pub fn BitDb::list(
  self : BitDb,
  backing_fs : &@git.RepoFileSystem,
  prefix : String,
) -> Array[String] {
  let path = normalize_key(prefix)
  let entries = self.bitfs.readdir(backing_fs, path) catch { _ => return [] }
  entries
}

///|
/// List all keys recursively under a prefix
pub fn BitDb::list_recursive(
  self : BitDb,
  backing_fs : &@git.RepoFileSystem,
  prefix : String,
) -> Array[String] {
  let results : Array[String] = []
  collect_keys_recursive(self, backing_fs, prefix, results)
  results
}

///|
fn collect_keys_recursive(
  db : BitDb,
  backing_fs : &@git.RepoFileSystem,
  prefix : String,
  results : Array[String],
) -> Unit {
  let path = normalize_key(prefix)
  let entries = db.bitfs.readdir(backing_fs, path) catch { _ => return }
  for entry in entries {
    let full_path = if path.length() == 0 { entry } else { path + "/" + entry }
    if db.bitfs.is_file(backing_fs, full_path) {
      results.push("/" + full_path)
    } else if db.bitfs.is_dir(backing_fs, full_path) {
      collect_keys_recursive(db, backing_fs, "/" + full_path, results)
    }
  }
}

///|
/// Commit current changes and update HEAD
pub fn BitDb::commit(
  self : BitDb,
  write_fs : &@git.FileSystem,
  backing_fs : &@git.RepoFileSystem,
  message : String,
  timestamp : Int64,
) -> @git.ObjectId raise @git.GitError {
  // Increment our clock
  self.clock = self.clock.increment(self.node_id)
  // Create snapshot
  let author = self.node_id.id
  let snapshot = self.bitfs.snapshot(
    write_fs, backing_fs, message, author, timestamp,
  )
  self.head = snapshot.commit_id
  snapshot.commit_id
}

///|
/// Discard uncommitted changes
pub fn BitDb::rollback(self : BitDb) -> Unit {
  self.bitfs.rollback()
}

///|
/// Normalize key to path format
fn normalize_key(key : String) -> String {
  let mut result = key
  // Remove leading slashes
  while result.length() > 0 && result[0] == '/' {
    result = String::unsafe_substring(result, start=1, end=result.length())
  }
  // Remove trailing slashes
  while result.length() > 0 && result[result.length() - 1] == '/' {
    result = String::unsafe_substring(result, start=0, end=result.length() - 1)
  }
  result
}
