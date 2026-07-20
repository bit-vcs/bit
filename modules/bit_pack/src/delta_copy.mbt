///| Copy one validated delta span into its output buffer.

///|
/// `apply_delta` checks all offsets and sizes before reaching this helper.
/// Native builds use libc's tuned bulk copy; JavaScript and Wasm preserve the
/// portable element-wise fallback.
#cfg(target="native")
#borrow(source, destination)
extern "C" fn copy_delta_bytes_ffi(
  source : Bytes,
  source_offset : Int,
  destination : FixedArray[Byte],
  destination_offset : Int,
  length : Int,
) -> Unit = "bit_pack_copy_delta_bytes"

///|
#cfg(target="native")
fn copy_delta_bytes(
  source : Bytes,
  source_offset : Int,
  destination : FixedArray[Byte],
  destination_offset : Int,
  length : Int,
) -> Unit {
  copy_delta_bytes_ffi(
    source, source_offset, destination, destination_offset, length,
  )
}

///|
#cfg(not(target="native"))
fn copy_delta_bytes(
  source : Bytes,
  source_offset : Int,
  destination : FixedArray[Byte],
  destination_offset : Int,
  length : Int,
) -> Unit {
  for i in 0..<length {
    destination[destination_offset + i] = source[source_offset + i]
  }
}
