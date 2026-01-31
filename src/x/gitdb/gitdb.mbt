///| GitDb core implementation

///|
/// Create a new GitDb from an existing GitFs
pub fn GitDb::new(
  node_id : NodeId,
  gitfs : @gitfs.GitFs,
  head : @git.ObjectId,
) -> GitDb {
  {
    node_id,
    gitfs,
    clock: VectorClock::new(),
    head,
    peers: {},
    pending_objects: {},
  }
}

///|
/// Create an empty GitDb
pub fn GitDb::empty(node_id : NodeId, git_dir : String) -> GitDb {
  let gitfs = @gitfs.GitFs::empty(git_dir)
  {
    node_id,
    gitfs,
    clock: VectorClock::new(),
    head: @git.ObjectId::zero(),
    peers: {},
    pending_objects: {},
  }
}

///|
/// Get the current HEAD
pub fn GitDb::head(self : GitDb) -> @git.ObjectId {
  self.head
}

///|
/// Get the node ID
pub fn GitDb::node_id(self : GitDb) -> NodeId {
  self.node_id
}

///|
/// Get the current vector clock
pub fn GitDb::clock(self : GitDb) -> VectorClock {
  self.clock
}

///|
/// Check if there are uncommitted changes
pub fn GitDb::is_dirty(self : GitDb) -> Bool {
  self.gitfs.is_dirty()
}

///|
/// Get value by hierarchical key
/// Key format: "/path/to/key" or "path/to/key"
pub fn GitDb::get(
  self : GitDb,
  backing_fs : &@git.RepoFileSystem,
  key : String,
) -> Bytes? {
  let path = normalize_key(key)
  let result = self.gitfs.read_file(backing_fs, path) catch { _ => return None }
  Some(result)
}

///|
/// Set value by hierarchical key
pub fn GitDb::set(self : GitDb, key : String, value : Bytes) -> Unit {
  let path = normalize_key(key)
  self.gitfs.write_file(path, value)
}

///|
/// Set string value
pub fn GitDb::set_string(self : GitDb, key : String, value : String) -> Unit {
  self.set(
    key,
    Bytes::from_array(value.to_array().map(fn(c) { c.to_int().to_byte() })),
  )
}

///|
/// Delete a key
pub fn GitDb::delete(self : GitDb, key : String) -> Unit {
  let path = normalize_key(key)
  self.gitfs.remove_file(path)
}

///|
/// Check if key exists
pub fn GitDb::has(
  self : GitDb,
  backing_fs : &@git.RepoFileSystem,
  key : String,
) -> Bool {
  let path = normalize_key(key)
  self.gitfs.is_file(backing_fs, path)
}

///|
/// List keys under a prefix (directory)
pub fn GitDb::list(
  self : GitDb,
  backing_fs : &@git.RepoFileSystem,
  prefix : String,
) -> Array[String] {
  let path = normalize_key(prefix)
  let entries = self.gitfs.readdir(backing_fs, path) catch { _ => return [] }
  entries
}

///|
/// List all keys recursively under a prefix
pub fn GitDb::list_recursive(
  self : GitDb,
  backing_fs : &@git.RepoFileSystem,
  prefix : String,
) -> Array[String] {
  let results : Array[String] = []
  collect_keys_recursive(self, backing_fs, prefix, results)
  results
}

///|
fn collect_keys_recursive(
  db : GitDb,
  backing_fs : &@git.RepoFileSystem,
  prefix : String,
  results : Array[String],
) -> Unit {
  let path = normalize_key(prefix)
  let entries = db.gitfs.readdir(backing_fs, path) catch { _ => return }
  for entry in entries {
    let full_path = if path.length() == 0 { entry } else { path + "/" + entry }
    if db.gitfs.is_file(backing_fs, full_path) {
      results.push("/" + full_path)
    } else if db.gitfs.is_dir(backing_fs, full_path) {
      collect_keys_recursive(db, backing_fs, "/" + full_path, results)
    }
  }
}

///|
/// Commit current changes and update HEAD
pub fn GitDb::commit(
  self : GitDb,
  write_fs : &@git.FileSystem,
  backing_fs : &@git.RepoFileSystem,
  message : String,
  timestamp : Int64,
) -> @git.ObjectId raise @git.GitError {
  // Increment our clock
  self.clock = self.clock.increment(self.node_id)
  // Create snapshot
  let author = self.node_id.id
  let snapshot = self.gitfs.snapshot(
    write_fs, backing_fs, message, author, timestamp,
  )
  self.head = snapshot.commit_id
  snapshot.commit_id
}

///|
/// Discard uncommitted changes
pub fn GitDb::rollback(self : GitDb) -> Unit {
  self.gitfs.rollback()
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
