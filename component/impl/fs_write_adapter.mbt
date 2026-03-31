///| WasmFs write adapter for @bit.FileSystem

///|
pub impl @bit.FileSystem for WasmFs with mkdir_p(_self, path) {
  wasmfs_unwrap_unit_result(@wit_fs.mkdir_p(path))
}

///|
pub impl @bit.FileSystem for WasmFs with write_file(_self, path, content) {
  wasmfs_unwrap_unit_result(
    @wit_fs.write_file(path, wasmfs_bytes_to_array(content)),
  )
}

///|
pub impl @bit.FileSystem for WasmFs with write_string(_self, path, content) {
  wasmfs_unwrap_unit_result(@wit_fs.write_string(path, content))
}

///|
pub impl @bit.FileSystem for WasmFs with remove_file(_self, path) {
  wasmfs_unwrap_unit_result(@wit_fs.remove_file(path))
}

///|
pub impl @bit.FileSystem for WasmFs with remove_dir(_self, path) {
  wasmfs_unwrap_unit_result(@wit_fs.remove_dir(path))
}
