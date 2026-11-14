///|
/// `(seconds, nanoseconds)` modification time of `path`.
/// `@fs.mtime` returns a `Timestamp` in moonbitlang/core/async.
async fn asyncfs_mtime_pair(
  path : StringView,
  follow_symlink~ : Bool,
) -> (Int64, Int) raise {
  let ts = @asyncfs.mtime(path, follow_symlink~)
  (ts.sec(), ts.nsec())
}
