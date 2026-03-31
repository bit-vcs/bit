///| WASM Component path helpers

///|
fn join_path(base : String, name : String) -> String {
  if base.length() == 0 {
    name
  } else if base == "/" {
    "/" + name
  } else {
    base + "/" + name
  }
}

///|
fn resolve_git_dir(fs : &@bit.RepoFileSystem, root : String) -> String {
  let _ = fs
  join_path(root, ".git")
}
