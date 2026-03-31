///|
test "component impl: with_wasm_fs returns Ok on success" {
  inspect(with_wasm_fs(fn(_fs) -> String { "ok" }), content="Ok(\"ok\")")
}

///|
test "component impl: with_wasm_fs_pair returns Ok on success" {
  inspect(
    with_wasm_fs_pair(fn(_fs, _rfs) -> String { "ok-pair" }),
    content="Ok(\"ok-pair\")",
  )
}

///|
test "component impl: with_wasm_repo_fs returns Ok on success" {
  inspect(
    with_wasm_repo_fs(fn(_rfs) -> String { "ok-repo" }),
    content="Ok(\"ok-repo\")",
  )
}

///|
test "component impl: with_wasm_rw_fs returns Ok on success" {
  inspect(
    with_wasm_rw_fs(fn(_fs, _rfs) -> String { "ok-rw" }),
    content="Ok(\"ok-rw\")",
  )
}
