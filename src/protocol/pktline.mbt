///| Git pkt-line protocol implementation

///|
fn int_to_hex_char(i : Int) -> Char {
  if i < 10 {
    (i + '0'.to_int()).unsafe_to_char()
  } else {
    (i - 10 + 'a'.to_int()).unsafe_to_char()
  }
}

///|
/// Helper to convert Array[Byte] to Bytes
fn pkt_array_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), i => arr[i]))
}

///|
/// Encode a single pkt-line
/// Format: {4-hex-length}{payload}
/// Length includes the 4-byte header
pub fn pktline_encode(data : String) -> Bytes {
  let len = data.length() + 4
  let result : Array[Byte] = []

  // 4-byte hex length
  result.push(int_to_hex_char((len >> 12) & 0xf).to_int().to_byte())
  result.push(int_to_hex_char((len >> 8) & 0xf).to_int().to_byte())
  result.push(int_to_hex_char((len >> 4) & 0xf).to_int().to_byte())
  result.push(int_to_hex_char(len & 0xf).to_int().to_byte())

  // Payload
  for c in data {
    result.push(c.to_int().to_byte())
  }
  pkt_array_to_bytes(result)
}

///|
/// Encode pkt-line from bytes
pub fn pktline_encode_bytes(data : Bytes) -> Bytes {
  let len = data.length() + 4
  let result : Array[Byte] = []

  // 4-byte hex length
  result.push(int_to_hex_char((len >> 12) & 0xf).to_int().to_byte())
  result.push(int_to_hex_char((len >> 8) & 0xf).to_int().to_byte())
  result.push(int_to_hex_char((len >> 4) & 0xf).to_int().to_byte())
  result.push(int_to_hex_char(len & 0xf).to_int().to_byte())

  // Payload
  for b in data {
    result.push(b)
  }
  pkt_array_to_bytes(result)
}

///|
/// Flush packet (0000)
pub fn pktline_flush() -> Bytes {
  Bytes::from_array([b'0', b'0', b'0', b'0'])
}

///|
/// Delimiter packet (0001)
pub fn pktline_delim() -> Bytes {
  Bytes::from_array([b'0', b'0', b'0', b'1'])
}

///|
/// Decode pkt-lines from bytes
/// Returns array of (data, is_flush)
pub fn pktline_decode(data : Bytes) -> Array[(Bytes, Bool)] raise @git.GitError {
  let result : Array[(Bytes, Bool)] = []
  let mut offset = 0
  while offset < data.length() {
    if offset + 4 > data.length() {
      raise @git.GitError::ProtocolError("Incomplete pkt-line header")
    }

    // Read 4-byte hex length
    let len_str = StringBuilder::new()
    for i in 0..<4 {
      len_str.write_char(data[offset + i].to_int().unsafe_to_char())
    }
    offset += 4
    let len = parse_pkt_hex_int(len_str.to_string())
    if len == 0 {
      // Flush packet
      result.push((Bytes::from_array([]), true))
      continue
    }
    if len == 1 {
      // Delimiter packet
      result.push((Bytes::from_array([]), false))
      continue
    }
    let payload_len = len - 4
    if offset + payload_len > data.length() {
      raise @git.GitError::ProtocolError("Incomplete pkt-line payload")
    }
    let payload : Array[Byte] = []
    for i in 0..<payload_len {
      payload.push(data[offset + i])
    }
    offset += payload_len
    result.push((pkt_array_to_bytes(payload), false))
  }
  result
}

///|
/// Parse hex string to int (simplified, no error handling needed)
fn parse_pkt_hex_int(s : String) -> Int {
  let mut result = 0
  for c in s {
    result = result << 4
    result = result | pkt_hex_char_to_int(c)
  }
  result
}

///|
fn pkt_hex_char_to_int(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    0
  }
}

///|
/// Build a ref update command for git-receive-pack
/// Format: {old_sha} {new_sha} {refname}\0{capabilities}\n
pub fn build_ref_update(
  old_id : @git.ObjectId,
  new_id : @git.ObjectId,
  refname : String,
  capabilities : String,
) -> String {
  "\{old_id.to_hex()} \{new_id.to_hex()} \{refname}\u0000\{capabilities}\n"
}

///|
/// Build a ref update command (without capabilities)
pub fn build_ref_update_simple(
  old_id : @git.ObjectId,
  new_id : @git.ObjectId,
  refname : String,
) -> String {
  "\{old_id.to_hex()} \{new_id.to_hex()} \{refname}\n"
}

///|
/// Parse refs from git-receive-pack response
/// Format: {sha} {refname}\0{capabilities}\n (for first line)
///         {sha} {refname}\n (for subsequent lines)
pub fn parse_refs(
  data : Bytes,
) -> Array[(@git.ObjectId, String)] raise @git.GitError {
  let lines = pktline_decode(data)
  let result : Array[(@git.ObjectId, String)] = []
  for item in lines {
    let (line_bytes, is_flush) = item
    if is_flush || line_bytes.length() == 0 {
      continue
    }

    // Convert to string
    let line = pkt_bytes_to_string(line_bytes)

    // Skip capability advertisement line (starts with #)
    if line.length() > 0 {
      let chars = line.to_array()
      if chars[0] == '#' {
        continue
      }
    }

    // Parse: {sha} {refname}[\0{capabilities}]
    if line.length() < 41 {
      continue
    }
    let chars = line.to_array()
    let sha_str = StringBuilder::new()
    for i in 0..<40 {
      sha_str.write_char(chars[i])
    }

    // Skip space
    if chars.length() <= 41 || chars[40] != ' ' {
      continue
    }

    // Read refname until null or newline
    let refname = StringBuilder::new()
    for i = 41; i < chars.length(); i = i + 1 {
      if chars[i] == '\u0000' || chars[i] == '\n' {
        break
      }
      refname.write_char(chars[i])
    }
    let id = @git.ObjectId::from_hex(sha_str.to_string())
    result.push((id, refname.to_string()))
  }
  result
}

///|
fn pkt_bytes_to_string(data : Bytes) -> String {
  let result = StringBuilder::new()
  for b in data {
    result.write_char(b.to_int().unsafe_to_char())
  }
  result.to_string()
}
