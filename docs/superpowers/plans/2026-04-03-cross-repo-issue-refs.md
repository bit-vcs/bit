# Cross-Repo Issue References Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** bit-issue にクロスリポジトリ参照（リンク）、ワーキングセット、リモートリポ直接操作機能を追加する

**Architecture:** WorkItem に `linked_issues` フィールド（`Array[String]`、`owner/repo#id` 形式）を追加し、シリアライズ/パースを拡張する。リポジトリ解決は ghq パス規約 + エイリアス（`.git/hub/remotes`）。ワーキングセットは `.git/hub/active-issues` ファイルで管理。リモートリポ操作は `make_hub_stores(git_dir)` に別リポの git_dir を渡すことで実現。

**Tech Stack:** MoonBit, Git notes (`refs/notes/bit-hub`)

---

### Task 1: WorkItem に linked_issues フィールドを追加

**Files:**
- Modify: `src/x/hub/types.mbt:340-384` (WorkItem struct + new)
- Modify: `src/x/hub/format.mbt:173-265` (serialize)
- Modify: `src/x/hub/format.mbt:269-380` (parse_work_item)
- Test: `src/x/hub/hub_test.mbt`

- [ ] **Step 1: Write the failing test**

`src/x/hub/hub_test.mbt` に追加:

```moonbit
test "format: serialize and parse WorkItem with linked_issues" {
  let item = WorkItem::new(
    "w-linked-1",
    "Issue with cross-repo links",
    "Body text",
    "alice@example.com",
    1706745600L,
    1706832000L,
    WorkItemState::Open,
    labels=["feature"],
    linked_issues=["bit-vcs/other-repo#a1b2c3d4", "myteam/lib#deadbeef"],
  )
  let serialized = item.serialize()
  assert_true(serialized.contains("linked-issue bit-vcs/other-repo#a1b2c3d4"))
  assert_true(serialized.contains("linked-issue myteam/lib#deadbeef"))
  let parsed = parse_work_item(serialized)
  assert_eq(parsed.linked_issues(), ["bit-vcs/other-repo#a1b2c3d4", "myteam/lib#deadbeef"])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test --package bit/x/hub --filter "linked_issues" 2>&1 | tail -20`
Expected: Compilation error — `linked_issues` field does not exist on WorkItem

- [ ] **Step 3: Add linked_issues field to WorkItem**

`src/x/hub/types.mbt` — WorkItem struct に追加:

```moonbit
pub struct WorkItem {
  id : String
  title : String
  body : String
  author : String
  created_at : Int64
  updated_at : Int64
  state : WorkItemState
  labels : Array[String]
  assignees : Array[String]
  linked_prs : Array[String]
  linked_issues : Array[String]   // NEW: cross-repo issue refs ("owner/repo#id")
  patch : WorkItemPatch?
  parent_id : String?
}
```

`WorkItem::new` にパラメータ追加:

```moonbit
pub fn WorkItem::new(
  id : String,
  title : String,
  body : String,
  author : String,
  created_at : Int64,
  updated_at : Int64,
  state : WorkItemState,
  labels? : Array[String] = [],
  assignees? : Array[String] = [],
  linked_prs? : Array[String] = [],
  linked_issues? : Array[String] = [],   // NEW
  patch? : WorkItemPatch? = None,
  parent_id? : String? = None,
) -> WorkItem {
  {
    id, title, body, author, created_at, updated_at, state,
    labels, assignees, linked_prs, linked_issues, patch, parent_id,
  }
}
```

`WorkItem::linked_issues` アクセサを追加:

```moonbit
pub fn WorkItem::linked_issues(self : WorkItem) -> Array[String] {
  self.linked_issues
}
```

- [ ] **Step 4: Add serialization for linked_issues**

`src/x/hub/format.mbt` の `WorkItem::serialize` にて、`linked-pr` ループの直後に追加:

```moonbit
  for issue_ref in self.linked_issues {
    sb.write_string("linked-issue ")
    sb.write_string(issue_ref)
    sb.write_char('\n')
  }
```

- [ ] **Step 5: Add parsing for linked_issues**

`src/x/hub/format.mbt` の `parse_work_item` にて:

1. 変数宣言に追加: `let linked_issues : Array[String] = []`
2. match ブランチに追加: `"linked-issue" => linked_issues.push(value)`
3. WorkItem::new 呼び出しに `linked_issues~` を追加

- [ ] **Step 6: Update Issue ↔ WorkItem conversion**

`src/x/hub/types.mbt` の Issue struct にも `linked_issues` フィールドを追加し、`Issue::to_work_item()` と `WorkItem::to_issue()` で相互変換を通す。既存の `Issue::new` にもオプショナルパラメータとして追加。

- [ ] **Step 7: Run test to verify it passes**

Run: `moon test --package bit/x/hub --filter "linked_issues" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 8: Run all hub tests**

Run: `moon test --package bit/x/hub 2>&1 | tail -20`
Expected: All tests pass（既存テストは linked_issues を渡さないのでデフォルト `[]` が使われる）

- [ ] **Step 9: Commit**

```bash
git add src/x/hub/types.mbt src/x/hub/format.mbt src/x/hub/hub_test.mbt
git commit -m "feat(hub): add linked_issues field to WorkItem for cross-repo issue references"
```

---

### Task 2: リポジトリ解決（エイリアス + ghq パス）

**Files:**
- Create: `src/cmd/bit/hub_remote.mbt` (リポ解決 + エイリアス管理)
- Test: `src/cmd/bit/hub_remote_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

`src/cmd/bit/hub_remote_wbtest.mbt`:

```moonbit
test "resolve_repo_path: ghq convention" {
  // ghq パス: ~/ghq/github.com/owner/repo
  let home = @sys.get_env_var("HOME").unwrap()
  let path = resolve_repo_ref_to_path("bit-vcs/bit", home)
  assert_eq(path, home + "/ghq/github.com/bit-vcs/bit")
}

test "parse_cross_repo_ref: owner/repo#id" {
  let (repo_ref, issue_id) = parse_cross_repo_ref("bit-vcs/other#a1b2c3d4")
  assert_eq(repo_ref, "bit-vcs/other")
  assert_eq(issue_id, "a1b2c3d4")
}

test "parse_cross_repo_ref: local #id" {
  let (repo_ref, issue_id) = parse_cross_repo_ref("#local123")
  assert_eq(repo_ref, "")
  assert_eq(issue_id, "local123")
}

test "parse_alias_file: roundtrip" {
  let entries : Array[(String, String)] = [("myapp", "/path/to/repo"), ("lib", "/other/path")]
  let serialized = serialize_alias_entries(entries)
  let parsed = parse_alias_entries(serialized)
  assert_eq(parsed.length(), 2)
  assert_eq(parsed[0].0, "myapp")
  assert_eq(parsed[0].1, "/path/to/repo")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test --package bit/cmd/bit --filter "resolve_repo_path" 2>&1 | tail -20`
Expected: Compilation error — functions not defined

- [ ] **Step 3: Implement repo resolution**

`src/cmd/bit/hub_remote.mbt`:

```moonbit
///|
/// Parse "owner/repo#issue-id" or "#issue-id" (local)
fn parse_cross_repo_ref(ref : String) -> (String, String) {
  match ref.find("#") {
    None => (ref, "")
    Some(idx) => {
      let repo_ref = String::unsafe_substring(ref, start=0, end=idx)
      let issue_id = String::unsafe_substring(ref, start=idx + 1, end=ref.length())
      (repo_ref, issue_id)
    }
  }
}

///|
/// Resolve "owner/repo" to local filesystem path.
/// Resolution order: alias → ghq path → error
fn resolve_repo_ref_to_path(
  repo_ref : String,
  home : String,
  aliases? : Map[String, String] = {},
) -> String raise Error {
  // 1. Check aliases
  match aliases.get(repo_ref) {
    Some(path) => return path
    None => ()
  }
  // 2. ghq convention: ~/ghq/github.com/owner/repo
  let ghq_path = home + "/ghq/github.com/" + repo_ref
  let fs = OsFs::new()
  if fs.is_dir(ghq_path + "/.git") {
    return ghq_path
  }
  raise @bitcore.GitError::InvalidObject(
    "Repository not found: \{repo_ref} (tried: \{ghq_path})",
  )
}

///|
fn hub_remotes_path(git_dir : String) -> String {
  git_dir + "/hub/remotes"
}

///|
fn serialize_alias_entries(entries : Array[(String, String)]) -> String {
  let sb = StringBuilder::new()
  for entry in entries {
    sb.write_string(entry.0)
    sb.write_char('\t')
    sb.write_string(entry.1)
    sb.write_char('\n')
  }
  sb.to_string()
}

///|
fn parse_alias_entries(content : String) -> Array[(String, String)] {
  let result : Array[(String, String)] = []
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 { continue }
    match line.find("\t") {
      None => continue
      Some(idx) => {
        let alias = String::unsafe_substring(line, start=0, end=idx)
        let path = String::unsafe_substring(line, start=idx + 1, end=line.length())
        result.push((alias, path))
      }
    }
  }
  result
}

///|
fn load_aliases(git_dir : String) -> Map[String, String] {
  let fs = OsFs::new()
  let path = hub_remotes_path(git_dir)
  let content = @utf8.decode_lossy(
    (fs.read_file(path) catch { _ => Bytes::default() })[:],
  ).to_string()
  let entries = parse_alias_entries(content)
  let map : Map[String, String] = {}
  for entry in entries {
    map.set(entry.0, entry.1)
  }
  map
}

///|
fn save_aliases(git_dir : String, aliases : Map[String, String]) -> Unit raise Error {
  let fs = OsFs::new()
  let entries : Array[(String, String)] = []
  for key, value in aliases {
    entries.push((key, value))
  }
  entries.sort_by(fn(a, b) { a.0.compare(b.0) })
  let path = hub_remotes_path(git_dir)
  let dir = os_parent_path(path)
  fs.mkdir_p(dir)
  fs.write_string(path, serialize_alias_entries(entries))
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test --package bit/cmd/bit --filter "resolve_repo_path\|parse_cross_repo_ref\|parse_alias" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/cmd/bit/hub_remote.mbt src/cmd/bit/hub_remote_wbtest.mbt
git commit -m "feat(hub): add repo resolution with ghq convention and alias support"
```

---

### Task 3: bit issue remote コマンド（エイリアス管理 CLI）

**Files:**
- Modify: `src/cmd/bit/hub_issue.mbt` (コマンドルーティング追加)
- Modify: `src/cmd/bit/hub_remote.mbt` (CLIハンドラ追加)
- Modify: `src/cmd/git-bit/hub_issue.mbt` (同じルーティング追加)

- [ ] **Step 1: Add remote subcommand routing**

`src/cmd/bit/hub_issue.mbt` の `handle_hub_issue` match に追加:

```moonbit
    "remote" => handle_hub_issue_remote(rest)
```

usage 出力にも追加:

```
  println("  remote add <alias> <path>")
  println("  remote list")
  println("  remote remove <alias>")
```

`src/cmd/git-bit/hub_issue.mbt` にも同様の変更を行う。

- [ ] **Step 2: Implement remote subcommand handlers**

`src/cmd/bit/hub_remote.mbt` に追加:

```moonbit
///|
async fn handle_hub_issue_remote(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    handle_hub_issue_remote_list([])
    return ()
  }
  match args[0] {
    "add" => handle_hub_issue_remote_add(collect_args(args, 1))
    "list" | "ls" => handle_hub_issue_remote_list(collect_args(args, 1))
    "remove" | "rm" => handle_hub_issue_remote_remove(collect_args(args, 1))
    _ => {
      eprint_line("bit issue remote: unknown subcommand '\{args[0]}'")
      @sys.exit(1)
    }
  }
}

///|
async fn handle_hub_issue_remote_add(args : Array[String]) -> Unit raise Error {
  if args.length() < 2 {
    eprint_line("Usage: bit issue remote add <alias> <path>")
    @sys.exit(1)
  }
  let alias = args[0]
  let path = args[1]
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let aliases = load_aliases(git_dir)
  aliases.set(alias, path)
  save_aliases(git_dir, aliases)
  print_line("Added remote '\{alias}' → \{path}")
}

///|
async fn handle_hub_issue_remote_list(_args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let aliases = load_aliases(git_dir)
  if aliases.size() == 0 {
    print_line("No remotes configured")
    return ()
  }
  for name, path in aliases {
    print_line("\{name}\t\{path}")
  }
}

///|
async fn handle_hub_issue_remote_remove(args : Array[String]) -> Unit raise Error {
  if args.length() < 1 {
    eprint_line("Usage: bit issue remote remove <alias>")
    @sys.exit(1)
  }
  let alias = args[0]
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let aliases = load_aliases(git_dir)
  if !aliases.contains(alias) {
    eprint_line("Remote '\{alias}' not found")
    @sys.exit(1)
  }
  aliases.remove(alias)
  save_aliases(git_dir, aliases)
  print_line("Removed remote '\{alias}'")
}
```

- [ ] **Step 3: Run build check**

Run: `moon check 2>&1 | tail -20`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add src/cmd/bit/hub_issue.mbt src/cmd/bit/hub_remote.mbt src/cmd/git-bit/hub_issue.mbt
git commit -m "feat(hub): add 'bit issue remote' subcommands for alias management"
```

---

### Task 4: bit issue link コマンドをクロスリポ対応に拡張

**Files:**
- Modify: `src/cmd/git-bit/hub_issue.mbt:1133-1146` (handle_hub_issue_link)
- Modify: `src/cmd/bit/hub_issue.mbt` (同等の link ハンドラ — `src/cmd/bit/` にも存在するか確認、なければ `git-bit` 側のみ)
- Modify: `src/x/hub/issue.mbt` (Hub::link_issue_to_issue 追加)

- [ ] **Step 1: Write the failing test**

`src/x/hub/hub_test.mbt` に追加:

```moonbit
test "hub: link cross-repo issue" {
  let (objects, refs, clock) = make_test_stores()
  let hub = @hub.Hub::init(objects, refs)
  let issue = hub.create_issue(
    objects, refs, clock,
    "Test issue", "body", "alice",
    labels=[], assignees=[],
  )
  hub.link_issue(objects, refs, clock, issue.id(), "bit-vcs/other#deadbeef")
  let updated = hub.get_issue(objects, issue.id())
  assert_true(updated is Some(_))
  let updated = updated.unwrap()
  assert_eq(updated.linked_issues(), ["bit-vcs/other#deadbeef"])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test --package bit/x/hub --filter "link cross-repo" 2>&1 | tail -20`
Expected: Compilation error — `link_issue` not defined

- [ ] **Step 3: Implement Hub::link_issue**

`src/x/hub/issue.mbt` に追加:

```moonbit
///|
pub fn Hub::link_issue(
  self : Hub,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  issue_id : String,
  target_ref : String,
) -> Unit raise @bit.GitError {
  let issue = self.get_issue(objects, issue_id)
  guard issue is Some(existing) else {
    raise @bit.GitError::InvalidObject("Issue not found: \{issue_id}")
  }
  let linked = existing.linked_issues()
  if !linked.contains(target_ref) {
    linked.push(target_ref)
  }
  let updated_item = existing.to_work_item()
  // Rebuild with updated linked_issues
  let new_item = WorkItem::new(
    updated_item.id(),
    updated_item.title(),
    updated_item.body(),
    updated_item.author(),
    updated_item.created_at(),
    clock.now(),
    updated_item.state(),
    labels=updated_item.labels(),
    assignees=updated_item.assignees(),
    linked_prs=updated_item.linked_prs(),
    linked_issues=linked,
    patch=updated_item.patch(),
    parent_id=updated_item.parent_id(),
  )
  ignore(
    self.store.put_record(
      objects,
      refs,
      clock,
      work_item_meta_key(issue_id),
      canonical_work_item_record_kind(),
      new_item.serialize(),
      existing.author(),
    ),
  )
}
```

- [ ] **Step 4: Update CLI handler**

`src/cmd/git-bit/hub_issue.mbt` の `handle_hub_issue_link` を拡張。現在は `(issue_id, pr_id)` の2引数だが、`owner/repo#id` 形式も受け付ける:

```moonbit
async fn handle_hub_issue_link(args : Array[String]) -> Unit raise Error {
  if args.length() < 2 {
    print_hub_issue_usage()
    return ()
  }
  let issue_id = args[0]
  let target = args[1]
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let (objects, refs, clock) = make_hub_stores(git_dir)
  let hub = load_hub_store(objects, refs)
  if target.contains("#") || target.contains("/") {
    // Cross-repo issue link
    hub.link_issue(objects, refs, clock, issue_id, target)
    print_line("Linked issue \{target} to issue #\{issue_id}")
  } else {
    // Legacy: PR link (local PR id)
    hub.link_pr_to_issue(objects, refs, clock, issue_id, target)
    print_line("Linked PR #\{target} to issue #\{issue_id}")
  }
}
```

`src/cmd/bit/hub_issue.mbt` にも同様のハンドラが存在する場合は同じ変更を適用。

- [ ] **Step 5: Run tests**

Run: `moon test --package bit/x/hub --filter "link cross-repo" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add src/x/hub/issue.mbt src/cmd/bit/hub_issue.mbt src/cmd/git-bit/hub_issue.mbt
git commit -m "feat(hub): extend 'bit issue link' to support cross-repo issue references"
```

---

### Task 5: bit issue get のクロスリポ対応

**Files:**
- Modify: `src/cmd/bit/hub_issue.mbt` (handle_hub_issue_get)
- Modify: `src/cmd/git-bit/hub_issue.mbt` (同上)

- [ ] **Step 1: Implement cross-repo get**

`handle_hub_issue_get` を修正。引数が `owner/repo#id` 形式なら、相手リポの git_dir を解決して読み取る:

```moonbit
async fn handle_hub_issue_get(args : Array[String]) -> Unit raise Error {
  // ... existing arg parsing ...
  let (repo_ref, parsed_id) = parse_cross_repo_ref(id_arg)
  let (git_dir, issue_id) = if repo_ref.length() > 0 {
    // Cross-repo: resolve to remote git_dir
    let root = get_work_root()
    let local_git_dir = resolve_hub_git_dir(root)
    let home = @sys.get_env_var("HOME").unwrap_or("/")
    let aliases = load_aliases(local_git_dir)
    let remote_path = resolve_repo_ref_to_path(repo_ref, home, aliases~)
    let remote_git_dir = resolve_hub_git_dir(remote_path)
    (remote_git_dir, parsed_id)
  } else {
    // Local
    let root = get_work_root()
    (resolve_hub_git_dir(root), parsed_id)
  }
  let (objects, refs, _clock) = make_hub_stores(git_dir)
  let hub = load_hub_store(objects, refs)
  // ... rest of existing get logic using hub and issue_id ...
}
```

- [ ] **Step 2: Test manually**

`bit issue get bit-vcs/bit#<some-id>` が自リポから読めることを確認（自リポへの ghq パスが解決できる場合）。

- [ ] **Step 3: Commit**

```bash
git add src/cmd/bit/hub_issue.mbt src/cmd/git-bit/hub_issue.mbt
git commit -m "feat(hub): support cross-repo ref in 'bit issue get'"
```

---

### Task 6: ワーキングセット（active issues）

**Files:**
- Create: `src/cmd/bit/hub_active.mbt` (ワーキングセット管理)
- Test: `src/cmd/bit/hub_active_wbtest.mbt`
- Modify: `src/cmd/bit/hub_issue.mbt` (コマンドルーティング追加)
- Modify: `src/cmd/git-bit/hub_issue.mbt` (同上)

- [ ] **Step 1: Write tests for active issues file parsing**

`src/cmd/bit/hub_active_wbtest.mbt`:

```moonbit
test "active_issues: parse and serialize roundtrip" {
  let entries = ["#local123", "bit-vcs/other#a1b2c3d4", "myapp#deadbeef"]
  let serialized = serialize_active_issues(entries)
  let parsed = parse_active_issues(serialized)
  assert_eq(parsed, entries)
}

test "active_issues: add and remove" {
  let entries : Array[String] = ["#local123"]
  let added = add_active_issue(entries, "bit-vcs/other#abc")
  assert_eq(added.length(), 2)
  let removed = remove_active_issue(added, "bit-vcs/other#abc")
  assert_eq(removed.length(), 1)
  assert_eq(removed[0], "#local123")
}

test "active_issues: no duplicates" {
  let entries : Array[String] = ["#local123"]
  let added = add_active_issue(entries, "#local123")
  assert_eq(added.length(), 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test --package bit/cmd/bit --filter "active_issues" 2>&1 | tail -20`
Expected: Compilation error

- [ ] **Step 3: Implement active issues management**

`src/cmd/bit/hub_active.mbt`:

```moonbit
///|
fn hub_active_issues_path(git_dir : String) -> String {
  git_dir + "/hub/active-issues"
}

///|
fn parse_active_issues(content : String) -> Array[String] {
  let result : Array[String] = []
  for line_view in content.split("\n") {
    let line = line_view.to_string().trim(chars=" \t\r")
    if line.length() > 0 {
      result.push(line)
    }
  }
  result
}

///|
fn serialize_active_issues(entries : Array[String]) -> String {
  let sb = StringBuilder::new()
  for entry in entries {
    sb.write_string(entry)
    sb.write_char('\n')
  }
  sb.to_string()
}

///|
fn add_active_issue(entries : Array[String], ref : String) -> Array[String] {
  if entries.contains(ref) {
    return entries
  }
  entries.push(ref)
  entries
}

///|
fn remove_active_issue(entries : Array[String], ref : String) -> Array[String] {
  entries.filter(fn(e) { e != ref })
}

///|
fn load_active_issues(git_dir : String) -> Array[String] {
  let fs = OsFs::new()
  let path = hub_active_issues_path(git_dir)
  let content = @utf8.decode_lossy(
    (fs.read_file(path) catch { _ => Bytes::default() })[:],
  ).to_string()
  parse_active_issues(content)
}

///|
fn save_active_issues(git_dir : String, entries : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let path = hub_active_issues_path(git_dir)
  let dir = os_parent_path(path)
  fs.mkdir_p(dir)
  fs.write_string(path, serialize_active_issues(entries))
}
```

- [ ] **Step 4: Run tests**

Run: `moon test --package bit/cmd/bit --filter "active_issues" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Implement CLI handlers**

`src/cmd/bit/hub_active.mbt` に追加:

```moonbit
///|
async fn handle_hub_issue_start(args : Array[String]) -> Unit raise Error {
  if args.length() < 1 {
    eprint_line("Usage: bit issue start <ref>")
    @sys.exit(1)
  }
  let ref = args[0]
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let entries = load_active_issues(git_dir)
  let updated = add_active_issue(entries, ref)
  save_active_issues(git_dir, updated)
  print_line("Started: \{ref}")
}

///|
async fn handle_hub_issue_stop(args : Array[String]) -> Unit raise Error {
  if args.length() < 1 {
    eprint_line("Usage: bit issue stop <ref>")
    @sys.exit(1)
  }
  let ref = args[0]
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let entries = load_active_issues(git_dir)
  let updated = remove_active_issue(entries, ref)
  save_active_issues(git_dir, updated)
  print_line("Stopped: \{ref}")
}

///|
async fn handle_hub_issue_active(_args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = resolve_hub_git_dir(root)
  let entries = load_active_issues(git_dir)
  if entries.length() == 0 {
    print_line("No active issues")
    return ()
  }
  let home = @sys.get_env_var("HOME").unwrap_or("/")
  let aliases = load_aliases(git_dir)
  for entry in entries {
    let (repo_ref, issue_id) = parse_cross_repo_ref(entry)
    if repo_ref.length() == 0 {
      // Local issue
      let (objects, refs, _clock) = make_hub_stores(git_dir)
      let hub = load_hub_store(objects, refs)
      let issue = hub.get_issue(objects, issue_id)
      match issue {
        Some(i) => print_line("#\{issue_id}\t\{i.state()}\t\{i.title()}")
        None => print_line("#\{issue_id}\t(not found)")
      }
    } else {
      // Cross-repo issue
      let remote_path = resolve_repo_ref_to_path(repo_ref, home, aliases~) catch {
        _ => {
          print_line("\{entry}\t(repo not found)")
          continue
        }
      }
      let remote_git_dir = resolve_hub_git_dir(remote_path)
      let (objects, refs, _clock) = make_hub_stores(remote_git_dir)
      let hub = load_hub_store(objects, refs) catch {
        _ => {
          print_line("\{entry}\t(hub not initialized)")
          continue
        }
      }
      let issue = hub.get_issue(objects, issue_id)
      match issue {
        Some(i) => print_line("\{entry}\t\{i.state()}\t\{i.title()}")
        None => print_line("\{entry}\t(not found)")
      }
    }
  }
}
```

- [ ] **Step 6: Add routing in hub_issue.mbt**

`src/cmd/bit/hub_issue.mbt` と `src/cmd/git-bit/hub_issue.mbt` の `handle_hub_issue` match に追加:

```moonbit
    "start" => handle_hub_issue_start(rest)
    "stop" => handle_hub_issue_stop(rest)
    "active" => handle_hub_issue_active(rest)
```

usage 出力にも追加:

```
  println("  start <ref>                           (add to working set)")
  println("  stop <ref>                            (remove from working set)")
  println("  active                                (list active issues)")
```

- [ ] **Step 7: Run build check**

Run: `moon check 2>&1 | tail -20`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add src/cmd/bit/hub_active.mbt src/cmd/bit/hub_active_wbtest.mbt src/cmd/bit/hub_issue.mbt src/cmd/git-bit/hub_issue.mbt
git commit -m "feat(hub): add working set commands (start/stop/active)"
```

---

### Task 7: bit issue create --repo のクロスリポ対応

**Files:**
- Modify: `src/cmd/bit/hub_issue.mbt` (handle_hub_issue_create)
- Modify: `src/cmd/git-bit/hub_issue.mbt` (同上)

- [ ] **Step 1: Add --repo flag to create handler**

既存の `handle_hub_issue_create` のフラグパース部分に `--repo` を追加:

```moonbit
  let mut repo_ref : String? = None
  // ... in arg parsing loop ...
  "--repo" => {
    i += 1
    if i < args.length() { repo_ref = Some(args[i]) }
  }
```

git_dir の解決を分岐:

```moonbit
  let git_dir = match repo_ref {
    Some(ref) => {
      let home = @sys.get_env_var("HOME").unwrap_or("/")
      let local_git_dir = resolve_hub_git_dir(root)
      let aliases = load_aliases(local_git_dir)
      let remote_path = resolve_repo_ref_to_path(ref, home, aliases~)
      resolve_hub_git_dir(remote_path)
    }
    None => resolve_hub_git_dir(root)
  }
```

- [ ] **Step 2: Run build check**

Run: `moon check 2>&1 | tail -20`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add src/cmd/bit/hub_issue.mbt src/cmd/git-bit/hub_issue.mbt
git commit -m "feat(hub): add --repo flag to 'bit issue create' for cross-repo creation"
```

---

### Task 8: bit-issue skill ドキュメント更新

**Files:**
- Modify: `.claude/skills/bit-issue/SKILL.md`

- [ ] **Step 1: Update skill documentation**

新しいコマンドのドキュメントを追加:

- `bit issue remote add|list|remove` — エイリアス管理
- `bit issue link <id> <owner/repo#id>` — クロスリポリンク
- `bit issue start|stop|active` — ワーキングセット
- `bit issue create --repo <ref>` — リモートリポ作成
- `bit issue get <owner/repo#id>` — リモートリポ読み取り

リポジトリ解決の説明（エイリアス → ghq パス → エラー）を記載。

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/bit-issue/SKILL.md
git commit -m "docs: update bit-issue skill with cross-repo reference commands"
```
