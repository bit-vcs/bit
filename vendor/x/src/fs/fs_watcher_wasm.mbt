///|
/// WASM does not provide the native watcher backend exposed by async@0.20.3.
pub struct Watcher {}

///|
pub async fn Watcher::Watcher(
  path : String,
  debounce_timeout? : Int32,
  max_debounce_delay? : Int32,
  ignored_paths? : (String) -> Bool,
) -> Watcher raise IOError {
  ignore((path, debounce_timeout, max_debounce_delay, ignored_paths))
  ignore(Watcher::{ })
  raise IOError::IOError("Watcher is not supported on wasm target")
}

///|
pub fn Watcher::close(self : Watcher) -> Unit {
  ignore(self)
}

///|
pub async fn Watcher::wait_any(self : Watcher) -> Unit raise IOError {
  ignore(self)
  raise IOError::IOError("Watcher::wait_any is not supported on wasm target")
}
