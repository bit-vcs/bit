///| Pack bitmap file reader.

///|
priv struct PackBitmapBits {
  bit_size : Int
  positions : Array[Int]
}

///|
priv struct PackBitmapEntry {
  object_pos : Int
  flags : Int
  positions : Array[Int]
}

///|
priv struct PackBitmap {
  version : Int
  options : Int
  entry_count : Int
  object_count : Int
  pack_checksum : Bytes
  commit_positions : Array[Int]
  tree_positions : Array[Int]
  blob_positions : Array[Int]
  tag_positions : Array[Int]
  entries : Array[PackBitmapEntry]
  name_hashes : Array[Int]
}

///|
fn pack_bitmap_read_u16(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
fn pack_bitmap_verify_trailer(data : Bytes) -> Bool {
  if data.length() < 20 {
    return false
  }
  let body_len = data.length() - 20
  let body = Bytes::from_array(FixedArray::makei(body_len, fn(i) { data[i] }))
  let expected = @bitcore.sha1(body)
  for i in 0..<20 {
    if expected.bytes[i] != data[body_len + i] {
      return false
    }
  }
  true
}

///|
fn pack_bitmap_push_word_positions(
  out : Array[Int],
  word_pos : Int,
  hi : Int,
  lo : Int,
  bit_size : Int,
) -> Unit {
  for bit in 0..<32 {
    let pos = word_pos * 64 + bit
    if pos >= bit_size {
      return
    }
    if (lo & (1 << bit)) != 0 {
      out.push(pos)
    }
  }
  for bit in 0..<32 {
    let pos = word_pos * 64 + 32 + bit
    if pos >= bit_size {
      return
    }
    if (hi & (1 << bit)) != 0 {
      out.push(pos)
    }
  }
}

///|
fn pack_bitmap_push_run_positions(
  out : Array[Int],
  start_word : Int,
  word_count : Int,
  bit_size : Int,
) -> Unit {
  for word_delta in 0..<word_count {
    let base = (start_word + word_delta) * 64
    for bit in 0..<64 {
      let pos = base + bit
      if pos >= bit_size {
        return
      }
      out.push(pos)
    }
  }
}

///|
fn pack_bitmap_read_ewah(
  data : Bytes,
  offset : Int,
  limit : Int,
) -> (PackBitmapBits, Int)? {
  if offset < 0 || limit > data.length() || offset + 12 > limit {
    return None
  }
  let bit_size = midx_read_u32(data, offset)
  let word_count = midx_read_u32(data, offset + 4)
  if bit_size < 0 || word_count < 0 {
    return None
  }
  let words_start = offset + 8
  let words_bytes = word_count * 8
  let words_end = words_start + words_bytes
  if words_bytes < 0 || words_end < words_start || words_end + 4 > limit {
    return None
  }
  let positions : Array[Int] = []
  let mut word_index = 0
  let mut logical_word = 0
  while word_index < word_count {
    let word_offset = words_start + word_index * 8
    let rlw_hi = midx_read_u32(data, word_offset)
    let rlw_lo = midx_read_u32(data, word_offset + 4)
    word_index += 1
    if (rlw_hi & 1) != 0 {
      return None
    }
    let run_bit = (rlw_lo & 1) != 0
    let running_len = (rlw_lo >> 1) & 0x7fffffff
    let literal_words = (rlw_hi >> 1) & 0x7fffffff
    if running_len < 0 || literal_words < 0 {
      return None
    }
    if run_bit {
      pack_bitmap_push_run_positions(
        positions, logical_word, running_len, bit_size,
      )
    }
    logical_word += running_len
    if word_index + literal_words > word_count {
      return None
    }
    for _ in 0..<literal_words {
      let lit_offset = words_start + word_index * 8
      let lit_hi = midx_read_u32(data, lit_offset)
      let lit_lo = midx_read_u32(data, lit_offset + 4)
      pack_bitmap_push_word_positions(
        positions, logical_word, lit_hi, lit_lo, bit_size,
      )
      logical_word += 1
      word_index += 1
    }
  }
  Some(({ bit_size, positions }, words_end + 4))
}

///|
fn pack_bitmap_parse(data : Bytes) -> PackBitmap? {
  if data.length() < 52 {
    return None
  }
  if data[0] != b'B' || data[1] != b'I' || data[2] != b'T' || data[3] != b'M' {
    return None
  }
  if !pack_bitmap_verify_trailer(data) {
    return None
  }
  let body_limit = data.length() - 20
  let version = pack_bitmap_read_u16(data, 4)
  if version != 1 {
    return None
  }
  let options = pack_bitmap_read_u16(data, 6)
  let entry_count = midx_read_u32(data, 8)
  if entry_count < 0 {
    return None
  }
  let pack_checksum = Bytes::from_array(
    FixedArray::makei(20, fn(i) { data[12 + i] }),
  )
  let mut pos = 32
  guard pack_bitmap_read_ewah(data, pos, body_limit) is Some((commits, next)) else {
    return None
  }
  pos = next
  guard pack_bitmap_read_ewah(data, pos, body_limit) is Some((trees, next)) else {
    return None
  }
  pos = next
  guard pack_bitmap_read_ewah(data, pos, body_limit) is Some((blobs, next)) else {
    return None
  }
  pos = next
  guard pack_bitmap_read_ewah(data, pos, body_limit) is Some((tags, next)) else {
    return None
  }
  pos = next
  let object_count = commits.bit_size
  if trees.bit_size != object_count ||
    blobs.bit_size != object_count ||
    tags.bit_size != object_count {
    return None
  }
  let entries : Array[PackBitmapEntry] = []
  for _ in 0..<entry_count {
    if pos + 6 > body_limit {
      return None
    }
    let object_pos = midx_read_u32(data, pos)
    let flags = pack_bitmap_read_u16(data, pos + 4)
    pos += 6
    if object_pos < 0 || object_pos >= object_count {
      return None
    }
    guard pack_bitmap_read_ewah(data, pos, body_limit) is Some((bits, next)) else {
      return None
    }
    if bits.bit_size != object_count {
      return None
    }
    entries.push({ object_pos, flags, positions: bits.positions })
    pos = next
  }
  let name_hashes : Array[Int] = []
  if (options & 4) != 0 {
    let hash_bytes = object_count * 4
    if hash_bytes < 0 || pos + hash_bytes > body_limit {
      return None
    }
    for i in 0..<object_count {
      name_hashes.push(midx_read_u32(data, pos + i * 4))
    }
    pos += hash_bytes
  }
  if pos > body_limit {
    return None
  }
  Some({
    version,
    options,
    entry_count,
    object_count,
    pack_checksum,
    commit_positions: commits.positions,
    tree_positions: trees.positions,
    blob_positions: blobs.positions,
    tag_positions: tags.positions,
    entries,
    name_hashes,
  })
}
