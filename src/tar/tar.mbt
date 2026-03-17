///| Pure tar archive generation helpers (USTAR format).

///|
/// Format an Int64 value as a zero-padded octal string of the given width.
pub fn tar_format_octal(value : Int64, width : Int) -> String {
  if value == 0L {
    let buf = StringBuilder::new()
    for _i in 0..<width {
      buf.write_char('0')
    }
    return buf.to_string()
  }
  // Convert to octal string
  let digits : Array[Char] = []
  let mut v = value
  while v > 0L {
    let d = (v % 8L).to_int()
    digits.push((d + '0'.to_int()).unsafe_to_char())
    v = v / 8L
  }
  // Reverse
  let buf = StringBuilder::new()
  let digit_len = digits.length()
  // Pad with leading zeros
  if digit_len < width {
    let pad_count = width - digit_len
    for _i in 0..<pad_count {
      buf.write_char('0')
    }
  }
  let mut di = digits.length() - 1
  while di >= 0 {
    buf.write_char(digits[di])
    di -= 1
  }
  buf.to_string()
}

///|
/// Write a UTF-8 string into a byte buffer at the given offset, up to max_len bytes.
pub fn tar_write_string(
  buf : FixedArray[Byte],
  offset : Int,
  s : String,
  max_len : Int,
) -> Unit {
  let bytes = @utf8.encode(s)
  let len = if bytes.length() < max_len { bytes.length() } else { max_len }
  for i in 0..<len {
    buf[offset + i] = bytes[i]
  }
}

///|
/// Split a long path into (name, prefix) for USTAR tar headers.
///  prefix is at most 155 bytes, name at most 100 bytes.
///  Returns (name, prefix). If the path cannot be split, name is truncated.
pub fn tar_split_path(path : String) -> (String, String) {
  // Find a '/' boundary to split into prefix (max 155) and name (max 100)
  let mut best_slash = -1
  for i in 0..<path.length() {
    if path[i] == '/' {
      let prefix_len = i
      let name_len = path.length() - i - 1
      if prefix_len <= 155 && name_len <= 100 {
        best_slash = i
      }
    }
  }
  if best_slash >= 0 {
    let prefix_part = path[:best_slash].to_string()
    let name_part = path[best_slash + 1:].to_string()
    (name_part, prefix_part)
  } else {
    // Can't split; truncate name
    (path[:100].to_string(), "")
  }
}

///|
/// Build a 512-byte USTAR tar header.
///
///  - `path`: file path (split into prefix+name if > 100 chars)
///  - `mode`: Unix file mode (e.g. 0o100644)
///  - `size`: file content size in bytes
///  - `mtime`: modification time as Unix timestamp
///  - `typeflag`: tar type flag byte (b'0' = regular, b'5' = directory, b'2' = symlink)
///  - `linkname`: symlink target (empty for non-symlinks)
pub fn tar_make_header(
  path : String,
  mode : Int,
  size : Int,
  mtime : Int64,
  typeflag : Byte,
  linkname : String,
) -> FixedArray[Byte] {
  let header = FixedArray::make(512, b'\x00')
  // Split path into prefix + name if needed
  let (name_str, prefix_str) = if path.length() > 100 {
    tar_split_path(path)
  } else {
    (path, "")
  }
  // name (offset 0, 100 bytes)
  tar_write_string(header, 0, name_str, 100)
  // mode (offset 100, 8 bytes) — octal NUL-terminated
  let mode_str = tar_format_octal(mode.to_int64(), 7)
  tar_write_string(header, 100, mode_str, 8)
  // uid (offset 108, 8 bytes)
  tar_write_string(header, 108, "0000000", 8)
  // gid (offset 116, 8 bytes)
  tar_write_string(header, 116, "0000000", 8)
  // size (offset 124, 12 bytes) — octal NUL-terminated
  let size_str = tar_format_octal(size.to_int64(), 11)
  tar_write_string(header, 124, size_str, 12)
  // mtime (offset 136, 12 bytes) — octal NUL-terminated
  let mtime_str = tar_format_octal(mtime, 11)
  tar_write_string(header, 136, mtime_str, 12)
  // checksum placeholder (offset 148, 8 bytes) — spaces for computation
  for ci in 0..<8 {
    header[148 + ci] = b' '
  }
  // typeflag (offset 156, 1 byte)
  header[156] = typeflag
  // linkname (offset 157, 100 bytes)
  if linkname.length() > 0 {
    tar_write_string(header, 157, linkname, 100)
  }
  // magic (offset 257, 6 bytes) "ustar\0"
  tar_write_string(header, 257, "ustar", 6)
  // version (offset 263, 2 bytes) "00"
  header[263] = b'0'
  header[264] = b'0'
  // uname (offset 265, 32 bytes)
  tar_write_string(header, 265, "root", 32)
  // gname (offset 297, 32 bytes)
  tar_write_string(header, 297, "root", 32)
  // devmajor (offset 329, 8 bytes)
  tar_write_string(header, 329, "0000000", 8)
  // devminor (offset 337, 8 bytes)
  tar_write_string(header, 337, "0000000", 8)
  // prefix (offset 345, 155 bytes)
  if prefix_str.length() > 0 {
    tar_write_string(header, 345, prefix_str, 155)
  }
  // Compute checksum
  let mut chksum = 0
  for ci in 0..<512 {
    chksum += header[ci].to_int()
  }
  // Write checksum as 6-digit octal + NUL + space
  let chksum_str = tar_format_octal(chksum.to_int64(), 6)
  for ci in 0..<6 {
    header[148 + ci] = chksum_str[ci].to_int().to_byte()
  }
  header[148 + 6] = b'\x00'
  header[148 + 7] = b' '
  header
}

///|
/// Parse the committer timestamp from raw commit object bytes.
///  Returns the Unix timestamp as Int64, or 0 if not found.
pub fn tar_parse_committer_timestamp(data : Bytes) -> Int64 {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("committer ") {
      // Format: "committer Name <email> timestamp tz"
      let rest = line[10:].to_string()
      // Find '>' to locate end of email
      let mut gt_pos = -1
      for ci in 0..<rest.length() {
        if rest[ci] == '>' {
          gt_pos = ci
        }
      }
      if gt_pos >= 0 && gt_pos + 2 < rest.length() {
        let after_email = rest[gt_pos + 2:].to_string()
        // "timestamp tz"
        let parts = after_email.split(" ")
        let parts_arr : Array[String] = []
        for p in parts {
          parts_arr.push(p.to_string())
        }
        if parts_arr.length() >= 1 {
          let ts_str = parts_arr[0]
          let ts = @strconv.parse_int64(ts_str) catch { _ => 0L }
          return ts
        }
      }
    }
  }
  0L
}

///|
/// Emit parent directory entries for a tar path into the output buffer.
///  Tracks already-emitted directories via the `emitted` map.
pub fn tar_emit_parent_dirs(
  out : Array[Byte],
  path : String,
  mtime : Int64,
  emitted : Map[String, Bool],
) -> Unit {
  // Collect all parent directories
  let dirs : Array[String] = []
  let mut p = path
  while true {
    let mut slash_pos = -1
    for i in 0..<p.length() {
      if p[i] == '/' {
        slash_pos = i
      }
    }
    if slash_pos <= 0 {
      break
    }
    let dir = p[:slash_pos + 1].to_string() // include trailing /
    if emitted.contains(dir) {
      break
    }
    dirs.push(dir)
    p = p[:slash_pos].to_string()
  }
  // Emit in order from shallowest to deepest
  let mut di = dirs.length() - 1
  while di >= 0 {
    let dir = dirs[di]
    if not(emitted.contains(dir)) {
      emitted[dir] = true
      let hdr = tar_make_header(dir, 0o40755, 0, mtime, b'5', "")
      for b in hdr {
        out.push(b)
      }
    }
    di -= 1
  }
}
