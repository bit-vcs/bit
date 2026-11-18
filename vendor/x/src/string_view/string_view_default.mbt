///|
pub fn find(target : StringView, needle : StringView) -> Int32? {
  target.find(needle)
}

///|
pub fn rev_find(target : StringView, needle : StringView) -> Int32? {
  target.rev_find(needle)
}

///|
pub fn find_code_unit(target : StringView, needle : UInt16) -> Int32? {
  for i in 0..<target.length() {
    if target.unsafe_get(i) == needle {
      break Some(i)
    }
  } nobreak {
    None
  }
}

///|
pub fn rev_find_code_unit(target : StringView, needle : UInt16) -> Int32? {
  let mut i = target.length() - 1
  while i >= 0 {
    if target.unsafe_get(i) == needle {
      return Some(i)
    }
    i = i - 1
  }
  None
}

///|
pub fn compare(left : StringView, right : StringView) -> Int32 {
  left.compare(right)
}
