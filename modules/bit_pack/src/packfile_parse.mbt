///| Packfile parsing (deflate + delta)

///|
/// Hard cap on the inflated size of a single pack-encoded object, in
/// bytes. The per-object size header is taken from untrusted pack
/// bytes, so we refuse to call `zlib_decompress_at` if the claimed
/// size is unreasonable — otherwise an attacker can hand us a small
/// pack whose entries claim multi-gigabyte inflated sizes, OOMing
/// the process before any other check fires.
///
/// 2 GiB matches `git`'s effective ceiling on 32-bit size fields.
/// If/when we expose this as `BIT_MAX_OBJECT_SIZE`, the const becomes
/// the default.
const MAX_PACK_OBJECT_SIZE : Int = 0x7fff_ffff

///|
fn check_pack_object_size(size : Int) -> Unit raise @bit.GitError {
  if size < 0 || size > MAX_PACK_OBJECT_SIZE {
    raise @bit.GitError::PackfileError(
      "Pack object size out of range: \{size} (max \{MAX_PACK_OBJECT_SIZE})",
    )
  }
}

///|
/// Hard cap on the delta chain length for a single pack-encoded
/// object. Matches git's runtime ceiling (50). Resolving a delta
/// chain is iterative here, so depth doesn't blow the stack; the
/// concern is the per-step `apply_delta` cost — at depth 1000+ a
/// hostile pack can drag parsing into the seconds-per-object range.
///
/// OFS_DELTA cycles are impossible by construction (base_offset is
/// strictly less than the current offset, enforced earlier).
/// REF_DELTA cycles are caught by the iterative `progress` flag and
/// leave entries unresolved — but the resolved-chain depth is the
/// remaining bound.
const MAX_DELTA_DEPTH : Int = 50

///|
fn check_delta_depth(depth : Int) -> Unit raise @bit.GitError {
  if depth > MAX_DELTA_DEPTH {
    raise @bit.GitError::PackfileError(
      "Delta chain too deep: \{depth} (max \{MAX_DELTA_DEPTH})",
    )
  }
}

///|
fn hash_algo_from_size(hash_size : Int) -> @bit.HashAlgorithm {
  if hash_size == 32 {
    @bit.HashAlgorithm::Sha256
  } else {
    @bit.HashAlgorithm::Sha1
  }
}

///|
/// Parse a packfile into objects.
pub fn parse_packfile(
  data : Bytes,
  verify_checksum? : Bool = true,
  hash_size? : Int = 20,
) -> Array[@bit.PackObject] raise @bit.GitError {
  parse_packfile_with_bases(data, [], verify_checksum~, hash_size~)
}

///|
/// Compute the maximum delta chain length in a packfile
pub fn max_delta_chain_length(
  data : Bytes,
  hash_size? : Int = 20,
) -> Int raise @bit.GitError {
  if data.length() < 32 {
    raise @bit.GitError::PackfileError("Packfile too short")
  }
  if !(data[0] == b'P' && data[1] == b'A' && data[2] == b'C' && data[3] == b'K') {
    raise @bit.GitError::PackfileError("Invalid packfile magic")
  }
  let version = read_u32_be(data, 4)
  if version != 2 {
    raise @bit.GitError::PackfileError(
      "Unsupported packfile version: \{version}",
    )
  }
  let count = read_u32_be(data, 8)
  let mut offset = 12
  let objects : Array[@bit.PackObject] = []
  let resolved : Array[Bool] = []
  let depths : Array[Int] = []
  let pending : Array[PendingDelta] = []
  let by_offset : Map[Int, Int] = {}
  let by_id : Map[@bit.ObjectId, @bit.PackObject] = {}
  let by_id_depth : Map[@bit.ObjectId, Int] = {}
  let mut max_depth = 0
  for _ in 0..<count {
    let obj_offset = offset
    let (type_id, size, next_offset) = decode_type_and_size_at(data, offset)
    check_pack_object_size(size)
    offset = next_offset
    let (obj_type, content, after) = match type_id {
      1 | 2 | 3 | 4 => {
        let obj_type = packfile_type_to_object_type(type_id)
        let (content, after) = @zlib.zlib_decompress_at(
          data,
          offset,
          max_size=size,
        ) catch {
          e => raise @bit.GitError::PackfileError("Zlib error: \{e}")
        }
        if content.length() != size {
          raise @bit.GitError::PackfileError(
            "Object size mismatch: expected=\{size}, got=\{content.length()}",
          )
        }
        (obj_type, content, after)
      }
      6 => {
        let (back_offset, after_ref) = read_ofs_delta_offset(data, offset)
        let base_offset = obj_offset - back_offset
        if base_offset < 0 {
          raise @bit.GitError::PackfileError("Invalid OFS_DELTA base offset")
        }
        let (delta, after) = @zlib.zlib_decompress_at(
          data,
          after_ref,
          max_size=size,
        ) catch {
          e => raise @bit.GitError::PackfileError("Zlib error: \{e}")
        }
        if delta.length() != size {
          raise @bit.GitError::PackfileError(
            "Delta size mismatch: expected=\{size}, got=\{delta.length()}",
          )
        }
        let crc = crc32_range(data, obj_offset, after)
        let placeholder = @bit.PackObject::with_metadata(
          @bit.ObjectType::Blob,
          Bytes::from_array([]),
          @bit.ObjectId::zero(),
          obj_offset,
          crc,
        )
        objects.push(placeholder)
        resolved.push(false)
        depths.push(0)
        let idx = objects.length() - 1
        by_offset[obj_offset] = idx
        match by_offset.get(base_offset) {
          Some(base_index) =>
            if base_index >= 0 &&
              base_index < objects.length() &&
              resolved[base_index] {
              let base = objects[base_index]
              let content = apply_delta(base.data, delta)
              let obj_id = @bit.hash_object_content_with_algo(
                hash_algo_from_size(hash_size),
                base.obj_type,
                content,
              )
              let obj = @bit.PackObject::with_metadata(
                base.obj_type,
                content,
                obj_id,
                obj_offset,
                crc,
              )
              objects[idx] = obj
              resolved[idx] = true
              let depth = depths[base_index] + 1
              check_delta_depth(depth)
              depths[idx] = depth
              if depth > max_depth {
                max_depth = depth
              }
              insert_pack_object_by_id(by_id, obj)
              by_id_depth[obj_id] = depth
            } else {
              pending.push({
                index: idx,
                base: DeltaBaseRef::Ofs(base_index),
                delta,
              })
            }
          None =>
            raise @bit.GitError::PackfileError(
              "Missing base object for OFS_DELTA",
            )
        }
        (@bit.ObjectType::Blob, Bytes::from_array([]), after)
      }
      7 => {
        let (base_oid, after_ref) = read_ref_delta_object_id(
          data,
          offset,
          hash_size~,
        )
        let (delta, after) = @zlib.zlib_decompress_at(
          data,
          after_ref,
          max_size=size,
        ) catch {
          e => raise @bit.GitError::PackfileError("Zlib error: \{e}")
        }
        if delta.length() != size {
          raise @bit.GitError::PackfileError(
            "Delta size mismatch: expected=\{size}, got=\{delta.length()}",
          )
        }
        let crc = crc32_range(data, obj_offset, after)
        let placeholder = @bit.PackObject::with_metadata(
          @bit.ObjectType::Blob,
          Bytes::from_array([]),
          @bit.ObjectId::zero(),
          obj_offset,
          crc,
        )
        objects.push(placeholder)
        resolved.push(false)
        depths.push(0)
        let idx = objects.length() - 1
        by_offset[obj_offset] = idx
        match by_id.get(base_oid) {
          Some(base) => {
            let content = apply_delta(base.data, delta)
            let obj_id = @bit.hash_object_content_with_algo(
              hash_algo_from_size(hash_size),
              base.obj_type,
              content,
            )
            let obj = @bit.PackObject::with_metadata(
              base.obj_type,
              content,
              obj_id,
              obj_offset,
              crc,
            )
            objects[idx] = obj
            resolved[idx] = true
            let base_depth = by_id_depth.get(base_oid).unwrap_or(0)
            let depth = base_depth + 1
            check_delta_depth(depth)
            depths[idx] = depth
            if depth > max_depth {
              max_depth = depth
            }
            insert_pack_object_by_id(by_id, obj)
            by_id_depth[obj_id] = depth
          }
          None =>
            pending.push({
              index: idx,
              base: DeltaBaseRef::Ref(base_oid),
              delta,
            })
        }
        (@bit.ObjectType::Blob, Bytes::from_array([]), after)
      }
      _ =>
        raise @bit.GitError::PackfileError(
          "Unknown packfile object type: \{type_id}",
        )
    }
    offset = after
    if type_id == 1 || type_id == 2 || type_id == 3 || type_id == 4 {
      let crc = crc32_range(data, obj_offset, after)
      let obj_id = @bit.hash_object_content_with_algo(
        hash_algo_from_size(hash_size),
        obj_type,
        content,
      )
      let obj = @bit.PackObject::with_metadata(
        obj_type, content, obj_id, obj_offset, crc,
      )
      objects.push(obj)
      resolved.push(true)
      depths.push(0)
      by_offset[obj_offset] = objects.length() - 1
      insert_pack_object_by_id(by_id, obj)
      by_id_depth[obj_id] = 0
    }
  }
  let mut progress = true
  let mut pending_list = pending
  while pending_list.length() > 0 && progress {
    progress = false
    let next_pending : Array[PendingDelta] = []
    for p in pending_list {
      match p.base {
        DeltaBaseRef::Ofs(base_index) =>
          if base_index >= 0 &&
            base_index < objects.length() &&
            resolved[base_index] {
            let base = objects[base_index]
            let content = apply_delta(base.data, p.delta)
            let obj_id = @bit.hash_object_content_with_algo(
              hash_algo_from_size(hash_size),
              base.obj_type,
              content,
            )
            let old = objects[p.index]
            let obj = @bit.PackObject::with_metadata(
              base.obj_type,
              content,
              obj_id,
              old.offset,
              old.crc32,
            )
            objects[p.index] = obj
            resolved[p.index] = true
            let depth = depths[base_index] + 1
            check_delta_depth(depth)
            depths[p.index] = depth
            if depth > max_depth {
              max_depth = depth
            }
            insert_pack_object_by_id(by_id, obj)
            by_id_depth[obj_id] = depth
            progress = true
          } else {
            next_pending.push(p)
          }
        DeltaBaseRef::Ref(base_oid) =>
          match by_id.get(base_oid) {
            Some(base) => {
              let content = apply_delta(base.data, p.delta)
              let obj_id = @bit.hash_object_content_with_algo(
                hash_algo_from_size(hash_size),
                base.obj_type,
                content,
              )
              let old = objects[p.index]
              let obj = @bit.PackObject::with_metadata(
                base.obj_type,
                content,
                obj_id,
                old.offset,
                old.crc32,
              )
              objects[p.index] = obj
              resolved[p.index] = true
              let base_depth = by_id_depth.get(base_oid).unwrap_or(0)
              let depth = base_depth + 1
              check_delta_depth(depth)
              depths[p.index] = depth
              if depth > max_depth {
                max_depth = depth
              }
              insert_pack_object_by_id(by_id, obj)
              by_id_depth[obj_id] = depth
              progress = true
            }
            None => next_pending.push(p)
          }
      }
    }
    pending_list = next_pending
  }
  if pending_list.length() > 0 {
    raise @bit.GitError::PackfileError("Unresolved delta objects")
  }
  let trailer_offset = data.length() - hash_size
  if offset != trailer_offset {
    raise @bit.GitError::PackfileError("Packfile length mismatch")
  }
  let computed = @bit.hash_prefix(data, trailer_offset, hash_size~)
  let trailer = read_trailer_id(data, trailer_offset, hash_size~)
  if computed != trailer {
    raise @bit.GitError::HashMismatch(computed.to_hex(), trailer.to_hex())
  }
  max_depth
}

///|
/// Parse a packfile with preloaded base objects (for thin packs).
pub fn parse_packfile_with_bases(
  data : Bytes,
  bases : Array[@bit.PackObject],
  verify_checksum? : Bool = true,
  hash_size? : Int = 20,
) -> Array[@bit.PackObject] raise @bit.GitError {
  let by_offset : Map[Int, Int] = {}
  let by_id : Map[@bit.ObjectId, @bit.PackObject] = {}
  for obj in bases {
    let id = @bit.hash_object_content_with_algo(
      hash_algo_from_size(hash_size),
      obj.obj_type,
      obj.data,
    )
    let base_obj = @bit.PackObject::with_metadata(
      obj.obj_type,
      obj.data,
      id,
      obj.offset,
      obj.crc32,
    )
    insert_pack_object_by_id(by_id, base_obj)
  }
  parse_packfile_internal(data, by_offset, by_id, verify_checksum~, hash_size~)
}

///|
/// Parse a packfile and emit resolved objects (order not guaranteed).
pub fn parse_packfile_stream(
  data : Bytes,
  emit : (@bit.PackObject) -> Unit,
  verify_checksum? : Bool = true,
  hash_size? : Int = 20,
) -> Unit raise @bit.GitError {
  parse_packfile_stream_with_bases(data, [], emit, verify_checksum~, hash_size~)
}

///|
/// Parse a packfile with base objects and emit resolved objects.
pub fn parse_packfile_stream_with_bases(
  data : Bytes,
  bases : Array[@bit.PackObject],
  emit : (@bit.PackObject) -> Unit,
  verify_checksum? : Bool = true,
  hash_size? : Int = 20,
) -> Unit raise @bit.GitError {
  let by_offset : Map[Int, @bit.PackObject] = {}
  let by_id : Map[@bit.ObjectId, @bit.PackObject] = {}
  for obj in bases {
    let id = @bit.hash_object_content_with_algo(
      hash_algo_from_size(hash_size),
      obj.obj_type,
      obj.data,
    )
    let base_obj = @bit.PackObject::with_metadata(
      obj.obj_type,
      obj.data,
      id,
      obj.offset,
      obj.crc32,
    )
    insert_pack_object_by_id(by_id, base_obj)
  }
  parse_packfile_stream_internal(
    data,
    by_offset,
    by_id,
    emit,
    verify_checksum~,
    hash_size~,
  )
}

///|
fn insert_pack_object_by_id(
  by_id : Map[@bit.ObjectId, @bit.PackObject],
  obj : @bit.PackObject,
) -> Unit raise @bit.GitError {
  match by_id.get(obj.id) {
    Some(existing) =>
      if existing.obj_type != obj.obj_type ||
        !Bytes::equal(existing.data, obj.data) {
        raise @bit.GitError::PackfileError("SHA1 COLLISION FOUND")
      }
    None => ()
  }
  by_id[obj.id] = obj
}

///|
priv enum DeltaBaseRef {
  Ofs(Int)
  Ref(@bit.ObjectId)
}

///|
priv struct PendingDelta {
  index : Int
  base : DeltaBaseRef
  delta : Bytes
}

///|
priv struct PendingDeltaStream {
  offset : Int
  base : DeltaBaseRef
  delta : Bytes
}

///|
fn parse_packfile_internal(
  data : Bytes,
  by_offset : Map[Int, Int],
  by_id : Map[@bit.ObjectId, @bit.PackObject],
  verify_checksum? : Bool = true,
  hash_size? : Int = 20,
) -> Array[@bit.PackObject] raise @bit.GitError {
  if data.length() < 32 {
    raise @bit.GitError::PackfileError("Packfile too short")
  }

  // Magic: "PACK"
  if !(data[0] == b'P' && data[1] == b'A' && data[2] == b'C' && data[3] == b'K') {
    raise @bit.GitError::PackfileError("Invalid packfile magic")
  }
  let version = read_u32_be(data, 4)
  if version != 2 {
    raise @bit.GitError::PackfileError(
      "Unsupported packfile version: \{version}",
    )
  }
  let count = read_u32_be(data, 8)
  let mut offset = 12
  let objects : Array[@bit.PackObject] = Array::new(capacity=count)
  let resolved : Array[Bool] = Array::new(capacity=count)
  let pending : Array[PendingDelta] = []
  for _ in 0..<count {
    let obj_offset = offset
    let (type_id, size, next_offset) = decode_type_and_size_at(data, offset)
    check_pack_object_size(size)
    offset = next_offset
    let (obj_type, content, after) = match type_id {
      1 | 2 | 3 | 4 => {
        let obj_type = packfile_type_to_object_type(type_id)
        let (content, after) = @zlib.zlib_decompress_at(
          data,
          offset,
          max_size=size,
        ) catch {
          e => raise @bit.GitError::PackfileError("Zlib error: \{e}")
        }
        if content.length() != size {
          raise @bit.GitError::PackfileError(
            "Object size mismatch: expected=\{size}, got=\{content.length()}",
          )
        }
        (obj_type, content, after)
      }
      6 => {
        let (back_offset, after_ref) = read_ofs_delta_offset(data, offset)
        let base_offset = obj_offset - back_offset
        if base_offset < 0 {
          raise @bit.GitError::PackfileError("Invalid OFS_DELTA base offset")
        }
        let (delta, after) = @zlib.zlib_decompress_at(
          data,
          after_ref,
          max_size=size,
        ) catch {
          e => raise @bit.GitError::PackfileError("Zlib error: \{e}")
        }
        if delta.length() != size {
          raise @bit.GitError::PackfileError(
            "Delta size mismatch: expected=\{size}, got=\{delta.length()}",
          )
        }
        // Compute CRC32 for this delta object
        let crc = crc32_range(data, obj_offset, after)
        let placeholder = @bit.PackObject::with_metadata(
          @bit.ObjectType::Blob,
          Bytes::from_array([]),
          @bit.ObjectId::zero(),
          obj_offset,
          crc,
        )
        objects.push(placeholder)
        resolved.push(false)
        let idx = objects.length() - 1
        by_offset[obj_offset] = idx
        match by_offset.get(base_offset) {
          Some(base_index) =>
            if resolved[base_index] {
              let base = objects[base_index]
              let content = apply_delta(base.data, delta)
              let obj_id = @bit.hash_object_content_with_algo(
                hash_algo_from_size(hash_size),
                base.obj_type,
                content,
              )
              let obj = @bit.PackObject::with_metadata(
                base.obj_type,
                content,
                obj_id,
                obj_offset,
                crc,
              )
              objects[idx] = obj
              resolved[idx] = true
              insert_pack_object_by_id(by_id, obj)
            } else {
              pending.push({
                index: idx,
                base: DeltaBaseRef::Ofs(base_index),
                delta,
              })
            }
          None =>
            raise @bit.GitError::PackfileError(
              "Missing base object for OFS_DELTA",
            )
        }
        (@bit.ObjectType::Blob, Bytes::from_array([]), after)
      }
      7 => {
        let (base_oid, after_ref) = read_ref_delta_object_id(
          data,
          offset,
          hash_size~,
        )
        let (delta, after) = @zlib.zlib_decompress_at(
          data,
          after_ref,
          max_size=size,
        ) catch {
          e => raise @bit.GitError::PackfileError("Zlib error: \{e}")
        }
        if delta.length() != size {
          raise @bit.GitError::PackfileError(
            "Delta size mismatch: expected=\{size}, got=\{delta.length()}",
          )
        }
        // Compute CRC32 for this delta object
        let crc = crc32_range(data, obj_offset, after)
        let placeholder = @bit.PackObject::with_metadata(
          @bit.ObjectType::Blob,
          Bytes::from_array([]),
          @bit.ObjectId::zero(),
          obj_offset,
          crc,
        )
        objects.push(placeholder)
        resolved.push(false)
        let idx = objects.length() - 1
        by_offset[obj_offset] = idx
        match by_id.get(base_oid) {
          Some(base) => {
            let content = apply_delta(base.data, delta)
            let obj_id = @bit.hash_object_content_with_algo(
              hash_algo_from_size(hash_size),
              base.obj_type,
              content,
            )
            let obj = @bit.PackObject::with_metadata(
              base.obj_type,
              content,
              obj_id,
              obj_offset,
              crc,
            )
            objects[idx] = obj
            resolved[idx] = true
            insert_pack_object_by_id(by_id, obj)
          }
          None =>
            pending.push({
              index: idx,
              base: DeltaBaseRef::Ref(base_oid),
              delta,
            })
        }
        (@bit.ObjectType::Blob, Bytes::from_array([]), after)
      }
      _ =>
        raise @bit.GitError::PackfileError(
          "Unknown packfile object type: \{type_id}",
        )
    }
    offset = after
    if type_id == 1 || type_id == 2 || type_id == 3 || type_id == 4 {
      // Compute CRC32 and hash for non-delta objects
      let crc = crc32_range(data, obj_offset, after)
      let obj_id = @bit.hash_object_content_with_algo(
        hash_algo_from_size(hash_size),
        obj_type,
        content,
      )
      let obj = @bit.PackObject::with_metadata(
        obj_type, content, obj_id, obj_offset, crc,
      )
      objects.push(obj)
      resolved.push(true)
      by_offset[obj_offset] = objects.length() - 1
      insert_pack_object_by_id(by_id, obj)
    }
  }
  let mut progress = true
  let mut pending_list = pending
  while pending_list.length() > 0 && progress {
    progress = false
    let next_pending : Array[PendingDelta] = []
    for p in pending_list {
      match p.base {
        DeltaBaseRef::Ofs(base_index) =>
          if base_index >= 0 &&
            base_index < objects.length() &&
            resolved[base_index] {
            let base = objects[base_index]
            let content = apply_delta(base.data, p.delta)
            let obj_id = @bit.hash_object_content_with_algo(
              hash_algo_from_size(hash_size),
              base.obj_type,
              content,
            )
            // Preserve offset and crc from placeholder
            let old = objects[p.index]
            let obj = @bit.PackObject::with_metadata(
              base.obj_type,
              content,
              obj_id,
              old.offset,
              old.crc32,
            )
            objects[p.index] = obj
            resolved[p.index] = true
            insert_pack_object_by_id(by_id, obj)
            progress = true
          } else {
            next_pending.push(p)
          }
        DeltaBaseRef::Ref(base_oid) =>
          match by_id.get(base_oid) {
            Some(base) => {
              let content = apply_delta(base.data, p.delta)
              let obj_id = @bit.hash_object_content_with_algo(
                hash_algo_from_size(hash_size),
                base.obj_type,
                content,
              )
              // Preserve offset and crc from placeholder
              let old = objects[p.index]
              let obj = @bit.PackObject::with_metadata(
                base.obj_type,
                content,
                obj_id,
                old.offset,
                old.crc32,
              )
              objects[p.index] = obj
              resolved[p.index] = true
              insert_pack_object_by_id(by_id, obj)
              progress = true
            }
            None => next_pending.push(p)
          }
      }
    }
    pending_list = next_pending
  }
  if pending_list.length() > 0 {
    raise @bit.GitError::PackfileError("Unresolved delta objects")
  }
  let trailer_offset = data.length() - hash_size
  if offset != trailer_offset {
    raise @bit.GitError::PackfileError("Packfile length mismatch")
  }
  if verify_checksum {
    let computed = @bit.hash_prefix(data, trailer_offset, hash_size~)
    let trailer = read_trailer_id(data, trailer_offset, hash_size~)
    if computed != trailer {
      raise @bit.GitError::HashMismatch(computed.to_hex(), trailer.to_hex())
    }
  }
  objects
}

///|
fn parse_packfile_stream_internal(
  data : Bytes,
  by_offset : Map[Int, @bit.PackObject],
  by_id : Map[@bit.ObjectId, @bit.PackObject],
  emit : (@bit.PackObject) -> Unit,
  verify_checksum? : Bool = true,
  hash_size? : Int = 20,
) -> Unit raise @bit.GitError {
  if data.length() < 32 {
    raise @bit.GitError::PackfileError("Packfile too short")
  }
  if !(data[0] == b'P' && data[1] == b'A' && data[2] == b'C' && data[3] == b'K') {
    raise @bit.GitError::PackfileError("Invalid packfile magic")
  }
  let version = read_u32_be(data, 4)
  if version != 2 {
    raise @bit.GitError::PackfileError(
      "Unsupported packfile version: \{version}",
    )
  }
  let count = read_u32_be(data, 8)
  let mut offset = 12
  let algo = hash_algo_from_size(hash_size)
  let pending : Array[PendingDeltaStream] = []
  // depth tracking — see MAX_DELTA_DEPTH (parse_packfile_with_bases
  // does the same). Stream variant emits objects as they resolve, so
  // we keep depth side-tables keyed by offset and id.
  let depth_by_offset : Map[Int, Int] = {}
  let depth_by_id : Map[@bit.ObjectId, Int] = {}
  for _ in 0..<count {
    let obj_offset = offset
    let (type_id, size, next_offset) = decode_type_and_size_at(data, offset)
    check_pack_object_size(size)
    offset = next_offset
    match type_id {
      1 | 2 | 3 | 4 => {
        let obj_type = packfile_type_to_object_type(type_id)
        let (content, after) = @zlib.zlib_decompress_at(
          data,
          offset,
          max_size=size,
        ) catch {
          e => raise @bit.GitError::PackfileError("Zlib error: \{e}")
        }
        if content.length() != size {
          raise @bit.GitError::PackfileError(
            "Object size mismatch: expected=\{size}, got=\{content.length()}",
          )
        }
        let obj_id = @bit.hash_object_content_with_algo(algo, obj_type, content)
        let obj = @bit.PackObject::with_metadata(
          obj_type, content, obj_id, obj_offset, 0U,
        )
        by_offset[obj_offset] = obj
        insert_pack_object_by_id(by_id, obj)
        depth_by_offset[obj_offset] = 0
        depth_by_id[obj_id] = 0
        emit(obj)
        offset = after
      }
      6 => {
        let (back_offset, after_ref) = read_ofs_delta_offset(data, offset)
        let base_offset = obj_offset - back_offset
        if base_offset < 0 {
          raise @bit.GitError::PackfileError("Invalid OFS_DELTA base offset")
        }
        let (delta, after) = @zlib.zlib_decompress_at(
          data,
          after_ref,
          max_size=size,
        ) catch {
          e => raise @bit.GitError::PackfileError("Zlib error: \{e}")
        }
        if delta.length() != size {
          raise @bit.GitError::PackfileError(
            "Delta size mismatch: expected=\{size}, got=\{delta.length()}",
          )
        }
        match by_offset.get(base_offset) {
          Some(base) => {
            let content = apply_delta(base.data, delta)
            let obj_id = @bit.hash_object_content_with_algo(
              algo,
              base.obj_type,
              content,
            )
            let obj = @bit.PackObject::with_metadata(
              base.obj_type,
              content,
              obj_id,
              obj_offset,
              0U,
            )
            by_offset[obj_offset] = obj
            insert_pack_object_by_id(by_id, obj)
            let depth = depth_by_offset.get(base_offset).unwrap_or(0) + 1
            check_delta_depth(depth)
            depth_by_offset[obj_offset] = depth
            depth_by_id[obj_id] = depth
            emit(obj)
          }
          None =>
            pending.push({
              offset: obj_offset,
              base: DeltaBaseRef::Ofs(base_offset),
              delta,
            })
        }
        offset = after
      }
      7 => {
        let (base_oid, after_ref) = read_ref_delta_object_id(
          data,
          offset,
          hash_size~,
        )
        let (delta, after) = @zlib.zlib_decompress_at(
          data,
          after_ref,
          max_size=size,
        ) catch {
          e => raise @bit.GitError::PackfileError("Zlib error: \{e}")
        }
        if delta.length() != size {
          raise @bit.GitError::PackfileError(
            "Delta size mismatch: expected=\{size}, got=\{delta.length()}",
          )
        }
        match by_id.get(base_oid) {
          Some(base) => {
            let content = apply_delta(base.data, delta)
            let obj_id = @bit.hash_object_content_with_algo(
              algo,
              base.obj_type,
              content,
            )
            let obj = @bit.PackObject::with_metadata(
              base.obj_type,
              content,
              obj_id,
              obj_offset,
              0U,
            )
            by_offset[obj_offset] = obj
            insert_pack_object_by_id(by_id, obj)
            let depth = depth_by_id.get(base_oid).unwrap_or(0) + 1
            check_delta_depth(depth)
            depth_by_offset[obj_offset] = depth
            depth_by_id[obj_id] = depth
            emit(obj)
          }
          None =>
            pending.push({
              offset: obj_offset,
              base: DeltaBaseRef::Ref(base_oid),
              delta,
            })
        }
        offset = after
      }
      _ =>
        raise @bit.GitError::PackfileError(
          "Unknown packfile object type: \{type_id}",
        )
    }
  }
  let mut pending_list = pending
  while pending_list.length() > 0 {
    let mut progress = false
    let next_pending : Array[PendingDeltaStream] = []
    for p in pending_list {
      match p.base {
        Ofs(base_offset) =>
          match by_offset.get(base_offset) {
            Some(base) => {
              let content = apply_delta(base.data, p.delta)
              let obj_id = @bit.hash_object_content_with_algo(
                algo,
                base.obj_type,
                content,
              )
              let obj = @bit.PackObject::with_metadata(
                base.obj_type,
                content,
                obj_id,
                p.offset,
                0U,
              )
              by_offset[p.offset] = obj
              insert_pack_object_by_id(by_id, obj)
              let depth = depth_by_offset.get(base_offset).unwrap_or(0) + 1
              check_delta_depth(depth)
              depth_by_offset[p.offset] = depth
              depth_by_id[obj_id] = depth
              emit(obj)
              progress = true
            }
            None => next_pending.push(p)
          }
        Ref(base_oid) =>
          match by_id.get(base_oid) {
            Some(base) => {
              let content = apply_delta(base.data, p.delta)
              let obj_id = @bit.hash_object_content_with_algo(
                algo,
                base.obj_type,
                content,
              )
              let obj = @bit.PackObject::with_metadata(
                base.obj_type,
                content,
                obj_id,
                p.offset,
                0U,
              )
              by_offset[p.offset] = obj
              insert_pack_object_by_id(by_id, obj)
              let depth = depth_by_id.get(base_oid).unwrap_or(0) + 1
              check_delta_depth(depth)
              depth_by_offset[p.offset] = depth
              depth_by_id[obj_id] = depth
              emit(obj)
              progress = true
            }
            None => next_pending.push(p)
          }
      }
    }
    if !progress {
      break
    }
    pending_list = next_pending
  }
  if pending_list.length() > 0 {
    raise @bit.GitError::PackfileError("Unresolved delta objects")
  }
  let trailer_offset = data.length() - hash_size
  if offset != trailer_offset {
    raise @bit.GitError::PackfileError("Packfile length mismatch")
  }
  if verify_checksum {
    let computed = @bit.hash_prefix(data, trailer_offset, hash_size~)
    let trailer = read_trailer_id(data, trailer_offset, hash_size~)
    if computed != trailer {
      raise @bit.GitError::HashMismatch(computed.to_hex(), trailer.to_hex())
    }
  }
}

///|
/// Decode packfile object header and return (type_id, size, next_offset).
pub fn decode_type_and_size_at(
  data : Bytes,
  start : Int,
) -> (Int, Int, Int) raise @bit.GitError {
  if start < 0 || start >= data.length() {
    raise @bit.GitError::PackfileError("Unexpected end of packfile header")
  }
  let first = data[start].to_int()
  let mut size = first & 0x0f
  let type_id = (first >> 4) & 0x07
  let mut shift = 4
  let mut offset = start + 1
  let mut has_more = (first & 0x80) != 0
  while has_more {
    if offset >= data.length() {
      raise @bit.GitError::PackfileError("Unexpected end of packfile size")
    }
    let b = data[offset].to_int()
    offset += 1
    size = size | ((b & 0x7f) << shift)
    shift += 7
    has_more = (b & 0x80) != 0
  }
  (type_id, size, offset)
}

///|
/// Convert packfile type id to ObjectType.
pub fn packfile_type_to_object_type(
  type_id : Int,
) -> @bit.ObjectType raise @bit.GitError {
  match type_id {
    1 => @bit.ObjectType::Commit
    2 => @bit.ObjectType::Tree
    3 => @bit.ObjectType::Blob
    4 => @bit.ObjectType::Tag
    _ =>
      raise @bit.GitError::PackfileError(
        "Unknown packfile object type: \{type_id}",
      )
  }
}

///|
pub fn read_ofs_delta_offset(
  data : Bytes,
  start : Int,
) -> (Int, Int) raise @bit.GitError {
  if start >= data.length() {
    raise @bit.GitError::PackfileError("Unexpected end of packfile delta")
  }
  let mut offset = start
  let mut c = data[offset].to_int()
  offset += 1
  let mut val = c & 0x7f
  while (c & 0x80) != 0 {
    if offset >= data.length() {
      raise @bit.GitError::PackfileError("Unexpected end of packfile delta")
    }
    c = data[offset].to_int()
    offset += 1
    val = (val + 1) << 7
    val = val | (c & 0x7f)
  }
  (val, offset)
}

///|
fn read_ref_delta_object_id(
  data : Bytes,
  start : Int,
  hash_size? : Int = 20,
) -> (@bit.ObjectId, Int) raise @bit.GitError {
  if start + hash_size > data.length() {
    raise @bit.GitError::PackfileError("Unexpected end of packfile delta")
  }
  let bytes : FixedArray[Byte] = FixedArray::make(hash_size, b'\x00')
  for i in 0..<hash_size {
    bytes[i] = data[start + i]
  }
  (@bit.ObjectId::new(bytes), start + hash_size)
}

///|
pub fn read_ref_delta_id(
  data : Bytes,
  start : Int,
  hash_size? : Int = 20,
) -> (String, Int) raise @bit.GitError {
  if start + hash_size > data.length() {
    raise @bit.GitError::PackfileError("Unexpected end of packfile delta")
  }
  let bytes : FixedArray[Byte] = FixedArray::make(hash_size, b'\x00')
  for i in 0..<hash_size {
    bytes[i] = data[start + i]
  }
  let id = @bit.ObjectId::new(bytes)
  (id.to_hex(), start + hash_size)
}

///|
pub fn apply_delta(base : Bytes, delta : Bytes) -> Bytes raise @bit.GitError {
  let mut offset = 0
  let (base_size, off1) = read_delta_size(delta, offset)
  offset = off1
  if base_size != base.length() {
    raise @bit.GitError::PackfileError("Delta base size mismatch")
  }
  let (result_size, off2) = read_delta_size(delta, offset)
  offset = off2
  // Same cap as pack object size: prevents `FixedArray::make` from
  // attempting a multi-GB allocation when the delta header claims an
  // outsized result (or the varint wraps to a value the caller can't
  // service).
  if result_size < 0 || result_size > MAX_PACK_OBJECT_SIZE {
    raise @bit.GitError::PackfileError(
      "Delta result size out of range: \{result_size}",
    )
  }
  let out : FixedArray[Byte] = FixedArray::make(result_size, b'\x00')
  let mut out_pos = 0
  while offset < delta.length() {
    let opcode = delta[offset].to_int()
    offset += 1
    if (opcode & 0x80) != 0 {
      let mut cp_off = 0
      let mut cp_size = 0
      if (opcode & 0x01) != 0 {
        if offset >= delta.length() {
          raise @bit.GitError::PackfileError("Delta copy header truncated")
        }
        cp_off = cp_off | delta[offset].to_int()
        offset += 1
      }
      if (opcode & 0x02) != 0 {
        if offset >= delta.length() {
          raise @bit.GitError::PackfileError("Delta copy header truncated")
        }
        cp_off = cp_off | (delta[offset].to_int() << 8)
        offset += 1
      }
      if (opcode & 0x04) != 0 {
        if offset >= delta.length() {
          raise @bit.GitError::PackfileError("Delta copy header truncated")
        }
        cp_off = cp_off | (delta[offset].to_int() << 16)
        offset += 1
      }
      if (opcode & 0x08) != 0 {
        if offset >= delta.length() {
          raise @bit.GitError::PackfileError("Delta copy header truncated")
        }
        cp_off = cp_off | (delta[offset].to_int() << 24)
        offset += 1
      }
      if (opcode & 0x10) != 0 {
        if offset >= delta.length() {
          raise @bit.GitError::PackfileError("Delta copy header truncated")
        }
        cp_size = cp_size | delta[offset].to_int()
        offset += 1
      }
      if (opcode & 0x20) != 0 {
        if offset >= delta.length() {
          raise @bit.GitError::PackfileError("Delta copy header truncated")
        }
        cp_size = cp_size | (delta[offset].to_int() << 8)
        offset += 1
      }
      if (opcode & 0x40) != 0 {
        if offset >= delta.length() {
          raise @bit.GitError::PackfileError("Delta copy header truncated")
        }
        cp_size = cp_size | (delta[offset].to_int() << 16)
        offset += 1
      }
      if cp_size == 0 {
        cp_size = 0x10000
      }
      // Bounds check guarding against integer overflow on Int32:
      // a `cp_off` near 2^31 plus a 7-bit-shifted `cp_size` can wrap
      // into a small negative value, slipping past
      // `cp_off + cp_size > base.length()`.
      let base_len = base.length()
      if cp_off < 0 ||
        cp_size < 0 ||
        cp_off > base_len ||
        cp_size > base_len - cp_off {
        raise @bit.GitError::PackfileError("Delta copy out of range")
      }
      // Same defense for the *output* cursor — a malicious delta that
      // sums its op sizes past `result_size` would otherwise index
      // out of the `out` FixedArray and panic.
      if out_pos < 0 || cp_size > result_size - out_pos {
        raise @bit.GitError::PackfileError("Delta copy past result size")
      }
      for i in 0..<cp_size {
        out[out_pos] = base[cp_off + i]
        out_pos += 1
      }
    } else {
      let literal_len = opcode & 0x7f
      if literal_len == 0 {
        raise @bit.GitError::PackfileError("Invalid delta opcode")
      }
      if literal_len > delta.length() - offset {
        raise @bit.GitError::PackfileError("Delta literal out of range")
      }
      if literal_len > result_size - out_pos {
        raise @bit.GitError::PackfileError("Delta literal past result size")
      }
      for i in 0..<literal_len {
        out[out_pos] = delta[offset + i]
        out_pos += 1
      }
      offset += literal_len
    }
  }
  if out_pos != result_size {
    raise @bit.GitError::PackfileError("Delta result size mismatch")
  }
  Bytes::from_array(out)
}

///|
fn read_delta_size(data : Bytes, start : Int) -> (Int, Int) raise @bit.GitError {
  let mut offset = start
  let mut size = 0
  let mut shift = 0
  while true {
    if offset >= data.length() {
      raise @bit.GitError::PackfileError("Unexpected end of delta data")
    }
    // Cap the shift before it can wrap MoonBit's 32-bit Int. A hostile
    // delta that keeps the continuation bit set indefinitely would
    // otherwise either truncate to a small `size` (silent corruption)
    // or shift into the sign bit (negative size accepted by the
    // caller, then handed to `FixedArray::make` — undefined for
    // negative len).
    if shift >= 32 {
      raise @bit.GitError::PackfileError("Delta size varint too large")
    }
    let b = data[offset].to_int()
    offset += 1
    size = size | ((b & 0x7f) << shift)
    if size < 0 {
      raise @bit.GitError::PackfileError("Delta size overflow")
    }
    if (b & 0x80) == 0 {
      break
    }
    shift = shift + 7
  }
  (size, offset)
}

///|
fn read_u32_be(data : Bytes, start : Int) -> Int raise @bit.GitError {
  if start < 0 || start + 4 > data.length() {
    raise @bit.GitError::PackfileError("Unexpected end of packfile header")
  }
  (data[start].to_int() << 24) |
  (data[start + 1].to_int() << 16) |
  (data[start + 2].to_int() << 8) |
  data[start + 3].to_int()
}

///|
fn read_trailer_id(
  data : Bytes,
  start : Int,
  hash_size? : Int = 20,
) -> @bit.ObjectId {
  let bytes : FixedArray[Byte] = FixedArray::make(hash_size, b'\x00')
  for i in 0..<hash_size {
    bytes[i] = data[start + i]
  }
  @bit.ObjectId::new(bytes)
}
