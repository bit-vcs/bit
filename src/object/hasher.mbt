///| Unified hash state that dispatches to SHA-1 or SHA-256

///|
pub(all) enum HashState {
  HS1(Sha1State)
  HS256(Sha256State)
}

///|
pub fn HashState::new(algo : HashAlgorithm) -> HashState {
  match algo {
    Sha1 => HS1(Sha1State::new())
    Sha256 => HS256(Sha256State::new())
  }
}

///|
pub fn HashState::reset(self : HashState) -> Unit {
  match self {
    HS1(s) => s.reset()
    HS256(s) => s.reset()
  }
}

///|
pub fn HashState::update(self : HashState, data : Bytes) -> Unit {
  match self {
    HS1(s) => s.update(data)
    HS256(s) => s.update(data)
  }
}

///|
pub fn HashState::update_slice(
  self : HashState,
  data : Bytes,
  offset : Int,
  len : Int,
) -> Unit {
  match self {
    HS1(s) => s.update_slice(data, offset, len)
    HS256(s) => s.update_slice(data, offset, len)
  }
}

///|
pub fn HashState::update_byte(self : HashState, b : Byte) -> Unit {
  match self {
    HS1(s) => s.update_byte(b)
    HS256(s) => s.update_byte(b)
  }
}

///|
pub fn HashState::update_string(self : HashState, s : String) -> Unit {
  match self {
    HS1(st) => st.update_string(s)
    HS256(st) => st.update_string(s)
  }
}

///|
pub fn HashState::finish(self : HashState) -> ObjectId {
  match self {
    HS1(s) => s.finish()
    HS256(s) => s.finish()
  }
}

///|
/// Hash object content using the specified algorithm.
pub fn hash_object_content_with_algo(
  algo : HashAlgorithm,
  obj_type : ObjectType,
  content : Bytes,
) -> ObjectId {
  let state = HashState::new(algo)
  let header = "\{obj_type.to_string()} \{content.length()}\u0000"
  state.update_string(header)
  state.update(content)
  state.finish()
}

///|
/// Create a git object (hash + compress) using the specified algorithm.
pub fn create_object_with_algo(
  algo : HashAlgorithm,
  obj_type : ObjectType,
  content : Bytes,
) -> (ObjectId, Bytes) {
  let raw = format_object(obj_type, content)
  let state = HashState::new(algo)
  state.update(raw)
  let id = state.finish()
  let compressed = @zlib.zlib_compress(raw)
  (id, compressed)
}

///|
pub fn create_tree_with_algo(
  algo : HashAlgorithm,
  entries : Array[TreeEntry],
) -> (ObjectId, Bytes) {
  let content : Array[Byte] = []
  for entry in entries {
    for c in entry.mode {
      content.push(c.to_int().to_byte())
    }
    content.push(b' ')
    for b in @utf8.encode(entry.name) {
      content.push(b)
    }
    content.push(b'\x00')
    for b in entry.id.bytes {
      content.push(b)
    }
  }
  create_object_with_algo(algo, ObjectType::Tree, array_to_bytes(content))
}

///|
pub fn create_commit_with_algo(
  algo : HashAlgorithm,
  commit : Commit,
) -> (ObjectId, Bytes) {
  create_object_with_algo(
    algo,
    ObjectType::Commit,
    serialize_commit_content(commit),
  )
}
