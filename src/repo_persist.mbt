///| Git repository materialization (.git + index)

///|
pub fn materialize_clone_to_fs(
  store : ObjectStore,
  commit_id : ObjectId,
  refname : String,
  remote_url : String,
  fs : &FileSystem,
  root : String,
) -> Unit raise GitError {
  checkout_commit_to_fs(store, commit_id, fs, root)
  write_git_metadata(store, commit_id, refname, remote_url, fs, root)
}

///|
pub fn write_git_metadata(
  store : ObjectStore,
  commit_id : ObjectId,
  refname : String,
  remote_url : String,
  fs : &FileSystem,
  root : String,
) -> Unit raise GitError {
  let git_dir = join_path(root, ".git")
  fs.mkdir_p(git_dir)
  fs.mkdir_p(join_path(git_dir, "objects"))
  fs.mkdir_p(join_path(git_dir, "objects/info"))
  fs.mkdir_p(join_path(git_dir, "objects/pack"))
  fs.mkdir_p(join_path(git_dir, "refs/heads"))
  fs.mkdir_p(join_path(git_dir, "refs/tags"))
  // Note: loose objects are not written here - pack file is used instead
  write_head_and_refs(fs, git_dir, refname, commit_id)
  write_config(fs, git_dir, remote_url)
  write_packed_refs(fs, git_dir)
  write_alternates(fs, git_dir)
  write_index_v2(store, fs, git_dir, commit_id)
}

///|
fn write_head_and_refs(
  fs : &FileSystem,
  git_dir : String,
  refname : String,
  commit_id : ObjectId,
) -> Unit raise GitError {
  let head_path = join_path(git_dir, "HEAD")
  if refname == "HEAD" {
    write_text(fs, head_path, commit_id.to_hex() + "\n")
    return
  }
  write_text(fs, head_path, "ref: \{refname}\n")
  let ref_path = join_path(git_dir, refname)
  let dir = parent_dir(ref_path)
  fs.mkdir_p(dir)
  write_text(fs, ref_path, commit_id.to_hex() + "\n")
}

///|
fn write_config(
  fs : &FileSystem,
  git_dir : String,
  remote_url : String,
) -> Unit raise GitError {
  let config_path = join_path(git_dir, "config")
  let base =
    #|[core]
    #|	repositoryformatversion = 0
    #|	filemode = true
    #|	bare = false
    #|	logallrefupdates = true
  let remote_block =
    $|[remote "origin"]
    $|	url = \{remote_url}
    $|	fetch = +refs/heads/*:refs/remotes/origin/*
    $|
  let config = if remote_url.length() == 0 {
    base + "\n"
  } else {
    base + "\n" + remote_block
  }
  write_text(fs, config_path, config)
}

///|
fn write_packed_refs(fs : &FileSystem, git_dir : String) -> Unit raise GitError {
  let path = join_path(git_dir, "packed-refs")
  write_text(fs, path, "# pack-refs with: peeled fully-peeled\n")
}

///|
fn write_alternates(fs : &FileSystem, git_dir : String) -> Unit raise GitError {
  let path = join_path(git_dir, "objects/info/alternates")
  write_text(fs, path, "")
}

///|
fn write_index_v2(
  store : ObjectStore,
  fs : &FileSystem,
  git_dir : String,
  commit_id : ObjectId,
) -> Unit raise GitError {
  let entries = collect_commit_entries(store, commit_id)
  entries.sort_by((a, b) => String::compare(a.path, b.path))
  let out : Array[Byte] = []
  // Header: "DIRC" + version(2) + count
  out.push(b'D')
  out.push(b'I')
  out.push(b'R')
  out.push(b'C')
  push_u32_be(out, 2)
  push_u32_be(out, entries.length())
  for e in entries {
    // Git index v2 entry format (62 bytes fixed + variable name):
    // ctime_sec (4) + ctime_nsec (4)
    push_u32_be(out, 0)
    push_u32_be(out, 0)
    // mtime_sec (4) + mtime_nsec (4)
    push_u32_be(out, 0)
    push_u32_be(out, 0)
    // dev (4) + ino (4)
    push_u32_be(out, 0)
    push_u32_be(out, 0)
    // mode (4) - comes BEFORE uid/gid
    push_u32_be(out, e.mode)
    // uid (4) + gid (4)
    push_u32_be(out, 0)
    push_u32_be(out, 0)
    // file_size (4)
    push_u32_be(out, e.size)
    // object id
    for b in e.id.bytes {
      out.push(b)
    }
    // Convert path to UTF-8 bytes
    let path_bytes = @utf8.encode(e.path)
    let name_byte_len = path_bytes.length()
    let name_len = if name_byte_len < 0x0fff { name_byte_len } else { 0x0fff }
    push_u16_be(out, name_len)
    for i in 0..<path_bytes.length() {
      out.push(path_bytes[i])
    }
    out.push(b'\x00')
    // Pad to 8-byte alignment from entry start
    // Entry fixed part = 62 bytes, then name bytes + NUL + padding
    // Total entry size must be multiple of 8
    let entry_len = 62 + name_byte_len + 1 // fixed + name bytes + NUL
    let padded_len = (entry_len + 7) & (0xFFFFFFFF - 7) // round up to 8
    let padding = padded_len - entry_len
    for _i in 0..<padding {
      out.push(b'\x00')
    }
  }
  let content = Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
  let checksum = sha1(content)
  for b in checksum.bytes {
    out.push(b)
  }
  let index_bytes = Bytes::from_array(
    FixedArray::makei(out.length(), i => out[i]),
  )
  let index_path = join_path(git_dir, "index")
  fs.write_file(index_path, index_bytes)
}

///|
priv struct IndexEntryInfo {
  path : String
  id : ObjectId
  size : Int
  mode : Int
}

///|
fn collect_commit_entries(
  store : ObjectStore,
  commit_id : ObjectId,
) -> Array[IndexEntryInfo] raise GitError {
  let commit_obj = store.get(commit_id)
  match commit_obj {
    None => raise GitError::InvalidObject("Missing commit object")
    Some(obj) => {
      if obj.obj_type != ObjectType::Commit {
        raise GitError::InvalidObject("Object is not a commit")
      }
      let info = parse_commit(obj.data)
      let out : Array[IndexEntryInfo] = []
      collect_tree_entries(store, info.tree, "", out)
      out
    }
  }
}

///|
fn collect_tree_entries(
  store : ObjectStore,
  tree_id : ObjectId,
  prefix : String,
  out : Array[IndexEntryInfo],
) -> Unit raise GitError {
  let tree_obj = store.get(tree_id)
  match tree_obj {
    None => raise GitError::InvalidObject("Missing tree object")
    Some(obj) => {
      if obj.obj_type != ObjectType::Tree {
        raise GitError::InvalidObject("Object is not a tree")
      }
      let entries = parse_tree(obj.data)
      for entry in entries {
        let path = if prefix.length() == 0 {
          entry.name
        } else {
          prefix + "/" + entry.name
        }
        if is_tree_mode(entry.mode) {
          collect_tree_entries(store, entry.id, path, out)
        } else if is_gitlink_mode(entry.mode) {
          let mode = parse_octal(entry.mode)
          out.push({ path, id: entry.id, size: 0, mode })
        } else {
          let blob = store.get(entry.id)
          match blob {
            None => raise GitError::InvalidObject("Missing blob object")
            Some(b) => {
              if b.obj_type != ObjectType::Blob {
                raise GitError::InvalidObject("Object is not a blob")
              }
              let mode = parse_octal(entry.mode)
              out.push({ path, id: entry.id, size: b.data.length(), mode })
            }
          }
        }
      }
    }
  }
}

///|
fn parse_octal(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c < '0' || c > '7' {
      continue
    }
    result = result * 8 + (c.to_int() - '0'.to_int())
  }
  result
}

///|
fn push_u32_be(out : Array[Byte], v : Int) -> Unit {
  out.push(((v >> 24) & 0xff).to_byte())
  out.push(((v >> 16) & 0xff).to_byte())
  out.push(((v >> 8) & 0xff).to_byte())
  out.push((v & 0xff).to_byte())
}

///|
fn push_u16_be(out : Array[Byte], v : Int) -> Unit {
  out.push(((v >> 8) & 0xff).to_byte())
  out.push((v & 0xff).to_byte())
}

///|
fn write_text(
  fs : &FileSystem,
  path : String,
  content : String,
) -> Unit raise GitError {
  fs.write_string(path, content)
}

///|
