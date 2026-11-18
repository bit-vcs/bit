///|
fn file_fd_to_int(fd : @types.Fd) -> Int32 {
  let fd = file_fd_raw(fd)
  let max_int = 2147483647
  if fd > max_int.to_uint64() {
    abort("file fd value too large to fit in Int")
  }
  fd.reinterpret_as_int64().to_int()
}

///|
/// `@types.Fd` is an opaque `UInt64` host handle on wasm.
fn file_fd_raw(fd : @types.Fd) -> UInt64 = "%identity"
