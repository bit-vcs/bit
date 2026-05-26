///| git show-index - show pack index contents

///|
async fn handle_show_index(args : Array[String]) -> Unit raise Error {
  for arg in args {
    match arg {
      "--object-format=sha256" => ()
      "-h" | "--help" => {
        show_simple_command_help(
          "git show-index",
          summary="Read a pack idx file from stdin and dump its contents.",
        )
        return
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("show-index", arg)
      _ => ()
    }
  }
  // Read idx file from stdin
  let data = read_all_stdin()
  if data.length() < 8 {
    eprint_line("fatal: invalid pack index")
    @sys.exit(1)
    return
  }
  // Check magic and version
  let magic = read_u32_be_i64(data, 0)
  if magic != 0xff744f63L {
    // Not a v2 index, try v1 format
    show_index_v1(data)
    return
  }
  let version = read_u32_be_i64(data, 4)
  if version != 2L {
    let ver_str = version.to_string()
    eprint_line("fatal: unsupported pack index version " + ver_str)
    @sys.exit(1)
    return
  }
  show_index_v2(data)
}

///|
async fn show_index_v1(data : Bytes) -> Unit {
  // v1 format: 256 * 4-byte fanout + entries (offset + oid)
  let mut offset = 0
  let mut count64 = 0L
  for _ in 0..<256 {
    if offset + 4 > data.length() {
      eprint_line("fatal: truncated pack index")
      @sys.exit(1)
      return
    }
    count64 = read_u32_be_i64(data, offset)
    offset += 4
  }
  let count = count64.to_int()
  // Entries: 4-byte offset + 20-byte OID
  let entries : Array[(Int64, String)] = []
  for _ in 0..<count {
    if offset + 24 > data.length() {
      eprint_line("fatal: truncated pack index")
      @sys.exit(1)
      return
    }
    let pack_offset = read_u32_be_i64(data, offset)
    offset += 4
    let oid_bytes : FixedArray[Byte] = FixedArray::make(20, b'\x00')
    for i in 0..<20 {
      oid_bytes[i] = data[offset + i]
    }
    offset += 20
    entries.push((pack_offset, @bitcore.ObjectId::new(oid_bytes).to_hex()))
  }
  // Sort by offset
  entries.sort_by(fn(a, b) { a.0.compare(b.0) })
  for entry in entries {
    let off_str = entry.0.to_string()
    print_line(off_str + " " + entry.1)
  }
}

///|
async fn show_index_v2(data : Bytes) -> Unit {
  // v2 format: magic(4) + version(4) + fanout(256*4) + oids + crcs + offsets
  let mut offset = 8
  let mut count64 = 0L
  for _ in 0..<256 {
    if offset + 4 > data.length() {
      eprint_line("fatal: truncated pack index")
      @sys.exit(1)
      return
    }
    count64 = read_u32_be_i64(data, offset)
    offset += 4
  }
  if count64 > 2147483647L {
    eprint_line("fatal: too many objects")
    @sys.exit(1)
    return
  }
  let count = count64.to_int()
  // Read OIDs
  let oids : Array[String] = []
  for _ in 0..<count {
    if offset + 20 > data.length() {
      eprint_line("fatal: truncated pack index")
      @sys.exit(1)
      return
    }
    let oid_bytes : FixedArray[Byte] = FixedArray::make(20, b'\x00')
    for i in 0..<20 {
      oid_bytes[i] = data[offset + i]
    }
    offset += 20
    oids.push(@bitcore.ObjectId::new(oid_bytes).to_hex())
  }
  // Read CRC32 values
  let crcs : Array[Int64] = []
  for _ in 0..<count {
    if offset + 4 > data.length() {
      eprint_line("fatal: truncated pack index")
      @sys.exit(1)
      return
    }
    crcs.push(read_u32_be_i64(data, offset))
    offset += 4
  }
  // Read 4-byte offsets
  let offsets : Array[Int64] = []
  let large_offset_start = offset + count * 4
  for _ in 0..<count {
    if offset + 4 > data.length() {
      eprint_line("fatal: truncated pack index")
      @sys.exit(1)
      return
    }
    let off = read_u32_be_i64(data, offset)
    offset += 4
    if (off & 0x80000000L) != 0L {
      // Large offset - index into 8-byte offset table
      let idx = (off & 0x7fffffffL).to_int()
      let large_off_pos = large_offset_start + idx * 8
      if large_off_pos + 8 <= data.length() {
        let hi = read_u32_be_i64(data, large_off_pos)
        let lo = read_u32_be_i64(data, large_off_pos + 4)
        offsets.push((hi << 32) | lo)
      } else {
        offsets.push(off)
      }
    } else {
      offsets.push(off)
    }
  }
  // Build entries and sort by offset
  let entries : Array[(Int64, String, Int64)] = []
  for i in 0..<count {
    entries.push((offsets[i], oids[i], crcs[i]))
  }
  entries.sort_by(fn(a, b) { a.0.compare(b.0) })
  // Output: offset oid (crc32)
  for entry in entries {
    let off_str = entry.0.to_string()
    let crc_str = entry.2.to_string()
    print_line(off_str + " " + entry.1 + " (" + crc_str + ")")
  }
}
