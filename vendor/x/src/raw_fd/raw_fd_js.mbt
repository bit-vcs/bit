///|
pub struct RawFd {
  fd : Int32
  priv mut closed : Bool
}

///|
extern "js" fn js_raw_fd_read(
  fd : Int32,
  max_len : Int32,
) -> @js_async.Promise[Bytes] =
  #| async (fd, maxLen) => {
  #|   const fs = await import('node:fs');
  #|   const len = Math.max(0, Number(maxLen || 0) | 0);
  #|   if (len <= 0) return new Uint8Array(0);
  #|   const buffer = Buffer.allocUnsafe(len);
  #|   const bytesRead = await new Promise((resolve, reject) => {
  #|     fs.read(fd, buffer, 0, len, null, (err, bytesRead) => {
  #|       if (err) reject(err); else resolve(bytesRead | 0);
  #|     });
  #|   });
  #|   return new Uint8Array(buffer.subarray(0, bytesRead));
  #| }

///|
extern "js" fn js_raw_fd_write(
  fd : Int32,
  data : Bytes,
  offset : Int32,
  len : Int32,
) -> @js_async.Promise[Int32] =
  #| async (fd, data, offset, len) => {
  #|   const fs = await import('node:fs');
  #|   const start = Math.max(0, Number(offset || 0) | 0);
  #|   const maxLen = Math.max(0, Number(len || 0) | 0);
  #|   const end = Math.min(data.length, start + maxLen);
  #|   if (end <= start) return 0;
  #|   const source = Buffer.from(data).subarray(start, end);
  #|   return await new Promise((resolve, reject) => {
  #|     fs.write(fd, source, 0, source.length, null, (err, written) => {
  #|       if (err) reject(err); else resolve(written | 0);
  #|     });
  #|   });
  #| }

///|
extern "js" fn js_raw_fd_close(fd : Int32) -> Unit =
  #| (fd) => {
  #|   try {
  #|     const fs = require('node:fs');
  #|     fs.closeSync(fd);
  #|   } catch {}
  #| }

///|
#alias(new, deprecated)
pub async fn RawFd::RawFd(fd : Int32) -> RawFd {
  { fd, closed: false, }
}

///|
pub fn RawFd::close(self : RawFd) -> Unit {
  if !self.closed {
    js_raw_fd_close(self.fd)
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
    return 0
  }
  let data = @js_async.Promise::wait(js_raw_fd_read(self.fd, max_len)) catch {
    _ => return 0
  }
  let n = @cmp.minimum(data.length(), max_len)
  buf.blit_from_bytes(offset, data, 0, n)
  n
}

///|
pub async fn RawFd::write(
  self : RawFd,
  buf : Bytes,
  offset~ : Int32 = 0,
  len~ : Int32 = buf.length() - offset,
) -> Int32 {
  if self.closed || len <= 0 {
    return 0
  }
  @js_async.Promise::wait(js_raw_fd_write(self.fd, buf, offset, len)) catch {
    _ => 0
  }
}
