///|
pub struct Watcher {
  priv inner : @async_fs.Watcher
}

///|
pub async fn Watcher::Watcher(
  path : String,
  debounce_timeout? : Int32,
  max_debounce_delay? : Int32,
  ignored_paths? : (String) -> Bool,
) -> Watcher raise IOError {
  let inner = @async_fs.Watcher(
    path,
    debounce_timeout?,
    max_debounce_delay?,
    ignored_paths?,
  ) catch {
    err => raise IOError::IOError(err.to_string())
  }
  Watcher::{ inner, }
}

///|
pub fn Watcher::close(self : Watcher) -> Unit {
  self.inner.close()
}

///|
pub async fn Watcher::wait_any(self : Watcher) -> Unit raise IOError {
  self.inner.wait_any() catch {
    err => raise IOError::IOError(err.to_string())
  }
}
