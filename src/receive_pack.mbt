///| Receive-pack (server-side) implementation

///|
pub struct RefUpdate {
  old_id : ObjectId
  new_id : ObjectId
  refname : String
}

///|
pub struct ReceivePackRequest {
  updates : Array[RefUpdate]
  capabilities : Array[String]
  pack : Bytes
}

///|
pub struct ReceivePackResult {
  updated : Array[String]
  rejected : Array[(String, String)]
}

///|
pub fn parse_receive_pack_request(data : Bytes) -> ReceivePackRequest raise GitError {
  let updates : Array[RefUpdate] = []
  let capabilities : Array[String] = []
  let mut i = 0
  let mut first = true
  while i + 4 <= data.length() {
    let len = receive_parse_pkt_len(data, i)
    if len == 0 {
      i += 4
      break
    }
    if len < 4 || i + len > data.length() {
      raise GitError::ProtocolError("Invalid pkt-line length")
    }
    let line = receive_bytes_to_string_range(data, i + 4, i + len)
    let mut line = receive_trim_line(line)
    if first {
      first = false
      match line.find("\u0000") {
        None => ()
        Some(idx) => {
          let caps_str = String::unsafe_substring(
            line,
            start=idx + 1,
            end=line.length(),
          )
          line = String::unsafe_substring(line, start=0, end=idx)
          let caps = receive_split_by_space(caps_str)
          for c in caps {
            if c.length() > 0 {
              capabilities.push(c)
            }
          }
        }
      }
    }
    let parts = receive_split_by_space(line)
    if parts.length() < 3 {
      raise GitError::ProtocolError("Invalid receive-pack command")
    }
    let old_id = ObjectId::from_hex(parts[0])
    let new_id = ObjectId::from_hex(parts[1])
    let refname = parts[2]
    updates.push({ old_id, new_id, refname })
    i += len
  }
  let pack = receive_bytes_slice(data, i, data.length())
  { updates, capabilities, pack }
}

///|
pub fn apply_receive_pack(
  fs : &FileSystem,
  rfs : &RepoFileSystem,
  root : String,
  req : ReceivePackRequest,
) -> ReceivePackResult raise GitError {
  let git_dir = join_path(root, ".git")
  if req.pack.length() > 0 {
    let objects = parse_packfile(req.pack)
    write_packfile_with_index(fs, git_dir, req.pack, objects)
  }
  let updated : Array[String] = []
  let rejected : Array[(String, String)] = []
  for upd in req.updates {
    let current = resolve_ref(rfs, git_dir, upd.refname)
    let current_id = match current {
      None => ObjectId::zero()
      Some(id) => id
    }
    if current_id != upd.old_id {
      rejected.push((upd.refname, "old id mismatch"))
      continue
    }
    if upd.new_id == ObjectId::zero() {
      if not(receive_delete_ref(fs, rfs, git_dir, upd.refname)) {
        rejected.push((upd.refname, "ref not found"))
        continue
      }
    } else {
      let ref_path = join_path(git_dir, upd.refname)
      let dir = parent_dir(ref_path)
      fs.mkdir_p(dir)
      fs.write_string(ref_path, upd.new_id.to_hex() + "\n")
    }
    updated.push(upd.refname)
  }
  { updated, rejected }
}

///|
pub fn receive_pack(
  fs : &FileSystem,
  rfs : &RepoFileSystem,
  root : String,
  data : Bytes,
) -> Bytes raise GitError {
  let req = parse_receive_pack_request(data)
  let result = apply_receive_pack(fs, rfs, root, req)
  receive_build_status_response(result)
}

///|
fn receive_build_status_response(result : ReceivePackResult) -> Bytes {
  let out : Array[Byte] = []
  let unpack = pktline_encode("unpack ok\n")
  for b in unpack {
    out.push(b)
  }
  for refname in result.updated {
    let line = pktline_encode("ok \{refname}\n")
    for b in line {
      out.push(b)
    }
  }
  for item in result.rejected {
    let (refname, msg) = item
    let line = pktline_encode("ng \{refname} \{msg}\n")
    for b in line {
      out.push(b)
    }
  }
  let flush = pktline_flush()
  for b in flush {
    out.push(b)
  }
  Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] }))
}

///|
fn receive_delete_ref(
  fs : &FileSystem,
  rfs : &RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Bool raise GitError {
  let ref_path = join_path(git_dir, refname)
  if rfs.is_file(ref_path) {
    fs.remove_file(ref_path)
    return true
  }
  let packed = join_path(git_dir, "packed-refs")
  if not(rfs.is_file(packed)) {
    return false
  }
  let data = rfs.read_file(packed)
  let text = @utf8.decode_lossy(data[:])
  let out : Array[String] = []
  let mut removed = false
  let mut skip_peeled = false
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    if skip_peeled {
      if line.has_prefix("^") {
        skip_peeled = false
        continue
      }
      skip_peeled = false
    }
    if line.has_prefix("#") || line.has_prefix("^") {
      out.push(line)
      continue
    }
    match line.find(" ") {
      None => out.push(line)
      Some(idx) => {
        let name = String::unsafe_substring(
          line,
          start=idx + 1,
          end=line.length(),
        )
        if name == refname {
          removed = true
          skip_peeled = true
        } else {
          out.push(line)
        }
      }
    }
  }
  if removed {
    let buf = StringBuilder::new()
    for l in out {
      buf.write_string(l)
      buf.write_char('\n')
    }
    fs.write_string(packed, buf.to_string())
  }
  removed
}

///|
fn receive_parse_pkt_len(data : Bytes, start : Int) -> Int raise GitError {
  if start + 4 > data.length() {
    raise GitError::ProtocolError("Invalid pkt-line length")
  }
  let mut v = 0
  for i in 0..<4 {
    let c = data[start + i].to_int().unsafe_to_char()
    v = v * 16 + receive_hex_char_to_int(c)
  }
  v
}

///|
fn receive_hex_char_to_int(c : Char) -> Int raise GitError {
  if c >= '0' && c <= '9' {
    return c.to_int() - '0'.to_int()
  }
  if c >= 'a' && c <= 'f' {
    return 10 + (c.to_int() - 'a'.to_int())
  }
  if c >= 'A' && c <= 'F' {
    return 10 + (c.to_int() - 'A'.to_int())
  }
  raise GitError::ProtocolError("Invalid hex char")
}

///|
fn receive_bytes_to_string_range(data : Bytes, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(data[i].to_int().unsafe_to_char())
    i += 1
  }
  buf.to_string()
}

///|
fn receive_bytes_slice(data : Bytes, start : Int, end : Int) -> Bytes {
  let len = end - start
  if len <= 0 {
    return Bytes::from_array([])
  }
  let fixed = FixedArray::makei(len, fn(i) { data[start + i] })
  Bytes::from_array(fixed)
}

///|
fn receive_trim_line(line : String) -> String {
  if line.has_suffix("\n") {
    String::unsafe_substring(line, start=0, end=line.length() - 1)
  } else {
    line
  }
}

///|
fn receive_split_by_space(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut buf : Array[Char] = []
  for c in s {
    if c == ' ' {
      out.push(receive_chars_to_string(buf))
      buf = []
    } else {
      buf.push(c)
    }
  }
  out.push(receive_chars_to_string(buf))
  out
}

///|
fn receive_chars_to_string(chars : Array[Char]) -> String {
  let buf = StringBuilder::new()
  for c in chars {
    buf.write_char(c)
  }
  buf.to_string()
}
