///|
pub impl @process.ProcessInput for PipeRead with fn _process_input_native(self) {
  ignore(self)
  abort("pipe process redirection not supported on wasm target")
}

///|
pub impl @process.ProcessOutput for PipeWrite with fn _process_output_native(
  self,
) {
  ignore(self)
  abort("pipe process redirection not supported on wasm target")
}

///|
pub extend PipeRead with @process.ProcessInput::{
  _release_input_native,
  _process_input_native,
}

///|
pub extend PipeWrite with @process.ProcessOutput::{
  _process_output_native,
  _release_output_native,
}
