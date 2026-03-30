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
extern "C" fn hub_stdin_is_tty_native() -> Int = "hub_stdin_is_tty_native"

///|
struct HubOriginSyncPlan {
  has_origin : Bool
  add_fetch_notes : Bool
  add_push_notes : Bool
  add_default_push_refspec : Bool
}

///|
fn hub_sync_config_path(git_dir : String) -> String {
  git_dir + "/config"
}

///|
fn hub_notes_fetch_refspec() -> String {
  "+\{@hub.hub_notes_ref_name()}:\{@hub.hub_notes_ref_name()}"
}

///|
fn hub_notes_push_refspec() -> String {
  "\{@hub.hub_notes_ref_name()}:\{@hub.hub_notes_ref_name()}"
}

///|
fn hub_default_push_refspec() -> String {
  "refs/heads/*:refs/heads/*"
}

///|
fn parse_hub_init_approval(input : String) -> Bool {
  let normalized = input.trim(chars=" \t\r\n").to_lower()
  normalized == "y" || normalized == "yes"
}

///|
fn parse_hub_init_prompt_override(input : String) -> Bool? {
  match input.trim(chars=" \t\r\n").to_lower() {
    "1" | "true" | "yes" | "y" => Some(true)
    "0" | "false" | "no" | "n" => Some(false)
    _ => None
  }
}

///|
async fn read_hub_init_approval() -> Bool {
  let bytes : Array[Byte] = []
  let mut finished = false
  while not(finished) {
    match @stdio.stdin.read_some(max_len=1) {
      None => finished = true
      Some(chunk) =>
        for b in chunk {
          if b == 10 {
            finished = true
            break
          }
          if b == 13 {
            continue
          }
          if bytes.length() <= 64 {
            bytes.push(b)
          }
          if bytes.length() >= 64 {
            finished = true
            break
          }
        }
    }
  }
  let text = @utf8.decode_lossy(bytes_from_array(bytes)[:])
  parse_hub_init_approval(text)
}

///|
fn hub_stdin_is_tty() -> Bool {
  hub_stdin_is_tty_native() != 0
}

///|
fn hub_should_prompt() -> Bool {
  match @sys.get_env_var("BIT_HUB_INIT_PROMPT") {
    Some(value) =>
      parse_hub_init_prompt_override(value).unwrap_or(hub_stdin_is_tty())
    None => hub_stdin_is_tty()
  }
}

///|
fn compute_hub_origin_sync_plan(content : String) -> HubOriginSyncPlan {
  let (remotes, _branches) = @bitlib.parse_remote_config(content)
  match remotes.get("origin") {
    None =>
      {
        has_origin: false,
        add_fetch_notes: false,
        add_push_notes: false,
        add_default_push_refspec: false,
      }
    Some(remote) => {
      let add_fetch_notes = not(
        remote.fetch.contains(hub_notes_fetch_refspec()),
      )
      let add_push_notes = not(remote.push.contains(hub_notes_push_refspec()))
      {
        has_origin: true,
        add_fetch_notes,
        add_push_notes,
        add_default_push_refspec: add_push_notes && remote.push.length() == 0,
      }
    }
  }
}

///|
fn load_hub_origin_sync_plan(fs : OsFs, git_dir : String) -> HubOriginSyncPlan {
  let config_path = hub_sync_config_path(git_dir)
  let content = decode_bytes(
    fs.read_file(config_path) catch {
      _ => Bytes::default()
    },
  )
  compute_hub_origin_sync_plan(content)
}

///|
fn apply_hub_origin_sync_plan(
  fs : OsFs,
  git_dir : String,
  plan : HubOriginSyncPlan,
) -> Unit raise Error {
  if not(plan.has_origin) {
    return ()
  }
  let config_path = hub_sync_config_path(git_dir)
  if plan.add_default_push_refspec {
    set_config(
      fs,
      config_path,
      "remote.origin.push",
      hub_default_push_refspec(),
      true,
      (None : String?),
      (None : String?),
    )
  }
  if plan.add_push_notes {
    set_config(
      fs,
      config_path,
      "remote.origin.push",
      hub_notes_push_refspec(),
      true,
      (None : String?),
      (None : String?),
    )
  }
  if plan.add_fetch_notes {
    set_config(
      fs,
      config_path,
      "remote.origin.fetch",
      hub_notes_fetch_refspec(),
      true,
      (None : String?),
      (None : String?),
    )
  }
}

///|
fn hub_metadata_is_initialized(fs : OsFs, git_dir : String) -> Bool {
  fs.is_file(hub_merge_policy_path(git_dir))
}

///|
async fn print_hub_init_metadata_prompt(
  command_name : String,
  git_dir : String,
) -> Unit {
  eprint_line(
    "bit \{command_name}: initialize local hub metadata in this repository?",
  )
  eprint_line("  creates: \{hub_merge_policy_path(git_dir)}")
  eprint_line("Continue? [y/N]")
}

///|
async fn print_hub_init_sync_prompt(
  command_name : String,
  plan : HubOriginSyncPlan,
) -> Unit {
  eprint_line(
    "bit \{command_name}: configure local git sync for hub metadata on 'origin'?",
  )
  if plan.add_fetch_notes {
    eprint_line("  remote.origin.fetch += " + hub_notes_fetch_refspec())
  }
  if plan.add_default_push_refspec {
    eprint_line("  remote.origin.push += " + hub_default_push_refspec())
    eprint_line(
      "  note: this makes plain `git push origin` use explicit refspecs",
    )
  }
  if plan.add_push_notes {
    eprint_line("  remote.origin.push += " + hub_notes_push_refspec())
  }
  eprint_line("Apply these local config changes now? [y/N]")
}

///|
async fn ensure_hub_initialized(
  git_dir : String,
  command_name? : String = "hub",
  explicit? : Bool = false,
) -> Unit raise Error {
  let fs = OsFs::new()
  let had_metadata = hub_metadata_is_initialized(fs, git_dir)
  let interactive = hub_should_prompt()
  if not(had_metadata) {
    if interactive {
      print_hub_init_metadata_prompt(command_name, git_dir)
      if not(read_hub_init_approval()) {
        eprint_line("fatal: hub metadata initialization was not approved")
        @sys.exit(1)
      }
    }
    let (objects, refs, _clock) = make_hub_stores(git_dir)
    let _ = load_hub_store(objects, refs)
    ensure_hub_merge_policy_file(fs, git_dir)
  }
  let plan = load_hub_origin_sync_plan(fs, git_dir)
  if not(plan.has_origin) {
    return ()
  }
  let needs_sync_config = plan.add_fetch_notes || plan.add_push_notes
  if not(needs_sync_config) {
    return ()
  }
  if not(explicit || not(had_metadata)) {
    return ()
  }
  if not(interactive) {
    return ()
  }
  print_hub_init_sync_prompt(command_name, plan)
  if read_hub_init_approval() {
    apply_hub_origin_sync_plan(fs, git_dir, plan)
  }
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
async fn handle_hub_init(args : Array[String]) -> Unit raise Error {
  for arg in args {
    if arg.has_prefix("-") {
      warn_unimplemented_arg("init", arg)
    }
  }
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  ensure_hub_initialized(git_dir, explicit=true)
  print_line("Initialized hub metadata")
}
