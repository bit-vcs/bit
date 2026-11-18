///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_find(target : StringView, needle : StringView) -> Int32 = "stringViewFind"

///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_rev_find(target : StringView, needle : StringView) -> Int32 = "stringViewRevFind"

///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_find_code_unit(target : StringView, needle : UInt16) -> Int32 = "stringViewFindCodeUnit"

///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_rev_find_code_unit(
  target : StringView,
  needle : UInt16,
) -> Int32 = "stringViewRevFindCodeUnit"

///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_compare(left : StringView, right : StringView) -> Int32 = "stringViewCompare"

///|
fn found(index : Int32) -> Int32? {
  if index < 0 {
    None
  } else {
    Some(index)
  }
}

///|
pub fn find(target : StringView, needle : StringView) -> Int32? {
  found(js_find(target, needle))
}

///|
pub fn rev_find(target : StringView, needle : StringView) -> Int32? {
  found(js_rev_find(target, needle))
}

///|
pub fn find_code_unit(target : StringView, needle : UInt16) -> Int32? {
  found(js_find_code_unit(target, needle))
}

///|
pub fn rev_find_code_unit(target : StringView, needle : UInt16) -> Int32? {
  found(js_rev_find_code_unit(target, needle))
}

///|
pub fn compare(left : StringView, right : StringView) -> Int32 {
  js_compare(left, right)
}
