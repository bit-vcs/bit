///|
test "component impl: with_wasm_fs maps GitError to Err" {
  inspect(
    with_wasm_fs(fn(_fs) -> String raise @bit.GitError {
      raise @bit.GitError::InvalidObject("boom")
    }),
    content="Err(\"boom\")",
  )
}

///|
test "component impl: with_wasm_fs_pair maps GitError to Err" {
  inspect(
    with_wasm_fs_pair(fn(_fs, _rfs) -> String raise @bit.GitError {
      raise @bit.GitError::InvalidObject("boom-pair")
    }),
    content="Err(\"boom-pair\")",
  )
}

///|
test "component impl: with_wasm_repo_fs maps GitError to Err" {
  inspect(
    with_wasm_repo_fs(fn(_rfs) -> String raise @bit.GitError {
      raise @bit.GitError::InvalidObject("boom-repo")
    }),
    content="Err(\"boom-repo\")",
  )
}

///|
test "component impl: with_wasm_rw_fs maps GitError to Err" {
  inspect(
    with_wasm_rw_fs(fn(_fs, _rfs) -> String raise @bit.GitError {
      raise @bit.GitError::InvalidObject("boom-rw")
    }),
    content="Err(\"boom-rw\")",
  )
}

///|
test "component impl: wrap_error maps GitError variants to strings" {
  inspect(
    wrap_error(fn() -> String raise @bit.GitError {
      raise @bit.GitError::IoError("io-boom")
    }),
    content="Err(\"io-boom\")",
  )
  inspect(
    wrap_error(fn() -> String raise @bit.GitError {
      raise @bit.GitError::InvalidObject("bad-object")
    }),
    content="Err(\"bad-object\")",
  )
  inspect(
    wrap_error(fn() -> String raise @bit.GitError {
      raise @bit.GitError::HashMismatch("aaaa", "bbbb")
    }),
    content="Err(\"hash mismatch: aaaa vs bbbb\")",
  )
  inspect(
    wrap_error(fn() -> String raise @bit.GitError {
      raise @bit.GitError::PackfileError("bad-pack")
    }),
    content="Err(\"packfile error: bad-pack\")",
  )
  inspect(
    wrap_error(fn() -> String raise @bit.GitError {
      raise @bit.GitError::ProtocolError("bad-proto")
    }),
    content="Err(\"protocol error: bad-proto\")",
  )
}
