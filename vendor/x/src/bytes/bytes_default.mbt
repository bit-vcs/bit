///|
/// Finds the first occurrence of `needle` in `target`.
pub fn find(target : Bytes, needle : BytesView) -> Int32? {
  target.find(needle)
}

///|
/// Finds the last occurrence of `needle` in `target`.
pub fn rev_find(target : Bytes, needle : BytesView) -> Int32? {
  target.rev_find(needle)
}

///|
/// Finds the first occurrence of `needle` in `target`.
pub fn find_byte(target : Bytes, needle : Byte) -> Int32? {
  target.find(Bytes::make(1, needle)[:])
}

///|
/// Finds the last occurrence of `needle` in `target`.
pub fn rev_find_byte(target : Bytes, needle : Byte) -> Int32? {
  target.rev_find(Bytes::make(1, needle)[:])
}

///|
/// Returns the first non-ASCII byte offset, or `None` when all bytes are ASCII.
pub fn find_non_ascii(target : Bytes) -> Int32? {
  for i in 0..<target.length() {
    if target.unsafe_get(i).to_int() >= 0x80 {
      break Some(i)
    }
  } nobreak {
    None
  }
}

///|
/// Returns whether `left` and `right` contain the same bytes.
pub fn equal(left : Bytes, right : Bytes) -> Bool {
  left == right
}

///|
/// Compares two byte sequences using the builtin `Bytes` shortlex ordering.
pub fn compare(left : Bytes, right : Bytes) -> Int32 {
  left.compare(right)
}
