///| git update-server-info - update auxiliary info for dumb HTTP serving

///|
async fn handle_update_server_info(args : Array[String]) -> Unit raise Error {
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git update-server-info [-f | --force]",
          summary="Update auxiliary info file to help dumb servers.",
        )
        return
      }
      "-f" | "--force" => () // Always update; flag is a no-op
      _ if arg.has_prefix("-") =>
        warn_unimplemented_arg("update-server-info", arg)
      _ => ()
    }
  }
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let pack_dir = git_dir + "/objects/pack"
  repack_update_server_info(fs, git_dir, pack_dir)
}
