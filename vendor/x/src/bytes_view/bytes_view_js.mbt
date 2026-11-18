///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_find(target : BytesView, needle : BytesView) -> Int32 = "find"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_find_byte(target : BytesView, needle : Byte) -> Int32 = "findByte"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_rev_find_byte(target : BytesView, needle : Byte) -> Int32 = "revFindByte"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_find_non_ascii(target : BytesView) -> Int32 = "findNonAscii"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_equal(left : BytesView, right : BytesView) -> Bool = "equal"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_compare(left : BytesView, right : BytesView) -> Int32 = "compare"

///|
fn found(index : Int32) -> Int32? {
  if index < 0 {
    None
  } else {
    Some(index)
  }
}

///|
pub fn find(target : BytesView, needle : BytesView) -> Int32? {
  found(js_find(target, needle))
}

///|
pub fn find_byte(target : BytesView, needle : Byte) -> Int32? {
  found(js_find_byte(target, needle))
}

///|
pub fn rev_find_byte(target : BytesView, needle : Byte) -> Int32? {
  found(js_rev_find_byte(target, needle))
}

///|
pub fn find_non_ascii(target : BytesView) -> Int32? {
  found(js_find_non_ascii(target))
}

///|
pub fn equal(left : BytesView, right : BytesView) -> Bool {
  js_equal(left, right)
}

///|
pub fn compare(left : BytesView, right : BytesView) -> Int32 {
  js_compare(left, right)
}
