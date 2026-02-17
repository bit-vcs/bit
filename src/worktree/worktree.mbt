///| Worktree operations facade.

///|
pub async fn status(
  fs : &@git.RepoFileSystem,
  root : String,
) -> @gitlib.Status raise @git.GitError {
  @gitlib.status(fs, root)
}

///|
pub async fn status_porcelain(
  fs : &@git.RepoFileSystem,
  root : String,
) -> Array[String] raise @git.GitError {
  @gitlib.status_porcelain(fs, root)
}

///|
pub fn status_porcelain_from(s : @gitlib.Status) -> Array[String] {
  @gitlib.status_porcelain_from(s)
}

///|
pub async fn status_text(
  fs : &@git.RepoFileSystem,
  root : String,
) -> String raise @git.GitError {
  @gitlib.status_text(fs, root)
}

///|
pub fn add_paths(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  paths : Array[String],
) -> Unit raise @git.GitError {
  @gitlib.add_paths(fs, rfs, root, paths)
}

///|
pub async fn add_paths_async(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  paths : Array[String],
) -> Unit raise @git.GitError {
  @gitlib.add_paths_async(fs, rfs, root, paths)
}

///|
pub fn commit(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  message : String,
  author : String,
  author_timestamp : Int64,
  committer? : String = author,
  committer_timestamp? : Int64 = author_timestamp,
  allow_empty? : Bool = false,
) -> @git.ObjectId raise @git.GitError {
  @gitlib.commit(
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
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  message : String,
  author : String,
  author_timestamp : Int64,
  committer? : String = author,
  committer_timestamp? : Int64 = author_timestamp,
) -> @git.ObjectId raise @git.GitError {
  @gitlib.commit_amend(
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
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  paths : Array[String],
  cached? : Bool = false,
  force? : Bool = false,
  recursive? : Bool = false,
) -> Unit raise @git.GitError {
  @gitlib.rm_paths(fs, rfs, root, paths, cached~, force~, recursive~)
}

///|
pub fn mv_path(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  source : String,
  dest : String,
  force? : Bool = false,
) -> Unit raise @git.GitError {
  @gitlib.mv_path(fs, rfs, root, source, dest, force~)
}

///|
pub fn write_loose_object(
  fs : &@git.FileSystem,
  git_dir : String,
  obj_type : @git.ObjectType,
  content : Bytes,
) -> @git.ObjectId raise @git.GitError {
  @gitlib.write_loose_object(fs, git_dir, obj_type, content)
}

///|
pub fn write_object_bytes(
  fs : &@git.FileSystem,
  git_dir : String,
  id : @git.ObjectId,
  compressed : Bytes,
) -> Unit raise @git.GitError {
  @gitlib.write_object_bytes(fs, git_dir, id, compressed)
}

///|
pub fn resolve_head_commit(
  fs : &@git.RepoFileSystem,
  git_dir : String,
) -> @git.ObjectId? raise @git.GitError {
  @gitlib.resolve_head_commit(fs, git_dir)
}

///|
pub fn update_head_ref(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  commit_id : @git.ObjectId,
) -> Unit raise @git.GitError {
  @gitlib.update_head_ref(fs, rfs, git_dir, commit_id)
}

///|
pub fn write_tree_from_index(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  entries : Array[@gitlib.IndexEntry],
  prefix? : String? = None,
) -> @git.ObjectId raise @git.GitError {
  @gitlib.write_tree_from_index(fs, rfs, git_dir, entries, prefix~)
}
