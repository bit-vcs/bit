///| Pure commit helper functions — string/bytes manipulation with no IO.

///|
/// Trim leading/trailing whitespace from a string.
fn commit_trim_string(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = s.unsafe_get(start)
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start += 1
    } else {
      break
    }
  }
  while end > start {
    let c = s.unsafe_get(end - 1)
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end -= 1
    } else {
      break
    }
  }
  if start == 0 && end == s.length() {
    s
  } else {
    String::unsafe_substring(s, start~, end~)
  }
}

///|
/// Strip comment lines and trailing/leading blank lines from a commit message.
pub fn commit_strip_message(msg : String) -> String {
  let lines : Array[String] = []
  for line_view in msg.split("\n") {
    let line = line_view.to_string()
    let trimmed = commit_trim_string(line)
    // Skip comment lines (lines starting with #)
    if trimmed.has_prefix("#") {
      continue
    }
    lines.push(line)
  }
  // Strip trailing empty lines
  while lines.length() > 0 {
    let last = lines[lines.length() - 1]
    if commit_trim_string(last).length() == 0 {
      let _ = lines.pop()
    } else {
      break
    }
  }
  // Strip leading empty lines
  while lines.length() > 0 && commit_trim_string(lines[0]).length() == 0 {
    let _ = lines.remove(0)
  }
  lines.join("\n")
}

///|
/// Check if a line is a trailer line (e.g., "Signed-off-by: ...").
pub fn commit_is_trailer_line(line : String) -> Bool {
  let trimmed = commit_trim_string(line)
  // A trailer line matches "Token: Value" or "Token #Value"
  match trimmed.find(": ") {
    Some(idx) => {
      // Token must be non-empty and contain only word chars and hyphens
      let token = String::unsafe_substring(trimmed, start=0, end=idx)
      if token.length() == 0 {
        return false
      }
      for c in token {
        if !((c >= 'a' && c <= 'z') ||
          (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') ||
          c == '-') {
          return false
        }
      }
      true
    }
    None => false
  }
}

///|
/// Apply Signed-off-by trailer to a commit message.
/// The `committer` parameter is the committer identity string (e.g. "Name <email>").
pub fn commit_apply_signoff(msg : String, committer~ : String) -> String {
  let signoff_line = "Signed-off-by: " + committer
  // Check if signoff already present at the end
  let lines : Array[String] = []
  for line_view in msg.split("\n") {
    lines.push(line_view.to_string())
  }
  // Strip trailing newlines for checking
  let mut last_nonblank = lines.length() - 1
  while last_nonblank >= 0 &&
        commit_trim_string(lines[last_nonblank]).length() == 0 {
    last_nonblank -= 1
  }
  if last_nonblank >= 0 &&
    commit_trim_string(lines[last_nonblank]) == signoff_line {
    return msg
  }
  // Determine if we need a blank line separator.
  // A blank line is needed if the last non-blank line is not a trailer.
  let need_blank = if last_nonblank >= 0 {
    !commit_is_trailer_line(lines[last_nonblank])
  } else {
    true
  }
  let result = StringBuilder::new()
  // Preserve original message
  if msg.has_suffix("\n") {
    result.write_string(msg)
  } else {
    result.write_string(msg)
    result.write_char('\n')
  }
  if need_blank {
    result.write_char('\n')
  }
  result.write_string(signoff_line)
  result.write_char('\n')
  result.to_string()
}

///|
/// Decode commit message bytes, handling ISO-8859-1 and UTF-8 encodings.
pub fn decode_commit_message_bytes(data : Bytes, encoding : String) -> String {
  if is_iso_8859_1_encoding(encoding) {
    let out = StringBuilder::new()
    for b in data {
      out.write_char(b.to_int().unsafe_to_char())
    }
    out.to_string()
  } else {
    @utf8.decode_lossy(data[:])
  }
}

///|
fn is_iso_8859_1_encoding(encoding : String) -> Bool {
  let normalized = normalize_commit_encoding_name(encoding)
  normalized == "iso88591" || normalized == "latin1" || normalized == "latin"
}

///|
fn normalize_commit_encoding_name(value : String) -> String {
  let out = StringBuilder::new()
  for c in commit_trim_string(value).to_lower() {
    if c == '-' || c == '_' || c == ' ' {
      continue
    }
    out.write_char(c)
  }
  out.to_string()
}

///|
/// Parse a tag object string to extract the target object ID.
/// Returns the ObjectId of the tagged object (from the "object <sha>" line).
pub fn parse_tag_object(data : String) -> @bit.ObjectId? raise Error {
  for line_view in data.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("object ") {
      let hex = String::unsafe_substring(line, start=7, end=line.length())
      return hex |> commit_trim_string |> @bit.ObjectId::from_hex |> Some
    }
  }
  None
}
