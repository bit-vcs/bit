///|
pub fn find(target : BytesView, needle : BytesView) -> Int32? {
  target.find(needle)
}

///|
pub fn find_byte(target : BytesView, needle : Byte) -> Int32? {
  target.find(Bytes::make(1, needle)[:])
}

///|
pub fn rev_find_byte(target : BytesView, needle : Byte) -> Int32? {
  target.rev_find(Bytes::make(1, needle)[:])
}

///|
pub fn find_non_ascii(target : BytesView) -> Int32? {
  for i in 0..<target.length() {
    if target.unsafe_get(i).to_int() >= 0x80 {
      break Some(i)
    }
  } nobreak {
    None
  }
}

///|
pub fn equal(left : BytesView, right : BytesView) -> Bool {
  left == right
}

///|
pub fn compare(left : BytesView, right : BytesView) -> Int32 {
  left.compare(right)
}
