///| JS-exported Hub (issue) operations.

///|
fn[T] hub_wrap_error(f : () -> T raise @bit.GitError) -> Result[T, String] {
  Ok(f()) catch {
    @bit.GitError::IoError(e) => Err(e)
    @bit.GitError::InvalidObject(e) => Err(e)
    @bit.GitError::HashMismatch(expected, actual) =>
      Err("hash mismatch: \{expected} vs \{actual}")
    @bit.GitError::PackfileError(e) => Err("packfile error: \{e}")
    @bit.GitError::ProtocolError(e) => Err("protocol error: \{e}")
  }
}

///|
priv struct HubJsObjectStore {
  fs : HubJsHostFs
  git_dir : String
}

///|
impl @lib.ObjectStore for HubJsObjectStore with get(self, id) {
  let db = @lib.ObjectDb::load_lazy(self.fs, self.git_dir)
  db.get(self.fs, id)
}

///|
impl @lib.ObjectStore for HubJsObjectStore with put(self, obj_type, content) {
  let (id, compressed) = @bit.create_object(obj_type, content)
  let hex = id.to_hex()
  let dir = self.git_dir +
    "/objects/" +
    String::unsafe_substring(hex, start=0, end=2)
  let path = dir + "/" + String::unsafe_substring(hex, start=2, end=40)
  (self.fs as &@bit.FileSystem).mkdir_p(dir)
  (self.fs as &@bit.FileSystem).write_file(path, compressed)
  id
}

///|
impl @lib.ObjectStore for HubJsObjectStore with has(self, id) {
  let db = @lib.ObjectDb::load_lazy(self.fs, self.git_dir)
  let obj = db.get(self.fs, id)
  obj is Some(_)
}

///|
priv struct HubJsRefStore {
  fs : HubJsHostFs
  git_dir : String
}

///|
impl @lib.RefStore for HubJsRefStore with resolve(self, ref_name) {
  @lib.resolve_ref(self.fs, self.git_dir, ref_name)
}

///|
impl @lib.RefStore for HubJsRefStore with update(self, ref_name, id) {
  match id {
    Some(commit_id) => {
      let ref_path = self.git_dir + "/" + ref_name
      let dir = hub_parent_path(ref_path)
      (self.fs as &@bit.FileSystem).mkdir_p(dir)
      (self.fs as &@bit.FileSystem).write_string(
        ref_path,
        commit_id.to_hex() + "\n",
      )
    }
    None => ()
  }
}

///|
impl @lib.RefStore for HubJsRefStore with list(self, prefix) {
  let result : Array[String] = []
  let refs_dir = self.git_dir + "/refs"
  hub_collect_refs(self.fs, refs_dir, "refs", prefix, result)
  result
}

///|
fn hub_collect_refs(
  fs : HubJsHostFs,
  dir : String,
  prefix : String,
  filter : String,
  result : Array[String],
) -> Unit {
  let entries = (fs as &@bit.RepoFileSystem).readdir(dir) catch { _ => return }
  for entry in entries {
    let full = dir + "/" + entry
    let ref_name = prefix + "/" + entry
    if (fs as &@bit.RepoFileSystem).is_dir(full) {
      hub_collect_refs(fs, full, ref_name, filter, result)
    } else if ref_name.has_prefix(filter) {
      result.push(ref_name)
    }
  }
}

///|
priv struct HubJsClock {
  timestamp : Int64
}

///|
impl @lib.Clock for HubJsClock with now(self) {
  self.timestamp
}

///|
fn hub_parent_path(path : String) -> String {
  match path.rev_find("/") {
    None => "."
    Some(0) => "/"
    Some(idx) => String::unsafe_substring(path, start=0, end=idx)
  }
}

///|
fn hub_resolve_git_dir(
  fs : HubJsHostFs,
  root : String,
) -> String raise @bit.GitError {
  let git_path = root + "/.git"
  if (fs as &@bit.RepoFileSystem).is_file(git_path) {
    @lib.resolve_gitdir(fs, git_path)
  } else {
    git_path
  }
}

///|
extern "js" fn hub_js_date_now() -> Double =
  #| () => Date.now()

///|
fn hub_make_stores(
  host_id : Int,
  root : String,
) -> (HubJsObjectStore, HubJsRefStore, HubJsClock) raise @bit.GitError {
  let fs = hub_make_host_fs(host_id)
  let git_dir = hub_resolve_git_dir(fs, root)
  let objects = HubJsObjectStore::{ fs, git_dir }
  let refs = HubJsRefStore::{ fs, git_dir }
  let now = hub_js_date_now().to_int64() / 1000L
  let clock = HubJsClock::{ timestamp: now }
  (objects, refs, clock)
}

// --- Issue API exports ---

///|
pub fn js_hub_issue_init(host_id : Int, root : String) -> Result[Unit, String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, _) = hub_make_stores(host_id, root)
    let _ = Hub::init(objects, refs)
  })
}

///|
pub fn js_hub_issue_list(
  host_id : Int,
  root : String,
  state : String,
) -> Result[Array[Issue], String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, _) = hub_make_stores(host_id, root)
    let hub = Hub::load(objects, refs)
    let filter : IssueState? = match state {
      "open" => Some(IssueState::Open)
      "closed" => Some(IssueState::Closed)
      _ => None
    }
    hub.list_issues(objects, state=filter)
  })
}

///|
pub fn js_hub_issue_get(
  host_id : Int,
  root : String,
  issue_id : String,
) -> Result[Issue?, String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, _) = hub_make_stores(host_id, root)
    let hub = Hub::load(objects, refs)
    hub.get_issue(objects, issue_id)
  })
}

///|
pub fn js_hub_issue_create(
  host_id : Int,
  root : String,
  title : String,
  body : String,
  author : String,
  labels : Array[String],
  parent_id : String,
) -> Result[Issue, String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, clock) = hub_make_stores(host_id, root)
    let hub = Hub::load(objects, refs)
    let pid : String? = if parent_id.length() > 0 {
      Some(parent_id)
    } else {
      None
    }
    hub.create_issue(
      objects,
      refs,
      clock,
      title,
      body,
      author,
      labels~,
      parent_id=pid,
    )
  })
}

///|
pub fn js_hub_issue_update(
  host_id : Int,
  root : String,
  issue_id : String,
  title : String,
  body : String,
  labels : Array[String],
) -> Result[Issue, String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, clock) = hub_make_stores(host_id, root)
    let hub = Hub::load(objects, refs)
    let t : String? = if title.length() > 0 { Some(title) } else { None }
    let b : String? = if body.length() > 0 { Some(body) } else { None }
    let l : Array[String]? = if labels.length() > 0 {
      Some(labels)
    } else {
      None
    }
    hub.update_issue(objects, refs, clock, issue_id, title=t, body=b, labels=l)
  })
}

///|
pub fn js_hub_issue_close(
  host_id : Int,
  root : String,
  issue_id : String,
) -> Result[Unit, String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, clock) = hub_make_stores(host_id, root)
    let hub = Hub::load(objects, refs)
    hub.close_issue(objects, refs, clock, issue_id)
  })
}

///|
pub fn js_hub_issue_reopen(
  host_id : Int,
  root : String,
  issue_id : String,
) -> Result[Unit, String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, clock) = hub_make_stores(host_id, root)
    let hub = Hub::load(objects, refs)
    hub.reopen_issue(objects, refs, clock, issue_id)
  })
}

///|
pub fn js_hub_issue_comment_list(
  host_id : Int,
  root : String,
  issue_id : String,
) -> Result[Array[IssueComment], String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, _) = hub_make_stores(host_id, root)
    let hub = Hub::load(objects, refs)
    hub.list_issue_comments(objects, issue_id)
  })
}

///|
pub fn js_hub_issue_comment_add(
  host_id : Int,
  root : String,
  issue_id : String,
  author : String,
  body : String,
) -> Result[IssueComment, String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, clock) = hub_make_stores(host_id, root)
    let hub = Hub::load(objects, refs)
    hub.add_issue_comment(objects, refs, clock, issue_id, author, body)
  })
}

///|
pub fn js_hub_issue_search(
  host_id : Int,
  root : String,
  query : String,
  state : String,
) -> Result[Array[Issue], String] {
  hub_wrap_error(fn() -> _ raise _ {
    let (objects, refs, _) = hub_make_stores(host_id, root)
    let hub = Hub::load(objects, refs)
    let filter : IssueState? = match state {
      "open" => Some(IssueState::Open)
      "closed" => Some(IssueState::Closed)
      _ => None
    }
    let all = hub.list_issues(objects, state=filter)
    let q = query.to_lower()
    let result : Array[Issue] = []
    for issue in all {
      if issue.title.to_lower().contains(q) || issue.body.to_lower().contains(q) {
        result.push(issue)
      }
    }
    result
  })
}
