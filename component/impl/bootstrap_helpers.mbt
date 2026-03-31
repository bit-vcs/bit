///| WASM Component bootstrap helpers

///|
fn make_fs() -> WasmFs {
  WasmFs::new()
}

///|
fn[T] with_wasm_fs_pair(
  action : (WasmFs, WasmFs) -> T raise @bit.GitError,
) -> Result[T, String] {
  let fs = make_fs()
  wrap_error(fn() raise @bit.GitError { action(fs, fs) })
}

///|
fn[T] with_wasm_rw_fs(
  action : (WasmFs, WasmFs) -> T raise @bit.GitError,
) -> Result[T, String] {
  with_wasm_fs_pair(action)
}

///|
fn[T] with_wasm_repo_fs(
  action : (WasmFs) -> T raise @bit.GitError,
) -> Result[T, String] {
  with_wasm_fs(fn(fs) raise @bit.GitError { action(fs) })
}

///|
fn[T] with_wasm_fs(
  action : (WasmFs) -> T raise @bit.GitError,
) -> Result[T, String] {
  with_wasm_fs_pair(fn(fs, _rfs) raise @bit.GitError { action(fs) })
}

///|
fn[T] wrap_error(f : () -> T raise @bit.GitError) -> Result[T, String] {
  Ok(f()) catch {
    @bit.GitError::IoError(e) => Err(e)
    @bit.GitError::InvalidObject(e) => Err(e)
    @bit.GitError::HashMismatch(a, b) => Err("hash mismatch: \{a} vs \{b}")
    @bit.GitError::PackfileError(e) => Err("packfile error: \{e}")
    @bit.GitError::ProtocolError(e) => Err("protocol error: \{e}")
  }
}
