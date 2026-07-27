///| Asynchronous Git repository metadata materialization.

///|
/// Asynchronous counterpart to `materialize_clone_to_fs`.
pub async fn[FS : @types.AsyncFileSystem + @types.AsyncRepoFileSystem] materialize_clone_to_fs_async(
  store : ObjectStore,
  commit_id : @object.ObjectId,
  refname : String,
  remote_url : String,
  fs : FS,
  root : String,
) -> Unit raise @object.GitError {
  checkout_commit_to_fs_async(store, commit_id, fs, root)
  write_git_metadata_async(store, commit_id, refname, remote_url, fs, root)
}

///|
/// Asynchronous counterpart to `write_git_metadata`.
pub async fn[FS : @types.AsyncFileSystem + @types.AsyncRepoFileSystem] write_git_metadata_async(
  store : ObjectStore,
  commit_id : @object.ObjectId,
  refname : String,
  remote_url : String,
  fs : FS,
  root : String,
) -> Unit raise @object.GitError {
  let git_dir = join_path(root, ".git")
  @types.AsyncFileSystem::mkdir_p(fs, git_dir)
  @types.AsyncFileSystem::mkdir_p(fs, join_path(git_dir, "objects"))
  @types.AsyncFileSystem::mkdir_p(fs, join_path(git_dir, "objects/info"))
  @types.AsyncFileSystem::mkdir_p(fs, join_path(git_dir, "objects/pack"))
  @types.AsyncFileSystem::mkdir_p(fs, join_path(git_dir, "refs/heads"))
  @types.AsyncFileSystem::mkdir_p(fs, join_path(git_dir, "refs/tags"))
  write_head_and_refs_async(fs, git_dir, refname, commit_id)
  @types.AsyncFileSystem::write_string(
    fs,
    join_path(git_dir, "config"),
    git_config_text(remote_url),
  )
  @types.AsyncFileSystem::write_string(
    fs,
    join_path(git_dir, "packed-refs"),
    "# pack-refs with: peeled fully-peeled\n",
  )
  @types.AsyncFileSystem::write_string(
    fs,
    join_path(git_dir, "objects/info/alternates"),
    "",
  )
  write_index_v2_async(store, fs, git_dir, commit_id, root)
}

///|
async fn[FS : @types.AsyncFileSystem] write_head_and_refs_async(
  fs : FS,
  git_dir : String,
  refname : String,
  commit_id : @object.ObjectId,
) -> Unit raise @object.GitError {
  let head_path = join_path(git_dir, "HEAD")
  if refname == "HEAD" {
    @types.AsyncFileSystem::write_string(
      fs,
      head_path,
      commit_id.to_hex() + "\n",
    )
    return
  }
  @types.AsyncFileSystem::write_string(fs, head_path, "ref: \{refname}\n")
  let ref_path = join_path(git_dir, refname)
  @types.AsyncFileSystem::mkdir_p(fs, parent_dir(ref_path))
  @types.AsyncFileSystem::write_string(fs, ref_path, commit_id.to_hex() + "\n")
}

///|
async fn[FS : @types.AsyncFileSystem + @types.AsyncRepoFileSystem] write_index_v2_async(
  store : ObjectStore,
  fs : FS,
  git_dir : String,
  commit_id : @object.ObjectId,
  root : String,
) -> Unit raise @object.GitError {
  let entries = collect_commit_entries(store, commit_id)
  entries.sort_by((a, b) => String::lexical_compare(a.path, b.path))
  let entries_with_mtime : Array[(IndexEntryInfo, (Int, Int))] = []
  for entry in entries {
    let mtime = if entry.mode == 0o160000 {
      (0, 0)
    } else {
      @types.AsyncRepoFileSystem::mtime(fs, join_path(root, entry.path))
    }
    entries_with_mtime.push((entry, mtime))
  }
  @types.AsyncFileSystem::write_file(
    fs,
    join_path(git_dir, "index"),
    build_index_v2(entries_with_mtime),
  )
}
