///| Upload-pack (server-side) implementation

///|
pub struct UploadPackRequest {
  wants : Array[@git.ObjectId]
  haves : Array[@git.ObjectId]
  capabilities : Array[String]
  done : Bool
}

///|
/// Build upload-pack advertisement (info/refs payload).
pub fn build_upload_pack_advertisement(
  fs : &@git.RepoFileSystem,
  root : String,
  agent? : String = "git/moonbit",
) -> Bytes raise @git.GitError {
  let git_dir = join_path(root, ".git")
  let refs = show_ref(fs, git_dir)
  refs.sort_by(fn(a, b) { String::compare(a.0, b.0) })
  let caps = upload_default_caps(agent)
  let out : Array[Byte] = []
  if refs.length() == 0 {
    let zero = @git.ObjectId::zero().to_hex()
    let line = "\{zero} capabilities^{}\u0000\{caps}\n"
    upload_push_bytes(out, @git.pktline_encode(line))
    upload_push_bytes(out, @git.pktline_flush())
    return Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] }))
  }
  let (first_name, first_id) = refs[0]
  let first_line = "\{first_id.to_hex()} \{first_name}\u0000\{caps}\n"
  upload_push_bytes(out, @git.pktline_encode(first_line))
  for i in 1..<refs.length() {
    let (name, id) = refs[i]
    let line = "\{id.to_hex()} \{name}\n"
    upload_push_bytes(out, @git.pktline_encode(line))
  }
  upload_push_bytes(out, @git.pktline_flush())
  Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] }))
}

///|
pub fn parse_upload_pack_request(
  data : Bytes,
) -> UploadPackRequest raise @git.GitError {
  let wants : Array[@git.ObjectId] = []
  let haves : Array[@git.ObjectId] = []
  let capabilities : Array[String] = []
  let mut done = false
  let mut i = 0
  let mut first_want = true
  while i + 4 <= data.length() {
    let len = upload_parse_pkt_len(data, i)
    if len == 0 {
      // flush packet
      i += 4
      continue
    }
    if len < 4 || i + len > data.length() {
      raise @git.GitError::ProtocolError("Invalid pkt-line length")
    }
    let line = upload_bytes_to_string_range(data, i + 4, i + len)
    let mut line = upload_trim_line(line)
    // Parse capabilities from first want line
    if first_want && line.has_prefix("want ") {
      first_want = false
      match line.find("\u0000") {
        None => ()
        Some(idx) => {
          let caps_str = String::unsafe_substring(
            line,
            start=idx + 1,
            end=line.length(),
          )
          line = String::unsafe_substring(line, start=0, end=idx)
          let caps = upload_split_by_space(caps_str)
          for c in caps {
            if c.length() > 0 {
              capabilities.push(c)
            }
          }
        }
      }
    }
    if line.has_prefix("want ") {
      let hex = String::unsafe_substring(line, start=5, end=line.length())
      let hex = upload_trim_line(hex)
      // Strip capabilities suffix if any
      let hex = match hex.find(" ") {
        None => hex
        Some(idx) => String::unsafe_substring(hex, start=0, end=idx)
      }
      if hex.length() >= 40 {
        let hex40 = String::unsafe_substring(hex, start=0, end=40)
        wants.push(@git.ObjectId::from_hex(hex40))
      }
    } else if line.has_prefix("have ") {
      let hex = String::unsafe_substring(line, start=5, end=line.length())
      let hex = upload_trim_line(hex)
      if hex.length() >= 40 {
        let hex40 = String::unsafe_substring(hex, start=0, end=40)
        haves.push(@git.ObjectId::from_hex(hex40))
      }
    } else if line == "done" {
      done = true
    }
    i += len
  }
  { wants, haves, capabilities, done }
}

///|
pub fn upload_pack(
  fs : &@git.RepoFileSystem,
  root : String,
  req : UploadPackRequest,
) -> Bytes raise @git.GitError {
  let git_dir = join_path(root, ".git")
  let db = ObjectDb::load(fs, git_dir)
  // Collect objects reachable from wants
  let objects = collect_reachable_objects_from_commits(db, fs, req.wants)
  // If client has some objects, filter them out
  if req.haves.length() > 0 {
    let have_set : Map[String, Bool] = {}
    let have_objects = collect_reachable_objects_from_commits(db, fs, req.haves)
    for obj in have_objects {
      let id = @git.hash_object_content(obj.obj_type, obj.data)
      have_set[id.to_hex()] = true
    }
    let filtered : Array[@git.PackObject] = []
    for obj in objects {
      let id = @git.hash_object_content(obj.obj_type, obj.data)
      if not(have_set.contains(id.to_hex())) {
        filtered.push(obj)
      }
    }
    return build_upload_pack_response(filtered)
  }
  build_upload_pack_response(objects)
}

///|
fn build_upload_pack_response(objects : Array[@git.PackObject]) -> Bytes {
  let out : Array[Byte] = []
  // NAK (no common commits)
  upload_push_bytes(out, @git.pktline_encode("NAK\n"))
  // Create packfile
  let pack = @git.create_packfile(objects)
  // Send packfile
  for b in pack {
    out.push(b)
  }
  Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] }))
}

///|
fn upload_default_caps(agent : String) -> String {
  let caps : Array[String] = [
    "multi_ack",
    "thin-pack",
    "side-band",
    "side-band-64k",
    "ofs-delta",
    "shallow",
    "no-progress",
    "include-tag",
    "object-format=sha1",
    "agent=\{agent}",
  ]
  caps.join(" ")
}

///|
fn upload_parse_pkt_len(data : Bytes, start : Int) -> Int raise @git.GitError {
  if start + 4 > data.length() {
    raise @git.GitError::ProtocolError("Invalid pkt-line length")
  }
  let mut v = 0
  for i in 0..<4 {
    let c = data[start + i].to_int().unsafe_to_char()
    v = v * 16 + upload_hex_char_to_int(c)
  }
  v
}

///|
fn upload_hex_char_to_int(c : Char) -> Int raise @git.GitError {
  if c >= '0' && c <= '9' {
    return c.to_int() - '0'.to_int()
  }
  if c >= 'a' && c <= 'f' {
    return 10 + (c.to_int() - 'a'.to_int())
  }
  if c >= 'A' && c <= 'F' {
    return 10 + (c.to_int() - 'A'.to_int())
  }
  raise @git.GitError::ProtocolError("Invalid hex char")
}

///|
fn upload_bytes_to_string_range(data : Bytes, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(data[i].to_int().unsafe_to_char())
    i += 1
  }
  buf.to_string()
}

///|
fn upload_trim_line(line : String) -> String {
  if line.has_suffix("\n") {
    String::unsafe_substring(line, start=0, end=line.length() - 1)
  } else {
    line
  }
}

///|
fn upload_split_by_space(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut buf : Array[Char] = []
  for c in s {
    if c == ' ' {
      out.push(upload_chars_to_string(buf))
      buf = []
    } else {
      buf.push(c)
    }
  }
  out.push(upload_chars_to_string(buf))
  out
}

///|
fn upload_chars_to_string(chars : Array[Char]) -> String {
  let buf = StringBuilder::new()
  for c in chars {
    buf.write_char(c)
  }
  buf.to_string()
}

///|
fn upload_push_bytes(out : Array[Byte], data : Bytes) -> Unit {
  for b in data {
    out.push(b)
  }
}
