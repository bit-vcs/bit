///| WASM Component history operations

///|
fn commit_with_fs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  message : String,
  author : String,
  timestamp : Int64,
) -> String raise @bit.GitError {
  let id = @bitlib.commit(fs, rfs, root, message, author, timestamp)
  id.to_hex()
}

///|
pub fn commit(
  root : String,
  message : String,
  author : String,
  timestamp : Int64,
) -> Result[String, String] {
  with_wasm_rw_fs(fn(fs, rfs) raise @bit.GitError {
    commit_with_fs(fs, rfs, root, message, author, timestamp)
  })
}

///|
fn log_with_fs(
  fs : &@bit.RepoFileSystem,
  root : String,
  max_count : Int,
) -> Array[LogEntry] raise @bit.GitError {
  let git_dir = resolve_git_dir(fs, root)
  let entries = @bitlib.log_head(fs, git_dir, max_count~)
  let result : Array[LogEntry] = []
  for e in entries {
    result.push(LogEntry::{
      id: e.id.to_hex(),
      author: e.author,
      message: e.message,
      timestamp: e.timestamp,
    })
  }
  result
}

///|
pub fn log(root : String, max_count : Int) -> Result[Array[LogEntry], String] {
  with_wasm_repo_fs(fn(rfs) raise @bit.GitError {
    log_with_fs(rfs, root, max_count)
  })
}
