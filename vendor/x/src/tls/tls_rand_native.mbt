///|
#borrow(buf)
extern "C" fn rand_bytes_ffi(buf : FixedArray[Byte], len : Int32) -> Int32 = "mizchi_x_tls_rand_bytes"

///|
/// Cryptographically secure random bytes from the OS (core's async/tls no
/// longer exposes `rand_bytes`).
pub fn rand_bytes(num : Int32) -> Bytes raise {
  if num < 0 {
    raise TlsError("rand_bytes length must be non-negative")
  }
  let buf = FixedArray::make(num, b'\x00')
  if rand_bytes_ffi(buf, num) != 0 {
    raise TlsError("rand_bytes: the OS random source failed")
  }
  Bytes::from_array(buf)
}
