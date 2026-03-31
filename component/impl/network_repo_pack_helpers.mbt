///| WASM Component network repository pack install helpers

///|
fn net_install_pack(
  fs : &@bit.FileSystem,
  git_dir : String,
  pack : Bytes,
) -> Unit raise @bit.GitError {
  let objects = @pack.parse_packfile(pack)
  @pack.write_packfile_with_index(fs, git_dir, pack, objects)
}
