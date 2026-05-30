// FFI declarations for SHA-NI / C SHA-1 and SHA-256 (native target only).

///|
#borrow(h, data)
extern "C" fn sha1_process_blocks_ffi(
  h : FixedArray[Int],
  data : FixedArray[Byte],
  offset : Int,
  num_blocks : Int,
) -> Unit = "sha1_process_blocks"

///|
#borrow(data, out)
extern "C" fn sha256_compute_ffi(
  data : Bytes,
  len : Int,
  out : FixedArray[Byte],
) -> Unit = "sha256_compute"
