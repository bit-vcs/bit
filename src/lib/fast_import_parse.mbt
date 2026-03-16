///| Pure parsing functions for git fast-import stream format.

///|
pub(all) struct FastImportDataResult {
  content : Bytes
  next_line : Int
}

///|
/// Parse a "data" command from pre-split lines starting at `start`.
/// Supports both byte-count mode ("data <count>") and delimited mode ("data <<DELIM").
/// Returns the parsed content bytes and the index of the next line to process.
pub fn fast_import_parse_data(
  lines : Array[String],
  start : Int,
) -> FastImportDataResult {
  if start >= lines.length() {
    return { content: Bytes::new(0), next_line: start }
  }
  let line = lines[start]
  if not(line.has_prefix("data ")) {
    return { content: Bytes::new(0), next_line: start + 1 }
  }
  let rest = String::unsafe_substring(line, start=5, end=line.length())
  if rest.has_prefix("<<") {
    // Delimited form
    let delim = String::unsafe_substring(rest, start=2, end=rest.length())
    let buf : Array[Byte] = []
    let mut idx = start + 1
    while idx < lines.length() {
      let l = lines[idx]
      if l == delim {
        idx += 1
        break
      }
      if buf.length() > 0 {
        buf.push(b'\n')
      }
      for c in l {
        buf.push(c.to_int().to_byte())
      }
      idx += 1
    }
    { content: fast_import_bytes_from_array(buf), next_line: idx }
  } else {
    // Exact byte count form
    let count = @strconv.parse_int(rest) catch { _ => 0 }
    if count == 0 {
      return { content: Bytes::new(0), next_line: start + 1 }
    }
    let buf : Array[Byte] = []
    let mut remaining = count
    let mut idx = start + 1
    while remaining > 0 && idx < lines.length() {
      let l = lines[idx]
      let line_bytes = fast_import_parse_string_byte_count(l)
      if buf.length() > 0 {
        if remaining > 0 {
          buf.push(b'\n')
          remaining -= 1
        }
      }
      if line_bytes <= remaining {
        for c in l {
          buf.push(c.to_int().to_byte())
        }
        remaining -= line_bytes
        idx += 1
      } else {
        let mut taken = 0
        for c in l {
          if taken >= remaining {
            break
          }
          buf.push(c.to_int().to_byte())
          taken += 1
        }
        remaining = 0
        idx += 1
      }
    }
    // After data, there may be a trailing LF (blank line) — consume it
    if idx < lines.length() && lines[idx].length() == 0 {
      idx += 1
    }
    { content: fast_import_bytes_from_array(buf), next_line: idx }
  }
}

///|
/// Count bytes in a string (each character = 1 byte, ASCII assumption).
pub fn fast_import_parse_string_byte_count(s : String) -> Int {
  let mut count = 0
  for _c in s {
    count += 1
  }
  count
}

///|
/// Parsed identity from an author/committer/tagger line.
pub(all) struct FastImportIdent {
  ident : String // "Name <email>"
  timestamp : Int64
  tz : String
}

///|
/// Parse an author/committer line value (after stripping the "author "/"committer " prefix).
/// Input: "Name <email> timestamp tz"
/// Returns None if the line cannot be parsed.
pub fn fast_import_parse_ident(line : String) -> FastImportIdent? {
  let chars : Array[Char] = []
  for c in line {
    chars.push(c)
  }
  let mut gt_pos = -1
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    if chars[i] == '>' {
      gt_pos = i
      break
    }
  }
  if gt_pos < 0 {
    return None
  }
  let ident_buf = StringBuilder::new()
  for i in 0..<=gt_pos {
    ident_buf.write_char(chars[i])
  }
  let ident = ident_buf.to_string()
  let rest_buf = StringBuilder::new()
  for i in (gt_pos + 1)..<chars.length() {
    rest_buf.write_char(chars[i])
  }
  let rest = fast_import_parse_trim(rest_buf.to_string())
  match rest.find(" ") {
    Some(sp) => {
      let ts_str = String::unsafe_substring(rest, start=0, end=sp)
      let tz = String::unsafe_substring(rest, start=sp + 1, end=rest.length())
      let ts = @strconv.parse_int64(ts_str) catch { _ => 0L }
      Some({ ident, timestamp: ts, tz })
    }
    None => {
      let ts = @strconv.parse_int64(rest) catch { _ => 0L }
      Some({ ident, timestamp: ts, tz: "+0000" })
    }
  }
}

///|
/// File operation types parsed from fast-import M/D/deleteall/R/C lines.
pub(all) enum FastImportFileOp {
  Modify(mode~ : String, dataref~ : String, path~ : String)
  Delete(path~ : String)
  DeleteAll
  Rename(old_path~ : String, new_path~ : String)
  Copy(old_path~ : String, new_path~ : String)
} derive(Eq, Show)

///|
/// Parse a single file operation line from a fast-import stream.
/// Returns None if the line is not a recognized file operation.
pub fn fast_import_parse_file_op(line : String) -> FastImportFileOp? {
  if line == "deleteall" {
    return Some(FastImportFileOp::DeleteAll)
  }
  if line.has_prefix("D ") {
    let path = String::unsafe_substring(line, start=2, end=line.length())
    return Some(
      FastImportFileOp::Delete(path=fast_import_parse_unquote_path(path)),
    )
  }
  if line.has_prefix("M ") {
    let rest = String::unsafe_substring(line, start=2, end=line.length())
    match rest.find(" ") {
      Some(sp1) => {
        let mode = String::unsafe_substring(rest, start=0, end=sp1)
        let after_mode = String::unsafe_substring(
          rest,
          start=sp1 + 1,
          end=rest.length(),
        )
        match after_mode.find(" ") {
          Some(sp2) => {
            let dataref = String::unsafe_substring(after_mode, start=0, end=sp2)
            let path = fast_import_parse_unquote_path(
              String::unsafe_substring(
                after_mode,
                start=sp2 + 1,
                end=after_mode.length(),
              ),
            )
            Some(FastImportFileOp::Modify(mode~, dataref~, path~))
          }
          None => None
        }
      }
      None => None
    }
  } else if line.has_prefix("R ") {
    let rest = String::unsafe_substring(line, start=2, end=line.length())
    match fast_import_parse_split_two_paths(rest) {
      Some((old_path, new_path)) =>
        Some(FastImportFileOp::Rename(old_path~, new_path~))
      None => None
    }
  } else if line.has_prefix("C ") {
    let rest = String::unsafe_substring(line, start=2, end=line.length())
    match fast_import_parse_split_two_paths(rest) {
      Some((old_path, new_path)) =>
        Some(FastImportFileOp::Copy(old_path~, new_path~))
      None => None
    }
  } else {
    None
  }
}

///|
/// Resolve a dataref string: ":N" returns the mark number, hex returns hex.
/// Returns (mark_number, hex_string) — one will be meaningful depending on format.
pub fn fast_import_parse_dataref(ref_str : String) -> (Int, String) {
  if ref_str.has_prefix(":") {
    let mark_str = String::unsafe_substring(
      ref_str,
      start=1,
      end=ref_str.length(),
    )
    let mark_num = @strconv.parse_int(mark_str) catch { _ => 0 }
    (mark_num, "")
  } else {
    (0, ref_str)
  }
}

///|
/// Parse a marks file content into an array of (mark_number, hex_oid) pairs.
pub fn fast_import_parse_marks(content : String) -> Array[(Int, String)] {
  let result : Array[(Int, String)] = []
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    if line.has_prefix(":") {
      match line.find(" ") {
        Some(sp) => {
          let mark_str = String::unsafe_substring(line, start=1, end=sp)
          let hex = String::unsafe_substring(
            line,
            start=sp + 1,
            end=line.length(),
          )
          let mark_num = @strconv.parse_int(mark_str) catch { _ => 0 }
          if mark_num > 0 && hex.length() == 40 {
            result.push((mark_num, hex))
          }
        }
        None => ()
      }
    }
  }
  result
}

///|
/// Trim whitespace from a string.
pub fn fast_import_parse_trim(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  while start < end &&
        (
          chars[start] == ' ' ||
          chars[start] == '\n' ||
          chars[start] == '\r' ||
          chars[start] == '\t'
        ) {
    start += 1
  }
  while end > start &&
        (
          chars[end - 1] == ' ' ||
          chars[end - 1] == '\n' ||
          chars[end - 1] == '\r' ||
          chars[end - 1] == '\t'
        ) {
    end -= 1
  }
  if start == 0 && end == s.length() {
    s
  } else {
    let buf = StringBuilder::new()
    for i in start..<end {
      buf.write_char(chars[i])
    }
    buf.to_string()
  }
}

///|
/// Unquote a C-style quoted path (e.g., "\"foo/bar\"" -> "foo/bar").
pub fn fast_import_parse_unquote_path(path : String) -> String {
  if path.has_prefix("\"") && path.length() > 1 {
    let inner = String::unsafe_substring(path, start=1, end=path.length())
    let inner = if inner.length() > 0 {
      let chars : Array[Char] = []
      for c in inner {
        chars.push(c)
      }
      if chars.length() > 0 && chars[chars.length() - 1] == '"' {
        let buf = StringBuilder::new()
        for i in 0..<(chars.length() - 1) {
          buf.write_char(chars[i])
        }
        buf.to_string()
      } else {
        inner
      }
    } else {
      inner
    }
    let chars : Array[Char] = []
    for c in inner {
      chars.push(c)
    }
    let buf = StringBuilder::new()
    let mut i = 0
    while i < chars.length() {
      if chars[i] == '\\' && i + 1 < chars.length() {
        match chars[i + 1] {
          'n' => buf.write_char('\n')
          't' => buf.write_char('\t')
          '\\' => buf.write_char('\\')
          '"' => buf.write_char('"')
          _ => {
            buf.write_char('\\')
            buf.write_char(chars[i + 1])
          }
        }
        i += 2
      } else {
        buf.write_char(chars[i])
        i += 1
      }
    }
    buf.to_string()
  } else {
    path
  }
}

///|
/// Split two space-separated paths, handling quoted paths.
pub fn fast_import_parse_split_two_paths(s : String) -> (String, String)? {
  if s.has_prefix("\"") {
    let chars : Array[Char] = []
    for c in s {
      chars.push(c)
    }
    let mut i = 1
    while i < chars.length() {
      if chars[i] == '"' && (i == 0 || chars[i - 1] != '\\') {
        let first = String::unsafe_substring(s, start=0, end=i + 1)
        let rest = if i + 2 < chars.length() {
          String::unsafe_substring(s, start=i + 2, end=chars.length())
        } else {
          ""
        }
        return Some(
          (
            fast_import_parse_unquote_path(first),
            fast_import_parse_unquote_path(rest),
          ),
        )
      }
      i += 1
    }
    None
  } else {
    match s.find(" ") {
      Some(sp) => {
        let first = String::unsafe_substring(s, start=0, end=sp)
        let second = String::unsafe_substring(s, start=sp + 1, end=s.length())
        Some((first, fast_import_parse_unquote_path(second)))
      }
      None => None
    }
  }
}

///|
fn fast_import_bytes_from_array(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), fn(i) { arr[i] }))
}
