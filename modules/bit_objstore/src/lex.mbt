///|
/// Byte-lexicographic string ordering.
///
/// `String::compare` orders by length first — it answers that `"b"` sorts
/// before `"aa"`. That is a fine total order for a local sort, and wrong for
/// any ordering that has to agree with another system's. SigV4 canonical
/// headers, S3 key listings and Git ref advertisements are all specified in
/// byte order, so they need this instead.
pub fn lex_compare(a : String, b : String) -> Int {
  let left = @utf8.encode(a)
  let right = @utf8.encode(b)
  let shorter = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<shorter {
    let x = left[i].to_int()
    let y = right[i].to_int()
    if x != y {
      return if x < y { -1 } else { 1 }
    }
  }
  if left.length() == right.length() {
    0
  } else if left.length() < right.length() {
    -1
  } else {
    1
  }
}

///|
/// `a < b` in byte-lexicographic order.
pub fn lex_lt(a : String, b : String) -> Bool {
  lex_compare(a, b) < 0
}
