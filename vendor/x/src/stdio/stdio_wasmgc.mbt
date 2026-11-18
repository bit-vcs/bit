///|
pub struct Input {}

///|
pub struct Output {}

///|
pub fn Input::fd(self : Input) -> Int32 raise {
  ignore(self)
  raise Failure::Failure("stdio not supported on wasm-gc target")
}

///|
pub fn Output::fd(self : Output) -> Int32 raise {
  ignore(self)
  raise Failure::Failure("stdio not supported on wasm-gc target")
}

///|
impl @io.BinaryReaderImpl for Input with fn get_controller(self) {
  ignore(self)
  abort("stdio not supported on wasm-gc target")
}

///|
impl @io.BinaryReaderImpl for Input with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  ignore((self, buf, offset, max_len))
  abort("stdio not supported on wasm-gc target")
}

///|
impl @io.BinaryWriterImpl for Output with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  ignore((self, buf, offset, len))
  abort("stdio not supported on wasm-gc target")
}

///|
pub let stdin : Input = Input::{ }

///|
pub let stdout : Output = Output::{ }

///|
pub let stderr : Output = Output::{ }

///|
pub impl @io.BinaryReader for Input

///|
pub extend Input with @io.BinaryReader::{
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
pub impl @io.BinaryWriter for Output

///|
pub extend Output with @io.BinaryWriter::{write_reader}

///|
impl @io.BinaryWriterImpl for Output with fn get_controller(self) {
  ignore(self)
  abort("writer not supported on this target")
}

///|
impl @io.BinaryReaderImpl for Input with fn name(_self) {
  "Input"
}

///|
impl @io.BinaryWriterImpl for Output with fn name(_self) {
  "Output"
}

///|
impl @io.BinaryWriterImpl for Output with fn flush_partial_data(_self) {
  ()
}
