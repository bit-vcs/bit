///| Common hash/hex helpers.

///|
pub fn short_hex(hex : String, n : Int) -> String {
  if hex.length() <= n {
    hex
  } else {
    String::unsafe_substring(hex, start=0, end=n)
  }
}

///|
pub fn is_hex_char(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
pub fn is_hex_string(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  for c in s {
    if not(is_hex_char(c)) {
      return false
    }
  }
  true
}

///|
pub fn lower_hex_string(s : String) -> String {
  let out = StringBuilder::new()
  for c in s {
    if c >= 'A' && c <= 'F' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
pub fn hex_char_to_int(c : Char) -> Int raise @git.GitError {
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
pub fn int_to_hex4(n : Int) -> String {
  let digits = "0123456789abcdef"
  let mut result = ""
  let mut v = n
  for _ in 0..<4 {
    let d = v % 16
    result = String::make(1, digits[d].to_int().unsafe_to_char()) + result
    v = v / 16
  }
  result
}
