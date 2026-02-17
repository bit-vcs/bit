///| Ref storage helpers facade

///|
pub fn collect_loose_ref_ids(
  fs : &@bit.RepoFileSystem,
  dir : String,
  prefix : String,
  out : Map[String, @bit.ObjectId],
  filter_prefix : String?,
) -> Unit {
  @bitrefs.collect_loose_ref_ids(fs, dir, prefix, out, filter_prefix)
}

///|
pub fn collect_packed_ref_ids(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  out : Map[String, @bit.ObjectId],
  filter_prefix : String?,
) -> Unit {
  @bitrefs.collect_packed_ref_ids(fs, git_dir, out, filter_prefix)
}

///|
pub fn list_refs_with_ids(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  filter_prefix : String?,
) -> Map[String, @bit.ObjectId] {
  @bitrefs.list_refs_with_ids(fs, git_dir, filter_prefix)
}

///|
pub fn rewrite_packed_refs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  transform : (String) -> String?,
) -> Unit raise @bit.GitError {
  @bitrefs.rewrite_packed_refs(fs, rfs, git_dir, transform)
}

///|
pub fn remove_packed_ref(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  refname : String,
) -> Unit raise @bit.GitError {
  @bitrefs.remove_packed_ref(fs, rfs, git_dir, refname)
}

///|
pub fn remove_packed_refs_with_prefix(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  prefix : String,
  exact : String,
) -> Unit raise @bit.GitError {
  @bitrefs.remove_packed_refs_with_prefix(fs, rfs, git_dir, prefix, exact)
}

///|
pub fn rename_packed_refs_prefix(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  old_prefix : String,
  new_prefix : String,
  old_exact : String,
  new_exact : String,
) -> Unit raise @bit.GitError {
  @bitrefs.rename_packed_refs_prefix(
    fs, rfs, git_dir, old_prefix, new_prefix, old_exact, new_exact,
  )
}

///|
pub fn list_remote_tracking_refs(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  remote_name : String,
) -> Map[String, @bit.ObjectId] {
  @bitrefs.list_remote_tracking_refs(fs, git_dir, remote_name)
}

///|
pub fn remove_remote_refs(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  name : String,
) -> Unit {
  @bitrefs.remove_remote_refs(fs, rfs, git_dir, name)
}
