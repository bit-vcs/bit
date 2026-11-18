///|
pub struct RawFd {
  fd : Int32
  priv mut closed : Bool
}

///|
#borrow(buf)
extern "C" fn raw_fd_read_ffi(
  fd : Int32,
  buf : FixedArray[Byte],
  offset~ : Int32,
  len~ : Int32,
) -> Int32 = "mizchi_x_raw_fd_read"

///|
#borrow(buf)
extern "C" fn raw_fd_write_ffi(
  fd : Int32,
  buf : Bytes,
  offset~ : Int32,
  len~ : Int32,
) -> Int32 = "mizchi_x_raw_fd_write"

///|
extern "C" fn raw_fd_close_ffi(fd : Int32) -> Int32 = "mizchi_x_raw_fd_close"

///|
#alias(new, deprecated)
pub async fn RawFd::RawFd(fd : Int32) -> RawFd {
  { fd, closed: false, }
}

///|
pub fn RawFd::close(self : RawFd) -> Unit {
  if !self.closed {
    ignore(raw_fd_close_ffi(self.fd))
    self.closed = true
  }
}

///|
pub async fn RawFd::read(
  self : RawFd,
  buf : FixedArray[Byte],
  offset~ : Int32 = 0,
  max_len~ : Int32 = buf.length() - offset,
) -> Int32 {
  if self.closed || max_len <= 0 {
    0
  } else {
    let ret = raw_fd_read_ffi(self.fd, buf, offset~, len=max_len)
    if ret < 0 {
      0
    } else {
      ret
    }
  }
}

///|
pub async fn RawFd::write(
  self : RawFd,
  buf : Bytes,
  offset~ : Int32 = 0,
  len~ : Int32 = buf.length() - offset,
) -> Int32 {
  if self.closed || len <= 0 {
    0
  } else {
    let ret = raw_fd_write_ffi(self.fd, buf, offset~, len~)
    if ret < 0 {
      0
    } else {
      ret
    }
  }
}
