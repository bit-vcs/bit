# GitHub Sync Plan A: SyncLink + GitHub API Client

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** GitHub 双方向 sync の基盤となる SyncLink データモデルと GitHub API クライアント抽象化を構築する

**Architecture:** SyncLink を hub record として `refs/notes/bit-hub` に保存（relay sync で peer に伝播）。GitHub API アクセスは `gh` CLI と直接 HTTP の2実装を GitHubApi trait で統一。JSON パースは既存の `@json.parse` + ヘルパー関数パターンを踏襲。

**Tech Stack:** MoonBit, Git notes, `gh` CLI, GitHub REST API v3

---

### Task 1: SyncLink 型定義

**Files:**
- Create: `src/x/hub/sync_link.mbt`
- Test: `src/x/hub/hub_test.mbt`

- [ ] **Step 1: Write the failing test**

`src/x/hub/hub_test.mbt` に追加:

```moonbit
test "sync_link: serialize and parse roundtrip" {
  let link = @hub.SyncLink::new(
    "abc12345",
    "issue",
    "github",
    "owner/repo",
    remote_number=42,
    remote_node_id="I_kwDOxxx",
    last_pull_at=1774900000L,
    last_push_at=1774900000L,
    remote_updated_at=1774899000L,
  )
  let serialized = link.serialize()
  assert_true(serialized.contains("sync-link abc12345"))
  assert_true(serialized.contains("local-kind issue"))
  assert_true(serialized.contains("provider github"))
  assert_true(serialized.contains("repo owner/repo"))
  assert_true(serialized.contains("remote-number 42"))
  let parsed = @hub.parse_sync_link(serialized)
  assert_eq(parsed.local_id(), "abc12345")
  assert_eq(parsed.local_kind(), "issue")
  assert_eq(parsed.provider(), "github")
  assert_eq(parsed.repo(), "owner/repo")
  assert_eq(parsed.remote_number(), 42)
  assert_eq(parsed.remote_node_id(), "I_kwDOxxx")
  assert_eq(parsed.last_pull_at(), 1774900000L)
  assert_eq(parsed.last_push_at(), 1774900000L)
  assert_eq(parsed.remote_updated_at(), 1774899000L)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test --package bit/x/hub --filter "sync_link" 2>&1 | tail -20`
Expected: Compilation error — SyncLink not defined

- [ ] **Step 3: Implement SyncLink type**

Create `src/x/hub/sync_link.mbt`:

```moonbit
///|
pub struct SyncLink {
  local_id : String
  local_kind : String       // "issue" or "pr"
  provider : String         // "github"
  repo : String             // "owner/repo"
  remote_number : Int       // GitHub issue/PR number
  remote_node_id : String   // GitHub GraphQL node ID
  last_pull_at : Int64      // Unix timestamp of last pull
  last_push_at : Int64      // Unix timestamp of last push
  remote_updated_at : Int64 // GitHub updated_at at last sync
}

///|
pub fn SyncLink::new(
  local_id : String,
  local_kind : String,
  provider : String,
  repo : String,
  remote_number? : Int = 0,
  remote_node_id? : String = "",
  last_pull_at? : Int64 = 0L,
  last_push_at? : Int64 = 0L,
  remote_updated_at? : Int64 = 0L,
) -> SyncLink {
  {
    local_id,
    local_kind,
    provider,
    repo,
    remote_number,
    remote_node_id,
    last_pull_at,
    last_push_at,
    remote_updated_at,
  }
}

///|
pub fn SyncLink::local_id(self : SyncLink) -> String {
  self.local_id
}

///|
pub fn SyncLink::local_kind(self : SyncLink) -> String {
  self.local_kind
}

///|
pub fn SyncLink::provider(self : SyncLink) -> String {
  self.provider
}

///|
pub fn SyncLink::repo(self : SyncLink) -> String {
  self.repo
}

///|
pub fn SyncLink::remote_number(self : SyncLink) -> Int {
  self.remote_number
}

///|
pub fn SyncLink::remote_node_id(self : SyncLink) -> String {
  self.remote_node_id
}

///|
pub fn SyncLink::last_pull_at(self : SyncLink) -> Int64 {
  self.last_pull_at
}

///|
pub fn SyncLink::last_push_at(self : SyncLink) -> Int64 {
  self.last_push_at
}

///|
pub fn SyncLink::remote_updated_at(self : SyncLink) -> Int64 {
  self.remote_updated_at
}

///|
/// Serialize SyncLink to Git-style text format
pub fn SyncLink::serialize(self : SyncLink) -> String {
  let sb = StringBuilder::new()
  sb.write_string("sync-link ")
  sb.write_string(self.local_id)
  sb.write_char('\n')
  sb.write_string("local-kind ")
  sb.write_string(self.local_kind)
  sb.write_char('\n')
  sb.write_string("provider ")
  sb.write_string(self.provider)
  sb.write_char('\n')
  sb.write_string("repo ")
  sb.write_string(self.repo)
  sb.write_char('\n')
  sb.write_string("remote-number ")
  sb.write_string(self.remote_number.to_string())
  sb.write_char('\n')
  sb.write_string("remote-node-id ")
  sb.write_string(self.remote_node_id)
  sb.write_char('\n')
  sb.write_string("last-pull-at ")
  sb.write_string(self.last_pull_at.to_string())
  sb.write_char('\n')
  sb.write_string("last-push-at ")
  sb.write_string(self.last_push_at.to_string())
  sb.write_char('\n')
  sb.write_string("remote-updated-at ")
  sb.write_string(self.remote_updated_at.to_string())
  sb.write_char('\n')
  sb.to_string()
}

///|
/// Parse SyncLink from Git-style text format
pub fn parse_sync_link(text : String) -> SyncLink raise PrError {
  let mut local_id = ""
  let mut local_kind = ""
  let mut provider = ""
  let mut repo = ""
  let mut remote_number = 0
  let mut remote_node_id = ""
  let mut last_pull_at : Int64 = 0L
  let mut last_push_at : Int64 = 0L
  let mut remote_updated_at : Int64 = 0L
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    let space = line.find(" ")
    match space {
      None => continue
      Some(idx) => {
        let key = String::unsafe_substring(line, start=0, end=idx)
        let value = String::unsafe_substring(
          line,
          start=idx + 1,
          end=line.length(),
        )
        match key {
          "sync-link" => local_id = value
          "local-kind" => local_kind = value
          "provider" => provider = value
          "repo" => repo = value
          "remote-number" =>
            remote_number = @strconv.parse_int(value) catch { _ => 0 }
          "remote-node-id" => remote_node_id = value
          "last-pull-at" => last_pull_at = parse_int64(value)
          "last-push-at" => last_push_at = parse_int64(value)
          "remote-updated-at" => remote_updated_at = parse_int64(value)
          _ => ()
        }
      }
    }
  }
  if local_id.length() == 0 {
    raise PrError::InvalidFormat("Missing sync-link id")
  }
  SyncLink::new(
    local_id,
    local_kind,
    provider,
    repo,
    remote_number~,
    remote_node_id~,
    last_pull_at~,
    last_push_at~,
    remote_updated_at~,
  )
}
```

Note: `parse_int64` は `format.mbt` に既に存在する。`PrError` も既存。`@strconv.parse_int` は MoonBit 標準。存在しない場合は `parse_int64(value).to_int()` で代替。

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test --package bit/x/hub --filter "sync_link" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Run all hub tests**

Run: `moon test --package bit/x/hub 2>&1 | tail -5`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add src/x/hub/sync_link.mbt src/x/hub/hub_test.mbt
git commit -m "feat(hub): add SyncLink type with serialize/parse"
```

---

### Task 2: SyncLink の Hub 統合（CRUD 操作）

**Files:**
- Create: `src/x/hub/sync_link_ops.mbt` (Hub メソッド)
- Modify: `src/x/hub/store.mbt` (record kind 定数追加)
- Test: `src/x/hub/hub_test.mbt`

- [ ] **Step 1: Write the failing test**

`src/x/hub/hub_test.mbt` に追加:

```moonbit
test "hub: create and get sync_link" {
  let (objects, refs, clock) = make_test_stores()
  let hub = @hub.Hub::init(objects, refs)
  let link = @hub.SyncLink::new(
    "issue-abc",
    "issue",
    "github",
    "owner/repo",
    remote_number=42,
    remote_node_id="I_kwDOxxx",
    last_pull_at=1774900000L,
    last_push_at=1774900000L,
    remote_updated_at=1774899000L,
  )
  hub.put_sync_link(objects, refs, clock, link)
  let retrieved = hub.get_sync_link(objects, "issue-abc", "github")
  assert_true(retrieved is Some(_))
  let retrieved = retrieved.unwrap()
  assert_eq(retrieved.local_id(), "issue-abc")
  assert_eq(retrieved.remote_number(), 42)
  assert_eq(retrieved.repo(), "owner/repo")
}

test "hub: list sync_links for repo" {
  let (objects, refs, clock) = make_test_stores()
  let hub = @hub.Hub::init(objects, refs)
  let link1 = @hub.SyncLink::new("id-1", "issue", "github", "owner/repo", remote_number=1)
  let link2 = @hub.SyncLink::new("id-2", "pr", "github", "owner/repo", remote_number=2)
  let link3 = @hub.SyncLink::new("id-3", "issue", "github", "other/repo", remote_number=3)
  hub.put_sync_link(objects, refs, clock, link1)
  hub.put_sync_link(objects, refs, clock, link2)
  hub.put_sync_link(objects, refs, clock, link3)
  let links = hub.list_sync_links(objects, repo="owner/repo")
  assert_eq(links.length(), 2)
  let all_links = hub.list_sync_links(objects)
  assert_eq(all_links.length(), 3)
}

test "hub: find sync_link by remote number" {
  let (objects, refs, clock) = make_test_stores()
  let hub = @hub.Hub::init(objects, refs)
  let link = @hub.SyncLink::new("id-1", "issue", "github", "owner/repo", remote_number=42)
  hub.put_sync_link(objects, refs, clock, link)
  let found = hub.find_sync_link_by_remote(objects, "github", "owner/repo", 42)
  assert_true(found is Some(_))
  assert_eq(found.unwrap().local_id(), "id-1")
  let not_found = hub.find_sync_link_by_remote(objects, "github", "owner/repo", 99)
  assert_true(not_found is None)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test --package bit/x/hub --filter "sync_link" 2>&1 | tail -20`
Expected: Compilation error — `put_sync_link` not defined

- [ ] **Step 3: Add record kind constant**

`src/x/hub/store.mbt` の既存定数の近くに追加:

```moonbit
///|
let sync_link_record_kind_value : String = "sync-link"

///|
pub fn sync_link_record_kind() -> String {
  sync_link_record_kind_value
}

///|
pub fn is_sync_link_record_kind(kind : String) -> Bool {
  kind == sync_link_record_kind_value
}

///|
pub fn sync_link_key(local_id : String, provider : String) -> String {
  "hub/sync-link/" + local_id + "/" + provider
}
```

- [ ] **Step 4: Implement Hub sync_link operations**

Create `src/x/hub/sync_link_ops.mbt`:

```moonbit
///|
pub fn Hub::put_sync_link(
  self : Hub,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  link : SyncLink,
) -> Unit raise @bit.GitError {
  ignore(
    self.store.put_record(
      objects,
      refs,
      clock,
      sync_link_key(link.local_id, link.provider),
      sync_link_record_kind(),
      link.serialize(),
      "sync",
    ),
  )
}

///|
pub fn Hub::get_sync_link(
  self : Hub,
  objects : &@lib.ObjectStore,
  local_id : String,
  provider : String,
) -> SyncLink? raise @bit.GitError {
  let key = sync_link_key(local_id, provider)
  let record = self.store.get_record(objects, key)
  match record {
    None => None
    Some(rec) => {
      if rec.deleted {
        return None
      }
      let link = parse_sync_link(rec.payload) catch { _ => return None }
      Some(link)
    }
  }
}

///|
pub fn Hub::list_sync_links(
  self : Hub,
  objects : &@lib.ObjectStore,
  repo? : String = "",
) -> Array[SyncLink] raise @bit.GitError {
  let result : Array[SyncLink] = []
  let prefix = "hub/sync-link/"
  for key, _blob_id in self.store.entries {
    if !key.starts_with(prefix) {
      // entries are keyed by blob hash, not by key — need to read records
      continue
    }
  }
  // Read all records and filter
  let records = self.store.list_records(objects)
  for record in records {
    if !is_sync_link_record_kind(record.kind) {
      continue
    }
    if record.deleted {
      continue
    }
    let link = parse_sync_link(record.payload) catch { _ => continue }
    if repo.length() > 0 && link.repo != repo {
      continue
    }
    result.push(link)
  }
  result
}

///|
pub fn Hub::find_sync_link_by_remote(
  self : Hub,
  objects : &@lib.ObjectStore,
  provider : String,
  repo : String,
  remote_number : Int,
) -> SyncLink? raise @bit.GitError {
  let links = self.list_sync_links(objects, repo~)
  for link in links {
    if link.provider == provider && link.remote_number == remote_number {
      return Some(link)
    }
  }
  None
}
```

Note: `HubStore::list_records` と `HubStore::get_record` が存在するか確認が必要。存在しない場合は `store.entries` を走査して blob を読み、`HubRecord` をパースする必要がある。既存の `list_work_items` の実装パターンを参考にすること。

- [ ] **Step 5: Run tests**

Run: `moon test --package bit/x/hub --filter "sync_link" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 6: Run all hub tests**

Run: `moon test --package bit/x/hub 2>&1 | tail -5`
Expected: All pass

- [ ] **Step 7: Commit**

```bash
git add src/x/hub/sync_link_ops.mbt src/x/hub/store.mbt src/x/hub/hub_test.mbt
git commit -m "feat(hub): add SyncLink CRUD operations on Hub"
```

---

### Task 3: GitHub API 型定義

**Files:**
- Create: `src/x/hub/github_types.mbt`
- Test: `src/x/hub/hub_test.mbt`

- [ ] **Step 1: Write the failing test**

```moonbit
test "github_types: parse GhIssue from JSON" {
  let json_str =
    #|{"number":42,"node_id":"I_kwDOxxx","title":"Bug report","body":"description","state":"open","user":{"login":"alice"},"labels":[{"name":"bug"}],"assignees":[{"login":"bob"}],"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}
  let parsed = @json.parse(json_str)
  guard parsed is Json::Object(obj) else { abort("not object") }
  let issue = @hub.GhIssue::from_json(obj)
  assert_eq(issue.number, 42)
  assert_eq(issue.node_id, "I_kwDOxxx")
  assert_eq(issue.title, "Bug report")
  assert_eq(issue.state, "open")
  assert_eq(issue.user, "alice")
  assert_eq(issue.labels, ["bug"])
  assert_eq(issue.assignees, ["bob"])
}

test "github_types: parse GhComment from JSON" {
  let json_str =
    #|{"id":12345,"node_id":"IC_kwDOyyy","body":"comment text","user":{"login":"alice"},"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}
  let parsed = @json.parse(json_str)
  guard parsed is Json::Object(obj) else { abort("not object") }
  let comment = @hub.GhComment::from_json(obj)
  assert_eq(comment.id, 12345)
  assert_eq(comment.body, "comment text")
  assert_eq(comment.user, "alice")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test --package bit/x/hub --filter "github_types" 2>&1 | tail -20`
Expected: Compilation error

- [ ] **Step 3: Implement GitHub types**

Create `src/x/hub/github_types.mbt`:

```moonbit
///|
pub struct GhIssue {
  number : Int
  node_id : String
  title : String
  body : String
  state : String             // "open" or "closed"
  user : String              // login name
  labels : Array[String]     // label names
  assignees : Array[String]  // login names
  created_at : String        // ISO 8601
  updated_at : String        // ISO 8601
}

///|
pub fn GhIssue::from_json(obj : Map[String, Json]) -> GhIssue {
  let labels : Array[String] = []
  match obj.get("labels") {
    Some(Json::Array(items)) =>
      for item in items {
        match item {
          Json::Object(label_obj) =>
            match label_obj.get("name") {
              Some(Json::String(name)) => labels.push(name)
              _ => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  let assignees : Array[String] = []
  match obj.get("assignees") {
    Some(Json::Array(items)) =>
      for item in items {
        match item {
          Json::Object(user_obj) =>
            match user_obj.get("login") {
              Some(Json::String(login)) => assignees.push(login)
              _ => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  let user = match obj.get("user") {
    Some(Json::Object(user_obj)) =>
      match user_obj.get("login") {
        Some(Json::String(login)) => login
        _ => ""
      }
    _ => ""
  }
  {
    number: json_get_int(obj, "number", 0),
    node_id: json_get_string(obj, "node_id", ""),
    title: json_get_string(obj, "title", ""),
    body: json_get_string(obj, "body", ""),
    state: json_get_string(obj, "state", "open"),
    user,
    labels,
    assignees,
    created_at: json_get_string(obj, "created_at", ""),
    updated_at: json_get_string(obj, "updated_at", ""),
  }
}

///|
pub struct GhPullRequest {
  number : Int
  node_id : String
  title : String
  body : String
  state : String           // "open", "closed", "merged"
  user : String
  head_ref : String        // branch name
  head_repo : String       // "owner/repo" or ""
  base_ref : String        // target branch
  labels : Array[String]
  created_at : String
  updated_at : String
  merged : Bool
  merged_at : String
}

///|
pub fn GhPullRequest::from_json(obj : Map[String, Json]) -> GhPullRequest {
  let labels : Array[String] = []
  match obj.get("labels") {
    Some(Json::Array(items)) =>
      for item in items {
        match item {
          Json::Object(label_obj) =>
            match label_obj.get("name") {
              Some(Json::String(name)) => labels.push(name)
              _ => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  let user = match obj.get("user") {
    Some(Json::Object(user_obj)) =>
      match user_obj.get("login") {
        Some(Json::String(login)) => login
        _ => ""
      }
    _ => ""
  }
  let head_ref = match obj.get("head") {
    Some(Json::Object(head)) => json_get_string(head, "ref", "")
    _ => ""
  }
  let head_repo = match obj.get("head") {
    Some(Json::Object(head)) =>
      match head.get("repo") {
        Some(Json::Object(repo)) => json_get_string(repo, "full_name", "")
        _ => ""
      }
    _ => ""
  }
  let base_ref = match obj.get("base") {
    Some(Json::Object(base)) => json_get_string(base, "ref", "")
    _ => ""
  }
  let merged = match obj.get("merged") {
    Some(Json::True) => true
    _ => false
  }
  let state_raw = json_get_string(obj, "state", "open")
  let state = if merged { "merged" } else { state_raw }
  {
    number: json_get_int(obj, "number", 0),
    node_id: json_get_string(obj, "node_id", ""),
    title: json_get_string(obj, "title", ""),
    body: json_get_string(obj, "body", ""),
    state,
    user,
    head_ref,
    head_repo,
    base_ref,
    labels,
    created_at: json_get_string(obj, "created_at", ""),
    updated_at: json_get_string(obj, "updated_at", ""),
    merged,
    merged_at: json_get_string(obj, "merged_at", ""),
  }
}

///|
pub struct GhComment {
  id : Int
  node_id : String
  body : String
  user : String
  created_at : String
  updated_at : String
}

///|
pub fn GhComment::from_json(obj : Map[String, Json]) -> GhComment {
  let user = match obj.get("user") {
    Some(Json::Object(user_obj)) =>
      match user_obj.get("login") {
        Some(Json::String(login)) => login
        _ => ""
      }
    _ => ""
  }
  {
    id: json_get_int(obj, "id", 0),
    node_id: json_get_string(obj, "node_id", ""),
    body: json_get_string(obj, "body", ""),
    user,
    created_at: json_get_string(obj, "created_at", ""),
    updated_at: json_get_string(obj, "updated_at", ""),
  }
}

///|
fn json_get_string(obj : Map[String, Json], key : String, fallback : String) -> String {
  match obj.get(key) {
    Some(Json::String(value)) => value
    Some(Json::Null) => fallback
    _ => fallback
  }
}

///|
fn json_get_int(obj : Map[String, Json], key : String, fallback : Int) -> Int {
  match obj.get(key) {
    Some(Json::Number(value, ..)) => value.to_int()
    _ => fallback
  }
}
```

Note: `json_get_string` と `json_get_int` は `hub_import.mbt`（cmd パッケージ）にも存在するが、`src/x/hub/`（ライブラリパッケージ）からは参照できない。このパッケージに独自のヘルパーを定義する。名前衝突が起きる場合はプレフィックス（`gh_json_get_string` など）を使う。

- [ ] **Step 4: Run tests**

Run: `moon test --package bit/x/hub --filter "github_types" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/x/hub/github_types.mbt src/x/hub/hub_test.mbt
git commit -m "feat(hub): add GitHub API types (GhIssue, GhPullRequest, GhComment)"
```

---

### Task 4: GitHub API クライアント — gh CLI 実装

**Files:**
- Create: `src/x/hub/native/github_api.mbt`
- Test: 統合テストは手動（外部 API 依存）

- [ ] **Step 1: Implement gh CLI client**

Create `src/x/hub/native/github_api.mbt`:

```moonbit
///|
/// Check if gh CLI is available
pub async fn github_has_gh_cli() -> Bool {
  let (code, _, _) = @process.collect_output(
    "gh",
    ["--version"],
    inherit_env=true,
  ) catch { _ => return false }
  code == 0
}

///|
/// Check if GITHUB_TOKEN is set
pub fn github_has_token() -> Bool {
  @sys.get_env_var("GITHUB_TOKEN") is Some(_)
}

///|
/// Detect available GitHub API access method
pub async fn github_detect_method() -> String raise @bitcore.GitError {
  if github_has_gh_cli() {
    return "gh"
  }
  if github_has_token() {
    return "token"
  }
  raise @bitcore.GitError::InvalidObject(
    "GitHub API not available: install gh CLI or set GITHUB_TOKEN",
  )
}

///|
/// Run gh api command and return JSON response
async fn gh_api(
  method : String,
  path : String,
  body? : String = "",
) -> String raise @bitcore.GitError {
  let args : Array[String] = ["api"]
  if method != "GET" {
    args.push("--method")
    args.push(method)
  }
  args.push(path)
  if body.length() > 0 {
    args.push("--input")
    args.push("-")
  }
  let (code, stdout, stderr) = @process.collect_output(
    "gh",
    args,
    inherit_env=true,
  ) catch {
    err => raise @bitcore.GitError::IoError("gh api failed: \{err}")
  }
  let out = stdout.text() catch {
    err if @async.is_cancellation_error(err) =>
      raise @bitcore.GitError::IoError(err.to_string())
    _ => ""
  }
  if code != 0 {
    let err_text = stderr.text() catch { _ => "" }
    raise @bitcore.GitError::InvalidObject(
      "gh api failed (\{code}): \{err_text}",
    )
  }
  out
}

///|
/// List issues from GitHub using gh CLI
pub async fn github_list_issues(
  repo : String,
  since? : String = "",
  state? : String = "all",
) -> Array[@hub.GhIssue] raise @bitcore.GitError {
  let path = "repos/" + repo + "/issues?state=" + state + "&per_page=100"
  let path = if since.length() > 0 {
    path + "&since=" + since
  } else {
    path
  }
  let response = gh_api("GET", path)
  let parsed = @json.parse(response) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "Invalid JSON from gh api: \{err}",
      )
  }
  let items = match parsed {
    Json::Array(items) => items
    _ =>
      raise @bitcore.GitError::InvalidObject("Expected JSON array from gh api")
  }
  let result : Array[@hub.GhIssue] = []
  for item in items {
    match item {
      Json::Object(obj) => {
        // Skip pull requests (GitHub API returns PRs in issues endpoint)
        if obj.get("pull_request") is Some(_) && obj.get("pull_request") is Some(Json::Object(_)) {
          continue
        }
        result.push(@hub.GhIssue::from_json(obj))
      }
      _ => ()
    }
  }
  result
}

///|
/// List PRs from GitHub using gh CLI
pub async fn github_list_prs(
  repo : String,
  since? : String = "",
  state? : String = "all",
) -> Array[@hub.GhPullRequest] raise @bitcore.GitError {
  let path = "repos/" + repo + "/pulls?state=" + state + "&per_page=100&sort=updated&direction=desc"
  let response = gh_api("GET", path)
  let parsed = @json.parse(response) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "Invalid JSON from gh api: \{err}",
      )
  }
  let items = match parsed {
    Json::Array(items) => items
    _ =>
      raise @bitcore.GitError::InvalidObject("Expected JSON array from gh api")
  }
  let result : Array[@hub.GhPullRequest] = []
  for item in items {
    match item {
      Json::Object(obj) => result.push(@hub.GhPullRequest::from_json(obj))
      _ => ()
    }
  }
  // Filter by since (updated_at) if provided — GitHub pulls endpoint doesn't have since param
  if since.length() > 0 {
    return result.filter(fn(pr) { pr.updated_at >= since })
  }
  result
}

///|
/// List comments for an issue/PR from GitHub
pub async fn github_list_comments(
  repo : String,
  number : Int,
  since? : String = "",
) -> Array[@hub.GhComment] raise @bitcore.GitError {
  let path = "repos/" + repo + "/issues/" + number.to_string() + "/comments?per_page=100"
  let path = if since.length() > 0 {
    path + "&since=" + since
  } else {
    path
  }
  let response = gh_api("GET", path)
  let parsed = @json.parse(response) catch {
    err =>
      raise @bitcore.GitError::InvalidObject(
        "Invalid JSON from gh api: \{err}",
      )
  }
  let items = match parsed {
    Json::Array(items) => items
    _ =>
      raise @bitcore.GitError::InvalidObject("Expected JSON array from gh api")
  }
  let result : Array[@hub.GhComment] = []
  for item in items {
    match item {
      Json::Object(obj) => result.push(@hub.GhComment::from_json(obj))
      _ => ()
    }
  }
  result
}

///|
/// Create an issue on GitHub
pub async fn github_create_issue(
  repo : String,
  title : String,
  body : String,
  labels : Array[String],
  assignees : Array[String],
) -> @hub.GhIssue raise @bitcore.GitError {
  let json_obj : Map[String, Json] = {}
  json_obj.set("title", Json::String(title))
  json_obj.set("body", Json::String(body))
  let label_arr : Array[Json] = labels.map(fn(l) { Json::String(l) })
  json_obj.set("labels", Json::Array(label_arr))
  let assignee_arr : Array[Json] = assignees.map(fn(a) { Json::String(a) })
  json_obj.set("assignees", Json::Array(assignee_arr))
  let payload = Json::Object(json_obj).stringify()
  let args = ["api", "--method", "POST", "repos/" + repo + "/issues", "--input", "-"]
  let (code, stdout, stderr) = @process.collect_output_with_stdin(
    "gh",
    args,
    payload,
    inherit_env=true,
  ) catch {
    err => raise @bitcore.GitError::IoError("gh api failed: \{err}")
  }
  let out = stdout.text() catch { _ => "" }
  if code != 0 {
    let err_text = stderr.text() catch { _ => "" }
    raise @bitcore.GitError::InvalidObject(
      "gh api create issue failed (\{code}): \{err_text}",
    )
  }
  let parsed = @json.parse(out) catch {
    err => raise @bitcore.GitError::InvalidObject("Invalid JSON: \{err}")
  }
  match parsed {
    Json::Object(obj) => @hub.GhIssue::from_json(obj)
    _ => raise @bitcore.GitError::InvalidObject("Expected JSON object")
  }
}

///|
/// Update an issue on GitHub
pub async fn github_update_issue(
  repo : String,
  number : Int,
  title? : String? = None,
  body? : String? = None,
  state? : String? = None,
  labels? : Array[String]? = None,
  assignees? : Array[String]? = None,
) -> @hub.GhIssue raise @bitcore.GitError {
  let json_obj : Map[String, Json] = {}
  match title {
    Some(t) => json_obj.set("title", Json::String(t))
    None => ()
  }
  match body {
    Some(b) => json_obj.set("body", Json::String(b))
    None => ()
  }
  match state {
    Some(s) => json_obj.set("state", Json::String(s))
    None => ()
  }
  match labels {
    Some(ls) => {
      let arr : Array[Json] = ls.map(fn(l) { Json::String(l) })
      json_obj.set("labels", Json::Array(arr))
    }
    None => ()
  }
  match assignees {
    Some(asns) => {
      let arr : Array[Json] = asns.map(fn(a) { Json::String(a) })
      json_obj.set("assignees", Json::Array(arr))
    }
    None => ()
  }
  let payload = Json::Object(json_obj).stringify()
  let path = "repos/" + repo + "/issues/" + number.to_string()
  let args = ["api", "--method", "PATCH", path, "--input", "-"]
  let (code, stdout, stderr) = @process.collect_output_with_stdin(
    "gh",
    args,
    payload,
    inherit_env=true,
  ) catch {
    err => raise @bitcore.GitError::IoError("gh api failed: \{err}")
  }
  let out = stdout.text() catch { _ => "" }
  if code != 0 {
    let err_text = stderr.text() catch { _ => "" }
    raise @bitcore.GitError::InvalidObject(
      "gh api update issue failed (\{code}): \{err_text}",
    )
  }
  let parsed = @json.parse(out) catch {
    err => raise @bitcore.GitError::InvalidObject("Invalid JSON: \{err}")
  }
  match parsed {
    Json::Object(obj) => @hub.GhIssue::from_json(obj)
    _ => raise @bitcore.GitError::InvalidObject("Expected JSON object")
  }
}

///|
/// Create a comment on GitHub issue/PR
pub async fn github_create_comment(
  repo : String,
  number : Int,
  body : String,
) -> @hub.GhComment raise @bitcore.GitError {
  let json_obj : Map[String, Json] = {}
  json_obj.set("body", Json::String(body))
  let payload = Json::Object(json_obj).stringify()
  let path = "repos/" + repo + "/issues/" + number.to_string() + "/comments"
  let args = ["api", "--method", "POST", path, "--input", "-"]
  let (code, stdout, stderr) = @process.collect_output_with_stdin(
    "gh",
    args,
    payload,
    inherit_env=true,
  ) catch {
    err => raise @bitcore.GitError::IoError("gh api failed: \{err}")
  }
  let out = stdout.text() catch { _ => "" }
  if code != 0 {
    let err_text = stderr.text() catch { _ => "" }
    raise @bitcore.GitError::InvalidObject(
      "gh api create comment failed (\{code}): \{err_text}",
    )
  }
  let parsed = @json.parse(out) catch {
    err => raise @bitcore.GitError::InvalidObject("Invalid JSON: \{err}")
  }
  match parsed {
    Json::Object(obj) => @hub.GhComment::from_json(obj)
    _ => raise @bitcore.GitError::InvalidObject("Expected JSON object")
  }
}
```

Note: `@process.collect_output_with_stdin` が存在しない場合、`gh api` の `--input -` の代わりに `--raw-field body=...` 形式を使うか、JSON を一時ファイル経由で渡す。実装時に利用可能な API を確認すること。代替として `gh api --method POST path -f title=xxx -f body=xxx` 形式も使える。

- [ ] **Step 2: Run build check**

Run: `moon check 2>&1 | tail -10`
Expected: No errors (外部 API テストはなし)

- [ ] **Step 3: Commit**

```bash
git add src/x/hub/native/github_api.mbt
git commit -m "feat(hub): add GitHub API client via gh CLI"
```

---

### Task 5: bit issue sync status コマンド

**Files:**
- Create: `src/cmd/bit/hub_github_sync.mbt`
- Modify: `src/cmd/bit/hub_issue.mbt` (ルーティング追加)
- Modify: `src/cmd/git-bit/hub_issue.mbt` (同上)

- [ ] **Step 1: Implement sync status command**

Create `src/cmd/bit/hub_github_sync.mbt`:

```moonbit
///|
fn print_hub_issue_sync_usage() -> Unit {
  println("Usage: bit issue sync <subcommand> [<args>]")
  println("")
  println("Subcommands:")
  println("  pull --repo <owner/repo> [--since <date>] [--conflict <policy>] [--comments <mode>]")
  println("  push --github --repo <owner/repo> [--apply] [--comments <mode>]")
  println("  status --repo <owner/repo>")
  println("  install-hook")
  println("")
  println("Conflict policies: newer-wins (default), github-wins, bit-wins, manual")
  println("Comment modes: append-only (default), full, no-delete")
}

///|
async fn handle_hub_issue_sync(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    print_hub_issue_sync_usage()
    return ()
  }
  let subcmd = args[0]
  let rest = collect_args(args, 1)
  match subcmd {
    "pull" => handle_hub_issue_sync_pull(rest)
    "push" => handle_hub_issue_sync_push(rest)
    "status" => handle_hub_issue_sync_status(rest)
    "install-hook" => handle_hub_issue_sync_install_hook(rest)
    "help" | "-h" | "--help" => print_hub_issue_sync_usage()
    _ => {
      // Bidirectional: bit issue sync --github --repo owner/repo
      handle_hub_issue_sync_bidirectional(args)
    }
  }
}

///|
async fn handle_hub_issue_sync_status(args : Array[String]) -> Unit raise Error {
  let mut repo : String? = None
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--repo" if i + 1 < args.length() => {
        repo = Some(args[i + 1])
        i += 2
      }
      _ if args[i].has_prefix("--repo=") => {
        repo = Some(String::unsafe_substring(args[i], start=7, end=args[i].length()))
        i += 1
      }
      _ => i += 1
    }
  }
  guard repo is Some(repo_name) else {
    eprint_line("Usage: bit issue sync status --repo <owner/repo>")
    @sys.exit(1)
  }
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let (objects, refs, _clock) = make_hub_stores(git_dir)
  let hub = load_hub_store(objects, refs)
  let links = hub.list_sync_links(objects, repo=repo_name)
  if links.length() == 0 {
    print_line("No sync links for \{repo_name}")
    print_line("Run 'bit issue sync pull --repo \{repo_name}' to start syncing")
    return ()
  }
  let mut issue_count = 0
  let mut pr_count = 0
  for link in links {
    if link.local_kind() == "issue" {
      issue_count += 1
    } else {
      pr_count += 1
    }
  }
  print_line("Sync status for \{repo_name}:")
  print_line("  Issues: \{issue_count} linked")
  print_line("  PRs:    \{pr_count} linked")
  print_line("")
  print_line("Recent sync links:")
  let shown = if links.length() > 10 { 10 } else { links.length() }
  for i = 0; i < shown; i = i + 1 {
    let link = links[i]
    print_line("  \{link.local_kind()} #\{link.local_id()} ↔ GitHub #\{link.remote_number()}")
    if link.last_pull_at() > 0L {
      print_line("    last pull: \{link.last_pull_at()}")
    }
    if link.last_push_at() > 0L {
      print_line("    last push: \{link.last_push_at()}")
    }
  }
  if links.length() > 10 {
    print_line("  ... and \{links.length() - 10} more")
  }
}

///|
async fn handle_hub_issue_sync_pull(_args : Array[String]) -> Unit raise Error {
  // Placeholder — implemented in Plan B
  eprint_line("bit issue sync pull: not yet implemented")
  @sys.exit(1)
}

///|
async fn handle_hub_issue_sync_push(_args : Array[String]) -> Unit raise Error {
  // Placeholder — implemented in Plan B
  eprint_line("bit issue sync push: not yet implemented")
  @sys.exit(1)
}

///|
async fn handle_hub_issue_sync_bidirectional(_args : Array[String]) -> Unit raise Error {
  // Placeholder — implemented in Plan B
  eprint_line("bit issue sync: not yet implemented (use pull or push)")
  @sys.exit(1)
}

///|
async fn handle_hub_issue_sync_install_hook(_args : Array[String]) -> Unit raise Error {
  // Placeholder — implemented in Plan C
  eprint_line("bit issue sync install-hook: not yet implemented")
  @sys.exit(1)
}
```

- [ ] **Step 2: Add routing**

`src/cmd/bit/hub_issue.mbt` の `handle_hub_issue` match に、既存の sync ルーティングがなければ追加:

```moonbit
    "sync" => handle_hub_issue_sync(rest)
```

usage に追加:

```
  println("  sync pull --repo <owner/repo>         (pull from GitHub)")
  println("  sync push --github --repo <owner/repo> [--apply]")
  println("  sync status --repo <owner/repo>")
```

`src/cmd/git-bit/hub_issue.mbt` にも同様。git-bit 用に `hub_github_sync.mbt` もコピー。

- [ ] **Step 3: Run build check**

Run: `moon check 2>&1 | tail -10`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add src/cmd/bit/hub_github_sync.mbt src/cmd/bit/hub_issue.mbt src/cmd/git-bit/hub_github_sync.mbt src/cmd/git-bit/hub_issue.mbt
git commit -m "feat(hub): add 'bit issue sync' command scaffold with status subcommand"
```

---

## Self-Review

**Spec coverage:**
- SyncLink record → Task 1, 2
- GitHub API access (gh CLI) → Task 4
- GitHub types → Task 3
- `bit issue sync status` → Task 5
- HTTP client (GITHUB_TOKEN fallback) → deferred to Plan B（基盤確立後に追加）

**Placeholder scan:** Task 5 の pull/push/bidirectional は明示的に stub として `eprint_line("not yet implemented")` + `@sys.exit(1)` で記述。Plan B で実装。

**Type consistency:** SyncLink の field 名とアクセサは全タスクで一貫。GhIssue/GhPullRequest/GhComment の field 名も一貫。
