///|
pub(all) struct PipeRead {}

///|
pub(all) struct PipeWrite {}

///|
pub fn pipe() -> (PipeRead, PipeWrite) raise {
  abort("pipe not supported on wasm-gc target")
}

///|
pub fn PipeRead::close(self : PipeRead) -> Unit {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
pub fn PipeWrite::close(self : PipeWrite) -> Unit {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
pub fn PipeRead::fd(self : PipeRead) -> Int32 {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
pub fn PipeWrite::fd(self : PipeWrite) -> Int32 {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
impl @io.BinaryReaderImpl for PipeRead with fn get_controller(self) {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
impl @io.BinaryReaderImpl for PipeRead with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  ignore((self, buf, offset, max_len))
  abort("pipe not supported on wasm-gc target")
}

///|
impl @io.BinaryWriterImpl for PipeWrite with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  ignore((self, buf, offset, len))
  abort("pipe not supported on wasm-gc target")
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

///|
impl @io.BinaryWriterImpl for PipeWrite with fn get_controller(self) {
  ignore(self)
  abort("writer not supported on this target")
}

///|
impl @io.BinaryReaderImpl for PipeRead with fn name(_self) {
  "PipeRead"
}

///|
impl @io.BinaryWriterImpl for PipeWrite with fn name(_self) {
  "PipeWrite"
}

///|
impl @io.BinaryWriterImpl for PipeWrite with fn flush_partial_data(_self) {
  ()
}
