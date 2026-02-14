///|
async fn handle_write_tree(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let rfs : &@git.RepoFileSystem = fs
  if write_tree_repo_requires_standalone_error(rfs, git_dir) {
    eprint_line(
      "fatal: write-tree with this repository object format is not supported in standalone mode",
    )
    @sys.exit(1)
  }
  // Parse --prefix option
  let mut prefix : String? = None
  for arg in args {
    if arg.has_prefix("--prefix=") {
      prefix = Some((try! arg[9:]).to_string())
    } else if arg.has_prefix("-") {
      warn_unimplemented_arg("write-tree", arg)
    }
  }
  let entries = @gitlib.read_index_entries(fs, git_dir)
  let tree_id = @gitlib.write_tree_from_index(fs, git_dir, entries, prefix~)
  print_line(tree_id.to_hex())
}

///|
fn write_tree_repo_requires_standalone_error(
  fs : &@git.RepoFileSystem,
  git_dir : String,
) -> Bool {
  repo_object_format(fs, git_dir) != "sha1" ||
  (match repo_compat_object_format(fs, git_dir) {
    Some(format) => format != "sha1"
    None => false
  })
}

///|
