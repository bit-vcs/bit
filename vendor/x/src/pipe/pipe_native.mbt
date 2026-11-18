///|
/// The read end of an OS pipe.
pub struct PipeRead {
  priv read_controller : @io.BinaryReaderController
  inner : @async_fs.File
}

///|
/// The write end of an OS pipe.
pub struct PipeWrite {
  priv write_controller : @io.BinaryWriterController
  inner : @async_fs.File
}

///|
#borrow(fds)
extern "C" fn pipe_open_ffi(fds : FixedArray[Int32]) -> Int32 = "mizchi_x_pipe_open"

///|
extern "C" fn pipe_close_ffi(fd : Int32) -> Int32 = "mizchi_x_pipe_close"

///|
fn pipe_fd_to_int(fd : @types.Fd) -> Int32 = "%identity"

///|
/// Failure to create an OS pipe, carrying the `errno` value.
pub suberror PipeError {
  PipeError(Int32)
}

///|
pub async fn pipe() -> (PipeRead, PipeWrite) {
  let fds : FixedArray[Int32] = [-1, -1]
  let err = pipe_open_ffi(fds)
  if err != 0 {
    raise PipeError(err)
  }
  // Reopen both ends through /dev/fd so core's async fs drives them (it
  // handles pipes); the descriptors from pipe(2) are closed right after.
  defer {
    ignore(pipe_close_ffi(fds[0]))
    ignore(pipe_close_ffi(fds[1]))
  }
  let r = @async_fs.open("/dev/fd/\{fds[0]}", mode=ReadOnly)
  let mut opened = false
  defer (if !opened { r.close() })
  let w = @async_fs.open("/dev/fd/\{fds[1]}", mode=WriteOnly)
  opened = true
  (
    PipeRead::{ read_controller: @io.BinaryReaderController(), inner: r, },
    PipeWrite::{ write_controller: @io.BinaryWriterController(), inner: w, },
  )
}

///|
pub fn PipeRead::close(self : PipeRead) -> Unit {
  self.inner.close()
}

///|
pub fn PipeWrite::close(self : PipeWrite) -> Unit {
  self.inner.close()
}

///|
pub fn PipeRead::fd(self : PipeRead) -> Int32 {
  pipe_fd_to_int(self.inner.fd())
}

///|
pub fn PipeWrite::fd(self : PipeWrite) -> Int32 {
  pipe_fd_to_int(self.inner.fd())
}

///|
impl @io.BinaryReaderImpl for PipeRead with fn name(_self) {
  "@pipe.PipeRead"
}

///|
impl @io.BinaryReaderImpl for PipeRead with fn get_controller(self) {
  self.read_controller
}

///|
impl @io.BinaryReaderImpl for PipeRead with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.inner.read_into(buf, offset~, max_len~)
}

///|
impl @io.BinaryWriterImpl for PipeWrite with fn name(_self) {
  "@pipe.PipeWrite"
}

///|
impl @io.BinaryWriterImpl for PipeWrite with fn get_controller(self) {
  self.write_controller
}

///|
impl @io.BinaryWriterImpl for PipeWrite with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len])
  len
}

///|
impl @io.BinaryWriterImpl for PipeWrite with fn flush_partial_data(_self) {
  ()
}

///|
pub impl @io.BinaryReader for PipeRead

///|
pub extend PipeRead with @io.BinaryReader::{
  read_into,
  read_at_least,
  peek,
  peek_at_least,
  read_exactly,
  drop_exactly,
  peek_exactly,
  drop_all,
  peek_until,
}

///|
pub impl @io.BinaryWriter for PipeWrite

///|
pub extend PipeWrite with @io.BinaryWriter::{write_reader}
