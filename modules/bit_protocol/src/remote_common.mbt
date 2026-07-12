///| Git HTTP push protocol - common logic (all targets)

///| Uses HttpClient functions passed as arguments

///|
/// Helper to convert Array[Byte] to Bytes
fn remote_array_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), i => arr[i]))
}

///|
/// Remote repository URL
pub struct Remote {
  url : String // e.g., "https://github.com/user/repo.git"
}

///|
pub fn Remote::new(url : String) -> Remote {
  { url, }
}

///|
/// Normalize URL (remove trailing .git if present)
fn normalize_url(url : String) -> String {
  if url.has_suffix(".git") {
    let chars = url.to_array()
    let result = StringBuilder::new()
    for i in 0..<(chars.length() - 4) {
      result.write_char(chars[i])
    }
    result.to_string()
  } else {
    url
  }
}

///|
/// Build URL for git-receive-pack info/refs
pub fn Remote::info_refs_url(self : Remote) -> String {
  let base = normalize_url(self.url)
  "\{base}/info/refs?service=git-receive-pack"
}

///|
/// Build URL for git-receive-pack
pub fn Remote::receive_pack_url(self : Remote) -> String {
  let base = normalize_url(self.url)
  "\{base}/git-receive-pack"
}

///|
/// Git push request data
pub struct PushRequest {
  old_id : @bit.ObjectId
  new_id : @bit.ObjectId
  refname : String
  packfile : Bytes
}

///|
pub fn PushRequest::new(
  old_id : @bit.ObjectId,
  new_id : @bit.ObjectId,
  refname : String,
  packfile : Bytes,
) -> PushRequest {
  { old_id, new_id, refname, packfile }
}

///|
/// Build the request body for git-receive-pack
pub fn build_receive_pack_body(req : PushRequest) -> Bytes {
  let result : Array[Byte] = []
  let cmd = build_ref_update(
    req.old_id,
    req.new_id,
    req.refname,
    "report-status side-band-64k",
  )
  let cmd_pkt = pktline_encode(cmd)
  for b in cmd_pkt {
    result.push(b)
  }
  let flush = pktline_flush()
  for b in flush {
    result.push(b)
  }
  for b in req.packfile {
    result.push(b)
  }
  remote_array_to_bytes(result)
}

///|
/// Parse receive-pack response
pub fn parse_receive_pack_response(
  data : Bytes,
) -> Result[String, @bit.GitError] {
  let decoded = pktline_decode(data) catch { e => return Err(e) }
  let mut unpack_ok = false
  let mut ref_ok = false
  let mut error_msg = ""
  let mut sideband = false
  let band1_bytes : Array[Byte] = []
  for item in decoded {
    let (line_bytes, is_flush) = item
    if is_flush || line_bytes.length() == 0 {
      continue
    }
    let first = line_bytes[0].to_int()
    if first >= 1 && first <= 3 {
      sideband = true
      let (channel, content) = parse_sideband(line_bytes)
      if channel == 1 {
        for b in content {
          band1_bytes.push(b)
        }
      } else if channel == 3 {
        let msg = remote_bytes_to_string(sanitize_sideband_text(content))
          .trim(chars=" \n\r\t")
          .to_owned()
        if msg.length() > 0 {
          error_msg = msg
        }
      }
      continue
    }
    let line = remote_bytes_to_string(line_bytes)
    if line.has_prefix("unpack ok") {
      unpack_ok = true
    } else if line.has_prefix("unpack ") {
      error_msg = line
    } else if line.has_prefix("ok ") {
      ref_ok = true
    } else if line.has_prefix("ng ") {
      error_msg = line
    }
  }
  if sideband {
    if error_msg.length() > 0 {
      return error_msg |> @bit.GitError::ProtocolError |> Err
    }
    let band1 = remote_array_to_bytes(band1_bytes)
    let band_decoded = pktline_decode(band1) catch { e => return Err(e) }
    unpack_ok = false
    ref_ok = false
    error_msg = ""
    for item in band_decoded {
      let (line_bytes, is_flush) = item
      if is_flush || line_bytes.length() == 0 {
        continue
      }
      let line = remote_bytes_to_string(line_bytes)
      if line.has_prefix("unpack ok") {
        unpack_ok = true
      } else if line.has_prefix("unpack ") {
        error_msg = line
      } else if line.has_prefix("ok ") {
        ref_ok = true
      } else if line.has_prefix("ng ") {
        error_msg = line
      }
    }
  }
  if unpack_ok && ref_ok {
    Ok("Push successful")
  } else if error_msg.length() > 0 {
    error_msg |> @bit.GitError::ProtocolError |> Err
  } else {
    "Unknown response" |> @bit.GitError::ProtocolError |> Err
  }
}

///|
/// Parse side-band data
pub fn parse_sideband(data : Bytes) -> (Int, Bytes) {
  if data.length() == 0 {
    return (0, Bytes::from_array([]))
  }
  let channel = data[0].to_int()
  let content : Array[Byte] = []
  for i in 1..<data.length() {
    content.push(data[i])
  }
  (channel, remote_array_to_bytes(content))
}

///|
/// Strip terminal control sequences from sideband payload before it
/// reaches the user's terminal. Mirrors git 2.55's
/// `sideband.allowControlCharacters=color` default: line feeds, tabs
/// and ANSI color (CSI ... m) pass through; every other C0/C1 byte
/// and every non-color CSI sequence is replaced with `?`.
///
/// A hostile remote can otherwise push CSI sequences via band 2
/// (progress) or band 3 (error). Bit's band 3 handling turns the
/// payload into a `GitError` message that flows to stderr, so an
/// attacker could clear the screen, hide their output, or fake a
/// password prompt.
pub fn sanitize_sideband_text(data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  while i < data.length() {
    let b = data[i].to_int()
    if b == 0x1B && i + 1 < data.length() && data[i + 1].to_int() == 0x5B {
      // CSI: ESC '[' params final.
      let mut j = i + 2
      while j < data.length() {
        let c = data[j].to_int()
        // Parameter / intermediate bytes: 0x20–0x3F.
        if c >= 0x20 && c < 0x40 {
          j = j + 1
          continue
        }
        break
      }
      if j < data.length() && data[j].to_int() == 0x6D {
        // CSI ... m — SGR (color/style). Keep verbatim.
        while i <= j {
          out.push(data[i])
          i = i + 1
        }
        continue
      }
      // Non-color CSI: drop the whole sequence (replace with one ?).
      out.push(b'?')
      i = if j < data.length() { j + 1 } else { data.length() }
      continue
    }
    if b == 0x09 ||
      b == 0x0A ||
      b == 0x0D ||
      (b >= 0x20 && b < 0x7F) ||
      b >= 0x80 {
      out.push(data[i])
    } else {
      // C0 (other than tab/LF/CR), DEL, lone ESC.
      out.push(b'?')
    }
    i = i + 1
  }
  remote_array_to_bytes(out)
}

///|
/// Extract capabilities from refs response
pub fn extract_capabilities(data : Bytes) -> Array[String] {
  let result : Array[String] = []
  let decoded = pktline_decode(data) catch { _ => return result }
  for item in decoded {
    let (line_bytes, _) = item
    if line_bytes.length() == 0 {
      continue
    }
    let line = remote_bytes_to_string(line_bytes)
    match line.find("\u0000") {
      None => continue
      Some(idx) => {
        let caps_str = remote_substring_from(line, idx + 1)
        let mut current : Array[Char] = []
        for c in caps_str {
          if c == ' ' || c == '\n' {
            if current.length() > 0 {
              let sb = StringBuilder::new()
              for ch in current {
                sb.write_char(ch)
              }
              result.push(sb.to_string())
              current = []
            }
          } else {
            current.push(c)
          }
        }
        if current.length() > 0 {
          let sb = StringBuilder::new()
          for ch in current {
            sb.write_char(ch)
          }
          result.push(sb.to_string())
        }
        break
      }
    }
  }
  result
}

///|
fn remote_substring_from(s : String, start : Int) -> String {
  let chars = s.to_array()
  if start >= chars.length() {
    return ""
  }
  let result = StringBuilder::new()
  for i in start..<chars.length() {
    result.write_char(chars[i])
  }
  result.to_string()
}

///|
fn remote_bytes_to_string(data : Bytes) -> String {
  let result = StringBuilder::new()
  for b in data {
    result.write_char(b.to_int().unsafe_to_char())
  }
  result.to_string()
}

///|
/// Discover refs using provided HTTP client functions
pub async fn discover_refs_with_http(
  remote : Remote,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> (Array[(@bit.ObjectId, String)], Array[String]) raise @bit.GitError {
  let url = remote.info_refs_url()
  let headers : Map[String, String] = {
    "User-Agent": "git/moonbit",
    "Accept": "application/x-git-receive-pack-advertisement",
  }
  let (response, data) = http_get(url, headers)
  if response.code != 200 {
    raise @bit.GitError::ProtocolError(
      "Failed to discover refs: HTTP \{response.code}",
    )
  }
  let refs = parse_refs(data)
  let caps = extract_capabilities(data)
  (refs, caps)
}

///|
/// Push using provided HTTP client functions
pub async fn push_with_http(
  remote : Remote,
  req : PushRequest,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> String raise @bit.GitError {
  let (_, caps) = discover_refs_with_http(remote, http_get)
  let has_report_status = caps.contains("report-status")
  if !has_report_status {
    raise @bit.GitError::ProtocolError("Server does not support report-status")
  }
  let url = remote.receive_pack_url()
  let body = build_receive_pack_body(req)
  let headers : Map[String, String] = {
    "User-Agent": "git/moonbit",
    "Content-Type": "application/x-git-receive-pack-request",
    "Accept": "application/x-git-receive-pack-result",
  }
  let (response, response_data) = http_post(url, body, headers)
  if response.code != 200 {
    raise @bit.GitError::ProtocolError("Failed to push: HTTP \{response.code}")
  }
  match parse_receive_pack_response(response_data) {
    Ok(msg) => msg
    Err(e) => raise e
  }
}
