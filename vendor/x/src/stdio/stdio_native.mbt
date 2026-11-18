///|
pub struct Input {
  priv read_controller : @io.BinaryReaderController
  inner : @async_stdio.Input
}

///|
pub struct Output {
  priv is_stdout : Bool
  priv write_controller : @io.BinaryWriterController
  inner : @async_stdio.Output
}

///|
pub fn Input::fd(self : Input) -> Int32 raise {
  let fd = self.inner.fd()
  stdio_fd_to_int(fd)
}

///|
pub fn Output::fd(self : Output) -> Int32 raise {
  let fd = self.inner.fd()
  stdio_fd_to_int(fd)
}

///|
impl @io.BinaryReaderImpl for Input with fn get_controller(self) {
  self.read_controller
}

///|
impl @io.BinaryReaderImpl for Input with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.inner.read_into(buf, offset~, max_len~)
}

///|
pub impl @process.ProcessInput for Input with fn _process_input_native(self) {
  ignore(self)
  @async_process.Stdin
}

///|
impl @io.BinaryWriterImpl for Output with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len])
  len
}

///|
pub impl @process.ProcessOutput for Output with fn _process_output_native(self) {
  if self.is_stdout {
    @async_process.Stdout
  } else {
    @async_process.Stderr
  }
}

///|
pub let stdin : Input = Input::{
  read_controller: @io.BinaryReaderController(),
  inner: @async_stdio.stdin,
}

///|
pub let stdout : Output = Output::{
  is_stdout: true,
  write_controller: @io.BinaryWriterController(),
  inner: @async_stdio.stdout,
}

///|
pub let stderr : Output = Output::{
  is_stdout: false,
  write_controller: @io.BinaryWriterController(),
  inner: @async_stdio.stderr,
}

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
  self.write_controller
}

///|
pub extend Input with @process.ProcessInput::{
  _release_input_native,
  _process_input_native,
}

///|
pub extend Output with @process.ProcessOutput::{
  _process_output_native,
  _release_output_native,
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
