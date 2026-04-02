///|
#borrow(path)
extern "C" fn hub_libgit2_repo_path(path : Bytes) -> Bytes = "hub_libgit2_repo_path"

///|
#borrow(path)
extern "C" fn hub_libgit2_head_name(path : Bytes) -> Bytes = "hub_libgit2_head_name"

///|
extern "C" fn hub_libgit2_init() -> Int = "hub_libgit2_init"

///|
extern "C" fn hub_libgit2_is_loaded() -> Int = "hub_libgit2_is_loaded"

///|
fn hub_libgit2_decode_nonempty(bytes : Bytes) -> String? {
  let value = decode_bytes(bytes)
  if value.length() == 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn hub_libgit2_available() -> Bool {
  hub_libgit2_is_loaded() == 1 || hub_libgit2_init() >= 0
}

///|
fn hub_git_repository_path(root : String) -> String? {
  if !hub_libgit2_available() {
    return None
  }
  hub_libgit2_decode_nonempty(hub_libgit2_repo_path(str_to_bytes(root)))
}

///|
fn hub_git_head_ref_name(root : String) -> String? {
  if !hub_libgit2_available() {
    return None
  }
  hub_libgit2_decode_nonempty(hub_libgit2_head_name(str_to_bytes(root)))
}
