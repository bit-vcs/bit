# Git LFS Read-Only Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable bit to clone/checkout LFS repositories by natively resolving pointer files to real content via the LFS batch API.

**Architecture:** Walk target tree before checkout to collect LFS pointers, batch-download objects to `.git/lfs/objects/`, then replace pointer blobs with cached content during worktree write. No `git-lfs` binary dependency.

**Tech Stack:** MoonBit, `@http` (async HTTP), `@json` (JSON parse/serialize), existing `ObjectDb` and `resolve_eol_attrs`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `src/lib/lfs.mbt` | Create | LFS pointer struct, parser, URL resolution |
| `src/lib/lfs_wbtest.mbt` | Create | Unit tests for pointer parser and URL resolution |
| `src/lib/native/lfs_client.mbt` | Create | Batch API client, object download, cache read |
| `src/lib/native/lfs_client_wbtest.mbt` | Create | Unit tests for JSON serialization/parsing |
| `src/lib/native/lfs_prefetch.mbt` | Create | Tree walk + prefetch orchestration |
| `src/lib/tree_ops.mbt` | Modify | LFS cache lookup in checkout blob loop |
| `src/lib/checkout.mbt` | Modify | Insert prefetch call before worktree write |
| `src/lib/gitattributes.mbt` | Modify | Remove `filter=lfs` block |
| `src/cmd/bit/fallback.mbt` | Modify | LFS repos no longer rejected at startup |
| `src/lib/moon.pkg` | Modify | Add `lfs.mbt`, `lfs_wbtest.mbt` |
| `src/lib/native/moon.pkg` | Modify | Add `lfs_client.mbt`, `lfs_client_wbtest.mbt`, `lfs_prefetch.mbt` to native targets |

---

### Task 1: LFS Pointer Parser

**Files:**
- Create: `src/lib/lfs.mbt`
- Create: `src/lib/lfs_wbtest.mbt`

- [ ] **Step 1: Write failing tests for pointer parser**

Create `src/lib/lfs_wbtest.mbt`:

```moonbit
///|
test "is_lfs_pointer: valid pointer" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 12345\n"
  assert_eq(is_lfs_pointer(content), true)
}

///|
test "is_lfs_pointer: empty content" {
  assert_eq(is_lfs_pointer(b""), false)
}

///|
test "is_lfs_pointer: regular file content" {
  assert_eq(is_lfs_pointer(b"hello world\n"), false)
}

///|
test "is_lfs_pointer: wrong version" {
  let content = b"version https://example.com/v1\noid sha256:abcd\nsize 100\n"
  assert_eq(is_lfs_pointer(content), false)
}

///|
test "parse_lfs_pointer: valid pointer" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 12345\n"
  let ptr = parse_lfs_pointer(content)
  assert_eq(ptr.is_empty(), false)
  let p = ptr.unwrap()
  assert_eq(p.oid, "4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393")
  assert_eq(p.size, 12345L)
}

///|
test "parse_lfs_pointer: missing oid" {
  let content = b"version https://git-lfs.github.com/spec/v1\nsize 100\n"
  assert_eq(parse_lfs_pointer(content).is_empty(), true)
}

///|
test "parse_lfs_pointer: missing size" {
  let content = b"version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\n"
  assert_eq(parse_lfs_pointer(content).is_empty(), true)
}

///|
test "lfs_object_path: correct sharding" {
  let path = lfs_object_path("/repo/.git", "4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393")
  assert_eq(path, "/repo/.git/lfs/objects/4d/7a/4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test --target native -p mizchi/bit/lib -f lfs_wbtest.mbt 2>&1 | head -20`
Expected: FAIL — functions not defined

- [ ] **Step 3: Implement LFS pointer parser**

Create `src/lib/lfs.mbt`:

```moonbit
///| LFS pointer file parsing and utilities

///|
pub struct LfsPointer {
  oid : String
  size : Int64
} derive(Show, Eq)

///|
let lfs_version_prefix : String = "version https://git-lfs.github.com/spec/v1\n"

///|
let lfs_oid_prefix : String = "oid sha256:"

///|
let lfs_size_prefix : String = "size "

///|
/// Max size of a valid LFS pointer file (bytes).
let lfs_max_pointer_size : Int = 1024

///|
/// Check if content looks like an LFS pointer file.
pub fn is_lfs_pointer(content : Bytes) -> Bool {
  if content.length() == 0 || content.length() > lfs_max_pointer_size {
    return false
  }
  let text = @utf8.decode_lossy(content[:])
  text.has_prefix(lfs_version_prefix)
}

///|
/// Parse an LFS pointer file, returning None if invalid.
pub fn parse_lfs_pointer(content : Bytes) -> LfsPointer? {
  if content.length() == 0 || content.length() > lfs_max_pointer_size {
    return None
  }
  let text = @utf8.decode_lossy(content[:])
  if !text.has_prefix(lfs_version_prefix) {
    return None
  }
  let mut oid : String? = None
  let mut size : Int64? = None
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix(lfs_oid_prefix) {
      oid = Some(
        String::unsafe_substring(line, start=lfs_oid_prefix.length(), end=line.length()),
      )
    } else if line.has_prefix(lfs_size_prefix) {
      let num_str = String::unsafe_substring(
        line,
        start=lfs_size_prefix.length(),
        end=line.length(),
      )
      match @strconv.parse_int64(num_str.trim()) {
        Ok(n) => size = Some(n)
        Err(_) => ()
      }
    }
  }
  match (oid, size) {
    (Some(o), Some(s)) =>
      if o.length() == 64 {
        Some({ oid: o, size: s })
      } else {
        None
      }
    _ => None
  }
}

///|
/// Compute the local cache path for an LFS object.
/// Layout: {git_dir}/lfs/objects/{oid[0:2]}/{oid[2:4]}/{oid}
pub fn lfs_object_path(git_dir : String, oid : String) -> String {
  let d1 = String::unsafe_substring(oid, start=0, end=2)
  let d2 = String::unsafe_substring(oid, start=2, end=4)
  "\{git_dir}/lfs/objects/\{d1}/\{d2}/\{oid}"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test --target native -p mizchi/bit/lib -f lfs_wbtest.mbt 2>&1`
Expected: All 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/lib/lfs.mbt src/lib/lfs_wbtest.mbt
git commit -m "feat(lfs): add LFS pointer parser and object path utility"
```

---

### Task 2: LFS URL Resolution

**Files:**
- Modify: `src/lib/lfs.mbt`
- Modify: `src/lib/lfs_wbtest.mbt`

- [ ] **Step 1: Write failing tests for URL resolution**

Append to `src/lib/lfs_wbtest.mbt`:

```moonbit
///|
test "resolve_lfs_url: from lfs.url config" {
  let url = resolve_lfs_url_from_config(
    lfs_url="https://custom-lfs.example.com",
    remote_lfs_url="",
    remote_url="https://github.com/user/repo.git",
  )
  assert_eq(url, "https://custom-lfs.example.com")
}

///|
test "resolve_lfs_url: from remote lfsurl" {
  let url = resolve_lfs_url_from_config(
    lfs_url="",
    remote_lfs_url="https://remote-lfs.example.com",
    remote_url="https://github.com/user/repo.git",
  )
  assert_eq(url, "https://remote-lfs.example.com")
}

///|
test "resolve_lfs_url: derived from remote url with .git suffix" {
  let url = resolve_lfs_url_from_config(
    lfs_url="",
    remote_lfs_url="",
    remote_url="https://github.com/user/repo.git",
  )
  assert_eq(url, "https://github.com/user/repo.git/info/lfs")
}

///|
test "resolve_lfs_url: derived from remote url without .git suffix" {
  let url = resolve_lfs_url_from_config(
    lfs_url="",
    remote_lfs_url="",
    remote_url="https://github.com/user/repo",
  )
  assert_eq(url, "https://github.com/user/repo.git/info/lfs")
}

///|
test "resolve_lfs_url: lfs.url takes priority" {
  let url = resolve_lfs_url_from_config(
    lfs_url="https://priority.example.com",
    remote_lfs_url="https://remote-lfs.example.com",
    remote_url="https://github.com/user/repo.git",
  )
  assert_eq(url, "https://priority.example.com")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test --target native -p mizchi/bit/lib -f lfs_wbtest.mbt 2>&1 | head -10`
Expected: FAIL — `resolve_lfs_url_from_config` not defined

- [ ] **Step 3: Implement URL resolution**

Append to `src/lib/lfs.mbt`:

```moonbit
///|
/// Resolve LFS server URL from pre-read config values.
/// Priority: lfs.url > remote.<name>.lfsurl > derive from remote URL.
/// This is a pure function for testability; the caller reads config.
pub fn resolve_lfs_url_from_config(
  lfs_url~ : String = "",
  remote_lfs_url~ : String = "",
  remote_url~ : String = "",
) -> String {
  if lfs_url.length() > 0 {
    return lfs_url
  }
  if remote_lfs_url.length() > 0 {
    return remote_lfs_url
  }
  // Derive from remote URL: ensure .git suffix, append /info/lfs
  let base = if remote_url.has_suffix(".git") {
    remote_url
  } else {
    remote_url + ".git"
  }
  base + "/info/lfs"
}

///|
/// Read LFS URL from git config and remote config.
/// Returns the resolved URL or empty string if no remote configured.
pub fn resolve_lfs_url(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  remote_name : String,
) -> String {
  let config_path = git_dir + "/config"
  let lfs_url = match read_config_value(rfs, config_path, "lfs", "url") {
    Some(v) => v
    None => ""
  }
  let remote_section = "remote \"\{remote_name}\""
  let remote_lfs_url = match read_config_value(rfs, config_path, remote_section, "lfsurl") {
    Some(v) => v
    None => ""
  }
  let remote_url = match get_remote_url(rfs, git_dir, remote_name) {
    Some(v) => v
    None => ""
  }
  resolve_lfs_url_from_config(lfs_url~, remote_lfs_url~, remote_url~)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test --target native -p mizchi/bit/lib -f lfs_wbtest.mbt 2>&1`
Expected: All 13 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/lib/lfs.mbt src/lib/lfs_wbtest.mbt
git commit -m "feat(lfs): add LFS URL resolution from config and remote URL"
```

---

### Task 3: LFS Batch API JSON Serialization

**Files:**
- Create: `src/lib/native/lfs_client.mbt`
- Create: `src/lib/native/lfs_client_wbtest.mbt`
- Modify: `src/lib/native/moon.pkg`

- [ ] **Step 1: Add new files to moon.pkg native targets**

Edit `src/lib/native/moon.pkg` — add to the `targets` object:

```
    "lfs_client.mbt": [ "native" ],
    "lfs_client_wbtest.mbt": [ "native" ],
    "lfs_prefetch.mbt": [ "native" ],
```

- [ ] **Step 2: Write failing tests for batch request/response JSON**

Create `src/lib/native/lfs_client_wbtest.mbt`:

```moonbit
///|
test "lfs_build_batch_request_json: single object" {
  let objects : Array[@bitlib.LfsPointer] = [
    { oid: "abc123def456abc123def456abc123def456abc123def456abc123def456abcd", size: 9876L },
  ]
  let json_str = lfs_build_batch_request_json(objects)
  let parsed = @json.parse(json_str)
  match parsed {
    Object(obj) => {
      assert_eq(obj["operation"], String("download"))
      match obj["objects"] {
        Some(Array(arr)) => {
          assert_eq(arr.length(), 1)
          match arr[0] {
            Object(o) => {
              assert_eq(
                o["oid"],
                Some(String("abc123def456abc123def456abc123def456abc123def456abc123def456abcd")),
              )
              assert_eq(o["size"], Some(Number(9876.0)))
            }
            _ => fail("expected object")
          }
        }
        _ => fail("expected objects array")
      }
    }
    _ => fail("expected object")
  }
}

///|
test "lfs_parse_batch_response: success with download action" {
  let json_str =
    #|{
    #|  "transfer": "basic",
    #|  "objects": [
    #|    {
    #|      "oid": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
    #|      "size": 5000,
    #|      "actions": {
    #|        "download": {
    #|          "href": "https://example.com/download/obj1",
    #|          "header": {
    #|            "Authorization": "Bearer token123"
    #|          }
    #|        }
    #|      }
    #|    }
    #|  ]
    #|}
  let (actions, errors) = lfs_parse_batch_response(json_str)
  assert_eq(actions.length(), 1)
  assert_eq(errors.length(), 0)
  assert_eq(actions[0].oid, "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
  assert_eq(actions[0].size, 5000L)
  assert_eq(actions[0].href, "https://example.com/download/obj1")
  assert_eq(actions[0].headers["Authorization"], Some("Bearer token123"))
}

///|
test "lfs_parse_batch_response: object with error" {
  let json_str =
    #|{
    #|  "objects": [
    #|    {
    #|      "oid": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
    #|      "size": 5000,
    #|      "error": {
    #|        "code": 404,
    #|        "message": "Object not found"
    #|      }
    #|    }
    #|  ]
    #|}
  let (actions, errors) = lfs_parse_batch_response(json_str)
  assert_eq(actions.length(), 0)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].oid, "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
  assert_eq(errors[0].code, 404)
  assert_eq(errors[0].message, "Object not found")
}

///|
test "lfs_parse_batch_response: mixed success and error" {
  let json_str =
    #|{
    #|  "objects": [
    #|    {
    #|      "oid": "aaaa1234567890abcdef1234567890abcdef1234567890abcdef1234567890aa",
    #|      "size": 100,
    #|      "actions": {
    #|        "download": {
    #|          "href": "https://example.com/obj1"
    #|        }
    #|      }
    #|    },
    #|    {
    #|      "oid": "bbbb1234567890abcdef1234567890abcdef1234567890abcdef1234567890bb",
    #|      "size": 200,
    #|      "error": {
    #|        "code": 410,
    #|        "message": "Gone"
    #|      }
    #|    }
    #|  ]
    #|}
  let (actions, errors) = lfs_parse_batch_response(json_str)
  assert_eq(actions.length(), 1)
  assert_eq(errors.length(), 1)
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `moon test --target native -p mizchi/bit/lib/native -f lfs_client_wbtest.mbt 2>&1 | head -10`
Expected: FAIL — types and functions not defined

- [ ] **Step 4: Implement batch API JSON types and serialization**

Create `src/lib/native/lfs_client.mbt`:

```moonbit
///| LFS Batch API client, object download, and cache management

///|
pub struct LfsDownloadAction {
  oid : String
  size : Int64
  href : String
  headers : Map[String, String]
} derive(Show, Eq)

///|
pub struct LfsDownloadError {
  oid : String
  code : Int
  message : String
} derive(Show, Eq)

///|
/// Build JSON request body for LFS batch API (download).
pub fn lfs_build_batch_request_json(
  objects : Array[@bitlib.LfsPointer],
) -> String {
  let obj_arr : Array[Json] = []
  for ptr in objects {
    let m : Map[String, Json] = {}
    m["oid"] = Json::string(ptr.oid)
    m["size"] = Json::number(ptr.size.to_double())
    obj_arr.push(Json::object(m))
  }
  let transfers : Array[Json] = [Json::string("basic")]
  let root : Map[String, Json] = {}
  root["operation"] = Json::string("download")
  root["transfers"] = Json::array(transfers)
  root["objects"] = Json::array(obj_arr)
  Json::object(root).stringify()
}

///|
/// Parse LFS batch API response JSON.
/// Returns (successful download actions, errored objects).
pub fn lfs_parse_batch_response(
  body : String,
) -> (Array[LfsDownloadAction], Array[LfsDownloadError]) {
  let actions : Array[LfsDownloadAction] = []
  let errors : Array[LfsDownloadError] = []
  let parsed = @json.parse(body) catch { _ => return (actions, errors) }
  let root = match parsed {
    Object(obj) => obj
    _ => return (actions, errors)
  }
  let objects = match root.get("objects") {
    Some(Array(arr)) => arr
    _ => return (actions, errors)
  }
  for item in objects {
    match item {
      Object(obj) => {
        let oid = match obj.get("oid") {
          Some(String(s)) => s
          _ => continue
        }
        let size = match obj.get("size") {
          Some(Number(n)) => n.to_int64()
          _ => 0L
        }
        // Check for error first
        match obj.get("error") {
          Some(Object(err_obj)) => {
            let code = match err_obj.get("code") {
              Some(Number(n)) => n.to_int()
              _ => 0
            }
            let message = match err_obj.get("message") {
              Some(String(s)) => s
              _ => ""
            }
            errors.push({ oid, code, message })
            continue
          }
          _ => ()
        }
        // Parse download action
        match obj.get("actions") {
          Some(Object(acts)) =>
            match acts.get("download") {
              Some(Object(dl)) => {
                let href = match dl.get("href") {
                  Some(String(s)) => s
                  _ => continue
                }
                let headers : Map[String, String] = {}
                match dl.get("header") {
                  Some(Object(hdr)) =>
                    for entry in hdr.to_array() {
                      let (k, v) = entry
                      match v {
                        String(s) => headers[k] = s
                        _ => ()
                      }
                    }
                  _ => ()
                }
                actions.push({ oid, size, href, headers })
              }
              _ => ()
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  (actions, errors)
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `moon test --target native -p mizchi/bit/lib/native -f lfs_client_wbtest.mbt 2>&1`
Expected: All 4 tests PASS

- [ ] **Step 6: Commit**

```bash
git add src/lib/native/lfs_client.mbt src/lib/native/lfs_client_wbtest.mbt src/lib/native/moon.pkg
git commit -m "feat(lfs): add LFS batch API JSON serialization and parsing"
```

---

### Task 4: LFS Object Download and Cache

**Files:**
- Modify: `src/lib/native/lfs_client.mbt`

- [ ] **Step 1: Write failing test for cache read**

Append to `src/lib/native/lfs_client_wbtest.mbt`:

```moonbit
///|
test "lfs_get_cached_object: returns None when not cached" {
  let fs = @osfs.OsFs::new()
  let result = lfs_get_cached_object(fs, "/tmp/nonexistent-git-dir", "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
  assert_eq(result, None)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test --target native -p mizchi/bit/lib/native -f lfs_client_wbtest.mbt -u "lfs_get_cached_object" 2>&1`
Expected: FAIL — function not defined

- [ ] **Step 3: Implement download and cache functions**

Append to `src/lib/native/lfs_client.mbt`:

```moonbit
///|
/// Check if an LFS object is already cached locally.
pub fn lfs_get_cached_object(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  oid : String,
) -> Bytes? {
  let path = @bitlib.lfs_object_path(git_dir, oid)
  if fs.is_file(path) {
    match fs.read_file(path) {
      data => Some(data)
    } catch {
      _ => None
    }
  } else {
    None
  }
}

///|
/// Send LFS batch download request and return download actions.
pub async fn lfs_batch_request(
  lfs_url : String,
  objects : Array[@bitlib.LfsPointer],
) -> (Array[LfsDownloadAction], Array[LfsDownloadError]) raise @bit.GitError {
  if objects.length() == 0 {
    return ([], [])
  }
  let batch_url = lfs_url + "/objects/batch"
  let body_str = lfs_build_batch_request_json(objects)
  let body = @utf8.encode(body_str)
  let headers : Map[String, String] = {}
  headers["Content-Type"] = "application/vnd.git-lfs+json"
  headers["Accept"] = "application/vnd.git-lfs+json"
  let (response, data) = native_http_post(batch_url, body, headers)
  if response.code >= 400 {
    let text = @utf8.decode_lossy(data[:])
    raise @bit.GitError::IoError(
      "LFS batch API failed (\{response.code}): \{text}",
    )
  }
  let text = @utf8.decode_lossy(data[:])
  lfs_parse_batch_response(text)
}

///|
/// Download a single LFS object to the local cache.
async fn lfs_download_single_object(
  fs : &@bit.FileSystem,
  git_dir : String,
  action : LfsDownloadAction,
) -> LfsDownloadError? raise @bit.GitError {
  let dest = @bitlib.lfs_object_path(git_dir, action.oid)
  // Skip if already cached
  let rfs : &@bit.RepoFileSystem = fs
  if rfs.is_file(dest) {
    return None
  }
  let dir = @bitlib.parent_dir(dest)
  fs.mkdir_p(dir)
  let headers : Map[String, String] = {}
  for entry in action.headers.to_array() {
    let (k, v) = entry
    headers[k] = v
  }
  let (response, data) = native_http_get(action.href, headers) catch {
    err =>
      return Some({
        oid: action.oid,
        code: 0,
        message: "Download failed: \{err}",
      })
  }
  if response.code >= 400 {
    return Some({
      oid: action.oid,
      code: response.code,
      message: "HTTP \{response.code}",
    })
  }
  // Atomic write: write to temp, then rename
  let tmp_path = dest + ".tmp"
  fs.write_file(tmp_path, data)
  fs.rename(tmp_path, dest)
  None
}

///|
/// Download LFS objects with up to 8 concurrent downloads.
/// Returns errors for objects that failed to download.
pub async fn lfs_download_objects(
  fs : &@bit.FileSystem,
  git_dir : String,
  actions : Array[LfsDownloadAction],
) -> Array[LfsDownloadError] raise @bit.GitError {
  let errors : Array[LfsDownloadError] = []
  if actions.length() == 0 {
    return errors
  }
  // Download in batches of 8
  let batch_size = 8
  let mut i = 0
  while i < actions.length() {
    let end = if i + batch_size < actions.length() {
      i + batch_size
    } else {
      actions.length()
    }
    let futures : Array[async () -> LfsDownloadError? raise @bit.GitError] = []
    let mut j = i
    while j < end {
      let action = actions[j]
      futures.push(async fn() -> LfsDownloadError? raise @bit.GitError {
        lfs_download_single_object(fs, git_dir, action)
      })
      j += 1
    }
    for future in futures {
      match future() {
        Some(err) => errors.push(err)
        None => ()
      }
    }
    i = end
  }
  errors
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test --target native -p mizchi/bit/lib/native -f lfs_client_wbtest.mbt 2>&1`
Expected: All 5 tests PASS

- [ ] **Step 5: Run build check**

Run: `just release-check 2>&1 | tail -10`
Expected: No errors (warnings OK)

- [ ] **Step 6: Commit**

```bash
git add src/lib/native/lfs_client.mbt src/lib/native/lfs_client_wbtest.mbt
git commit -m "feat(lfs): add LFS object download with cache and concurrent fetching"
```

---

### Task 5: LFS Prefetch (Tree Walk + Batch Download)

**Files:**
- Create: `src/lib/native/lfs_prefetch.mbt`

- [ ] **Step 1: Implement prefetch orchestration**

Create `src/lib/native/lfs_prefetch.mbt`:

```moonbit
///| LFS prefetch: walk tree, collect pointers, batch download

///|
/// Walk a commit's tree, find all LFS pointer blobs, download any not already cached.
/// Call this before checkout to populate .git/lfs/objects/.
pub async fn lfs_prefetch_for_checkout(
  db : @bitlib.ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
  commit_id : @bit.ObjectId,
  remote_name : String,
) -> Unit raise @bit.GitError {
  // 1. Collect all tree files
  let files = @bitlib.collect_tree_files_from_commit(db, rfs, commit_id)
  // 2. Find LFS pointers that need downloading
  let needed : Array[@bitlib.LfsPointer] = []
  for item in files.to_array() {
    let (path, info) = item
    if @bitlib.is_gitlink_mode_int(info.mode) {
      continue
    }
    // Check if this path has filter=lfs in .gitattributes
    let attrs = @bitlib.resolve_eol_attrs(rfs, root, path)
    if attrs.filter != Some("lfs") {
      continue
    }
    // Read blob and check if it's a pointer
    let obj = db.get(rfs, info.id)
    match obj {
      Some(o) =>
        if o.obj_type == @bit.ObjectType::Blob && @bitlib.is_lfs_pointer(o.data) {
          match @bitlib.parse_lfs_pointer(o.data) {
            Some(ptr) => {
              // Skip if already cached
              let cached_path = @bitlib.lfs_object_path(git_dir, ptr.oid)
              if !rfs.is_file(cached_path) {
                needed.push(ptr)
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }
  if needed.length() == 0 {
    return
  }
  // 3. Resolve LFS URL
  let lfs_url = @bitlib.resolve_lfs_url(rfs, git_dir, remote_name)
  if lfs_url.length() == 0 {
    raise @bit.GitError::IoError(
      "Cannot resolve LFS server URL. Set lfs.url in git config or configure a remote.",
    )
  }
  // 4. Batch download
  let (actions, batch_errors) = lfs_batch_request(lfs_url, needed)
  // Report batch errors as warnings (don't abort entire checkout)
  for err in batch_errors {
    @bitio.eprint_line("warning: LFS object \{err.oid}: \{err.message} (code \{err.code})")
  }
  // 5. Download objects
  let dl_errors = lfs_download_objects(fs, git_dir, actions)
  for err in dl_errors {
    @bitio.eprint_line("warning: LFS download failed for \{err.oid}: \{err.message}")
  }
}
```

- [ ] **Step 2: Run build check**

Run: `moon check --target native 2>&1 | tail -10`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add src/lib/native/lfs_prefetch.mbt
git commit -m "feat(lfs): add LFS prefetch tree walk and batch download orchestration"
```

---

### Task 6: Remove LFS Block and Integrate with Checkout

**Files:**
- Modify: `src/lib/gitattributes.mbt:350-351` — remove LFS rejection
- Modify: `src/lib/tree_ops.mbt:525-534` — LFS cache lookup in `write_worktree_from_files`
- Modify: `src/lib/tree_ops.mbt:617-627` — LFS cache lookup in `write_worktree_and_build_index`
- Modify: `src/lib/checkout.mbt:150-180` — insert prefetch before worktree write

- [ ] **Step 1: Remove LFS block from gitattributes**

In `src/lib/gitattributes.mbt`, replace the LFS rejection (lines 350-351):

```moonbit
// Old:
      if token == "filter=lfs" || token.has_prefix("filter=lfs ") {
        return Some("fatal: filter 'lfs' is not supported in standalone mode")
      }

// New:
      // filter=lfs is handled natively by bit (LFS pointer resolution)
```

- [ ] **Step 2: Add LFS cache lookup to `write_worktree_from_files`**

In `src/lib/tree_ops.mbt`, replace lines 532-534 in the `write_worktree_from_files` function:

```moonbit
// Old:
        let attrs = resolve_eol_attrs(rfs, root, path)
        let output = smudge_for_checkout(o.data, attrs, autocrlf, core_eol~)
        fs.write_file(full_path, output)

// New:
        let attrs = resolve_eol_attrs(rfs, root, path)
        let data = if attrs.filter == Some("lfs") && is_lfs_pointer(o.data) {
          match parse_lfs_pointer(o.data) {
            Some(ptr) =>
              match lfs_get_cached_content(rfs, git_dir, ptr.oid) {
                Some(cached) => cached
                None => o.data // Fall back to pointer content if not cached
              }
            None => o.data
          }
        } else {
          o.data
        }
        let output = smudge_for_checkout(data, attrs, autocrlf, core_eol~)
        fs.write_file(full_path, output)
```

- [ ] **Step 3: Add LFS cache lookup to `write_worktree_and_build_index`**

In `src/lib/tree_ops.mbt`, replace lines 625-627 in the `write_worktree_and_build_index` function:

```moonbit
// Old:
          let attrs = resolve_eol_attrs(rfs, root, path)
          let output = smudge_for_checkout(o.data, attrs, autocrlf, core_eol~)
          fs.write_file(full_path, output)

// New:
          let attrs = resolve_eol_attrs(rfs, root, path)
          let data = if attrs.filter == Some("lfs") && is_lfs_pointer(o.data) {
            match parse_lfs_pointer(o.data) {
              Some(ptr) =>
                match lfs_get_cached_content(rfs, git_dir, ptr.oid) {
                  Some(cached) => cached
                  None => o.data
                }
              None => o.data
            }
          } else {
            o.data
          }
          let output = smudge_for_checkout(data, attrs, autocrlf, core_eol~)
          fs.write_file(full_path, output)
```

- [ ] **Step 4: Add `lfs_get_cached_content` helper to `src/lib/lfs.mbt`**

Append to `src/lib/lfs.mbt`:

```moonbit
///|
/// Read an LFS object from the local cache. Returns None if not cached.
/// This is a non-async version that reads directly from the filesystem.
pub fn lfs_get_cached_content(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  oid : String,
) -> Bytes? {
  let path = lfs_object_path(git_dir, oid)
  if rfs.is_file(path) {
    match rfs.read_file(path) {
      data => Some(data)
    } catch {
      _ => None
    }
  } else {
    None
  }
}
```

- [ ] **Step 5: Add `restore_paths` LFS support in `src/lib/checkout.mbt`**

In `src/lib/checkout.mbt`, replace lines 47-49 in `restore_paths`:

```moonbit
// Old:
            let attrs = resolve_eol_attrs(rfs, root, safe_path)
            let output = smudge_for_checkout(o.data, attrs, autocrlf, core_eol~)
            fs.write_file(abs_path, output)

// New:
            let attrs = resolve_eol_attrs(rfs, root, safe_path)
            let data = if attrs.filter == Some("lfs") && is_lfs_pointer(o.data) {
              match parse_lfs_pointer(o.data) {
                Some(ptr) =>
                  match lfs_get_cached_content(rfs, actual_git_dir, ptr.oid) {
                    Some(cached) => cached
                    None => o.data
                  }
                None => o.data
              }
            } else {
              o.data
            }
            let output = smudge_for_checkout(data, attrs, autocrlf, core_eol~)
            fs.write_file(abs_path, output)
```

- [ ] **Step 6: Run build check**

Run: `moon check --target native 2>&1 | tail -10`
Expected: No errors

- [ ] **Step 7: Run existing tests**

Run: `moon test --target native -p mizchi/bit/lib 2>&1 | tail -10`
Expected: All existing tests PASS (LFS block removal should not affect other tests)

- [ ] **Step 8: Commit**

```bash
git add src/lib/gitattributes.mbt src/lib/tree_ops.mbt src/lib/checkout.mbt src/lib/lfs.mbt
git commit -m "feat(lfs): integrate LFS cache lookup into checkout path and remove LFS block"
```

---

### Task 7: Insert Prefetch into Checkout Flow

**Files:**
- Modify: `src/lib/checkout.mbt:150-180` — add prefetch call
- Modify: `src/lib/native/lfs_prefetch.mbt` — adjust if needed

Note: The prefetch function is async and native-only, but `checkout()` in `src/lib/checkout.mbt` is a non-async synchronous function. The prefetch needs to be called from the command-level (native) code that invokes checkout, not from the library `checkout()` function itself.

- [ ] **Step 1: Find the command-level checkout caller**

The prefetch must be called from `src/cmd/bit/checkout.mbt` (native command handler) or the native worktree_modes that call checkout. Since `lfs_prefetch_for_checkout` is async and in `src/lib/native/`, it should be called from the cmd layer before calling `@bitlib.checkout()`.

Read `src/cmd/bit/checkout.mbt` to find where `@bitlib.checkout()` is called, and insert a prefetch call before it.

- [ ] **Step 2: Add prefetch to command-level checkout**

In the checkout command handler (e.g. `src/cmd/bit/checkout.mbt`), before the call to `@bitlib.checkout()`, add:

```moonbit
// Before checkout, prefetch LFS objects if .gitattributes has filter=lfs
if @bitlib.has_any_filter_attributes(rfs, root) {
  let git_dir = join_path(root, ".git")
  let actual_git_dir = if rfs.is_file(git_dir) {
    @bitlib.resolve_gitdir(rfs, git_dir)
  } else {
    git_dir
  }
  let object_git_dir = @bitlib.resolve_checkout_common_git_dir(rfs, actual_git_dir)
  let db = @bitlib.ObjectDb::load_lazy(rfs, object_git_dir)
  // Resolve target commit for prefetch
  let target_id = @bitlib.rev_parse(rfs, actual_git_dir, spec)
  match target_id {
    Some(id) =>
      @bitnative.lfs_prefetch_for_checkout(
        db, fs, rfs, root, actual_git_dir, id, "origin",
      )
    None => ()
  }
}
```

The exact integration point depends on what `src/cmd/bit/checkout.mbt` looks like. The implementer should read that file and insert the prefetch at the appropriate point before `@bitlib.checkout()` is called.

Similarly, add prefetch to the clone command handler if it calls checkout after fetching.

- [ ] **Step 3: Run build check**

Run: `moon check --target native 2>&1 | tail -10`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add src/cmd/bit/checkout.mbt
git commit -m "feat(lfs): add LFS prefetch before checkout in command handler"
```

---

### Task 8: Duplicate for git-bit package and final wiring

**Files:**
- The `src/cmd/git-bit/` package duplicates command handlers from `src/cmd/bit/`
- Apply the same checkout.mbt changes to `src/cmd/git-bit/checkout.mbt`

- [ ] **Step 1: Apply same prefetch to git-bit checkout**

Read `src/cmd/git-bit/checkout.mbt` and apply the same prefetch integration as Task 7 Step 2.

- [ ] **Step 2: Run full build check**

Run: `just release-check 2>&1 | tail -20`
Expected: fmt OK, info OK, check OK, test OK

- [ ] **Step 3: Run all LFS tests**

Run: `moon test --target native -p mizchi/bit/lib -f lfs_wbtest.mbt 2>&1 && moon test --target native -p mizchi/bit/lib/native -f lfs_client_wbtest.mbt 2>&1`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add src/cmd/git-bit/checkout.mbt
git commit -m "feat(lfs): add LFS prefetch to git-bit checkout handler"
```

---

### Task 9: Add lfs.mbt to moon.pkg and verify JS/WASM build

**Files:**
- Modify: `src/lib/moon.pkg` — no special target needed (lfs.mbt is pure logic, works on all targets)

- [ ] **Step 1: Verify lfs.mbt compiles on all targets**

`src/lib/lfs.mbt` uses only `@utf8`, `@strconv`, and string operations — all available on JS/WASM. It should compile without target restrictions.

Run: `moon check --target js 2>&1 | tail -10`
Expected: No errors

If there are errors because `lfs.mbt` references types not available on JS, add it to native-only targets in `src/lib/moon.pkg`:

```
    "lfs.mbt": [ "native" ],
    "lfs_wbtest.mbt": [ "native" ],
```

- [ ] **Step 2: Run full release check**

Run: `just release-check 2>&1 | tail -20`
Expected: All checks pass

- [ ] **Step 3: Commit if any moon.pkg changes were needed**

```bash
git add src/lib/moon.pkg
git commit -m "chore: add lfs.mbt to moon.pkg targets if needed"
```

---

## Self-Review Checklist

### Spec coverage:
- [x] LFS Pointer Parser — Task 1
- [x] LFS URL Resolution — Task 2
- [x] LFS Batch API Client — Task 3
- [x] LFS Object Storage/Download — Task 4
- [x] LFS Prefetch — Task 5
- [x] Checkout Integration — Task 6
- [x] LFS Block Removal — Task 6 Step 1
- [x] `restore_paths` LFS support — Task 6 Step 5
- [x] Error handling (batch errors, download errors) — Task 4 & 5
- [x] git-bit package duplication — Task 8

### Placeholder scan: None found.

### Type consistency:
- `LfsPointer` struct used consistently (defined in lfs.mbt, referenced in lfs_client.mbt as `@bitlib.LfsPointer`)
- `LfsDownloadAction` and `LfsDownloadError` defined in lfs_client.mbt, used in lfs_prefetch.mbt
- `lfs_object_path` in lfs.mbt, referenced as `@bitlib.lfs_object_path` in native code
- `lfs_get_cached_content` in lfs.mbt (non-async, uses `rfs`), `lfs_get_cached_object` in lfs_client.mbt (non-async, uses `fs`) — two variants for different callers
