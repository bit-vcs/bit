///| git get-tar-commit-id - extract commit ID from a tar archive created by git archive

///|
async fn handle_get_tar_commit_id(args : Array[String]) -> Unit raise Error {
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git get-tar-commit-id",
          summary="Extract the commit ID from an archive created using git archive.\nReads a tar stream from stdin.",
        )
        return
      }
      _ => ()
    }
  }
  // Read tar archive from stdin
  let data = read_all_stdin()
  if data.length() < 512 {
    // Tar files must have at least one 512-byte block
    @sys.exit(1)
    return
  }
  // git archive embeds commit OID as a PAX global extended header
  // PAX global header: typeflag 'g' (0x67) at offset 156
  // The header block is followed by data blocks containing "key=value\n" entries
  // We look for "comment=<hex-oid>"
  let commit_id = tar_extract_pax_comment(data)
  match commit_id {
    Some(id) => print_line(id)
    None =>
      // No commit ID found
      @sys.exit(1)
  }
}

///|
fn tar_extract_pax_comment(data : Bytes) -> String? {
  let mut offset = 0
  while offset + 512 <= data.length() {
    // Check if this is an all-zero block (end of archive)
    let mut all_zero = true
    for i in 0..<512 {
      if data[offset + i] != b'\x00' {
        all_zero = false
        break
      }
    }
    if all_zero {
      break
    }
    // Read typeflag at offset 156
    let typeflag = data[offset + 156]
    // Read size from header at offset 124, 12 bytes (octal)
    let size = tar_parse_octal(data, offset + 124, 12)
    if typeflag == b'g' {
      // PAX global extended header - scan data blocks for comment=
      let data_start = offset + 512
      let data_end = data_start + size
      if data_end <= data.length() {
        match tar_find_pax_comment(data, data_start, data_end) {
          Some(id) => return Some(id)
          None => ()
        }
      }
    }
    // Skip to next header: current header (512) + data blocks (rounded up to 512)
    let data_blocks = (size + 511) / 512
    offset = offset + 512 + data_blocks * 512
  }
  None
}

///|
fn tar_parse_octal(data : Bytes, offset : Int, len : Int) -> Int {
  let mut result = 0
  for i in 0..<len {
    let b = data[offset + i]
    if b == b'\x00' || b == b' ' {
      break
    }
    if b >= b'0' && b <= b'7' {
      result = result * 8 + (b.to_int() - b'0'.to_int())
    }
  }
  result
}

///|
fn tar_find_pax_comment(data : Bytes, start : Int, end : Int) -> String? {
  // PAX data format: "<length> <key>=<value>\n" per entry
  // We look for "comment=<hex-oid>"
  // Extract substring manually
  let arr : Array[Byte] = []
  for i in start..<end {
    arr.push(data[i])
  }
  let text = decode_bytes(bytes_from_array(arr))
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    // Format: "<len> key=value"
    // Find the first space
    match line.find(" ") {
      Some(sp) => {
        let rest = String::unsafe_substring(
          line,
          start=sp + 1,
          end=line.length(),
        )
        if rest.has_prefix("comment=") {
          let value = String::unsafe_substring(rest, start=8, end=rest.length())
          // Validate it looks like a hex OID (40 or 64 chars)
          if (value.length() == 40 || value.length() == 64) &&
            is_hex_string(value) {
            return Some(value)
          }
        }
      }
      None => continue
    }
  }
  None
}
