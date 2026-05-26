///|
/// Check for unsupported gitattributes (filter=lfs, working-tree-encoding)
/// and exit with fatal error if found. Generic filter= is now handled natively.
async fn check_and_exit_unsupported_attrs(root : String) -> Unit {
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  match @bitlib.check_unsupported_gitattributes(rfs, root) {
    Some(msg) => {
      eprint_line(msg)
      @sys.exit(128)
    }
    None => ()
  }
}
