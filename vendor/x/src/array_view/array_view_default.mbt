///|
pub fn find_byte(target : ArrayView[Byte], needle : Byte) -> Int32? {
  target.search(needle)
}

///|
pub fn rev_find_byte(target : ArrayView[Byte], needle : Byte) -> Int32? {
  let mut i = target.length() - 1
  while i >= 0 {
    if target[i] == needle {
      return Some(i)
    }
    i = i - 1
  }
  None
}

///|
fn matches_at(
  target : ArrayView[Byte],
  needle : ArrayView[Byte],
  index : Int32,
) -> Bool {
  for offset in 0..<needle.length() {
    if target[index + offset] != needle[offset] {
      return false
    }
  }
  true
}

///|
pub fn find(target : ArrayView[Byte], needle : ArrayView[Byte]) -> Int32? {
  if needle.length() == 0 {
    return Some(0)
  }
  if needle.length() > target.length() {
    return None
  }
  for i in 0..<=(target.length() - needle.length()) {
    if matches_at(target, needle, i) {
      break Some(i)
    }
  } nobreak {
    None
  }
}

///|
pub fn rev_find(target : ArrayView[Byte], needle : ArrayView[Byte]) -> Int32? {
  if needle.length() == 0 {
    return Some(target.length())
  }
  let mut i = target.length() - needle.length()
  while i >= 0 {
    if matches_at(target, needle, i) {
      return Some(i)
    }
    i = i - 1
  }
  None
}
