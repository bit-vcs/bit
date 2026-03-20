///| JS-exported local Git operations backed by `src/lib`.

///|
fn[T] js_wrap_error(f : () -> T raise @bit.GitError) -> Result[T, String] {
  Ok(f()) catch {
    @bit.GitError::IoError(error) => Err(error)
    @bit.GitError::InvalidObject(error) => Err(error)
    @bit.GitError::HashMismatch(expected, actual) =>
      Err("hash mismatch: \{expected} vs \{actual}")
    @bit.GitError::PackfileError(error) => Err("packfile error: \{error}")
    @bit.GitError::ProtocolError(error) => Err("protocol error: \{error}")
  }
}

///|
fn js_resolve_git_dir(
  fs : LibJsHostFs,
  root : String,
) -> String raise @bit.GitError {
  let git_path = join_path(root, ".git")
  if fs.is_file(git_path) {
    resolve_gitdir(fs, git_path)
  } else {
    resolve_worktree_git_dir(fs, root)
  }
}

///|
priv struct JsPreparedCommit {
  git_dir : String
  parent : @bit.ObjectId?
  tree_id : @bit.ObjectId
  entries : Array[IndexEntry]
  committer : String
  timestamp : Int64
  timezone : String
  message : String
  payload : Bytes
}

///|
fn js_prepare_commit(
  fs : LibJsHostFs,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
) -> JsPreparedCommit raise @bit.GitError {
  let actual_git_dir = js_resolve_git_dir(fs, root)
  let parent = resolve_head_commit(fs, actual_git_dir)
  let entries = read_index_entries(fs, actual_git_dir)
  let tree_id = if entries.length() == 0 {
    raise @bit.GitError::InvalidObject("Empty index")
  } else {
    write_tree_from_index(fs, fs, actual_git_dir, entries, missing_ok=true)
  }
  let parents = match parent {
    Some(id) => [id]
    None => []
  }
  let timestamp = timestamp_secs.to_int64()
  let timezone = "+0000"
  let commit = @bit.Commit::new(
    tree_id, parents, author, timestamp, timezone, author, timestamp, timezone, message,
  )
  {
    git_dir: actual_git_dir,
    parent,
    tree_id,
    entries,
    committer: author,
    timestamp,
    timezone,
    message,
    payload: @bit.serialize_commit_content(commit),
  }
}

///|
fn js_append_bytes(out : Array[Byte], data : BytesView) -> Unit {
  for b in data {
    out.push(b)
  }
}

///|
fn js_append_utf8(out : Array[Byte], value : String) -> Unit {
  js_append_bytes(out, @utf8.encode(value))
}

///|
fn js_normalize_newlines(value : String) -> String {
  let out = StringBuilder::new()
  let mut saw_cr = false
  for c in value {
    if saw_cr {
      if c == '\n' {
        out.write_char('\n')
        saw_cr = false
        continue
      } else {
        out.write_char('\n')
        saw_cr = false
      }
    }
    if c == '\r' {
      saw_cr = true
    } else {
      out.write_char(c)
    }
  }
  if saw_cr {
    out.write_char('\n')
  }
  out.to_string()
}

///|
fn js_signature_lines(signature : String) -> Array[String] raise @bit.GitError {
  let lines : Array[String] = []
  let normalized = js_normalize_newlines(signature)
  for line_view in normalized.split("\n") {
    lines.push(line_view.to_string())
  }
  while lines.length() > 0 && lines[lines.length() - 1] == "" {
    ignore(lines.pop())
  }
  if lines.length() == 0 {
    raise @bit.GitError::InvalidObject("Empty commit signature")
  }
  lines
}

///|
fn js_find_commit_header_end(payload : Bytes) -> Int raise @bit.GitError {
  let mut i = 0
  while i + 1 < payload.length() {
    if payload[i] == b'\n' && payload[i + 1] == b'\n' {
      return i
    }
    i += 1
  }
  raise @bit.GitError::InvalidObject("Malformed commit payload")
}

///|
fn js_inject_commit_signature(
  payload : Bytes,
  signature : String,
) -> Bytes raise @bit.GitError {
  let lines = js_signature_lines(signature)
  let header_end = js_find_commit_header_end(payload)
  let out : Array[Byte] = []
  js_append_bytes(out, payload[:header_end + 1])
  js_append_utf8(out, "gpgsig ")
  js_append_utf8(out, lines[0])
  out.push(b'\n')
  for i in 1..<lines.length() {
    js_append_utf8(out, " ")
    js_append_utf8(out, lines[i])
    out.push(b'\n')
  }
  out.push(b'\n')
  js_append_bytes(out, payload[header_end + 2:])
  Bytes::from_iter(out.iter())
}

///|
fn js_finalize_commit(
  fs : LibJsHostFs,
  prepared : JsPreparedCommit,
  payload : Bytes,
) -> @bit.ObjectId raise @bit.GitError {
  let (commit_id, compressed) = @bit.create_object(
    @bit.ObjectType::Commit,
    payload,
  )
  write_object_bytes(fs, prepared.git_dir, commit_id, compressed)
  update_head_ref(fs, fs, prepared.git_dir, commit_id)
  let committer = prepared.committer
  append_head_update_reflogs(
    fs,
    fs,
    prepared.git_dir,
    prepared.parent.unwrap_or(@bit.ObjectId::zero()),
    commit_id,
    if prepared.parent is None {
      "commit (initial): " + worktree_commit_subject(prepared.message)
    } else {
      "commit: " + worktree_commit_subject(prepared.message)
    },
    committer~,
    timestamp=prepared.timestamp,
    timezone=prepared.timezone,
  )
  if prepared.entries.length() > 0 {
    write_index_entries_with_tree(
      fs,
      fs,
      prepared.git_dir,
      prepared.entries,
      prepared.tree_id,
    )
  }
  commit_id
}

///|
pub fn js_git_init(
  host_id : Int,
  root : String,
  default_branch : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => init_repo(fs, root, default_branch~))
}

///|
pub fn js_add_paths(
  host_id : Int,
  root : String,
  paths : Array[String],
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => add_paths(fs, fs, root, paths))
}

///|
pub fn js_status(host_id : Int, root : String) -> Result[Status, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let entries = read_index_entries(fs, git_dir)
    let index_map : Map[String, IndexEntry] = {}
    for entry in entries {
      index_map[entry.path] = entry
    }
    let files = list_working_files(fs, root)
    files.sort()
    let visited : Map[String, Bool] = {}
    let untracked : Array[String] = []
    let unstaged_modified : Array[String] = []
    for rel_path in files {
      visited[rel_path] = true
      match index_map.get(rel_path) {
        Some(index_entry) => {
          let abs_path = join_path(root, rel_path)
          let content = (fs as &@bit.RepoFileSystem).read_file(abs_path) catch {
            _ => continue
          }
          let worktree_id = @bit.hash_blob(content)
          if worktree_id != index_entry.id {
            unstaged_modified.push(rel_path)
          }
        }
        None => untracked.push(rel_path)
      }
    }
    let unstaged_deleted : Array[String] = []
    for entry in entries {
      if visited.get(entry.path) is Some(_) {
        continue
      }
      let abs_path = join_path(root, entry.path)
      if not(fs.is_file(abs_path)) {
        unstaged_deleted.push(entry.path)
      }
    }
    let staged_index_map : Map[String, IndexEntry] = {}
    for entry in entries {
      staged_index_map[entry.path] = entry
    }
    let staged_modified : Array[String] = []
    let staged_deleted : Array[String] = []
    let skip_worktree_paths : Map[String, Bool] = {}
    collect_staged_changes_from_head(
      fs, git_dir, staged_index_map, skip_worktree_paths, staged_modified, staged_deleted,
    )
    let staged_added : Array[String] = []
    for item in staged_index_map.to_array() {
      let (path, _) = item
      staged_added.push(path)
    }
    staged_added.sort()
    staged_modified.sort()
    staged_deleted.sort()
    unstaged_modified.sort()
    unstaged_deleted.sort()
    untracked.sort()
    {
      staged_added,
      staged_modified,
      staged_deleted,
      unstaged_modified,
      unstaged_deleted,
      untracked,
    }
  })
}

///|
pub fn js_status_porcelain(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  match js_status(host_id, root) {
    Ok(status_result) => Ok(status_porcelain_from(status_result))
    Err(error) => Err(error)
  }
}

///|
pub fn js_commit(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let prepared = js_prepare_commit(fs, root, message, author, timestamp_secs)
    js_finalize_commit(fs, prepared, prepared.payload).to_hex()
  })
}

///|
pub fn js_build_commit_payload(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let prepared = js_prepare_commit(fs, root, message, author, timestamp_secs)
    @utf8.decode_lossy(prepared.payload[:])
  })
}

///|
pub fn js_commit_signed(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
  signature : String,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let prepared = js_prepare_commit(fs, root, message, author, timestamp_secs)
    let signed_payload = js_inject_commit_signature(prepared.payload, signature)
    js_finalize_commit(fs, prepared, signed_payload).to_hex()
  })
}

///|
pub fn js_log(
  host_id : Int,
  root : String,
  max_count : Int,
) -> Result[Array[JsLogEntry], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let entries = log_head(fs, git_dir, max_count~)
    let result : Array[JsLogEntry] = []
    for entry in entries {
      result.push({
        id: entry.id.to_hex(),
        author: entry.author,
        message: entry.message,
        timestamp: entry.timestamp.to_int(),
      })
    }
    result
  })
}

///|
pub fn js_checkout(
  host_id : Int,
  root : String,
  target : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => ignore(checkout(fs, fs, root, target)))
}

///|
pub fn js_checkout_b(
  host_id : Int,
  root : String,
  branch_name : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    create_branch(fs, fs, root, branch_name)
    ignore(checkout(fs, fs, root, branch_name))
  })
}

///|
pub fn js_branch_list(
  host_id : Int,
  root : String,
) -> Result[Array[JsBranchInfo], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let (_, branches) = list_branches(fs, git_dir)
    let result : Array[JsBranchInfo] = []
    for branch in branches {
      result.push({
        name: branch.name,
        commit_id: branch.id.to_hex(),
        is_current: branch.current,
      })
    }
    result
  })
}

///|
pub fn js_branch_create(
  host_id : Int,
  root : String,
  name : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => create_branch(fs, fs, root, name))
}

///|
pub fn js_branch_delete(
  host_id : Int,
  root : String,
  name : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => delete_branch(fs, fs, root, name))
}

///|
pub fn js_rm_paths(
  host_id : Int,
  root : String,
  paths : Array[String],
  cached : Bool,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => rm_paths(fs, fs, root, paths, cached~))
}

///|
pub fn js_mv_path(
  host_id : Int,
  root : String,
  source : String,
  dest : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => mv_path(fs, fs, root, source, dest))
}
