///| Git object creation and hashing

///|
/// Helper to convert Array[Byte] to Bytes
pub fn array_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_iter(arr.iter())
}

///|
/// Helper to convert String to byte array (ASCII encoding)
fn string_to_byte_array(s : String) -> Array[Byte] {
  let arr : Array[Byte] = []
  for c in s {
    arr.push(c.to_int().to_byte())
  }
  arr
}

///|
fn object_append_bytes(out : Array[Byte], data : Bytes) -> Unit {
  for b in data {
    out.push(b)
  }
}

///|
fn object_append_utf8_string(out : Array[Byte], s : String) -> Unit {
  object_append_bytes(out, @utf8.encode(s))
}

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
fn object_commit_message_bytes(
  message : String,
  encoding : String,
) -> Array[Byte] {
  if object_is_iso_8859_1_encoding(encoding) {
    let out : Array[Byte] = []
    for c in message {
      let code = c.to_int()
      if code <= 0xff {
        out.push(code.to_byte())
      } else {
        object_append_bytes(out, @utf8.encode(c.to_string()))
      }
    }
    out
  } else {
    @utf8.encode(message).to_array()
  }
}

///|
fn object_serialize_commit_content_array(commit : Commit) -> Array[Byte] {
  let content : Array[Byte] = []
  object_append_utf8_string(content, "tree ")
  object_append_utf8_string(content, commit.tree.to_hex())
  content.push(b'\n')
  for parent in commit.parents {
    object_append_utf8_string(content, "parent ")
    object_append_utf8_string(content, parent.to_hex())
    content.push(b'\n')
  }
  object_append_utf8_string(content, "author ")
  object_append_utf8_string(content, commit.author)
  object_append_utf8_string(content, " ")
  object_append_utf8_string(content, commit.author_time.to_string())
  object_append_utf8_string(content, " ")
  object_append_utf8_string(content, commit.author_tz)
  content.push(b'\n')
  object_append_utf8_string(content, "committer ")
  object_append_utf8_string(content, commit.committer)
  object_append_utf8_string(content, " ")
  object_append_utf8_string(content, commit.commit_time.to_string())
  object_append_utf8_string(content, " ")
  object_append_utf8_string(content, commit.committer_tz)
  content.push(b'\n')
  if commit.encoding.length() > 0 && !object_is_utf8_encoding(commit.encoding) {
    object_append_utf8_string(content, "encoding ")
    object_append_utf8_string(content, commit.encoding)
    content.push(b'\n')
  }
  content.push(b'\n')
  let msg_bytes = object_commit_message_bytes(commit.message, commit.encoding)
  content.append(msg_bytes)
  // For verbatim mode (commit-tree), store message exactly as given.
  // Otherwise, ensure trailing newline (git commit behavior).
  if !commit.verbatim_message {
    if msg_bytes.length() == 0 || msg_bytes[msg_bytes.length() - 1] != b'\n' {
      content.push(b'\n')
    }
  }
  content
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
  let result : Array[Byte] = []
  for c in header {
    result.push(c.to_int().to_byte())
  }
  for b in content {
    result.push(b)
  }
  array_to_bytes(result)
}

///|
/// Create a blob object from content
pub fn create_blob(content : Bytes) -> (ObjectId, Bytes) {
  create_object(ObjectType::Blob, content)
}

///|
/// Create a blob from string content
pub fn create_blob_string(content : String) -> (ObjectId, Bytes) {
  content |> string_to_byte_array |> array_to_bytes |> create_blob
}

///|
/// Create a tree object from entries
/// Entries must be sorted by name
pub fn create_tree(entries : Array[TreeEntry]) -> (ObjectId, Bytes) {
  let content : Array[Byte] = []
  for entry in entries {
    // mode (as ASCII)
    for c in entry.mode {
      content.push(c.to_int().to_byte())
    }
    // space
    content.push(b' ')
    // name (as UTF-8 bytes)
    object_append_utf8_string(content, entry.name)
    // null byte
    content.push(b'\x00')
    // 20-byte SHA
    for b in entry.id.bytes {
      content.push(b)
    }
  }
  create_object(ObjectType::Tree, array_to_bytes(content))
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
  let content : Array[Byte] = []
  for entry in entries {
    for c in entry.mode {
      content.push(c.to_int().to_byte())
    }
    content.push(b' ')
    object_append_utf8_string(content, entry.name)
    content.push(b'\x00')
    for b in entry.id.bytes {
      content.push(b)
    }
  }
  array_to_bytes(content)
}

///|
/// Serialize commit to raw content bytes (without git object header)
pub fn serialize_commit_content(commit : Commit) -> Bytes {
  array_to_bytes(object_serialize_commit_content_array(commit))
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
