///| WasmFs read adapter for @bit.RepoFileSystem

///|
pub impl @bit.RepoFileSystem for WasmFs with read_file(_self, path) {
  wasmfs_unwrap_bytes_result(@wit_fs.read_file(path))
}

///|
pub impl @bit.RepoFileSystem for WasmFs with readdir(_self, path) {
  wasmfs_unwrap_readdir_result(@wit_fs.readdir(path))
}

///|
pub impl @bit.RepoFileSystem for WasmFs with is_dir(_self, path) {
  @wit_fs.is_dir(path)
}

///|
pub impl @bit.RepoFileSystem for WasmFs with is_file(_self, path) {
  @wit_fs.is_file(path)
}
