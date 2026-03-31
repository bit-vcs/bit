///|
test "component impl: fs adapter helpers convert bytes and read results" {
  let bytes = wasmfs_unwrap_bytes_result(Ok([1, 2, 3]))
  assert_eq(bytes.length(), 3)
  assert_eq(bytes[0], 1)
  assert_eq(bytes[1], 2)
  assert_eq(bytes[2], 3)
  assert_eq(wasmfs_bytes_to_array(bytes), [1, 2, 3])
  assert_eq(wasmfs_unwrap_readdir_result(Ok(["a", "b"])), ["a", "b"])
}

///|
test "component impl: fs adapter helpers map Err to IoError" {
  let unit_err : Result[Unit, @bit.GitError] = try? wasmfs_unwrap_unit_result(
    Err("boom-unit"),
  )
  match unit_err {
    Err(@bit.GitError::IoError(msg)) => assert_eq(msg, "boom-unit")
    _ => assert_true(false)
  }

  let bytes_err : Result[Bytes, @bit.GitError] = try? wasmfs_unwrap_bytes_result(
    Err("boom-bytes"),
  )
  match bytes_err {
    Err(@bit.GitError::IoError(msg)) => assert_eq(msg, "boom-bytes")
    _ => assert_true(false)
  }

  let readdir_err : Result[Array[String], @bit.GitError] = try? wasmfs_unwrap_readdir_result(
    Err("boom-readdir"),
  )
  match readdir_err {
    Err(@bit.GitError::IoError(msg)) => assert_eq(msg, "boom-readdir")
    _ => assert_true(false)
  }
}
