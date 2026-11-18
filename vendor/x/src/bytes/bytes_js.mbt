// JS fast paths are provided by @mizchi/jsimd-moonbit-interop. That package
// preserves MoonBit Bytes semantics while delegating hot paths to the prebuilt
// Wasm SIMD kernels in @mizchi/jsimd/bytes.

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_find_byte(target : Bytes, needle : Byte) -> Int32 = "findByte"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_find(target : Bytes, needle : Bytes) -> Int32 = "find"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_rev_find_byte(target : Bytes, needle : Byte) -> Int32 = "revFindByte"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_rev_find(target : Bytes, needle : Bytes) -> Int32 = "revFind"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_find_non_ascii(target : Bytes) -> Int32 = "findNonAscii"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_equal(left : Bytes, right : Bytes) -> Bool = "equal"

///|
#module("@mizchi/jsimd-moonbit-interop")
extern "js" fn js_compare(left : Bytes, right : Bytes) -> Int32 = "compare"

///|
fn found(index : Int32) -> Int32? {
  if index < 0 {
    None
  } else {
    Some(index)
  }
}

///|
/// Finds the first occurrence of `needle` in `target`.
pub fn find(target : Bytes, needle : BytesView) -> Int32? {
  if needle.length() == 1 {
    found(js_find_byte(target, needle.unsafe_get(0)))
  } else {
    found(js_find(target, needle.to_owned()))
  }
}

///|
/// Finds the last occurrence of `needle` in `target`.
pub fn rev_find(target : Bytes, needle : BytesView) -> Int32? {
  if needle.length() == 1 {
    found(js_rev_find_byte(target, needle.unsafe_get(0)))
  } else {
    found(js_rev_find(target, needle.to_owned()))
  }
}

///|
/// Finds the first occurrence of `needle` in `target`.
pub fn find_byte(target : Bytes, needle : Byte) -> Int32? {
  found(js_find_byte(target, needle))
}

///|
/// Finds the last occurrence of `needle` in `target`.
pub fn rev_find_byte(target : Bytes, needle : Byte) -> Int32? {
  found(js_rev_find_byte(target, needle))
}

///|
/// Returns the first non-ASCII byte offset, or `None` when all bytes are ASCII.
pub fn find_non_ascii(target : Bytes) -> Int32? {
  found(js_find_non_ascii(target))
}

///|
/// Returns whether `left` and `right` contain the same bytes.
pub fn equal(left : Bytes, right : Bytes) -> Bool {
  js_equal(left, right)
}

///|
/// Compares two byte sequences using the builtin `Bytes` shortlex ordering.
pub fn compare(left : Bytes, right : Bytes) -> Int32 {
  js_compare(left, right)
}
