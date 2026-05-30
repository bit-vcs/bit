// SHA-256 fast path for the native target (C FFI + SHA-NI).

///|
pub fn sha256_bytes(data : Bytes) -> Bytes {
  let out : FixedArray[Byte] = FixedArray::make(32, b'\x00')
  sha256_compute_ffi(data, data.length(), out)
  Bytes::makei(32, fn(i) { out[i] })
}

///|
pub fn sha256_raw(data : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(32, b'\x00')
  sha256_compute_ffi(data, data.length(), out)
  out
}
