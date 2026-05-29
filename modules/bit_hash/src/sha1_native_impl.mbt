// SHA-1 implementations for the native target (C FFI + SHA-NI).

///|
fn Sha1State::process_block(self : Sha1State) -> Unit {
  sha1_process_blocks_ffi(self.h, self.block, 0, 1)
}

///|
pub fn sha1_raw(data : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(20, b'\x00')
  sha1_compute_ffi(data, data.length(), out)
  out
}
