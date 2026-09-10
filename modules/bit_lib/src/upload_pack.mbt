///| Upload-pack (server-side) implementation

///|
#warnings("-deprecated")
fn upload_pack_parse_int(value : StringView) -> Int raise {
  @strconv.parse_int(value)
}

///|
#warnings("-deprecated")
fn upload_pack_parse_int64(value : StringView) -> Int64 raise {
  @strconv.parse_int64(value)
}

///|
pub struct UploadPackRequest {
  wants : Array[@bit.ObjectId]
  haves : Array[@bit.ObjectId]
  capabilities : Array[String]
  done : Bool
  shallow : Array[@bit.ObjectId]
  deepen : Int?
}

///|
/// Protocol v2 upload-pack request
pub struct UploadPackRequestV2 {
  command : String // "fetch", "ls-refs", etc.
  capabilities : Array[String]
  wants : Array[@bit.ObjectId]
  want_refs : Array[String]
  haves : Array[@bit.ObjectId]
  done : Bool
  // v2-specific capabilities
  filter : String? // e.g., "blob:none"
  packfile_uris : String? // e.g., "https"
  // ls-refs arguments
  ref_prefixes : Array[String] // restrict the listing; empty means all refs
  symrefs : Bool // report what a symbolic ref points at
  peel : Bool // report the commit an annotated tag resolves to
  unborn : Bool // report HEAD even when its branch has no commits yet
}

///|
/// Detect protocol version from request bytes
/// Returns 1 for v1 (want lines), 2 for v2 (command=...)
pub fn detect_protocol_version(data : Bytes) -> Int {
  if data.length() < 8 {
    return 1
  }
  // Parse first pktline length
  let len = upload_parse_pkt_len_safe(data, 0)
  if len < 4 {
    return 1
  }
  // Check if first line starts with "command="
  let end = if len > data.length() { data.length() } else { len }
  let line = upload_bytes_to_string_range(data, 4, end)
  if line.has_prefix("command=") {
    2
  } else {
    1
  }
}

///|
fn upload_parse_pkt_len_safe(data : Bytes, start : Int) -> Int {
  if start + 4 > data.length() {
    return 0
  }
  let mut v = 0
  for i in 0..<4 {
    let c = data[start + i].to_int()
    let digit = if c >= 0x30 && c <= 0x39 {
      // '0'-'9'
      c - 0x30
    } else if c >= 0x61 && c <= 0x66 {
      // 'a'-'f'
      10 + (c - 0x61)
    } else if c >= 0x41 && c <= 0x46 {
      // 'A'-'F'
      10 + (c - 0x41)
    } else {
      return 0
    }
    v = v * 16 + digit
  }
  v
}

///|
/// Parse protocol v2 upload-pack request
pub fn parse_upload_pack_request_v2(
  data : Bytes,
) -> UploadPackRequestV2 raise @bit.GitError {
  let mut command = ""
  let capabilities : Array[String] = []
  let wants : Array[@bit.ObjectId] = []
  let want_refs : Array[String] = []
  let haves : Array[@bit.ObjectId] = []
  let mut done = false
  let mut filter : String? = None
  let mut packfile_uris : String? = None
  let ref_prefixes : Array[String] = []
  let mut symrefs = false
  let mut peel = false
  let mut unborn = false
  let mut i = 0
  let mut in_args = false // After delimiter (0001)
  let mut saw_flush_after_args = false
  while i + 4 <= data.length() {
    let len = upload_parse_pkt_len_safe(data, i)

    // 0000 = flush
    if len == 0 {
      i += 4
      if in_args {
        saw_flush_after_args = true
      }
      continue
    }

    // 0001 = delimiter (switch from command section to arguments)
    if len == 1 {
      if in_args {
        let cmd = if command.length() > 0 { command } else { "unknown" }
        raise @bit.GitError::ProtocolError(
          "expected flush after " + cmd + " arguments",
        )
      }
      in_args = true
      i += 4
      continue
    }
    if len < 4 || i + len > data.length() {
      raise @bit.GitError::ProtocolError("Invalid pkt-line length in v2")
    }
    if saw_flush_after_args {
      raise @bit.GitError::ProtocolError("Unexpected data after flush")
    }
    let line = upload_bytes_to_string_range(data, i + 4, i + len)
    let line = upload_trim_line(line)
    i += len
    if !in_args {
      // Command section
      if line.has_prefix("command=") {
        command = String::unsafe_substring(line, start=8, end=line.length())
      } else if line.has_prefix("object-format=") {
        // Ignore for now, assume sha1
      } else if line.length() > 0 {
        capabilities.push(line)
      }
      // Arguments section
    } else if line.has_prefix("want-ref ") {
      let refname = String::unsafe_substring(line, start=9, end=line.length())
      let refname = upload_trim_line(refname)
      if refname.length() > 0 {
        want_refs.push(refname)
      }
    } else if line.has_prefix("want ") {
      let hex = String::unsafe_substring(line, start=5, end=line.length())
      let hex = upload_trim_line(hex)
      if hex.length() >= 40 {
        let hex40 = String::unsafe_substring(hex, start=0, end=40)
        wants.push(@bit.ObjectId::from_hex(hex40))
      }
    } else if line.has_prefix("have ") {
      let hex = String::unsafe_substring(line, start=5, end=line.length())
      let hex = upload_trim_line(hex)
      if hex.length() >= 40 {
        let hex40 = String::unsafe_substring(hex, start=0, end=40)
        haves.push(@bit.ObjectId::from_hex(hex40))
      }
    } else if line == "done" {
      done = true
    } else if line.has_prefix("filter ") {
      filter = Some(String::unsafe_substring(line, start=7, end=line.length()))
    } else if line.has_prefix("packfile-uris ") {
      packfile_uris = Some(
        String::unsafe_substring(line, start=14, end=line.length()),
      )
    } else if line.has_prefix("ref-prefix ") {
      let prefix = upload_trim_line(
        String::unsafe_substring(line, start=11, end=line.length()),
      )
      if prefix.length() > 0 {
        ref_prefixes.push(prefix)
      }
    } else if line == "symrefs" {
      symrefs = true
    } else if line == "peel" {
      peel = true
    } else if line == "unborn" {
      unborn = true
    }
  }
  {
    command,
    capabilities,
    wants,
    want_refs,
    haves,
    done,
    ref_prefixes,
    symrefs,
    peel,
    unborn,
    filter,
    packfile_uris,
  }
}

///|
/// Locate the git directory for an upload-pack request.
///
/// Defaults to `<root>/.git`, preserving the behaviour every existing caller
/// relies on. A server passes the directory explicitly, because a bare
/// repository keeps `refs/` and `objects/` at its top level and has no
/// `.git` inside it.
fn resolve_upload_pack_git_dir(root : String, override_ : String) -> String {
  if override_.length() > 0 {
    override_
  } else {
    join_path(root, ".git")
  }
}

///|
/// Build upload-pack advertisement (info/refs payload).
pub fn build_upload_pack_advertisement(
  fs : &@bit.RepoFileSystem,
  root : String,
  agent? : String = "git/moonbit",
  protocol_version? : Int = 0,
  git_dir_override? : String = "",
) -> Bytes raise @bit.GitError {
  let git_dir = resolve_upload_pack_git_dir(root, git_dir_override)
  let out : Array[Byte] = []
  // Protocol v2: output capabilities instead of refs
  if protocol_version == 2 {
    upload_push_bytes(out, @protocol.pktline_encode("version 2\n"))
    upload_push_bytes(out, @protocol.pktline_encode("agent=\{agent}\n"))
    upload_push_bytes(out, @protocol.pktline_encode("ls-refs=unborn\n"))
    upload_push_bytes(
      out,
      @protocol.pktline_encode("fetch=shallow wait-for-done\n"),
    )
    upload_push_bytes(out, @protocol.pktline_encode("server-option\n"))
    upload_push_bytes(out, @protocol.pktline_encode("object-format=sha1\n"))
    upload_push_bytes(out, @protocol.pktline_flush())
    return Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
  }
  let refs = show_ref(fs, git_dir)
  refs.sort_by((a, b) => String::compare(a.0, b.0))
  // Resolve HEAD and prepend it to refs list
  let head_id = resolve_ref(fs, git_dir, "HEAD")
  let all_refs : Array[(String, @bit.ObjectId)] = []
  match head_id {
    Some(id) => all_refs.push(("HEAD", id))
    None => ()
  }
  for item in refs {
    all_refs.push(item)
  }
  // Build symref capability when HEAD is a symbolic ref
  let head_symref : String? = try {
    let head_ref = read_head_ref(fs, git_dir)
    match head_ref {
      HeadRef::Branch(name) =>
        if name.has_prefix("refs/") {
          Some(name)
        } else {
          Some("refs/heads/" + name)
        }
      HeadRef::Detached(_) => None
    }
  } catch {
    _ => None
  }
  let caps = match head_symref {
    Some(target) => upload_default_caps(agent) + " symref=HEAD:" + target
    None => upload_default_caps(agent)
  }
  // Protocol v1: output version line before refs
  if protocol_version == 1 {
    upload_push_bytes(out, @protocol.pktline_encode("version 1\n"))
  }
  if all_refs.length() == 0 {
    let zero = @bit.ObjectId::zero().to_hex()
    let line = "\{zero} capabilities^{}\u0000\{caps}\n"
    upload_push_bytes(out, @protocol.pktline_encode(line))
    upload_push_bytes(out, @protocol.pktline_flush())
    return Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
  }
  let (first_name, first_id) = all_refs[0]
  let first_line = "\{first_id.to_hex()} \{first_name}\u0000\{caps}\n"
  upload_push_bytes(out, @protocol.pktline_encode(first_line))
  for i in 1..<all_refs.length() {
    let (name, id) = all_refs[i]
    let line = "\{id.to_hex()} \{name}\n"
    upload_push_bytes(out, @protocol.pktline_encode(line))
  }
  upload_push_bytes(out, @protocol.pktline_flush())
  Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
}

///|
pub fn parse_upload_pack_request(
  data : Bytes,
) -> UploadPackRequest raise @bit.GitError {
  let wants : Array[@bit.ObjectId] = []
  let haves : Array[@bit.ObjectId] = []
  let shallow : Array[@bit.ObjectId] = []
  let capabilities : Array[String] = []
  let mut done = false
  let mut deepen : Int? = None
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
      raise @bit.GitError::ProtocolError("Invalid pkt-line length")
    }
    let line = upload_bytes_to_string_range(data, i + 4, i + len)
    let mut line = upload_trim_line(line)
    // Parse capabilities from first want line
    if first_want && line.has_prefix("want ") {
      first_want = false
      // Try NUL separator first (git protocol)
      match line.find("\u0000") {
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
        None => {
          // HTTP stateless-rpc: caps are space-separated after SHA
          // Format: "want <sha40> <cap1> <cap2> ..."
          let rest = String::unsafe_substring(line, start=5, end=line.length())
          let rest = upload_trim_line(rest)
          if rest.length() > 40 {
            let caps_str = String::unsafe_substring(
              rest,
              start=41,
              end=rest.length(),
            )
            let caps = upload_split_by_space(caps_str)
            for c in caps {
              if c.length() > 0 {
                capabilities.push(c)
              }
            }
          }
        }
      }
    }
    if line.has_prefix("want ") {
      let hex = String::unsafe_substring(line, start=5, end=line.length())
      let hex = upload_trim_line(hex)
      // Extract just the SHA (first 40 chars or until space)
      let hex = if hex.length() > 40 {
        String::unsafe_substring(hex, start=0, end=40)
      } else {
        match hex.find(" ") {
          None => hex
          Some(idx) => String::unsafe_substring(hex, start=0, end=idx)
        }
      }
      if hex.length() >= 40 {
        let hex40 = String::unsafe_substring(hex, start=0, end=40)
        wants.push(@bit.ObjectId::from_hex(hex40))
      }
    } else if line.has_prefix("have ") {
      let hex = String::unsafe_substring(line, start=5, end=line.length())
      let hex = upload_trim_line(hex)
      if hex.length() >= 40 {
        let hex40 = String::unsafe_substring(hex, start=0, end=40)
        haves.push(@bit.ObjectId::from_hex(hex40))
      }
    } else if line.has_prefix("shallow ") {
      let hex = String::unsafe_substring(line, start=8, end=line.length())
      let hex = upload_trim_line(hex)
      if hex.length() >= 40 {
        let hex40 = String::unsafe_substring(hex, start=0, end=40)
        shallow.push(@bit.ObjectId::from_hex(hex40))
      }
    } else if line.has_prefix("deepen ") {
      let depth_str = String::unsafe_substring(line, start=7, end=line.length())
      let depth_str = upload_trim_line(depth_str)
      let depth = upload_pack_parse_int(depth_str) catch { _ => -1 }
      if depth >= 0 {
        deepen = Some(depth)
      }
    } else if line == "done" {
      done = true
    }
    i += len
  }
  { wants, haves, capabilities, done, shallow, deepen }
}

///|
pub fn upload_pack(
  fs : &@bit.RepoFileSystem,
  root : String,
  req : UploadPackRequest,
  git_dir_override? : String = "",
) -> Bytes raise @bit.GitError {
  let git_dir = resolve_upload_pack_git_dir(root, git_dir_override)
  let db = ObjectDb::load(fs, git_dir)

  // Validate wants (must be commit objects)
  for want in req.wants {
    let obj = db.get(fs, want)
    match obj {
      None => raise @bit.GitError::ProtocolError("not our ref " + want.to_hex())
      Some(o) =>
        if o.obj_type != @bit.ObjectType::Commit {
          raise @bit.GitError::ProtocolError("not our ref " + want.to_hex())
        }
    }
  }

  // Stateless clients may terminate after wants; respond with flush only
  if !req.done && req.haves.length() == 0 {
    return @protocol.pktline_flush()
  }

  // Check if client wants side-band
  let use_side_band = req.capabilities.contains("side-band-64k") ||
    req.capabilities.contains("side-band")

  // Collect have ACKs (v0 allows duplicates)
  let ack_ids = collect_have_acks_v0(db, fs, req.haves)
  if !req.done {
    return build_upload_pack_ack_response(ack_ids)
  }

  // Collect objects reachable from wants
  let include_pack_objects_died = req.shallow.length() == 0 &&
    req.deepen is None
  let objects = collect_upload_pack_objects(db, fs, req.wants, req.haves) catch {
    err =>
      raise @bit.GitError::ProtocolError(
        upload_pack_error_message(err, include_pack_objects_died),
      )
  }

  build_upload_pack_response(objects, use_side_band, ack_ids)
}

///|
fn build_upload_pack_ack_response(ack_ids : Array[@bit.ObjectId]) -> Bytes {
  let out : Array[Byte] = []
  if ack_ids.length() > 0 {
    for id in ack_ids {
      upload_push_bytes(
        out,
        @protocol.pktline_encode("ACK " + id.to_hex() + "\n"),
      )
    }
  } else {
    upload_push_bytes(out, @protocol.pktline_encode("NAK\n"))
  }
  upload_push_bytes(out, @protocol.pktline_flush())
  Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
}

///|
fn build_upload_pack_response(
  objects : Array[@bit.PackObject],
  use_side_band : Bool,
  ack_ids : Array[@bit.ObjectId],
) -> Bytes {
  let out : Array[Byte] = []
  if ack_ids.length() > 0 {
    for id in ack_ids {
      upload_push_bytes(
        out,
        @protocol.pktline_encode("ACK " + id.to_hex() + "\n"),
      )
    }
  }
  // NAK (no common commits)
  upload_push_bytes(out, @protocol.pktline_encode("NAK\n"))
  let pack = build_upload_packfile(objects)
  if use_side_band {
    // Send packfile via side-band-64k (band 1)
    let chunk_size = 65515 // 65520 - 4 (pkt-line header) - 1 (band byte)
    let mut offset = 0
    while offset < pack.length() {
      let end = if offset + chunk_size > pack.length() {
        pack.length()
      } else {
        offset + chunk_size
      }
      let data_len = end - offset
      let pkt_len = data_len + 5 // 4 (header) + 1 (band byte)
      let len_hex = @bithash.int_to_hex4(pkt_len)
      for c in len_hex {
        out.push(c.to_int().to_byte())
      }
      out.push(b'\x01') // band 1 = packfile data
      for i in offset..<end {
        out.push(pack[i])
      }
      offset = end
    }
    // Send flush to indicate end of packfile
    upload_push_bytes(out, @protocol.pktline_flush())
  } else {
    // Send packfile directly (no side-band)
    for b in pack {
      out.push(b)
    }
  }
  Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
}

///|
/// Build transfer packs with the same bounded OFS-delta search used by
/// pack-objects. It reduces bytes-on-wire and the receiver's index-pack work
/// without allowing unbounded delta chains.
fn build_upload_packfile(objects : Array[@bit.PackObject]) -> Bytes {
  let (pack, _) = @pack.create_packfile_with_delta_stats_compression_reuse(
    objects,
    @bit.PackDeltaMode::OfsDelta,
    @bit.PackCompression::Default,
    false,
    50,
    10,
  )
  pack
}

///|
fn collect_have_acks_v0(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  haves : Array[@bit.ObjectId],
) -> Array[@bit.ObjectId] {
  let out : Array[@bit.ObjectId] = []
  for id in haves {
    if (db.get(fs, id) catch { _ => None }) is Some(_) {
      out.push(id)
    }
  }
  out
}

///|
fn collect_have_acks_v2(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  haves : Array[@bit.ObjectId],
) -> Array[@bit.ObjectId] {
  let out : Array[@bit.ObjectId] = []
  let seen : Map[String, Bool] = Map([])
  for id in haves {
    let hex = id.to_hex()
    if seen.contains(hex) {
      continue
    }
    if (db.get(fs, id) catch { _ => None }) is Some(_) {
      out.push(id)
      seen[hex] = true
    }
  }
  out
}

///|
/// Walk wants once, using the client's have commits as traversal boundaries.
/// This avoids materializing and hashing the complete have-side object set.
fn collect_upload_pack_objects(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  wants : Array[@bit.ObjectId],
  haves : Array[@bit.ObjectId],
) -> Array[@bit.PackObject] raise @bit.GitError {
  if haves.length() == 0 {
    collect_reachable_objects_from_commits(db, fs, wants)
  } else {
    collect_reachable_objects_excluding_commits(db, fs, wants, haves)
  }
}

///|
fn upload_pack_error_message(
  err : @bit.GitError,
  include_pack_objects_died : Bool,
) -> String {
  let base = match err {
    InvalidObject(msg) => upload_pack_map_invalid_object(msg)
    HashMismatch(_, _) => "hash mismatch"
    PackfileError(msg) => msg
    ProtocolError(msg) => msg
    IoError(msg) => msg
  }
  if include_pack_objects_died && !base.contains("pack-objects died") {
    base + "\npack-objects died"
  } else {
    base
  }
}

///|
fn upload_pack_map_invalid_object(msg : String) -> String {
  let prefix = "Missing blob object: "
  if msg.has_prefix(prefix) {
    let hex = String::unsafe_substring(
      msg,
      start=prefix.length(),
      end=msg.length(),
    )
    "unable to read " + hex
  } else if msg.has_prefix("Missing tree object") ||
    msg.has_prefix("Object is not a tree") {
    "bad tree object"
  } else if msg.has_prefix("Missing commit object") ||
    msg.has_prefix("Object is not a commit") {
    "not our ref"
  } else {
    msg
  }
}

///|
fn upload_default_caps(agent : String) -> String {
  let caps : Array[String] = [
    "multi_ack",
    "multi_ack_detailed",
    "thin-pack",
    "side-band",
    "side-band-64k",
    "ofs-delta",
    "shallow",
    "no-progress",
    "include-tag",
    "no-done",
    "object-format=sha1",
    "agent=\{agent}",
  ]
  caps.join(" ")
}

///|
fn upload_parse_pkt_len(data : Bytes, start : Int) -> Int raise @bit.GitError {
  if start + 4 > data.length() {
    raise @bit.GitError::ProtocolError("Invalid pkt-line length")
  }
  let mut v = 0
  for i in 0..<4 {
    let c = data[start + i].to_int().unsafe_to_char()
    let digit = @bithash.hex_char_to_int(c) catch {
      _ => raise @bit.GitError::ProtocolError("Invalid pkt-line length")
    }
    v = v * 16 + digit
  }
  v
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

///|
/// Upload-pack configuration for v2 protocol
pub(all) struct UploadPackConfig {
  allow_filter : Bool
  blob_packfile_uri : String? // If set, packfile-uris is allowed
  allow_ref_in_want : Bool
}

///|
pub fn UploadPackConfig::new(
  allow_filter : Bool,
  blob_packfile_uri : String?,
  allow_ref_in_want : Bool,
) -> UploadPackConfig {
  { allow_filter, blob_packfile_uri, allow_ref_in_want }
}

///|
pub fn UploadPackConfig::default() -> UploadPackConfig {
  { allow_filter: true, blob_packfile_uri: None, allow_ref_in_want: false }
}

///|
/// Does `refname` match any of the client's `ref-prefix` arguments?
///
/// No prefixes at all means "everything", which is what the protocol
/// specifies for a client that sent none.
fn ls_refs_matches(refname : String, prefixes : Array[String]) -> Bool {
  if prefixes.length() == 0 {
    return true
  }
  for prefix in prefixes {
    if refname.has_prefix(prefix) {
      return true
    }
  }
  false
}

///|
/// Target of a tag object, read from its `object` header.
fn ls_refs_tag_target(data : Bytes) -> @bit.ObjectId? {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("object ") {
      let hex = upload_trim_line(
        String::unsafe_substring(line, start=7, end=line.length()),
      )
      let id = @bit.ObjectId::from_hex(hex) catch { _ => return None }
      return Some(id)
    }
  }
  None
}

///|
/// The object an annotated tag resolves to, or None for anything else.
///
/// Chases nested tags with a bound, so a tag cycle in a corrupt repository
/// cannot hang the server.
fn ls_refs_peel(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  id : @bit.ObjectId,
) -> @bit.ObjectId? {
  let mut current = id
  for _ in 0..<8 {
    let obj = db.get(fs, current) catch { _ => return None }
    guard obj is Some(o) else { return None }
    if o.obj_type != @bit.ObjectType::Tag {
      return if current == id { None } else { Some(current) }
    }
    guard ls_refs_tag_target(o.data) is Some(next) else { return None }
    current = next
  }
  None
}

///|
/// Answer a protocol v2 `ls-refs` command.
///
/// Each line is `<oid> <refname>`, followed by `symref-target:<target>` and
/// `peeled:<oid>` when the client asked for them, terminated by a flush.
pub fn ls_refs_v2(
  fs : &@bit.RepoFileSystem,
  root : String,
  req : UploadPackRequestV2,
  git_dir_override? : String = "",
) -> Bytes raise @bit.GitError {
  let git_dir = resolve_upload_pack_git_dir(root, git_dir_override)
  let out : Array[Byte] = []
  let refs = show_ref(fs, git_dir)
  refs.sort_by((a, b) => String::compare(a.0, b.0))
  let head_symref : String? = try {
    match read_head_ref(fs, git_dir) {
      HeadRef::Branch(name) =>
        if name.has_prefix("refs/") {
          Some(name)
        } else {
          Some("refs/heads/" + name)
        }
      HeadRef::Detached(_) => None
    }
  } catch {
    _ => None
  }
  let listing : Array[(String, @bit.ObjectId)] = []
  match resolve_ref(fs, git_dir, "HEAD") {
    Some(id) =>
      if ls_refs_matches("HEAD", req.ref_prefixes) {
        listing.push(("HEAD", id))
      }
    None => ()
  }
  for item in refs {
    if ls_refs_matches(item.0, req.ref_prefixes) {
      listing.push(item)
    }
  }
  // Only open the object database when peeling was actually asked for.
  let db = if req.peel { Some(ObjectDb::load(fs, git_dir)) } else { None }
  for entry in listing {
    let (name, id) = entry
    let line = StringBuilder::new()
    line.write_string(id.to_hex())
    line.write_char(' ')
    line.write_string(name)
    if req.symrefs && name == "HEAD" {
      match head_symref {
        Some(target) => {
          line.write_string(" symref-target:")
          line.write_string(target)
        }
        None => ()
      }
    }
    if req.peel {
      match db {
        Some(database) =>
          match ls_refs_peel(database, fs, id) {
            Some(peeled) => {
              line.write_string(" peeled:")
              line.write_string(peeled.to_hex())
            }
            None => ()
          }
        None => ()
      }
    }
    line.write_char('\n')
    upload_push_bytes(out, @protocol.pktline_encode(line.to_string()))
  }
  // An unborn HEAD has no object to report, so it is named on its own. A
  // client without the capability expects an empty listing instead.
  if req.unborn && listing.length() == 0 {
    match head_symref {
      Some(target) =>
        if ls_refs_matches("HEAD", req.ref_prefixes) {
          upload_push_bytes(
            out,
            @protocol.pktline_encode("unborn HEAD symref-target:\{target}\n"),
          )
        }
      None => ()
    }
  }
  upload_push_bytes(out, @protocol.pktline_flush())
  Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
}

///|
/// Handle protocol v2 upload-pack request
pub fn upload_pack_v2(
  fs : &@bit.RepoFileSystem,
  root : String,
  req : UploadPackRequestV2,
  config : UploadPackConfig,
  git_dir_override? : String = "",
) -> Bytes raise @bit.GitError {
  // Validate request against config
  if req.filter is Some(_) && !config.allow_filter {
    raise @bit.GitError::ProtocolError(
      "unexpected line: 'filter " + req.filter.unwrap() + "'",
    )
  }
  if req.packfile_uris is Some(_) && config.blob_packfile_uri is None {
    raise @bit.GitError::ProtocolError(
      "unexpected line: 'packfile-uris " + req.packfile_uris.unwrap() + "'",
    )
  }

  // Protocol v2 multiplexes several commands over one endpoint; ls-refs is
  // how a v2 client discovers refs, so a server that only answers fetch
  // cannot complete a default `git clone`.
  if req.command == "ls-refs" {
    return ls_refs_v2(fs, root, req, git_dir_override~)
  }
  // Process the fetch command
  if req.command != "fetch" {
    raise @bit.GitError::ProtocolError(
      "unsupported command: '" + req.command + "'",
    )
  }
  let git_dir = resolve_upload_pack_git_dir(root, git_dir_override)
  let db = ObjectDb::load(fs, git_dir)
  let refs = show_ref(fs, git_dir)
  let ref_map : Map[String, @bit.ObjectId] = Map([])
  for item in refs {
    let (name, id) = item
    ref_map[name] = id
  }
  let all_wants : Array[@bit.ObjectId] = []
  for id in req.wants {
    all_wants.push(id)
  }
  let wanted_refs : Array[(String, @bit.ObjectId)] = []
  if req.want_refs.length() > 0 {
    if !config.allow_ref_in_want {
      raise @bit.GitError::ProtocolError("unknown command 'want-ref'")
    }
    for name in req.want_refs {
      match ref_map.get(name) {
        Some(id) => {
          wanted_refs.push((name, id))
          all_wants.push(id)
        }
        None => raise @bit.GitError::ProtocolError("unknown ref " + name)
      }
    }
  }
  let seen_wants : Map[String, Bool] = Map([])
  let wants : Array[@bit.ObjectId] = []
  for id in all_wants {
    let hex = id.to_hex()
    if !seen_wants.contains(hex) {
      seen_wants[hex] = true
      wants.push(id)
    }
  }
  if !req.done {
    let ack_ids = collect_have_acks_v2(db, fs, req.haves)
    return build_upload_pack_response_v2_ack(ack_ids)
  }

  // Collect objects reachable from wants
  let objects = collect_upload_pack_objects(db, fs, wants, req.haves) catch {
    err =>
      raise @bit.GitError::ProtocolError(upload_pack_error_message(err, true))
  }

  // Apply partial clone filter (blob:none, blob:limit, tree:depth)
  let filter_spec = match req.filter {
    Some(f) => parse_filter_spec(f)
    None => @protocol.FilterSpec::NoFilter
  }
  let filtered_objects = apply_filter_spec(objects, filter_spec)

  // Build v2 response
  build_upload_pack_response_v2(filtered_objects, wanted_refs)
}

///|
/// Parse filter specification string (e.g., "blob:none", "blob:limit=1000")
fn parse_filter_spec(spec : String) -> @protocol.FilterSpec {
  if spec == "blob:none" {
    @protocol.FilterSpec::BlobNone
  } else if spec.has_prefix("blob:limit=") {
    let limit_str = String::unsafe_substring(spec, start=11, end=spec.length())
    let limit = upload_pack_parse_int64(limit_str) catch { _ => 0L }
    @protocol.FilterSpec::BlobLimit(limit)
  } else if spec.has_prefix("tree:") {
    let depth_str = String::unsafe_substring(spec, start=5, end=spec.length())
    let depth = upload_pack_parse_int(depth_str) catch { _ => 0 }
    @protocol.FilterSpec::TreeDepth(depth)
  } else {
    @protocol.FilterSpec::NoFilter
  }
}

///|
/// Apply filter specification to objects
fn apply_filter_spec(
  objects : Array[@bit.PackObject],
  filter : @protocol.FilterSpec,
) -> Array[@bit.PackObject] {
  match filter {
    NoFilter => objects
    BlobNone => {
      // Exclude all blobs
      let result : Array[@bit.PackObject] = []
      for obj in objects {
        if obj.obj_type != @bit.ObjectType::Blob {
          result.push(obj)
        }
      }
      result
    }
    BlobLimit(max_size) => {
      // Exclude blobs larger than max_size
      let result : Array[@bit.PackObject] = []
      for obj in objects {
        if obj.obj_type != @bit.ObjectType::Blob ||
          obj.data.length().to_int64() <= max_size {
          result.push(obj)
        }
      }
      result
    }
    TreeDepth(depth) =>
      if depth == 0 {
        let result : Array[@bit.PackObject] = []
        for obj in objects {
          if obj.obj_type != @bit.ObjectType::Tree &&
            obj.obj_type != @bit.ObjectType::Blob {
            result.push(obj)
          }
        }
        result
      } else {
        objects
      }
    SparseOid(_) | SparsePathUnsupported => objects
  }
}

///|
/// Negotiation round of a v2 fetch: the client sent `have` lines but not
/// `done`, so the server reports what it recognised and stops there.
///
/// The section always appears and always carries either ACKs or a NAK. No
/// `ready` is sent, because this server does not build the pack until the
/// client says `done` — and the protocol forbids any further section once
/// `ready` was withheld, which is exactly the rule the previous version
/// broke by following ACKs with a packfile.
fn build_upload_pack_response_v2_ack(
  ack_ids : Array[@bit.ObjectId],
) -> Bytes {
  let out : Array[Byte] = []
  upload_push_bytes(out, @protocol.pktline_encode("acknowledgments\n"))
  if ack_ids.length() == 0 {
    upload_push_bytes(out, @protocol.pktline_encode("NAK\n"))
  } else {
    for id in ack_ids {
      upload_push_bytes(
        out,
        @protocol.pktline_encode("ACK " + id.to_hex() + "\n"),
      )
    }
  }
  upload_push_bytes(out, @protocol.pktline_flush())
  Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
}

///|
/// Final round of a v2 fetch: the client sent `done`, so the pack follows.
///
/// No acknowledgments section appears here. The protocol omits it once the
/// client is finished negotiating, and sending one without `ready` in front
/// of a packfile is what made git reject this response.
fn build_upload_pack_response_v2(
  objects : Array[@bit.PackObject],
  wanted_refs : Array[(String, @bit.ObjectId)],
) -> Bytes {
  let out : Array[Byte] = []
  if wanted_refs.length() > 0 {
    upload_push_bytes(out, @protocol.pktline_encode("wanted-refs\n"))
    for item in wanted_refs {
      let (name, id) = item
      upload_push_bytes(
        out,
        @protocol.pktline_encode("\{id.to_hex()} \{name}\n"),
      )
    }
    upload_push_bytes(out, @protocol.pktline_delim())
  }

  // Send packfile-section header
  upload_push_bytes(out, @protocol.pktline_encode("packfile\n"))

  let pack = build_upload_packfile(objects)

  // Send packfile via side-band-64k (band 1)
  let chunk_size = 65515 // 65520 - 4 (pkt-line header) - 1 (band byte)
  let mut offset = 0
  while offset < pack.length() {
    let end = if offset + chunk_size > pack.length() {
      pack.length()
    } else {
      offset + chunk_size
    }
    let data_len = end - offset
    let pkt_len = data_len + 5 // 4 (header) + 1 (band byte)
    let len_hex = @bithash.int_to_hex4(pkt_len)
    for c in len_hex {
      out.push(c.to_int().to_byte())
    }
    out.push(b'\x01') // band 1 = packfile data
    for i in offset..<end {
      out.push(pack[i])
    }
    offset = end
  }

  // Flush packet to end
  upload_push_bytes(out, @protocol.pktline_flush())
  Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
}
