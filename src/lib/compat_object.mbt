///| Helpers for compatObjectFormat repositories.

///|
fn compat_hash_algorithm_name(algo : @object.HashAlgorithm) -> String {
  match algo {
    @object.HashAlgorithm::Sha1 => "sha1"
    @object.HashAlgorithm::Sha256 => "sha256"
  }
}

///|
pub fn repo_hash_algorithm(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
) -> @object.HashAlgorithm {
  match
    read_config_value(rfs, git_dir + "/config", "extensions", "objectformat") {
    Some(raw) =>
      if config_strip_quotes(raw).to_lower() == "sha256" {
        @object.HashAlgorithm::Sha256
      } else {
        @object.HashAlgorithm::Sha1
      }
    None => @object.HashAlgorithm::Sha1
  }
}

///|
pub fn repo_compat_hash_algorithm(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
) -> @object.HashAlgorithm? {
  let storage_algo = repo_hash_algorithm(rfs, git_dir)
  match
    read_config_value(
      rfs,
      git_dir + "/config",
      "extensions",
      "compatobjectformat",
    ) {
    Some(raw) => {
      let normalized = config_strip_quotes(raw).to_lower()
      if normalized.length() == 0 ||
        normalized == compat_hash_algorithm_name(storage_algo) {
        None
      } else if normalized == "sha256" {
        Some(@object.HashAlgorithm::Sha256)
      } else if normalized == "sha1" {
        Some(@object.HashAlgorithm::Sha1)
      } else {
        None
      }
    }
    None => None
  }
}

///|
pub fn compat_lookup_loose_object_idx(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> String? {
  let idx_path = git_dir + "/objects/loose-object-idx"
  if !rfs.is_file(idx_path) {
    return None
  }
  let text = @utf8.decode_lossy(
    rfs.read_file(idx_path) catch {
      _ => return None
    },
  )
  for line_view in text.split("\n") {
    let line = line_view.to_string().trim().to_string()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let cols : Array[String] = []
    for col_view in line.split(" ") {
      let col = col_view.to_string().trim().to_string()
      if col.length() > 0 {
        cols.push(col)
      }
    }
    if cols.length() < 2 {
      continue
    }
    let a = cols[0]
    let b = cols[1]
    if spec == a {
      return Some(b)
    }
    if spec == b {
      return Some(a)
    }
  }
  None
}

///|
pub fn compat_lookup_object_id(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  id : @bit.ObjectId,
) -> @bit.ObjectId? {
  match compat_lookup_loose_object_idx(rfs, git_dir, id.to_hex()) {
    Some(mapped_hex) =>
      Some(@bit.ObjectId::from_hex(mapped_hex)) catch {
        _ => None
      }
    None => None
  }
}

///|
pub fn compat_append_loose_object_idx(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  storage_id : @bit.ObjectId,
  compat_id : @bit.ObjectId,
) -> Unit raise @bit.GitError {
  let storage_hex = storage_id.to_hex()
  let compat_hex = compat_id.to_hex()
  if storage_hex == compat_hex {
    return
  }
  match compat_lookup_loose_object_idx(rfs, git_dir, storage_hex) {
    Some(mapped) if mapped == compat_hex => return
    _ => ()
  }
  let idx_path = git_dir + "/objects/loose-object-idx"
  let mut text = if rfs.is_file(idx_path) {
    @utf8.decode_lossy(rfs.read_file(idx_path) catch { _ => @utf8.encode("") })
  } else {
    "# loose-object-idx\n"
  }
  if text.length() == 0 {
    text = "# loose-object-idx\n"
  } else if !text.has_suffix("\n") {
    text = text + "\n"
  }
  text += "\{storage_hex} \{compat_hex}\n"
  fs.mkdir_p(git_dir + "/objects")
  fs.write_file(idx_path, @utf8.encode(text))
}

///|
pub fn compat_record_blob_mapping(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  storage_id : @bit.ObjectId,
  content : Bytes,
) -> Unit raise @bit.GitError {
  guard repo_compat_hash_algorithm(rfs, git_dir) is Some(compat_algo) else {
    return
  }
  let compat_id = @object.hash_object_content_with_algo(
    compat_algo,
    @bit.ObjectType::Blob,
    content,
  )
  compat_append_loose_object_idx(fs, rfs, git_dir, storage_id, compat_id)
}

///|
pub fn compat_record_tree_mapping(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  storage_id : @bit.ObjectId,
  entries : Array[@bit.TreeEntry],
) -> Unit raise @bit.GitError {
  guard repo_compat_hash_algorithm(rfs, git_dir) is Some(compat_algo) else {
    return
  }
  let compat_entries : Array[@bit.TreeEntry] = []
  for entry in entries {
    guard compat_lookup_object_id(rfs, git_dir, entry.id) is Some(mapped_id) else {
      return
    }
    compat_entries.push(@bit.TreeEntry::new(entry.mode, entry.name, mapped_id))
  }
  let (compat_id, _) = @object.create_tree_with_algo(
    compat_algo, compat_entries,
  )
  compat_append_loose_object_idx(fs, rfs, git_dir, storage_id, compat_id)
}

///|
pub fn compat_record_commit_mapping(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  storage_id : @bit.ObjectId,
  commit : @bit.Commit,
) -> Unit raise @bit.GitError {
  guard repo_compat_hash_algorithm(rfs, git_dir) is Some(compat_algo) else {
    return
  }
  guard compat_lookup_object_id(rfs, git_dir, commit.tree) is Some(compat_tree) else {
    return
  }
  let compat_parents : Array[@bit.ObjectId] = []
  for parent in commit.parents {
    guard compat_lookup_object_id(rfs, git_dir, parent) is Some(mapped_parent) else {
      return
    }
    compat_parents.push(mapped_parent)
  }
  let compat_commit = @bit.Commit::new(
    compat_tree,
    compat_parents,
    commit.author,
    commit.author_time,
    commit.author_tz,
    commit.committer,
    commit.commit_time,
    commit.committer_tz,
    commit.message,
    encoding=commit.encoding,
    verbatim_message=commit.verbatim_message,
  )
  let (compat_id, _) = @object.create_commit_with_algo(
    compat_algo, compat_commit,
  )
  compat_append_loose_object_idx(fs, rfs, git_dir, storage_id, compat_id)
}

///|
pub fn compat_record_annotated_tag_mapping(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  storage_id : @bit.ObjectId,
  target : @bit.ObjectId,
  target_type : String,
  name : String,
  message : String,
  tagger : String,
  timestamp : Int64,
  timezone : String,
) -> Unit raise @bit.GitError {
  guard repo_compat_hash_algorithm(rfs, git_dir) is Some(compat_algo) else {
    return
  }
  guard compat_lookup_object_id(rfs, git_dir, target) is Some(compat_target) else {
    return
  }
  let tag_content = if message.length() == 0 {
    "object \{compat_target.to_hex()}\ntype \{target_type}\ntag \{name}\ntagger \{tagger} \{timestamp} \{timezone}\n\n"
  } else {
    "object \{compat_target.to_hex()}\ntype \{target_type}\ntag \{name}\ntagger \{tagger} \{timestamp} \{timezone}\n\n\{message}\n"
  }
  let (compat_id, _) = @object.create_object_with_algo(
    compat_algo,
    @bit.ObjectType::Tag,
    @utf8.encode(tag_content),
  )
  compat_append_loose_object_idx(fs, rfs, git_dir, storage_id, compat_id)
}
