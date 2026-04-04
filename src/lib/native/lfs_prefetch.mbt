///| LFS prefetch: walk tree, collect pointers, batch download

///|
async fn lfs_prefetch_eprint_line(s : String) -> Unit noraise {
  @stdio.stderr.write(@utf8.encode(s + "\n")) catch {
    _ => ()
  }
}

///|
/// Walk a commit's tree, find all LFS pointer blobs, download any not already cached.
/// Call this before checkout to populate .git/lfs/objects/.
pub async fn lfs_prefetch_for_checkout(
  db : @bitlib.ObjectDb,
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  root : String,
  git_dir : String,
  commit_id : @bit.ObjectId,
  remote_name : String,
) -> Unit raise @bit.GitError {
  // 1. Collect all tree files
  let files = @bitlib.collect_tree_files_from_commit(db, rfs, commit_id)
  // 2. Find LFS pointers that need downloading
  let needed : Array[@bitlib.LfsPointer] = []
  for item in files.to_array() {
    let (path, info) = item
    if info.mode == 0o160000 {
      continue
    }
    let attrs = @bitlib.resolve_eol_attrs(rfs, root, path)
    if attrs.filter != Some("lfs") {
      continue
    }
    let obj = db.get(rfs, info.id)
    match obj {
      Some(o) =>
        if o.obj_type == @bit.ObjectType::Blob && @bitlib.is_lfs_pointer(o.data) {
          match @bitlib.parse_lfs_pointer(o.data) {
            Some(ptr) => {
              let cached_path = @bitlib.lfs_object_path(git_dir, ptr.oid)
              if !rfs.is_file(cached_path) {
                needed.push(ptr)
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }
  if needed.length() == 0 {
    return
  }
  // 3. Resolve LFS URL
  let lfs_url = @bitlib.resolve_lfs_url(rfs, git_dir, remote_name)
  if lfs_url.length() == 0 {
    raise @bit.GitError::IoError(
      "Cannot resolve LFS server URL. Set lfs.url in git config or configure a remote.",
    )
  }
  // Security: validate LFS URL scheme
  if !@bitlib.lfs_is_valid_http_url(lfs_url) {
    raise @bit.GitError::IoError(
      "LFS server URL must use http:// or https:// scheme, got: \{lfs_url}",
    )
  }
  // 4. Batch download
  let (actions, batch_errors) = lfs_batch_request(lfs_url, needed)
  for err in batch_errors {
    lfs_prefetch_eprint_line(
      "warning: LFS object \{err.oid}: \{err.message} (code \{err.code})",
    )
  }
  // 5. Download objects
  let dl_errors = lfs_download_objects(fs, rfs, git_dir, actions)
  for err in dl_errors {
    lfs_prefetch_eprint_line(
      "warning: LFS download failed for \{err.oid}: \{err.message}",
    )
  }
}
