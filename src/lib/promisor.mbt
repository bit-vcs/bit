///| Promisor remote support for partial clones (pure)

///|
/// Read promisor remote URL from .git/objects/info/promisor
pub fn read_promisor_remote(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
) -> String? {
  let promisor_path = promisor_join_path(git_dir, "objects/info/promisor")
  if not(fs.is_file(promisor_path)) {
    return None
  }
  let content = fs.read_file(promisor_path) catch { _ => return None }
  let remote = @utf8.decode_lossy(content[:]).trim().to_string()
  if remote.length() > 0 {
    Some(remote)
  } else {
    None
  }
}

///|
/// Check if this is a partial clone repository
pub fn is_partial_clone(fs : &@bit.RepoFileSystem, git_dir : String) -> Bool {
  read_promisor_remote(fs, git_dir) is Some(_)
}

///|
/// Promisor-aware object database that can fetch missing objects.
/// The fetch_fn callback is injectable for platform independence.
/// When fetch_fn is None, only local operations are available.
pub struct PromisorDb {
  db : ObjectDb
  git_dir : String
  promisor_remote : String?
  fetched : Map[String, Bool]
  fetch_fn : (async (String, Array[@bit.ObjectId]) -> Result[
    Array[@bit.PackObject],
    @bit.GitError,
  ] noraise)?
}

///|
pub fn PromisorDb::new(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  lazy_load? : Bool = true,
  fetch_fn~ : (async (String, Array[@bit.ObjectId]) -> Result[
    Array[@bit.PackObject],
    @bit.GitError,
  ] noraise)?,
) -> PromisorDb raise @bit.GitError {
  let db = if lazy_load {
    ObjectDb::load_lazy(fs, git_dir)
  } else {
    ObjectDb::load(fs, git_dir)
  }
  let promisor_remote = read_promisor_remote(fs, git_dir)
  { db, git_dir, promisor_remote, fetched: {}, fetch_fn }
}

///|
/// Get object synchronously (local only)
pub fn PromisorDb::get(
  self : PromisorDb,
  fs : &@bit.RepoFileSystem,
  id : @bit.ObjectId,
) -> @bit.PackObject? raise @bit.GitError {
  self.db.get(fs, id)
}

///|
/// Check if an object exists locally
pub fn PromisorDb::has_local(
  self : PromisorDb,
  fs : &@bit.RepoFileSystem,
  id : @bit.ObjectId,
) -> Bool raise @bit.GitError {
  match self.db.get(fs, id) {
    Some(_) => true
    None => false
  }
}

///|
/// Check if this is a partial clone with promisor remote
pub fn PromisorDb::has_promisor(self : PromisorDb) -> Bool {
  self.promisor_remote is Some(_)
}

///|
/// Get the promisor remote URL if available
pub fn PromisorDb::get_promisor_remote(self : PromisorDb) -> String? {
  self.promisor_remote
}

///|
/// Fetch missing objects from the promisor remote (async).
/// Requires fetch_fn to be set; returns empty if no fetcher available.
pub async fn PromisorDb::fetch_missing(
  self : PromisorDb,
  write_fs : &@bit.FileSystem,
  ids : Array[@bit.ObjectId],
) -> Array[@bit.PackObject] raise @bit.GitError {
  guard self.promisor_remote is Some(remote) else { return [] }
  guard self.fetch_fn is Some(fetch_fn) else { return [] }
  // Filter out already fetched
  let to_fetch : Array[@bit.ObjectId] = []
  for id in ids {
    let hex = id.to_hex()
    if not(self.fetched.contains(hex)) {
      to_fetch.push(id)
      self.fetched.set(hex, true)
    }
  }
  if to_fetch.length() == 0 {
    return []
  }
  // Fetch from remote via injected callback
  let result = fetch_fn(remote, to_fetch)
  let objects = match result {
    Ok(objs) => objs
    Err(e) => raise e
  }
  // Write to local storage
  for obj in objects {
    let _ = write_loose_object(write_fs, self.git_dir, obj.obj_type, obj.data)
  }
  objects
}

///|
/// Fetch a single missing object (async)
pub async fn PromisorDb::fetch_one(
  self : PromisorDb,
  write_fs : &@bit.FileSystem,
  id : @bit.ObjectId,
) -> @bit.PackObject? raise @bit.GitError {
  let objects = self.fetch_missing(write_fs, [id])
  for obj in objects {
    if obj.id == id {
      return Some(obj)
    }
  }
  None
}

///|
/// Get object, fetching from remote if necessary (async version)
pub async fn PromisorDb::get_or_fetch(
  self : PromisorDb,
  read_fs : &@bit.RepoFileSystem,
  write_fs : &@bit.FileSystem,
  id : @bit.ObjectId,
) -> @bit.PackObject? raise @bit.GitError {
  // First try local
  let result = self.db.get(read_fs, id)
  if result is Some(_) {
    return result
  }
  // If not found and we have a promisor remote, fetch it
  if self.promisor_remote is None {
    return None
  }
  let hex = id.to_hex()
  // Check if already tried to fetch
  if self.fetched.contains(hex) {
    return None
  }
  // Fetch and return
  self.fetch_one(write_fs, id)
}

///|
fn promisor_join_path(root : String, path : String) -> String {
  if root.has_suffix("/") {
    root + path
  } else {
    root + "/" + path
  }
}
