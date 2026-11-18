///|
pub(open) trait ProcessInput {
  fn _process_input_wasmgc(Self) -> Unit
}

///|
pub(open) trait ProcessOutput {
  fn _process_output_wasmgc(Self) -> Unit
}

///|
pub struct ReadFromProcess {
  read_buf : @async_io.BinaryReaderController
}

///|
pub fn ReadFromProcess::close(_self : ReadFromProcess) -> Unit {
  abort("process is not supported on wasm-gc target")
}

///|
impl @async_io.BinaryReaderImpl for ReadFromProcess with fn get_controller(self) {
  self.read_buf
}

///|
impl @async_io.BinaryReaderImpl for ReadFromProcess with fn raw_read_impl(
  _self,
  _buf,
  offset~ : Int32,
  max_len~ : Int32,
) {
  ignore((offset, max_len))
  abort("process is not supported on wasm-gc target")
}

///|
pub struct WriteToProcess {}

///|
pub fn WriteToProcess::close(_self : WriteToProcess) -> Unit {
  abort("process is not supported on wasm-gc target")
}

///|
impl @async_io.BinaryWriterImpl for WriteToProcess with fn raw_write_impl(
  _self,
  _buf,
  offset~ : Int32,
  len~ : Int32,
) {
  ignore((offset, len))
  abort("process is not supported on wasm-gc target")
}

///|
pub fn read_from_process() -> (ReadFromProcess, &ProcessOutput) raise {
  abort("process is not supported on wasm-gc target")
}

///|
pub fn write_to_process() -> (&ProcessInput, WriteToProcess) raise {
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn run(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler~ : CancellationHandler = graceful_cancel(timeout=5000),
) -> Int32 {
  ignore((cwd, extra_env, inherit_env, stdin, stdout, stderr, cancel_handler))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn run_inherit(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  cwd? : StringView,
) -> Int32 {
  ignore((cwd, extra_env, inherit_env))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn collect_output(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int32, &@data.Data, &@data.Data) {
  ignore((cwd, extra_env, inherit_env, stdin))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn collect_stdout(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> (Int32, &@data.Data) {
  ignore((cwd, extra_env, inherit_env, stdin, stderr))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn collect_stderr(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  cwd? : StringView,
) -> (Int32, &@data.Data) {
  ignore((cwd, extra_env, inherit_env, stdin, stdout))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn collect_output_merged(
  _cmd : StringView,
  _args : Array[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int32, &@data.Data) {
  ignore((cwd, extra_env, inherit_env, stdin))
  abort("process is not supported on wasm-gc target")
}

///|
pub fn redirect_from_file(_path : String) -> &ProcessInput {
  abort("process is not supported on wasm-gc target")
}

///|
pub fn redirect_to_file(
  _path : String,
  append? : Bool,
  create_mode? : @fs.CreateMode,
  permission? : Int32,
  create? : Int32,
  truncate? : Bool,
) -> &ProcessOutput {
  ignore((append, create_mode, permission, create, truncate))
  abort("process is not supported on wasm-gc target")
}

///|
pub struct Process {
  pid : Int32
}

///|
pub async fn Process::wait(_self : Process) -> Int32 {
  abort("process is not supported on wasm-gc target")
}

///|
pub fn Process::try_wait(_self : Process) -> Int32? raise {
  abort("process is not supported on wasm-gc target")
}

///|
pub fn Process::cancel(_self : Process) -> Unit {
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn spawn(
  _group : @async.TaskGroup,
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler~ : CancellationHandler = graceful_cancel(timeout=5000),
  no_wait? : Bool,
) -> Process {
  ignore(
    (
      cwd, extra_env, inherit_env, stdin, stdout, stderr, cancel_handler, no_wait,
    ),
  )
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn spawn_orphan(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> Int32 {
  ignore((cwd, extra_env, inherit_env, stdin, stdout, stderr))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn wait_pid(_pid : Int32) -> Int32 {
  abort("process is not supported on wasm-gc target")
}

///|
pub impl @async_io.BinaryReader for ReadFromProcess

///|
pub extend ReadFromProcess with @async_io.BinaryReader::{
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
pub impl @async_io.BinaryWriter for WriteToProcess

///|
pub extend WriteToProcess with @async_io.BinaryWriter::{write_reader}

///|
impl @async_io.BinaryWriterImpl for WriteToProcess with fn get_controller(self) {
  ignore(self)
  abort("writer not supported on this target")
}

///|
impl @async_io.BinaryReaderImpl for ReadFromProcess with fn name(_self) {
  "ReadFromProcess"
}

///|
impl @async_io.BinaryWriterImpl for WriteToProcess with fn name(_self) {
  "WriteToProcess"
}

///|
impl @async_io.BinaryWriterImpl for WriteToProcess with fn flush_partial_data(
  _self,
) {
  ()
}
