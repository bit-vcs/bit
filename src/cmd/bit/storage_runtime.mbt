///|
pub async fn run_storage_command(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  command : @runtime.StorageCommand,
) -> Unit raise Error {
  @runtime.run_storage_command(fs, rfs, root, command)
}

///|
pub async fn run_storage_command_by_name(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  cmd : String,
  args : Array[String],
) -> Unit raise Error {
  @runtime.run_storage_command_by_name(fs, rfs, root, cmd, args)
}
