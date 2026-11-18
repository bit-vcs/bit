///|
pub struct RawFd {
  fd : Int32
}

///|
#alias(new, deprecated)
pub async fn RawFd::RawFd(fd : Int32) -> RawFd {
  ignore(fd)
  abort("raw_fd is not supported on wasm target")
}

///|
pub fn RawFd::close(self : RawFd) -> Unit {
  ignore(self)
}

///|
pub async fn RawFd::read(
  self : RawFd,
  buf : FixedArray[Byte],
  offset~ : Int32 = 0,
  max_len~ : Int32 = buf.length() - offset,
) -> Int32 {
  ignore((self, buf, offset, max_len))
  abort("raw_fd is not supported on wasm target")
}

///|
pub async fn RawFd::write(
  self : RawFd,
  buf : Bytes,
  offset~ : Int32 = 0,
  len~ : Int32 = buf.length() - offset,
) -> Int32 {
  ignore((self, buf, offset, len))
  abort("raw_fd is not supported on wasm target")
}
