# Git LFS Read-Only Support — Design Spec

## Goal

Enable bit to clone/checkout repositories that use git LFS, resolving LFS pointer files to their actual content. Write operations (push, clean filter) are out of scope — this is read-only (download) support only.

## Approach

- **Native implementation** — no `git-lfs` binary dependency. bit handles LFS directly.
- **Batch prefetch before checkout** — collect all LFS pointers from the target tree, download in bulk via batch API, then checkout reads from local cache.
- **8 concurrent downloads** — fixed parallelism, matching git-lfs default.

## Architecture

```
clone/fetch
  → checkout begins
  → walk target tree, identify LFS pointer blobs
  → POST /objects/batch to LFS server (download URLs)
  → download objects in parallel (8) to .git/lfs/objects/
  → checkout: replace pointer blobs with cached real content
```

## Components

### 1. LFS Pointer Parser

**File:** `src/lib/lfs.mbt`

```
pub struct LfsPointer {
  oid : String    // sha256 hex (64 chars)
  size : Int64    // actual file size in bytes
}

pub fn is_lfs_pointer(content : Bytes) -> Bool
pub fn parse_lfs_pointer(content : Bytes) -> LfsPointer?
```

**Pointer format:**
```
version https://git-lfs.github.com/spec/v1
oid sha256:<64-hex-chars>
size <decimal-bytes>
```

Detection rules:
- Content starts with `version https://git-lfs.github.com/spec/v1\n`
- Total size < 1024 bytes
- Contains exactly `oid sha256:` and `size ` lines

### 2. LFS URL Resolution

**File:** `src/lib/lfs.mbt`

```
pub fn resolve_lfs_url(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  remote_name : String,
) -> String? raise @bit.GitError
```

Priority order:
1. `lfs.url` in git config
2. `remote.<name>.lfsurl` in git config
3. Derive from remote URL: `{remote-url}/info/lfs`
   - Strip trailing `.git` if present before appending

`.lfsconfig` file is out of scope for Phase 1.

### 3. LFS Batch API Client

**File:** `src/lib/native/lfs_client.mbt`

```
pub struct LfsDownloadAction {
  oid : String
  size : Int64
  href : String
  headers : Map[String, String]
}

pub async fn lfs_batch_download(
  lfs_url : String,
  objects : Array[LfsPointer],
) -> Array[LfsDownloadAction] raise @bit.GitError
```

Request:
```json
{
  "operation": "download",
  "transfers": ["basic"],
  "objects": [
    { "oid": "sha256-hex", "size": 12345 }
  ]
}
```

- `POST {lfs_url}/objects/batch`
- `Content-Type: application/vnd.git-lfs+json`
- `Accept: application/vnd.git-lfs+json`
- Auth via existing `apply_auth_header()` (credential helper)

Response parsing: extract `actions.download.href` and `actions.download.header` per object. Objects with `error` field are collected and reported but do not abort the entire batch.

### 4. LFS Object Storage

**File:** `src/lib/native/lfs_client.mbt`

```
pub async fn lfs_download_objects(
  git_dir : String,
  actions : Array[LfsDownloadAction],
) -> Array[LfsDownloadError] raise @bit.GitError

pub fn lfs_get_cached_object(
  fs : &@bit.FileSystem,
  git_dir : String,
  oid : String,
) -> Bytes?

pub fn lfs_object_path(git_dir : String, oid : String) -> String
```

Storage layout:
```
.git/lfs/objects/<oid[0:2]>/<oid[2:4]>/<full-oid>
```

Download:
- 8 concurrent HTTP GETs
- Write to temp file first, rename on success (atomic)
- Skip objects already in cache

### 5. LFS Prefetch

**File:** `src/lib/native/lfs_prefetch.mbt`

```
pub async fn lfs_prefetch_for_checkout(
  db : ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  tree_id : @bit.ObjectId,
  remote_name : String,
) -> Unit raise @bit.GitError
```

Steps:
1. Walk the target tree recursively
2. For each blob entry where `.gitattributes` indicates `filter=lfs`: read blob, check if LFS pointer
3. Collect all LFS pointers not already cached
4. Resolve LFS URL
5. Call `lfs_batch_download` + `lfs_download_objects`

Optimization: only check blobs whose path matches `filter=lfs` in `.gitattributes`. This avoids reading every blob.

### 6. Checkout Integration

**File:** `src/lib/tree_ops.mbt` (modify existing)

In `write_worktree_from_files`, the blob-to-disk loop:

```
// Current:
let output = smudge_for_checkout(o.data, attrs, autocrlf, core_eol)
fs.write_file(full_path, output)

// New:
let data = if attrs.filter == Some("lfs") && is_lfs_pointer(o.data) {
  match lfs_get_cached_object(fs, git_dir, parse_lfs_pointer(o.data).unwrap().oid) {
    Some(cached) => cached
    None => raise GitError::IoError("LFS object not found in cache: ...")
  }
} else {
  o.data
}
let output = smudge_for_checkout(data, attrs, autocrlf, core_eol)
fs.write_file(full_path, output)
```

### 7. LFS Block Removal

**Files:**
- `src/lib/gitattributes.mbt` — remove `filter=lfs` fatal error from `check_unsupported_gitattributes()`
- `src/cmd/bit/fallback.mbt` — the startup check now passes for LFS repos

The `filter=lfs` smudge/clean commands are NOT invoked. bit handles LFS directly at the checkout level, bypassing the filter mechanism entirely.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| LFS server unreachable | `GitError::IoError`, checkout fails |
| Auth failure (401/403) | Propagate credential helper error |
| Individual object 404 | Report error for that file, continue with others |
| Pointer in blob but no `filter=lfs` attr | Treat as normal file (write pointer content as-is) |
| `filter=lfs` attr but blob is not a pointer | Treat as normal file (write blob as-is) |
| No LFS URL resolvable | `GitError::IoError` with message suggesting `lfs.url` config |
| Cache miss during checkout | `GitError::IoError` (prefetch should have populated cache) |

## Testing

### Unit Tests
- **Pointer parser:** valid pointer, missing fields, oversized content, empty, non-pointer blob
- **URL resolution:** `lfs.url` set, `remote.origin.lfsurl` set, derive from remote URL, no remote configured
- **Batch API JSON:** request serialization, response parsing (success, partial error, empty)
- **Object path:** correct sharding (`ab/cd/abcdef...`)

### Integration Tests (manual / CI)
- Clone a GitHub repo with LFS files, verify files are real content not pointers
- Checkout a branch that adds LFS files, verify content
- Checkout with no LFS server access, verify error message

## File Summary

| File | Action | Purpose |
|------|--------|---------|
| `src/lib/lfs.mbt` | Create | Pointer parser, URL resolution |
| `src/lib/lfs_wbtest.mbt` | Create | Unit tests for pointer parser, URL resolution |
| `src/lib/native/lfs_client.mbt` | Create | Batch API client, download, cache |
| `src/lib/native/lfs_client_wbtest.mbt` | Create | Unit tests for JSON serialization/parsing |
| `src/lib/native/lfs_prefetch.mbt` | Create | Tree walk + prefetch orchestration |
| `src/lib/tree_ops.mbt` | Modify | LFS pointer replacement in checkout |
| `src/lib/checkout.mbt` | Modify | Insert prefetch call before worktree write |
| `src/lib/gitattributes.mbt` | Modify | Remove `filter=lfs` block |
| `src/cmd/bit/fallback.mbt` | Modify | LFS repos no longer rejected at startup |
| `src/lib/moon.pkg` | Modify | Add new files to targets |

## Out of Scope

- Clean filter (pointer creation on `git add`)
- LFS push (upload to server)
- Locking API
- `.lfsconfig` file parsing
- `lfs.fetchinclude` / `lfs.fetchexclude` filters
- Long-running filter process protocol
- `lfs.concurrenttransfers` config (fixed at 8)
- bit-relay LFS transfer
- Delayed checkout optimization
