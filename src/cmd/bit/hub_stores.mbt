///|
struct OsObjectStore {
  git_dir : String
}

///|
impl @bitlib.ObjectStore for OsObjectStore with get(self, id) {
  let fs = OsFs::new()
  let db = @bitlib.ObjectDb::load_lazy(fs, self.git_dir)
  db.get(fs, id)
}

///|
impl @bitlib.ObjectStore for OsObjectStore with put(self, obj_type, content) {
  let fs = OsFs::new()
  let (id, compressed) = @bitcore.create_object(obj_type, content)
  let hex = id.to_hex()
  let dir = self.git_dir +
    "/objects/" +
    String::unsafe_substring(hex, start=0, end=2)
  let path = dir + "/" + String::unsafe_substring(hex, start=2, end=40)
  fs.mkdir_p(dir)
  fs.write_file(path, compressed)
  id
}

///|
impl @bitlib.ObjectStore for OsObjectStore with has(self, id) {
  let fs = OsFs::new()
  let db = @bitlib.ObjectDb::load_lazy(fs, self.git_dir)
  let obj = db.get(fs, id)
  obj is Some(_)
}

///|
struct OsRefStore {
  git_dir : String
}

///|
impl @bitlib.RefStore for OsRefStore with resolve(self, ref_name) {
  let fs = OsFs::new()
  @bitlib.resolve_ref(fs, self.git_dir, ref_name)
}

///|
impl @bitlib.RefStore for OsRefStore with update(self, ref_name, id) {
  let fs = OsFs::new()
  match id {
    Some(commit_id) => {
      let ref_path = self.git_dir + "/" + ref_name
      let dir = os_parent_path(ref_path)
      fs.mkdir_p(dir)
      fs.write_string(ref_path, commit_id.to_hex() + "\n")
    }
    None => ()
  }
}

///|
impl @bitlib.RefStore for OsRefStore with list(self, _prefix) {
  ignore(self)
  []
}

///|
fn os_parent_path(path : String) -> String {
  match path.rev_find("/") {
    None => "."
    Some(0) => "."
    Some(idx) => String::unsafe_substring(path, start=0, end=idx)
  }
}

///|
struct OsClock {
  time : Int64
}

///|
impl @bitlib.Clock for OsClock with now(self) {
  self.time
}

///|
/// Resolve git_dir for hub operations, handling worktrees.
/// In a worktree, .git is a file pointing to .git/worktrees/<name>.
/// Hub data (refs/notes) lives in the shared common git dir.
fn resolve_hub_git_dir(root : String) -> String {
  let fs = OsFs::new()
  let git_path = root + "/.git"
  // Resolve .git file → actual gitdir (e.g. /repo/.git/worktrees/foo)
  let git_dir = if fs.is_file(git_path) {
    @bitlib.resolve_gitdir(fs, git_path)
  } else {
    git_path
  }
  // Resolve commondir → shared .git (e.g. /repo/.git)
  let commondir_path = git_dir + "/commondir"
  if fs.is_file(commondir_path) {
    let raw = @utf8.decode_lossy(
      (fs.read_file(commondir_path) catch { _ => Bytes::default() })[:],
    )
    let rel = raw.trim(chars=" \t\r\n").to_string()
    if rel.length() > 0 {
      if rel.has_prefix("/") {
        return normalize_path(rel)
      }
      return normalize_path(git_dir + "/" + rel)
    }
  }
  git_dir
}

///|
fn make_hub_stores(
  git_dir : String,
) -> (&@bitlib.ObjectStore, &@bitlib.RefStore, &@bitlib.Clock) {
  let objects : OsObjectStore = { git_dir, }
  let refs : OsRefStore = { git_dir, }
  let clock : OsClock = { time: get_commit_timestamp() }
  (objects, refs, clock)
}

///|
/// Load hub store, auto-initializing if needed.
fn load_hub_store(
  objects : &@bitlib.ObjectStore,
  refs : &@bitlib.RefStore,
) -> @hub.Hub raise @bitcore.GitError {
  @hub.Hub::init(
    objects,
    refs,
    signing_key=get_hub_signing_key(),
    require_signed=get_hub_require_signed(),
  )
}

///|
fn ensure_hub_initialized(git_dir : String) -> Unit raise @bitcore.GitError {
  let fs = OsFs::new()
  let (objects, refs, _clock) = make_hub_stores(git_dir)
  let _ = load_hub_store(objects, refs)
  ensure_hub_merge_policy_file(fs, git_dir)
}

///|
async fn handle_hub_init(args : Array[String]) -> Unit raise Error {
  for arg in args {
    if arg.has_prefix("-") {
      warn_unimplemented_arg("init", arg)
    }
  }
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let fs = OsFs::new()
  let (objects, refs, _clock) = make_hub_stores(git_dir)
  let _ = load_hub_store(objects, refs)
  ensure_hub_merge_policy_file(fs, git_dir)
  print_line("Initialized hub metadata")
}
