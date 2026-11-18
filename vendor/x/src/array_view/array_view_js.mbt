///|
#module("@mizchi/jsimd-moonbit-interop/array-view")
extern "js" fn js_find_byte(target : ArrayView[Byte], needle : Byte) -> Int32 = "arrayViewFindByte"

///|
#module("@mizchi/jsimd-moonbit-interop/array-view")
extern "js" fn js_rev_find_byte(
  target : ArrayView[Byte],
  needle : Byte,
) -> Int32 = "arrayViewRevFindByte"

///|
#module("@mizchi/jsimd-moonbit-interop/array-view")
extern "js" fn js_find(
  target : ArrayView[Byte],
  needle : ArrayView[Byte],
) -> Int32 = "arrayViewFind"

///|
#module("@mizchi/jsimd-moonbit-interop/array-view")
extern "js" fn js_rev_find(
  target : ArrayView[Byte],
  needle : ArrayView[Byte],
) -> Int32 = "arrayViewRevFind"

///|
fn found(index : Int32) -> Int32? {
  if index < 0 {
    None
  } else {
    Some(index)
  }
}

///|
pub fn find_byte(target : ArrayView[Byte], needle : Byte) -> Int32? {
  found(js_find_byte(target, needle))
}

///|
pub fn rev_find_byte(target : ArrayView[Byte], needle : Byte) -> Int32? {
  found(js_rev_find_byte(target, needle))
}

///|
pub fn find(target : ArrayView[Byte], needle : ArrayView[Byte]) -> Int32? {
  found(js_find(target, needle))
}

///|
pub fn rev_find(target : ArrayView[Byte], needle : ArrayView[Byte]) -> Int32? {
  found(js_rev_find(target, needle))
}
