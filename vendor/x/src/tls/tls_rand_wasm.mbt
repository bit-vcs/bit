///|
/// Core's async/tls no longer exposes `rand_bytes`, and the wasm host offers
/// no entropy source to this package.
pub fn rand_bytes(_num : Int32) -> Bytes raise {
  raise TlsError("tls rand_bytes is not supported on the wasm target")
}
