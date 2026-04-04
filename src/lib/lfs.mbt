///| LFS pointer file parsing and utilities

///|
pub struct LfsPointer {
  oid : String
  size : Int64
} derive(Show, Eq)

///|
let lfs_version_prefix : String = "version https://git-lfs.github.com/spec/v1\n"

///|
let lfs_oid_prefix : String = "oid sha256:"

///|
let lfs_size_prefix : String = "size "

///|
let lfs_max_pointer_size : Int = 1024

///|
pub fn is_lfs_pointer(content : Bytes) -> Bool {
  if content.length() == 0 || content.length() > lfs_max_pointer_size {
    return false
  }
  let text = @utf8.decode_lossy(content[:])
  text.has_prefix(lfs_version_prefix)
}

///|
pub fn parse_lfs_pointer(content : Bytes) -> LfsPointer? {
  if content.length() == 0 || content.length() > lfs_max_pointer_size {
    return None
  }
  let text = @utf8.decode_lossy(content[:])
  if !text.has_prefix(lfs_version_prefix) {
    return None
  }
  let mut oid : String? = None
  let mut size : Int64? = None
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix(lfs_oid_prefix) {
      oid = Some(
        String::unsafe_substring(
          line,
          start=lfs_oid_prefix.length(),
          end=line.length(),
        ),
      )
    } else if line.has_prefix(lfs_size_prefix) {
      let num_str = String::unsafe_substring(
        line,
        start=lfs_size_prefix.length(),
        end=line.length(),
      )
      let n = @string.parse_int64(num_str.trim()) catch { _ => -1L }
      if n >= 0L {
        size = Some(n)
      }
    }
  }
  match (oid, size) {
    (Some(o), Some(s)) =>
      if o.length() == 64 && @bithash.is_hex_string(o) {
        Some({ oid: o, size: s })
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn lfs_object_path(git_dir : String, oid : String) -> String {
  let d1 = String::unsafe_substring(oid, start=0, end=2)
  let d2 = String::unsafe_substring(oid, start=2, end=4)
  "\{git_dir}/lfs/objects/\{d1}/\{d2}/\{oid}"
}
