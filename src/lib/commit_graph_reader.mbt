///| Commit-graph binary file reader

///|
pub struct CommitGraphFile {
  data : Bytes
  hash_size : Int
  num_commits : Int
  oidf_offset : Int // OID fanout chunk
  oidl_offset : Int // OID lookup chunk
  cdat_offset : Int // commit data chunk
  edge_offset : Int // extra edges chunk (0 if absent)
}

///|
pub fn CommitGraphFile::load(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
) -> CommitGraphFile? raise @bit.GitError {
  let graph_path = join_path(git_dir, "objects/info/commit-graph")
  if not(rfs.is_file(graph_path)) {
    return None
  }
  let data = rfs.read_file(graph_path)
  if data.length() < 8 {
    return None
  }
  let sig = cgraph_read_u32(data, 0)
  if sig != 0x43475048 {
    return None
  }
  let hash_version = data[5].to_int()
  let hash_size = if hash_version == 2 { 32 } else { 20 }
  let num_chunks = data[6].to_int()
  let toc_start = 8
  let mut oidf_offset = 0
  let mut oidl_offset = 0
  let mut cdat_offset = 0
  let mut edge_offset = 0
  // Parse chunk TOC: each entry is 4 bytes chunk_id + 8 bytes offset
  // After the last chunk entry there is a terminator entry.
  let chunk_offsets : Array[(Int, Int)] = [] // (chunk_id, offset)
  for i = 0; i <= num_chunks; i = i + 1 {
    let entry = toc_start + i * 12
    if entry + 12 > data.length() {
      break
    }
    let chunk_id = cgraph_read_u32(data, entry)
    let offset = cgraph_read_u32(data, entry + 8) // lower 32 bits
    chunk_offsets.push((chunk_id, offset))
  }
  for i = 0; i < chunk_offsets.length() - 1; i = i + 1 {
    let (cid, off) = chunk_offsets[i]
    match cid {
      0x4f494446 => oidf_offset = off // OIDF
      0x4f49444c => oidl_offset = off // OIDL
      0x43444154 => cdat_offset = off // CDAT
      0x45444745 => edge_offset = off // EDGE
      _ => ()
    }
  }
  if oidf_offset == 0 || oidl_offset == 0 || cdat_offset == 0 {
    return None
  }
  // num_commits from fanout[255]
  let num_commits = cgraph_read_u32(data, oidf_offset + 255 * 4)
  Some({
    data,
    hash_size,
    num_commits,
    oidf_offset,
    oidl_offset,
    cdat_offset,
    edge_offset,
  })
}

///|
/// Look up a commit OID in the graph. Returns its position index or -1.
pub fn CommitGraphFile::find_commit(
  self : CommitGraphFile,
  id : @bit.ObjectId,
) -> Int {
  let hex_bytes = id.bytes
  let first_byte = hex_bytes[0].to_int()
  // Fanout: lo = fanout[first_byte - 1], hi = fanout[first_byte]
  let lo = if first_byte == 0 {
    0
  } else {
    cgraph_read_u32(self.data, self.oidf_offset + (first_byte - 1) * 4)
  }
  let hi = cgraph_read_u32(self.data, self.oidf_offset + first_byte * 4)
  // Binary search in OIDL[lo..hi]
  let mut left = lo
  let mut right = hi
  while left < right {
    let mid = (left + right) / 2
    let cmp = cgraph_compare_oid(
      self.data,
      self.oidl_offset + mid * self.hash_size,
      hex_bytes,
      self.hash_size,
    )
    if cmp < 0 {
      left = mid + 1
    } else if cmp > 0 {
      right = mid
    } else {
      return mid
    }
  }
  -1
}

///|
/// Get the OID at position `pos` in the OID lookup table.
pub fn CommitGraphFile::get_oid(
  self : CommitGraphFile,
  pos : Int,
) -> @bit.ObjectId {
  @bit.ObjectId::from_bytes_at(
    self.data,
    self.oidl_offset + pos * self.hash_size,
    hash_size=self.hash_size,
  )
}

///|
/// Read commit data at position `pos`. Returns (tree_oid, parent_ids, timestamp).
pub fn CommitGraphFile::read_commit(
  self : CommitGraphFile,
  pos : Int,
) -> (@bit.ObjectId, Array[@bit.ObjectId], Int64) {
  let entry = self.cdat_offset + pos * (self.hash_size + 16)
  let tree_oid = @bit.ObjectId::from_bytes_at(
    self.data,
    entry,
    hash_size=self.hash_size,
  )
  let parent1_raw = cgraph_read_u32(self.data, entry + self.hash_size)
  let parent2_raw = cgraph_read_u32(self.data, entry + self.hash_size + 4)
  let gen_and_date = cgraph_read_u32(self.data, entry + self.hash_size + 8)
  let date_low = cgraph_read_u32(self.data, entry + self.hash_size + 12)
  // Timestamp: upper 2 bits from gen_and_date[31:30], lower 32 from date_low
  let date_hi = (gen_and_date >> 30) & 0x3
  let timestamp = (date_hi.to_int64() << 32) |
    date_low.to_int64().land(0xffffffffL)
  // Parents
  let parents : Array[@bit.ObjectId] = []
  if parent1_raw != 0x70000000 {
    // GRAPH_PARENT_NONE = 0x70000000
    parents.push(self.get_oid(parent1_raw))
  }
  if parent2_raw == 0x70000000 {
    // no second parent
    ()
  } else if (parent2_raw & 0x80000000) != 0 {
    // GRAPH_EXTRA_EDGES_NEEDED
    let edge_pos = parent2_raw & 0x7fffffff
    if self.edge_offset > 0 {
      let mut ei = edge_pos
      while true {
        let edge_val = cgraph_read_u32(self.data, self.edge_offset + ei * 4)
        let parent_pos = edge_val & 0x3fffffff
        parents.push(self.get_oid(parent_pos))
        if (edge_val & 0x80000000) != 0 {
          break // GRAPH_LAST_EDGE
        }
        ei += 1
      }
    }
  } else {
    parents.push(self.get_oid(parent2_raw))
  }
  (tree_oid, parents, timestamp)
}

///|
/// Synthesize a commit object from graph data (for fallback when loose/packed missing).
pub fn CommitGraphFile::synthesize_commit_object(
  self : CommitGraphFile,
  pos : Int,
  id : @bit.ObjectId,
) -> @bit.PackObject {
  let (tree_oid, parents, timestamp) = self.read_commit(pos)
  // Build minimal commit content
  let buf = StringBuilder::new()
  buf.write_string("tree ")
  buf.write_string(tree_oid.to_hex())
  buf.write_string("\n")
  for parent in parents {
    buf.write_string("parent ")
    buf.write_string(parent.to_hex())
    buf.write_string("\n")
  }
  buf.write_string("author Unknown <unknown> ")
  buf.write_string(timestamp.to_string())
  buf.write_string(" +0000\n")
  buf.write_string("committer Unknown <unknown> ")
  buf.write_string(timestamp.to_string())
  buf.write_string(" +0000\n")
  buf.write_string("\ncommit-graph synthesized\n")
  let content_str = buf.to_string()
  let content_bytes = @utf8.encode(content_str)
  @bit.PackObject::with_metadata(
    @bit.ObjectType::Commit,
    content_bytes,
    id,
    -1,
    0U,
  )
}

///|
fn cgraph_read_u32(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn cgraph_compare_oid(
  data : Bytes,
  offset : Int,
  target : FixedArray[Byte],
  len : Int,
) -> Int {
  for i = 0; i < len; i = i + 1 {
    let a = data[offset + i].to_int()
    let b = target[i].to_int()
    if a < b {
      return -1
    }
    if a > b {
      return 1
    }
  }
  0
}
