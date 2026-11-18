///|
fn to_async_create_mode(mode : @fs.CreateMode) -> @async_fs.CreateMode {
  match mode {
    OpenExisting => @async_fs.OpenExisting
    TruncateExisting => @async_fs.TruncateExisting
    OpenOrCreate => @async_fs.OpenOrCreate
    CreateOrTruncate => @async_fs.CreateOrTruncate
    CreateNew => @async_fs.CreateNew
  }
}

///|
fn to_async_cancel(
  handler : CancellationHandler,
) -> @async_process.CancellationHandler {
  match handler.kind {
    Graceful(timeout, signal) =>
      @async_process.graceful_cancel(
        timeout~,
        signal?=signal.map(signal_to_async),
      )
    Hard => @async_process.hard_cancel()
  }
}

///|
fn signal_to_async(signal : @signal.Signal) -> @async_signal.Signal {
  match signal {
    SIGINT => @async_signal.SIGINT
    SIGTERM => @async_signal.SIGTERM
    SIGHUP => @async_signal.SIGHUP
    SIGBREAK => @async_signal.SIGBREAK
  }
}

///|
pub(open) trait ProcessInput {
  fn _process_input_native(Self) -> @async_process.ProcessInput
  fn _release_input_native(Self) -> Unit = _
}

///|
pub(open) trait ProcessOutput {
  fn _process_output_native(Self) -> @async_process.ProcessOutput
  fn _release_output_native(Self) -> Unit = _
}

///|
priv struct NativeProcessInput {
  inner : @async_process.SharedProcessInput
}

///|
impl ProcessInput for NativeProcessInput with fn _process_input_native(self) {
  @async_process.Shared(self.inner)
}

///|
priv struct NativeProcessOutput {
  inner : @async_process.SharedProcessOutput
}

///|
impl ProcessOutput for NativeProcessOutput with fn _process_output_native(self) {
  @async_process.Shared(self.inner)
}

///|
pub struct ReadFromProcess {
  priv read_controller : @async_io.BinaryReaderController
  priv inner : @async_process.ReadFromProcess
}

///|
pub fn ReadFromProcess::close(self : ReadFromProcess) -> Unit {
  self.inner.close()
}

///|
impl @async_io.BinaryReaderImpl for ReadFromProcess with fn get_controller(self) {
  self.read_controller
}

///|
impl @async_io.BinaryReaderImpl for ReadFromProcess with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.inner.read_into(buf, offset~, max_len~)
}

///|
pub struct WriteToProcess {
  priv write_controller : @async_io.BinaryWriterController
  priv inner : @async_process.WriteToProcess
}

///|
pub fn WriteToProcess::close(self : WriteToProcess) -> Unit {
  self.inner.close()
}

///|
impl @async_io.BinaryWriterImpl for WriteToProcess with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len])
  len
}

///|
pub fn read_from_process() -> (ReadFromProcess, &ProcessOutput) raise {
  let (r, w) = @async_process.read_from_process()
  (
    ReadFromProcess::{
      read_controller: @async_io.BinaryReaderController(),
      inner: r,
    },
    NativeProcessOutput::{ inner: w, },
  )
}

///|
pub fn write_to_process() -> (&ProcessInput, WriteToProcess) raise {
  let (r, w) = @async_process.write_to_process()
  (
    NativeProcessInput::{ inner: r, },
    WriteToProcess::{
      write_controller: @async_io.BinaryWriterController(),
      inner: w,
    },
  )
}

///|
pub async fn run(
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler~ : CancellationHandler = graceful_cancel(timeout=5000),
) -> Int32 {
  run_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cancel_handler~,
  )
}

///|
pub async fn run_inherit(
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  cwd? : StringView,
) -> Int32 {
  run_inherit_internal(cmd, args, cwd?, extra_env~, inherit_env~)
}

///|
pub async fn collect_output(
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int32, &@data.Data, &@data.Data) {
  collect_output_internal(cmd, args, cwd?, extra_env~, inherit_env~, stdin?)
}

///|
pub async fn collect_stdout(
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> (Int32, &@data.Data) {
  collect_stdout_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stderr?,
  )
}

///|
pub async fn collect_stderr(
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  cwd? : StringView,
) -> (Int32, &@data.Data) {
  collect_stderr_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
  )
}

///|
pub async fn collect_output_merged(
  cmd : StringView,
  args : Array[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int32, &@data.Data) {
  collect_output_merged_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
  )
}

///|
pub async fn redirect_from_file(path : String) -> &ProcessInput {
  NativeProcessInput::{ inner: @async_process.redirect_from_file(path), }
}

///|
pub async fn redirect_to_file(
  path : String,
  append? : Bool,
  create_mode? : @fs.CreateMode,
  permission? : Int32,
  create? : Int32,
  truncate? : Bool,
) -> &ProcessOutput {
  let create_mode = to_async_create_mode(
    match create_mode {
      Some(mode) => mode
      None =>
        match (create is Some(_), truncate.unwrap_or(false)) {
          (true, true) => @fs.CreateOrTruncate
          (true, false) => @fs.OpenOrCreate
          (false, true) => @fs.TruncateExisting
          (false, false) => @fs.OpenExisting
        }
    },
  )
  let permission = match permission {
    Some(p) => p
    None =>
      match create {
        Some(p) => p
        None => 0o644
      }
  }
  @async_process.redirect_to_file(path, append?, create_mode~, permission~)
  |> inner => { NativeProcessOutput::{ inner, } }
}

///|
async fn run_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cancel_handler~ : CancellationHandler,
) -> Int32 {
  let mut code = 0
  @async.with_task_group(group => {
    let process = spawn_internal(
      group,
      cmd,
      args,
      cwd?,
      extra_env~,
      inherit_env~,
      stdin?,
      stdout?,
      stderr?,
      cancel_handler~,
    )
    code = process.wait()
  })
  code
}

///|
async fn run_inherit_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
) -> Int32 {
  @async_process.run(cmd, args, extra_env~, inherit_env~, cwd?).exit_code
}

///|
async fn collect_output_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
) -> (Int32, &@data.Data, &@data.Data) {
  defer (if stdin is Some(input) { input._release_input_native() })
  let stdin = stdin.map(input => input._process_input_native())
  let result = @async_process.run(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout=@async_process.Collect,
    stderr=@async_process.Collect,
    cwd?,
  )
  (result.exit_code, result.stdout_binary(), result.stderr_binary())
}

///|
async fn collect_stdout_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stderr? : &ProcessOutput,
) -> (Int32, &@data.Data) {
  defer (if stdin is Some(input) { input._release_input_native() })
  defer (if stderr is Some(output) { output._release_output_native() })
  let stderr = stderr.map(output => output._process_output_native())
  let stdin = stdin.map(input => input._process_input_native())
  let result = @async_process.run(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout=@async_process.Collect,
    stderr?,
    cwd?,
  )
  (result.exit_code, result.stdout_binary())
}

///|
async fn collect_stderr_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
) -> (Int32, &@data.Data) {
  defer (if stdin is Some(input) { input._release_input_native() })
  defer (if stdout is Some(output) { output._release_output_native() })
  let stdout = stdout.map(output => output._process_output_native())
  let stdin = stdin.map(input => input._process_input_native())
  let result = @async_process.run(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr=@async_process.Collect,
    cwd?,
  )
  (result.exit_code, result.stderr_binary())
}

///|
async fn collect_output_merged_internal(
  cmd : StringView,
  args : Array[String],
  cwd? : StringView,
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
) -> (Int32, &@data.Data) {
  defer (if stdin is Some(input) { input._release_input_native() })
  let stdin = stdin.map(input => input._process_input_native())
  let result = @async_process.run(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout=@async_process.Collect,
    stderr=@async_process.DuplicateStdout,
    cwd?,
  )
  (result.exit_code, result.stdout_binary())
}

///|
pub struct Process {
  pid : Int32
  priv inner : @async_process.Process
}

///|
pub async fn Process::wait(self : Process) -> Int32 {
  self.inner.wait()
}

///|
pub fn Process::try_wait(self : Process) -> Int32? raise {
  self.inner.try_wait()
}

///|
pub fn Process::cancel(self : Process) -> Unit {
  self.inner.cancel()
}

///|
async fn spawn_internal(
  group : @async.TaskGroup,
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler~ : CancellationHandler = graceful_cancel(timeout=5000),
  no_wait? : Bool,
) -> Process {
  defer (if stdin is Some(input) { input._release_input_native() })
  defer (if stdout is Some(output) { output._release_output_native() })
  defer (if stderr is Some(output) { output._release_output_native() })
  let stdin = stdin.map(fn(input) { input._process_input_native() })
  let stdout = stdout.map(fn(output) { output._process_output_native() })
  let stderr = stderr.map(fn(output) { output._process_output_native() })
  let inner = @async_process.spawn(
    group,
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cwd?,
    cancel_handler=to_async_cancel(cancel_handler),
    no_wait?,
  )
  Process::{ pid: inner.pid, inner, }
}

///|
pub async fn spawn_orphan(
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String] = {},
  inherit_env~ : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> Int32 {
  defer (if stdin is Some(input) { input._release_input_native() })
  defer (if stdout is Some(output) { output._release_output_native() })
  defer (if stderr is Some(output) { output._release_output_native() })
  let stdin = stdin.map(fn(input) { input._process_input_native() })
  let stdout = stdout.map(fn(output) { output._process_output_native() })
  let stderr = stderr.map(fn(output) { output._process_output_native() })
  let process = @async_process.spawn_orphan(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cwd?,
  )
  process.pid
}

///|
pub async fn wait_pid(pid : Int32) -> Int32 {
  @async_process.wait_pid(pid)
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
  self.write_controller
}

///|
impl ProcessInput with fn _release_input_native(self) {
  ignore(self)
}

///|
impl ProcessOutput with fn _release_output_native(self) {
  ignore(self)
}

///|
impl ProcessInput for NativeProcessInput with fn _release_input_native(self) {
  self.inner.close()
}

///|
impl ProcessOutput for NativeProcessOutput with fn _release_output_native(self) {
  self.inner.close()
}

///|
impl @async_io.BinaryReaderImpl for ReadFromProcess with fn name(_self) {
  "@process.ReadFromProcess"
}

///|
impl @async_io.BinaryWriterImpl for WriteToProcess with fn name(_self) {
  "@process.WriteToProcess"
}

///|
impl @async_io.BinaryWriterImpl for WriteToProcess with fn flush_partial_data(
  _self,
) {
  ()
}
