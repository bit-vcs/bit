// SHA-1 fast path for the native target (C FFI + SHA-NI).

///|
fn Sha1State::process_block(self : Sha1State) -> Unit {
  sha1_process_blocks_ffi(self.h, self.block, 0, 1)
}

///|
pub fn sha1_bytes(data : Bytes) -> Bytes {
  let raw = sha1_raw(data)
  Bytes::makei(20, fn(i) { raw[i] })
}

///|
pub fn sha1_raw(data : Bytes) -> FixedArray[Byte] {
  let state = Sha1State::new()
  state.update(data)
  state.finish_raw()
}
