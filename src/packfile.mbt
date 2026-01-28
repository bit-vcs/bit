///| Git packfile generation

///|
/// Helper to convert Array[Byte] to Bytes
fn pack_array_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), fn(i) { arr[i] }))
}

///|
/// A Git object ready for packing
pub struct PackObject {
  obj_type : ObjectType
  data : Bytes // Uncompressed object content (without header)
}

///|
pub fn PackObject::new(obj_type : ObjectType, data : Bytes) -> PackObject {
  { obj_type, data }
}

///|
/// Create a packfile from a list of objects
/// Format:
///   [PACK]           4 bytes magic
///   [version]        4 bytes (big-endian, always 2)
///   [object count]   4 bytes (big-endian)
///   [...objects...]  variable
///   [SHA-1 trailer]  20 bytes
pub fn create_packfile(objects : Array[PackObject]) -> Bytes {
  let result : Array[Byte] = []

  // Magic: "PACK"
  result.push(b'P')
  result.push(b'A')
  result.push(b'C')
  result.push(b'K')

  // Version: 2 (big-endian)
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x02')

  // Object count (big-endian)
  let count = objects.length()
  result.push(((count >> 24) & 0xff).to_byte())
  result.push(((count >> 16) & 0xff).to_byte())
  result.push(((count >> 8) & 0xff).to_byte())
  result.push((count & 0xff).to_byte())

  // Pack each object
  for obj in objects {
    pack_object(obj, result)
  }

  // Compute SHA-1 of everything so far
  let pack_data = pack_array_to_bytes(result)
  let trailer = sha1(pack_data)

  // Append trailer
  for b in trailer.bytes {
    result.push(b)
  }
  pack_array_to_bytes(result)
}

///|
/// Pack a single object into the result array
fn pack_object(obj : PackObject, result : Array[Byte]) -> Unit {
  let obj_type = obj.obj_type.to_packfile_type()
  let data = obj.data
  let size = data.length()

  // Encode type and size
  // First byte: [MSB | type(3 bits) | size(4 bits)]
  // Continue bytes: [MSB | size(7 bits)]
  encode_type_and_size(obj_type, size, result)

  // Compress data with zlib
  let compressed = @zlib.zlib_compress_stored(data)

  // Append compressed data
  for b in compressed {
    result.push(b)
  }
}

///|
/// Encode type and size in Git's variable-length format
pub fn encode_type_and_size(
  obj_type : Int,
  size : Int,
  result : Array[Byte],
) -> Unit {
  // First byte: MSB | type(3) | size(4)
  let mut remaining = size >> 4
  let first_byte = if remaining > 0 {
    0x80 | (obj_type << 4) | (size & 0x0f)
  } else {
    (obj_type << 4) | (size & 0x0f)
  }
  result.push(first_byte.to_byte())

  // Continue bytes: MSB | size(7)
  while remaining > 0 {
    let next_remaining = remaining >> 7
    let byte_val = if next_remaining > 0 {
      0x80 | (remaining & 0x7f)
    } else {
      remaining & 0x7f
    }
    result.push(byte_val.to_byte())
    remaining = next_remaining
  }
}

///|
/// Create a packfile containing a single blob
pub fn create_blob_packfile(content : Bytes) -> Bytes {
  let obj = PackObject::new(ObjectType::Blob, content)
  create_packfile([obj])
}

///|
/// Create a packfile with blob, tree, and commit
pub fn create_commit_packfile(
  blob_content : Bytes,
  filename : String,
  commit : Commit,
) -> (ObjectId, Bytes) {
  // Create blob
  let (blob_id, _) = create_blob(blob_content)

  // Create tree with single entry
  let entry = TreeEntry::new("100644", filename, blob_id)
  let (tree_id, _) = create_tree([entry])

  // Update commit with correct tree
  let final_commit = Commit::new(
    tree_id,
    commit.parents,
    commit.author,
    commit.author_time,
    commit.author_tz,
    commit.committer,
    commit.commit_time,
    commit.committer_tz,
    commit.message,
  )
  let (commit_id, _) = create_commit(final_commit)

  // Build pack objects (raw content, not git object format)
  let pack_objects = [
    PackObject::new(ObjectType::Blob, blob_content),
    PackObject::new(ObjectType::Tree, build_tree_content([entry])),
    PackObject::new(ObjectType::Commit, build_commit_content(final_commit)),
  ]
  let packfile = create_packfile(pack_objects)
  (commit_id, packfile)
}

///|
/// Build raw tree content (without "tree {size}\0" header)
fn build_tree_content(entries : Array[TreeEntry]) -> Bytes {
  let content : Array[Byte] = []
  for entry in entries {
    for c in entry.mode {
      content.push(c.to_int().to_byte())
    }
    content.push(b' ')
    for c in entry.name {
      content.push(c.to_int().to_byte())
    }
    content.push(b'\x00')
    for b in entry.id.bytes {
      content.push(b)
    }
  }
  pack_array_to_bytes(content)
}

///|
/// Build raw commit content (without "commit {size}\0" header)
fn build_commit_content(commit : Commit) -> Bytes {
  let content = StringBuilder::new()
  content.write_string("tree ")
  content.write_string(commit.tree.to_hex())
  content.write_char('\n')
  for parent in commit.parents {
    content.write_string("parent ")
    content.write_string(parent.to_hex())
    content.write_char('\n')
  }
  content.write_string("author ")
  content.write_string(commit.author)
  content.write_string(" ")
  content.write_string(commit.author_time.to_string())
  content.write_string(" ")
  content.write_string(commit.author_tz)
  content.write_char('\n')
  content.write_string("committer ")
  content.write_string(commit.committer)
  content.write_string(" ")
  content.write_string(commit.commit_time.to_string())
  content.write_string(" ")
  content.write_string(commit.committer_tz)
  content.write_char('\n')
  content.write_char('\n')
  content.write_string(commit.message)
  let str = content.to_string()
  let bytes : Array[Byte] = []
  for c in str {
    bytes.push(c.to_int().to_byte())
  }
  pack_array_to_bytes(bytes)
}
