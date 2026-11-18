///|
pub struct Input {
  buf : @io.BinaryReaderController
}

///|
pub struct Output {
  priv write_controller : @io.BinaryWriterController
  target : Int32 // 1 = stdout, 2 = stderr
}

///|
fn ensure_fd_available(ok : Bool) -> Unit raise {
  guard ok else { raise Failure::Failure("stdio fd is not available") }
}

///|
pub fn Input::fd(self : Input) -> Int32 raise {
  ignore(self)
  ensure_fd_available(true)
  0
}

///|
pub fn Output::fd(self : Output) -> Int32 raise {
  ensure_fd_available(self.target == 1 || self.target == 2)
  self.target
}

///|
extern "js" fn js_stdin_read(max_len : Int32) -> @js_async.Promise[Bytes] =
  #| async (maxLen) => {
  #|   const { stdin } = process;
  #|   return new Promise((resolve) => {
  #|     if (stdin.readableEnded || stdin.destroyed) {
  #|       resolve(new Uint8Array(0));
  #|       return;
  #|     }
  #|     const tryRead = () => {
  #|       const chunk = stdin.read(Math.min(maxLen, stdin.readableLength || maxLen));
  #|       if (chunk !== null) {
  #|         resolve(new Uint8Array(chunk));
  #|         return true;
  #|       }
  #|       return false;
  #|     };
  #|     if (tryRead()) return;
  #|     const onReadable = () => {
  #|       if (tryRead()) {
  #|         stdin.removeListener('readable', onReadable);
  #|         stdin.removeListener('end', onEnd);
  #|       }
  #|     };
  #|     const onEnd = () => {
  #|       stdin.removeListener('readable', onReadable);
  #|       resolve(new Uint8Array(0));
  #|     };
  #|     stdin.on('readable', onReadable);
  #|     stdin.once('end', onEnd);
  #|   });
  #| }

///|
extern "js" fn js_write(
  target : Int32,
  data : Bytes,
  offset : Int32,
  len : Int32,
) -> Unit =
  #| (target, data, offset, len) => {
  #|   const slice = data.subarray(offset, offset + len);
  #|   (target === 1 ? process.stdout : process.stderr).write(slice);
  #| }

///|
impl @io.BinaryReaderImpl for Input with fn get_controller(self) {
  self.buf
}

///|
impl @io.BinaryReaderImpl for Input with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  ignore(self)
  let controller = @js_async.AbortController::AbortController()
  let promise = js_stdin_read(max_len)
  let data = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    _ => return 0
  }
  let len = data.length()
  if len == 0 {
    return 0
  }
  let actual = if len < max_len { len } else { max_len }
  for i = 0; i < actual; i = i + 1 {
    buf[offset + i] = data[i]
  }
  actual
}

///|
pub impl @process.ProcessInput for Input with fn _process_input_js(self) {
  ignore(self)
  -1
}

///|
impl @io.BinaryWriterImpl for Output with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  js_write(self.target, buf, offset, len)
  len
}

///|
pub impl @process.ProcessOutput for Output with fn _process_output_js(self) {
  0 - self.target
}

///|
pub let stdin : Input = Input::{ buf: @io.BinaryReaderController(), }

///|
pub let stdout : Output = Output::{
  write_controller: @io.BinaryWriterController(),
  target: 1,
}

///|
pub let stderr : Output = Output::{
  write_controller: @io.BinaryWriterController(),
  target: 2,
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
pub extend Input with @process.ProcessInput::{_process_input_js}

///|
pub extend Output with @process.ProcessOutput::{_process_output_js}

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
