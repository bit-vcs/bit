///| Native promisor adapter - provides fetch_objects_http callback

///|
/// Create a PromisorDb with native HTTP fetch capability
pub fn native_promisor_db(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  lazy_load? : Bool = true,
) -> @bitlib.PromisorDb raise @bit.GitError {
  @bitlib.PromisorDb::new(
    fs,
    git_dir,
    lazy_load~,
    fetch_fn=Some(async fn(
      remote : String,
      wants : Array[@bit.ObjectId],
    ) -> Result[Array[@bit.PackObject], @bit.GitError] noraise {
      let result : Result[Array[@bit.PackObject], @bit.GitError] = Ok(
        @bitnative.fetch_objects_http(remote, wants, true, depth=0),
      ) catch {
        e => Err(e)
      }
      result
    }),
  )
}
