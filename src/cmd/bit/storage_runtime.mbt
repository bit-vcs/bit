///|
pub async fn run_storage_command(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  cmd : String,
  args : Array[String],
) -> Unit raise Error {
  @runtime.run_storage_command(fs, rfs, root, cmd, args)
}
