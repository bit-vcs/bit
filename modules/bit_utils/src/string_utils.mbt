///| String utility functions shared across packages.

///|
/// Convert an integer mode to its octal string representation.
pub fn to_octal_string(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let digits : Array[Char] = []
  let mut v = value
  while v > 0 {
    let d = v % 8
    digits.push((d + '0'.to_int()).unsafe_to_char())
    v = v / 8
  }
  let rev = digits.rev()
  let sb = StringBuilder::new()
  for c in rev {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// Convert a file mode integer to its canonical string (e.g. 33188 → "100644").
pub fn mode_to_string(mode : Int) -> String {
  if mode == 33188 {
    "100644"
  } else {
    to_octal_string(mode)
  }
}

///|
/// Decode bytes to string using UTF-8 lossy decoding.
pub fn decode_bytes(data : Bytes) -> String {
  @utf8.decode_lossy(data[:])
}

///|
/// Trim whitespace (space, tab, newline, carriage return) from both ends.
pub fn trim_string(s : String) -> String {
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
