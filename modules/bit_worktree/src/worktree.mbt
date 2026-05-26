///| Worktree operations facade.

///|
pub async fn status(
  fs : &@bit.RepoFileSystem,
  root : String,
) -> @bitlib.Status raise @bit.GitError {
  @bitlib.status(fs, root)
}

///|
pub async fn status_porcelain(
  fs : &@bit.RepoFileSystem,
  root : String,
) -> Array[String] raise @bit.GitError {
  @bitlib.status_porcelain(fs, root)
}

///|
pub fn status_porcelain_from(s : @bitlib.Status) -> Array[String] {
  @bitlib.status_porcelain_from(s)
}

///|
pub async fn status_text(
  fs : &@bit.RepoFileSystem,
  root : String,
) -> String raise @bit.GitError {
  @bitlib.status_text(fs, root)
}

///|
pub fn add_paths(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  paths : Array[String],
) -> Unit raise @bit.GitError {
  @bitlib.add_paths(fs, rfs, root, paths)
}

///|
pub async fn add_paths_async(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  paths : Array[String],
) -> Unit raise @bit.GitError {
  @bitlib.add_paths_async(fs, rfs, root, paths)
}

///|
pub fn commit(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  message : String,
  author : String,
  author_timestamp : Int64,
  committer? : String = author,
  committer_timestamp? : Int64 = author_timestamp,
  allow_empty? : Bool = false,
) -> @bit.ObjectId raise @bit.GitError {
  @bitlib.commit(
    fs,
    rfs,
    root,
    message,
    author,
    author_timestamp,
    committer~,
    committer_timestamp~,
    allow_empty~,
  )
}

///|
pub fn commit_amend(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  message : String,
  author : String,
  author_timestamp : Int64,
  committer? : String = author,
  committer_timestamp? : Int64 = author_timestamp,
) -> @bit.ObjectId raise @bit.GitError {
  @bitlib.commit_amend(
    fs,
    rfs,
    root,
    message,
    author,
    author_timestamp,
    committer~,
    committer_timestamp~,
  )
}

///|
pub fn rm_paths(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  paths : Array[String],
  cached? : Bool = false,
  force? : Bool = false,
  recursive? : Bool = false,
) -> Unit raise @bit.GitError {
  @bitlib.rm_paths(fs, rfs, root, paths, cached~, force~, recursive~)
}

///|
pub fn mv_path(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  source : String,
  dest : String,
  force? : Bool = false,
) -> Unit raise @bit.GitError {
  @bitlib.mv_path(fs, rfs, root, source, dest, force~)
}

///|
pub fn write_loose_object(
  fs : &@bit.FileSystem,
  git_dir : String,
  obj_type : @bit.ObjectType,
  content : Bytes,
) -> @bit.ObjectId raise @bit.GitError {
  @bitlib.write_loose_object(fs, git_dir, obj_type, content)
}

///|
pub fn write_object_bytes(
  fs : &@bit.FileSystem,
  git_dir : String,
  id : @bit.ObjectId,
  compressed : Bytes,
) -> Unit raise @bit.GitError {
  @bitlib.write_object_bytes(fs, git_dir, id, compressed)
}

///|
pub fn resolve_head_commit(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
) -> @bit.ObjectId? raise @bit.GitError {
  @bitlib.resolve_head_commit(fs, git_dir)
}

///|
pub fn update_head_ref(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  commit_id : @bit.ObjectId,
) -> Unit raise @bit.GitError {
  @bitlib.update_head_ref(fs, rfs, git_dir, commit_id)
}

///|
pub fn write_tree_from_index(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  entries : Array[@bitlib.IndexEntry],
  prefix? : String? = None,
) -> @bit.ObjectId raise @bit.GitError {
  @bitlib.write_tree_from_index(fs, rfs, git_dir, entries, prefix~)
}
