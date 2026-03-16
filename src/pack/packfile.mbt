///| Git packfile generation

///|
/// Helper to convert Array[Byte] to Bytes
fn pack_array_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), i => arr[i]))
}

///|
/// Compress pack data. Use stored when compression expands data.
fn compress_pack_data(
  data : Bytes,
  compression : @bit.PackCompression,
) -> Bytes {
  match compression {
    @bit.PackCompression::Stored => @zlib.zlib_compress_stored(data)
    @bit.PackCompression::Default => {
      // Use fixed Huffman (fast) for pack data, matching git's default level 1
      let deflated = @zlib.deflate_compress_fixed(data)
      let total_len = 2 + deflated.length() + 4
      let result : FixedArray[Byte] = FixedArray::make(total_len, b'\x00')
      result[0] = b'\x78'
      result[1] = b'\x01'
      for i in 0..<deflated.length() {
        result[2 + i] = deflated[i]
      }
      let checksum = @zlib.adler32(data)
      result[total_len - 4] = ((checksum >> 24) & 0xFF).to_byte()
      result[total_len - 3] = ((checksum >> 16) & 0xFF).to_byte()
      result[total_len - 2] = ((checksum >> 8) & 0xFF).to_byte()
      result[total_len - 1] = (checksum & 0xFF).to_byte()
      let compressed = Bytes::from_array(result)
      if compressed.length() > data.length() + 11 {
        @zlib.zlib_compress_stored(data)
      } else {
        compressed
      }
    }
  }
}

///|
fn type_and_size_len(size : Int) -> Int {
  let mut remaining = size >> 4
  let mut len = 1
  while remaining > 0 {
    len += 1
    remaining = remaining >> 7
  }
  len
}

///|
fn ofs_delta_len(back_offset : Int) -> Int {
  let mut count = 1
  let mut val = back_offset
  while val > 0x7f {
    val = (val >> 7) - 1
    count += 1
  }
  count
}

///|
fn encode_ofs_delta_offset(back_offset : Int, result : Array[Byte]) -> Unit {
  let parts : Array[Int] = []
  let mut val = back_offset
  parts.push(val & 0x7f)
  while val > 0x7f {
    val = (val >> 7) - 1
    parts.push(val & 0x7f)
  }
  for i in 0..<parts.length() {
    let idx = parts.length() - 1 - i
    let mut b = parts[idx]
    if i < parts.length() - 1 {
      b = b | 0x80
    }
    result.push(b.to_byte())
  }
}

///|
fn encode_delta_size(value : Int, out : Array[Byte]) -> Unit {
  let mut v = value
  while true {
    let b = v & 0x7f
    v = v >> 7
    if v == 0 {
      out.push(b.to_byte())
      break
    } else {
      out.push((b | 0x80).to_byte())
    }
  }
}

///|
fn encode_delta_insert(
  data : Bytes,
  start : Int,
  len : Int,
  out : Array[Byte],
) -> Unit {
  let mut offset = start
  let mut remaining = len
  while remaining > 0 {
    let chunk = if remaining > 0x7f { 0x7f } else { remaining }
    out.push(chunk.to_byte())
    for i in 0..<chunk {
      out.push(data[offset + i])
    }
    offset = offset + chunk
    remaining = remaining - chunk
  }
}

///|
fn encode_delta_copy_single(
  offset : Int,
  size : Int,
  out : Array[Byte],
) -> Unit {
  let mut op = 0x80
  let buf : Array[Byte] = []
  if (offset & 0xff) != 0 {
    op = op | 0x01
    buf.push((offset & 0xff).to_byte())
  }
  if ((offset >> 8) & 0xff) != 0 {
    op = op | 0x02
    buf.push(((offset >> 8) & 0xff).to_byte())
  }
  if ((offset >> 16) & 0xff) != 0 {
    op = op | 0x04
    buf.push(((offset >> 16) & 0xff).to_byte())
  }
  if ((offset >> 24) & 0xff) != 0 {
    op = op | 0x08
    buf.push(((offset >> 24) & 0xff).to_byte())
  }
  if (size & 0xff) != 0 {
    op = op | 0x10
    buf.push((size & 0xff).to_byte())
  }
  if ((size >> 8) & 0xff) != 0 {
    op = op | 0x20
    buf.push(((size >> 8) & 0xff).to_byte())
  }
  if ((size >> 16) & 0xff) != 0 {
    op = op | 0x40
    buf.push(((size >> 16) & 0xff).to_byte())
  }
  out.push(op.to_byte())
  for b in buf {
    out.push(b)
  }
}

///|
fn encode_delta_copy(offset : Int, size : Int, out : Array[Byte]) -> Unit {
  let max_chunk = 0xffffff
  let mut remaining = size
  let mut off = offset
  while remaining > 0 {
    let chunk = if remaining > max_chunk { max_chunk } else { remaining }
    encode_delta_copy_single(off, chunk, out)
    off = off + chunk
    remaining = remaining - chunk
  }
}

///|
let delta_block_size : Int = 32

///|
fn byte_to_uint(b : Byte) -> UInt {
  Int::reinterpret_as_uint(b.to_int())
}

///|
fn uint_from_int(v : Int) -> UInt {
  Int::reinterpret_as_uint(v)
}

///|
fn rolling_hash_init(data : Bytes, start : Int, len : Int) -> UInt {
  let base = uint_from_int(257)
  let mut h = uint_from_int(0)
  for i in 0..<len {
    h = h * base + byte_to_uint(data[start + i])
  }
  h
}

///|
fn rolling_hash_base_pow(len : Int) -> UInt {
  let base = uint_from_int(257)
  let mut pow = uint_from_int(1)
  for _ in 1..<len {
    pow = pow * base
  }
  pow
}

///|
fn rolling_hash_next(
  hash : UInt,
  base_pow : UInt,
  out_b : Byte,
  in_b : Byte,
) -> UInt {
  let base = uint_from_int(257)
  let removed = byte_to_uint(out_b) * base_pow
  let h1 = hash - removed
  h1 * base + byte_to_uint(in_b)
}

///|
fn build_block_index(
  base : Bytes,
  block_size : Int,
) -> (Map[UInt, Array[Int]], UInt) {
  let base_pow = rolling_hash_base_pow(block_size)
  let index : Map[UInt, Array[Int]] = {}
  if base.length() < block_size {
    return (index, base_pow)
  }
  let mut h = rolling_hash_init(base, 0, block_size)
  let last = base.length() - block_size
  for i = 0; i <= last; i = i + 1 {
    match index.get(h) {
      Some(arr) => arr.push(i)
      None => {
        let arr : Array[Int] = [i]
        index[h] = arr
      }
    }
    if i < last {
      h = rolling_hash_next(h, base_pow, base[i], base[i + block_size])
    }
  }
  (index, base_pow)
}

///|
fn find_best_match(
  base : Bytes,
  target : Bytes,
  target_pos : Int,
  block_size : Int,
  candidates : Array[Int],
) -> (Int, Int)? {
  let mut best_len = 0
  let mut best_off = 0
  let mut checked = 0
  let max_candidates = 32
  for off in candidates {
    if off + block_size > base.length() {
      continue
    }
    // Quick 4-byte prefix check before full comparison
    if base[off] != target[target_pos] ||
      base[off + 1] != target[target_pos + 1] {
      checked += 1
      if checked >= max_candidates {
        break
      }
      continue
    }
    let mut ok = true
    for i = 2; i < block_size; i = i + 1 {
      if base[off + i] != target[target_pos + i] {
        ok = false
        break
      }
    }
    if ok {
      let mut len = block_size
      while target_pos + len < target.length() &&
        off + len < base.length() &&
        base[off + len] == target[target_pos + len] {
        len += 1
      }
      if len > best_len {
        best_len = len
        best_off = off
        // Good enough match: skip remaining candidates
        if best_len >= block_size * 2 {
          break
        }
      }
    }
    checked += 1
    if checked >= max_candidates {
      break
    }
  }
  if best_len >= block_size {
    Some((best_off, best_len))
  } else {
    None
  }
}

///|
fn build_delta_with_index(
  base : Bytes,
  target : Bytes,
  index : Map[UInt, Array[Int]],
  base_pow : UInt,
) -> Bytes {
  let base_len = base.length()
  let target_len = target.length()
  let out : Array[Byte] = []
  encode_delta_size(base_len, out)
  encode_delta_size(target_len, out)
  if target_len == 0 {
    return Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
  }
  if base_len < delta_block_size || target_len < delta_block_size {
    encode_delta_insert(target, 0, target_len, out)
    return Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
  }
  let mut t = 0
  let mut literal_start = 0
  let mut literal_len = 0
  let last = target_len - delta_block_size
  let mut th = rolling_hash_init(target, 0, delta_block_size)
  while t <= last {
    let matched = match index.get(th) {
      None => None
      Some(cands) => find_best_match(base, target, t, delta_block_size, cands)
    }
    match matched {
      Some((base_off, match_len)) => {
        if literal_len > 0 {
          encode_delta_insert(target, literal_start, literal_len, out)
          literal_len = 0
        }
        encode_delta_copy(base_off, match_len, out)
        t = t + match_len
        literal_start = t
        if t <= last {
          th = rolling_hash_init(target, t, delta_block_size)
        }
      }
      None => {
        if literal_len == 0 {
          literal_start = t
        }
        literal_len += 1
        if t < last {
          th = rolling_hash_next(
            th,
            base_pow,
            target[t],
            target[t + delta_block_size],
          )
        }
        t = t + 1
      }
    }
  }
  if t < target_len {
    let tail_len = target_len - t
    if literal_len == 0 {
      literal_start = t
      literal_len = tail_len
    } else if literal_start + literal_len == t {
      literal_len = literal_len + tail_len
    } else {
      encode_delta_insert(target, literal_start, literal_len, out)
      literal_start = t
      literal_len = tail_len
    }
  }
  if literal_len > 0 {
    encode_delta_insert(target, literal_start, literal_len, out)
  }
  Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
}

///|
fn build_delta(base : Bytes, target : Bytes) -> Bytes {
  let (index, base_pow) = build_block_index(base, delta_block_size)
  build_delta_with_index(base, target, index, base_pow)
}

///|
pub fn build_delta_pub(base : Bytes, target : Bytes) -> Bytes {
  build_delta(base, target)
}

///|
priv struct DeltaWindowEntry {
  offset : Int
  obj : @bit.PackObject
  depth : Int
  mut block_index : (Map[UInt, Array[Int]], UInt)?
}

///|
fn pack_object_with_delta(
  obj : @bit.PackObject,
  base : (Int, @bit.PackObject)?,
  obj_offset : Int,
  result : Array[Byte],
  delta_mode : @bit.PackDeltaMode,
  compression : @bit.PackCompression,
  precomputed_delta : Bytes?,
) -> (Int, Bool) {
  let obj_type = obj.obj_type.to_packfile_type()
  let data = obj.data
  // NoDelta or no base: compress normally
  let try_delta = match delta_mode {
    @bit.PackDeltaMode::NoDelta => false
    _ =>
      match base {
        Some((base_offset, base_obj)) =>
          base_offset < obj_offset && base_obj.obj_type == obj.obj_type
        None => false
      }
  }
  if not(try_delta) {
    let compressed = compress_pack_data(data, compression)
    let normal_len = type_and_size_len(data.length()) + compressed.length()
    encode_type_and_size(obj_type, data.length(), result)
    for b in compressed {
      result.push(b)
    }
    return (normal_len, false)
  }
  // Delta path: compute delta first, only compress normal if delta loses
  let (base_offset, base_obj) = base.unwrap()
  let delta = match precomputed_delta {
    Some(d) => d
    None => build_delta(base_obj.data, data)
  }
  let compressed_delta = compress_pack_data(delta, compression)
  // Estimate delta overhead
  let delta_overhead = match delta_mode {
    @bit.PackDeltaMode::OfsDelta => {
      let back_offset = obj_offset - base_offset
      type_and_size_len(delta.length()) + ofs_delta_len(back_offset)
    }
    @bit.PackDeltaMode::RefDelta => type_and_size_len(delta.length()) + 20
    @bit.PackDeltaMode::NoDelta => 0 // unreachable
  }
  let delta_total = delta_overhead + compressed_delta.length()
  // Quick upper bound: if delta is already smaller than raw data header + raw,
  // we can skip normal compression entirely
  let normal_upper = type_and_size_len(data.length()) + data.length()
  if delta_total < normal_upper {
    // Delta wins without needing normal compression
    match delta_mode {
      @bit.PackDeltaMode::OfsDelta => {
        let back_offset = obj_offset - base_offset
        encode_type_and_size(6, delta.length(), result)
        encode_ofs_delta_offset(back_offset, result)
        for b in compressed_delta {
          result.push(b)
        }
        return (delta_total, true)
      }
      @bit.PackDeltaMode::RefDelta => {
        let base_id = @bit.hash_object_content(base_obj.obj_type, base_obj.data)
        encode_type_and_size(7, delta.length(), result)
        for b in base_id.bytes {
          result.push(b)
        }
        for b in compressed_delta {
          result.push(b)
        }
        return (delta_total, true)
      }
      @bit.PackDeltaMode::NoDelta => () // unreachable
    }
  }
  // Delta might not win — need to compare against normal compression
  let compressed = compress_pack_data(data, compression)
  let normal_len = type_and_size_len(data.length()) + compressed.length()
  if delta_total < normal_len {
    match delta_mode {
      @bit.PackDeltaMode::OfsDelta => {
        let back_offset = obj_offset - base_offset
        encode_type_and_size(6, delta.length(), result)
        encode_ofs_delta_offset(back_offset, result)
        for b in compressed_delta {
          result.push(b)
        }
        return (delta_total, true)
      }
      @bit.PackDeltaMode::RefDelta => {
        let base_id = @bit.hash_object_content(base_obj.obj_type, base_obj.data)
        encode_type_and_size(7, delta.length(), result)
        for b in base_id.bytes {
          result.push(b)
        }
        for b in compressed_delta {
          result.push(b)
        }
        return (delta_total, true)
      }
      @bit.PackDeltaMode::NoDelta => () // unreachable
    }
  }
  // Normal wins
  encode_type_and_size(obj_type, data.length(), result)
  for b in compressed {
    result.push(b)
  }
  (normal_len, false)
}

///|
/// Create a packfile from a list of objects
/// Format:
///   [PACK]           4 bytes magic
///   [version]        4 bytes (big-endian, always 2)
///   [object count]   4 bytes (big-endian)
///   [...objects...]  variable
///   [SHA-1 trailer]  20 bytes
pub fn create_packfile(objects : Array[@bit.PackObject]) -> Bytes {
  create_packfile_with_delta(objects, @bit.PackDeltaMode::OfsDelta)
}

///|
/// Create a packfile from a list of objects with a chosen delta mode
pub fn create_packfile_with_delta(
  objects : Array[@bit.PackObject],
  delta_mode : @bit.PackDeltaMode,
) -> Bytes {
  let (pack, _) = create_packfile_with_delta_stats(objects, delta_mode)
  pack
}

///|
/// Create a packfile with delta statistics (delta object count)
pub fn create_packfile_with_delta_stats(
  objects : Array[@bit.PackObject],
  delta_mode : @bit.PackDeltaMode,
) -> (Bytes, Int) {
  create_packfile_with_delta_stats_compression(
    objects,
    delta_mode,
    @bit.PackCompression::Default,
  )
}

///|
/// Create a packfile with delta statistics and compression mode
pub fn create_packfile_with_delta_stats_compression(
  objects : Array[@bit.PackObject],
  delta_mode : @bit.PackDeltaMode,
  compression : @bit.PackCompression,
) -> (Bytes, Int) {
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

  // Pack each object with sliding window for delta base selection.
  // Window keeps recent objects of same type for better delta matches.
  let mut offset = 12
  let window_by_type : Map[Int, Array[DeltaWindowEntry]] = {}
  let window_size = 10
  let mut delta_count = 0
  for obj in objects {
    let obj_offset = offset
    let key = obj.obj_type.to_packfile_type()
    let window = match window_by_type.get(key) {
      Some(w) => w
      None => {
        let w : Array[DeltaWindowEntry] = []
        window_by_type[key] = w
        w
      }
    }
    // Find best delta base from window (smallest delta wins)
    let mut best_base : (Int, @bit.PackObject)? = None
    let mut best_delta : Bytes? = None
    let mut best_delta_size = obj.data.length() // upper bound: raw size
    let try_window = match delta_mode {
      @bit.PackDeltaMode::NoDelta => false
      _ => window.length() > 0
    }
    if try_window {
      // Try most recent first (best locality), early exit if delta < 50% of raw
      let half_raw = obj.data.length() / 2
      let mut wi = window.length() - 1
      while wi >= 0 {
        let entry = window[wi]
        wi -= 1
        if entry.offset >= obj_offset {
          continue
        }
        // Size heuristic: skip if base size is vastly different (>4x or <1/4)
        let base_size = entry.obj.data.length()
        let target_size = obj.data.length()
        if base_size > target_size * 4 || target_size > base_size * 4 {
          continue
        }
        // Build block index (cached per window entry)
        let (idx, bpow) = match entry.block_index {
          Some(cached) => cached
          None => {
            let built = build_block_index(entry.obj.data, delta_block_size)
            entry.block_index = Some(built)
            built
          }
        }
        let delta = build_delta_with_index(entry.obj.data, obj.data, idx, bpow)
        if delta.length() < best_delta_size {
          best_delta_size = delta.length()
          best_base = Some((entry.offset, entry.obj))
          best_delta = Some(delta)
          // Early exit if delta is already good enough
          if best_delta_size < half_raw {
            break
          }
        }
      }
    }
    let (written, used_delta) = pack_object_with_delta(
      obj, best_base, obj_offset, result, delta_mode, compression, best_delta,
    )
    offset = offset + written
    if used_delta {
      delta_count = delta_count + 1
    }
    // Add to window, evict oldest if full
    window.push({ offset: obj_offset, obj, depth: 0, block_index: None })
    if window.length() > window_size {
      ignore(window.remove(0))
    }
  }

  // Compute SHA-1 of everything so far
  let trailer = @bit.sha1_array_prefix(result, result.length())

  // Append trailer
  for b in trailer.bytes {
    result.push(b)
  }
  (pack_array_to_bytes(result), delta_count)
}

///|
/// Write PACK header (magic + version 2 + placeholder object count)
fn write_pack_header(result : Array[Byte]) -> Unit {
  result.push(b'P')
  result.push(b'A')
  result.push(b'C')
  result.push(b'K')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x02')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
}

///|
/// Fix up the object count in a PACK header (bytes 8-11)
fn fixup_pack_header_count(result : Array[Byte], count : Int) -> Unit {
  result[8] = ((count >> 24) & 0xff).to_byte()
  result[9] = ((count >> 16) & 0xff).to_byte()
  result[10] = ((count >> 8) & 0xff).to_byte()
  result[11] = (count & 0xff).to_byte()
}

///|
/// Finalize a pack: fix header count, compute and append SHA-1 trailer
fn finalize_pack(result : Array[Byte], count : Int) -> Bytes {
  fixup_pack_header_count(result, count)
  let trailer = @bit.sha1_array_prefix(result, result.length())
  for b in trailer.bytes {
    result.push(b)
  }
  pack_array_to_bytes(result)
}

///|
/// Create multiple packfiles respecting a size limit.
/// Objects are written one by one; when adding an object would cause the
/// pack (including the 20-byte SHA-1 trailer) to reach or exceed
/// `size_limit`, the current pack is finalized and a new one is started.
/// The first object in each pack is always written regardless of size.
pub fn create_packfiles_with_size_limit(
  objects : Array[@bit.PackObject],
  delta_mode : @bit.PackDeltaMode,
  compression : @bit.PackCompression,
  reuse_only : Bool,
  max_depth : Int,
  size_limit : Int64,
  window : Int,
) -> (Array[Bytes], Int) {
  let packs : Array[Bytes] = []
  let mut total_delta_count = 0
  if objects.length() == 0 {
    packs.push(
      finalize_pack(
        {
          let r : Array[Byte] = []
          write_pack_header(r)
          r
        },
        0,
      ),
    )
    return (packs, 0)
  }
  // No sort — caller manages insertion order for size_limit packs
  let window_size = if window > 0 { window } else { 1 }
  let mut result : Array[Byte] = []
  write_pack_header(result)
  let mut offset = 12
  let mut nr_written = 0
  let window_by_type : Map[Int, Array[DeltaWindowEntry]] = {}
  for obj in objects {
    let key = obj.obj_type.to_packfile_type()
    let entries = match window_by_type.get(key) {
      Some(arr) => arr
      None => {
        let arr : Array[DeltaWindowEntry] = []
        window_by_type[key] = arr
        arr
      }
    }
    // Find best delta from window
    let can_delta = max_depth > 0 &&
      (match delta_mode {
        @bit.PackDeltaMode::NoDelta => false
        _ => true
      })
    let mut best : (Int, @bit.PackObject, Bytes, Int)? = None
    let mut best_size = obj.data.length()
    if can_delta {
      for i = entries.length() - 1; i >= 0; i = i - 1 {
        let e = entries[i]
        if e.depth >= max_depth {
          continue
        }
        if reuse_only && (obj.offset < 0 || e.obj.offset < 0) {
          continue
        }
        let (idx, pow) = match e.block_index {
          Some(cached) => cached
          None => {
            let r = build_block_index(e.obj.data, delta_block_size)
            e.block_index = Some(r)
            r
          }
        }
        let delta = build_delta_with_index(e.obj.data, obj.data, idx, pow)
        if delta.length() < best_size {
          best_size = delta.length()
          best = Some((e.offset, e.obj, delta, e.depth))
          if delta.length() < obj.data.length() / 2 {
            break
          }
        }
      }
    }
    let (base, precomputed) : ((Int, @bit.PackObject)?, Bytes?) = match best {
      Some((bo, bobj, delta, _)) => (Some((bo, bobj)), Some(delta))
      None => (None, None)
    }
    let best_depth = match best {
      Some((_, _, _, d)) => d
      None => 0
    }
    let mode = match best {
      Some(_) => delta_mode
      None => @bit.PackDeltaMode::NoDelta
    }
    // Pack object into a temporary buffer to measure its packed size
    let temp : Array[Byte] = []
    let (written, used_delta) = pack_object_with_delta(
      obj, base, offset, temp, mode, compression, precomputed,
    )
    // Check whether adding this object would bust the size limit
    if nr_written >= 1 && (offset + written + 20).to_int64() >= size_limit {
      // Finalize current pack
      packs.push(finalize_pack(result, nr_written))
      // Start a new pack
      result = []
      write_pack_header(result)
      offset = 12
      nr_written = 0
      window_by_type.clear()
      // Re-write the object without delta (base is in previous pack)
      let (written2, _) = pack_object_with_delta(
        obj,
        None,
        12,
        result,
        @bit.PackDeltaMode::NoDelta,
        compression,
        None,
      )
      offset = 12 + written2
      let new_entries : Array[DeltaWindowEntry] = []
      new_entries.push({ offset: 12, obj, depth: 0, block_index: None })
      window_by_type[key] = new_entries
      nr_written = 1
    } else {
      // Object fits – append temp bytes to current pack
      for b in temp {
        result.push(b)
      }
      if used_delta {
        total_delta_count += 1
      }
      let next_depth = if used_delta { best_depth + 1 } else { 0 }
      entries.push({ offset, obj, depth: next_depth, block_index: None })
      if entries.length() > window_size {
        ignore(entries.remove(0))
      }
      offset += written
      nr_written += 1
    }
  }
  // Finalize last pack
  if nr_written > 0 {
    packs.push(finalize_pack(result, nr_written))
  }
  (packs, total_delta_count)
}

///|
/// Create a packfile with delta stats, optional delta reuse, and depth limit
pub fn create_packfile_with_delta_stats_compression_reuse(
  objects : Array[@bit.PackObject],
  delta_mode : @bit.PackDeltaMode,
  compression : @bit.PackCompression,
  reuse_only : Bool,
  max_depth : Int,
  window : Int,
) -> (Bytes, Int) {
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

  // Sort objects: type asc, size desc (improves delta compression)
  let sorted = objects.copy()
  sorted.sort_by(fn(a, b) {
    let at = a.obj_type.to_packfile_type()
    let bt = b.obj_type.to_packfile_type()
    if at != bt {
      at - bt
    } else {
      b.data.length() - a.data.length()
    }
  })

  // Pack each object with sliding window delta search
  let window_size = if window > 0 { window } else { 1 }
  let mut offset = 12
  let window_by_type : Map[Int, Array[DeltaWindowEntry]] = {}
  let mut delta_count = 0
  for obj in sorted {
    let obj_offset = offset
    let key = obj.obj_type.to_packfile_type()
    let entries = match window_by_type.get(key) {
      Some(arr) => arr
      None => {
        let arr : Array[DeltaWindowEntry] = []
        window_by_type[key] = arr
        arr
      }
    }
    // Find best delta from window
    let can_delta = max_depth > 0 &&
      (match delta_mode {
        @bit.PackDeltaMode::NoDelta => false
        _ => true
      })
    let mut best : (Int, @bit.PackObject, Bytes, Int)? = None
    let mut best_size = obj.data.length()
    if can_delta {
      for i = entries.length() - 1; i >= 0; i = i - 1 {
        let e = entries[i]
        if e.depth >= max_depth {
          continue
        }
        if reuse_only && (obj.offset < 0 || e.obj.offset < 0) {
          continue
        }
        let (idx, pow) = match e.block_index {
          Some(cached) => cached
          None => {
            let r = build_block_index(e.obj.data, delta_block_size)
            e.block_index = Some(r)
            r
          }
        }
        let delta = build_delta_with_index(e.obj.data, obj.data, idx, pow)
        if delta.length() < best_size {
          best_size = delta.length()
          best = Some((e.offset, e.obj, delta, e.depth))
          if delta.length() < obj.data.length() / 2 {
            break
          }
        }
      }
    }
    let (base, precomputed) : ((Int, @bit.PackObject)?, Bytes?) = match best {
      Some((bo, bobj, delta, _)) => (Some((bo, bobj)), Some(delta))
      None => (None, None)
    }
    let best_depth = match best {
      Some((_, _, _, d)) => d
      None => 0
    }
    let mode = match best {
      Some(_) => delta_mode
      None => @bit.PackDeltaMode::NoDelta
    }
    let (written, used_delta) = pack_object_with_delta(
      obj, base, obj_offset, result, mode, compression, precomputed,
    )
    offset = offset + written
    if used_delta {
      delta_count = delta_count + 1
    }
    let next_depth = if used_delta { best_depth + 1 } else { 0 }
    entries.push({
      offset: obj_offset,
      obj,
      depth: next_depth,
      block_index: None,
    })
    if entries.length() > window_size {
      ignore(entries.remove(0))
    }
  }

  // Compute SHA-1 of everything so far
  let trailer = @bit.sha1_array_prefix(result, result.length())

  // Append trailer
  for b in trailer.bytes {
    result.push(b)
  }
  (pack_array_to_bytes(result), delta_count)
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
  let obj = @bit.PackObject::new(@bit.ObjectType::Blob, content)
  create_packfile([obj])
}

///|
/// Create a packfile with blob, tree, and commit
pub fn create_commit_packfile(
  blob_content : Bytes,
  filename : String,
  commit : @bit.Commit,
) -> (@bit.ObjectId, Bytes) {
  // Create blob
  let (blob_id, _) = @bit.create_blob(blob_content)

  // Create tree with single entry
  let entry = @bit.TreeEntry::new("100644", filename, blob_id)
  let (tree_id, _) = @bit.create_tree([entry])

  // Update commit with correct tree
  let final_commit = @bit.Commit::new(
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
  let (commit_id, _) = @bit.create_commit(final_commit)

  // Build pack objects (raw content, not git object format)
  let pack_objects = [
    @bit.PackObject::new(@bit.ObjectType::Blob, blob_content),
    @bit.PackObject::new(@bit.ObjectType::Tree, build_tree_content([entry])),
    @bit.PackObject::new(
      @bit.ObjectType::Commit,
      build_commit_content(final_commit),
    ),
  ]
  let packfile = create_packfile(pack_objects)
  (commit_id, packfile)
}

///|
/// Build raw tree content (without "tree {size}\0" header)
fn build_tree_content(entries : Array[@bit.TreeEntry]) -> Bytes {
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
fn build_commit_content(commit : @bit.Commit) -> Bytes {
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
