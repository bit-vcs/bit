///| Git object creation and hashing

///|
fn object_normalize_encoding_name(value : String) -> String {
  let out = StringBuilder::new()
  for c in value.trim().to_lower() {
    if c == '-' || c == '_' || c == ' ' {
      continue
    }
    out.write_char(c)
  }
  out.to_string()
}

///|
fn object_is_utf8_encoding(encoding : String) -> Bool {
  let normalized = object_normalize_encoding_name(encoding)
  normalized == "" || normalized == "utf8"
}

///|
fn object_is_iso_8859_1_encoding(encoding : String) -> Bool {
  let normalized = object_normalize_encoding_name(encoding)
  normalized == "iso88591" || normalized == "latin1" || normalized == "latin"
}

///|
fn object_commit_message_bytes(message : String, encoding : String) -> Bytes {
  let buf = @buffer.new()
  if object_is_iso_8859_1_encoding(encoding) {
    for c in message {
      let code = c.to_int()
      if code <= 0xff {
        buf.write_byte(code.to_byte())
      } else {
        buf.write_bytes(@utf8.encode(c.to_string()))
      }
    }
  } else {
    buf.write_bytes(@utf8.encode(message))
  }
  buf.to_bytes()
}

///|
fn object_serialize_commit_content_bytes(commit : Commit) -> Bytes {
  let buf = @buffer.new()
  buf.write_bytes(@utf8.encode("tree "))
  buf.write_bytes(@utf8.encode(commit.tree.to_hex()))
  buf.write_byte(b'\n')
  for parent in commit.parents {
    buf.write_bytes(@utf8.encode("parent "))
    buf.write_bytes(@utf8.encode(parent.to_hex()))
    buf.write_byte(b'\n')
  }
  buf.write_bytes(@utf8.encode("author "))
  buf.write_bytes(@utf8.encode(commit.author))
  buf.write_byte(b' ')
  buf.write_bytes(@utf8.encode(commit.author_time.to_string()))
  buf.write_byte(b' ')
  buf.write_bytes(@utf8.encode(commit.author_tz))
  buf.write_byte(b'\n')
  buf.write_bytes(@utf8.encode("committer "))
  buf.write_bytes(@utf8.encode(commit.committer))
  buf.write_byte(b' ')
  buf.write_bytes(@utf8.encode(commit.commit_time.to_string()))
  buf.write_byte(b' ')
  buf.write_bytes(@utf8.encode(commit.committer_tz))
  buf.write_byte(b'\n')
  if commit.encoding.length() > 0 && !object_is_utf8_encoding(commit.encoding) {
    buf.write_bytes(@utf8.encode("encoding "))
    buf.write_bytes(@utf8.encode(commit.encoding))
    buf.write_byte(b'\n')
  }
  buf.write_byte(b'\n')
  let msg_bytes = object_commit_message_bytes(commit.message, commit.encoding)
  buf.write_bytes(msg_bytes)
  // For verbatim mode (commit-tree), store message exactly as given.
  // Otherwise, ensure trailing newline (git commit behavior).
  if !commit.verbatim_message {
    if msg_bytes.length() == 0 || msg_bytes[msg_bytes.length() - 1] != b'\n' {
      buf.write_byte(b'\n')
    }
  }
  buf.to_bytes()
}

///|
/// Create a Git object and return its ID and compressed data
/// Format: {type} {size}\0{content} -> SHA-1 -> zlib compress
pub fn create_object(
  obj_type : ObjectType,
  content : Bytes,
) -> (ObjectId, Bytes) {
  let raw = format_object(obj_type, content)
  let id = sha1(raw)
  let compressed = @zlib.zlib_compress(raw)
  (id, compressed)
}

///|
/// Hash object content (without compression) - optimized with incremental SHA1
pub fn hash_object_content(obj_type : ObjectType, content : Bytes) -> ObjectId {
  let state = Sha1State::new()
  let header = "\{obj_type.to_string()} \{content.length()}\u0000"
  state.update_string(header)
  state.update(content)
  state.finish()
}

///|
/// Format a Git object (without compression)
fn format_object(obj_type : ObjectType, content : Bytes) -> Bytes {
  let header = "\{obj_type.to_string()} \{content.length()}\u0000"
  let header_bytes = @utf8.encode(header)
  let buf = @buffer.new(size_hint=header_bytes.length() + content.length())
  buf.write_bytes(header_bytes)
  buf.write_bytes(content)
  buf.to_bytes()
}

///|
/// Create a blob object from content
pub fn create_blob(content : Bytes) -> (ObjectId, Bytes) {
  create_object(ObjectType::Blob, content)
}

///|
/// Create a blob from string content
pub fn create_blob_string(content : String) -> (ObjectId, Bytes) {
  let buf = @buffer.new(size_hint=content.length())
  for c in content {
    buf.write_byte(c.to_int().to_byte())
  }
  create_blob(buf.to_bytes())
}

///|
/// Create a tree object from entries
/// Entries must be sorted by name
pub fn create_tree(entries : Array[TreeEntry]) -> (ObjectId, Bytes) {
  create_object(ObjectType::Tree, serialize_tree(entries))
}

///|
/// Create a commit object
pub fn create_commit(commit : Commit) -> (ObjectId, Bytes) {
  create_object(ObjectType::Commit, serialize_commit_content(commit))
}

///|
/// Hash a blob without creating the compressed object - optimized with incremental SHA1
pub fn hash_blob(content : Bytes) -> ObjectId {
  hash_object_content(ObjectType::Blob, content)
}

///|
/// Serialize tree entries to raw content bytes (without git object header)
pub fn serialize_tree(entries : Array[TreeEntry]) -> Bytes {
  let buf = @buffer.new()
  for entry in entries {
    // mode (as ASCII)
    for c in entry.mode {
      buf.write_byte(c.to_int().to_byte())
    }
    // space
    buf.write_byte(b' ')
    // name (as UTF-8 bytes)
    buf.write_bytes(@utf8.encode(entry.name))
    // null byte
    buf.write_byte(b'\x00')
    // 20-byte SHA
    for b in entry.id.bytes {
      buf.write_byte(b)
    }
  }
  buf.to_bytes()
}

///|
/// Serialize commit to raw content bytes (without git object header)
pub fn serialize_commit_content(commit : Commit) -> Bytes {
  object_serialize_commit_content_bytes(commit)
}

///|
/// Hash a blob from string - optimized with incremental SHA1
pub fn hash_blob_string(content : String) -> ObjectId {
  let state = Sha1State::new()
  // Count bytes for header (ASCII only, same as original behavior)
  let byte_len = content.iter().count()
  let header = "blob \{byte_len}\u0000"
  state.update_string(header)
  state.update_string(content)
  state.finish()
}
