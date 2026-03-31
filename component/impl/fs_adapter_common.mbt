///| WasmFs - WIT filesystem import adapter helpers

///|
pub struct WasmFs {
  priv _dummy : Int
}

///|
pub fn WasmFs::new() -> WasmFs {
  { _dummy: 0 }
}

///|
fn wasmfs_unwrap_unit_result(
  r : Result[Unit, String],
) -> Unit raise @bit.GitError {
  match r {
    Ok(_) => ()
    Err(e) => raise @bit.GitError::IoError(e)
  }
}

///|
fn wasmfs_bytes_to_array(content : Bytes) -> Array[Byte] {
  let arr : Array[Byte] = Array::new(capacity=content.length())
  for i in 0..<content.length() {
    arr.push(content[i])
  }
  arr
}

///|
fn wasmfs_unwrap_bytes_result(
  r : Result[Array[Byte], String],
) -> Bytes raise @bit.GitError {
  match r {
    Ok(arr) => Bytes::from_array(arr)
    Err(e) => raise @bit.GitError::IoError(e)
  }
}

///|
fn wasmfs_unwrap_readdir_result(
  r : Result[Array[String], String],
) -> Array[String] raise @bit.GitError {
  match r {
    Ok(arr) => arr
    Err(e) => raise @bit.GitError::IoError(e)
  }
}
