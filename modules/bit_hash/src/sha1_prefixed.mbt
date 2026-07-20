///| Hash two consecutive byte slices as one SHA-1 stream.

///|
/// The native implementation dispatches to the platform SHA-1 backend without
/// copying `prefix` and `data` into one temporary buffer. Other targets retain
/// the portable MoonBit implementation.
#cfg(target="native")
#borrow(prefix, data, out)
extern "C" fn sha1_compute_prefixed_ffi(
  prefix : Bytes,
  prefix_len : Int,
  data : Bytes,
  data_len : Int,
  out : FixedArray[Byte],
) -> Unit = "sha1_compute_prefixed"

///|
#cfg(target="native")
pub fn sha1_prefixed_raw(prefix : Bytes, data : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(20, b'\x00')
  sha1_compute_prefixed_ffi(prefix, prefix.length(), data, data.length(), out)
  out
}

///|
#cfg(not(target="native"))
pub fn sha1_prefixed_raw(prefix : Bytes, data : Bytes) -> FixedArray[Byte] {
  let state = Sha1State::new()
  state.update(prefix)
  state.update(data)
  state.finish_raw()
}
