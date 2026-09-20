///| Git shallow-boundary metadata.

///|
pub fn read_shallow_boundaries(
  fs : &@types.RepoFileSystem,
  git_dir : String,
) -> Array[@object.ObjectId] {
  let path = join_path(git_dir, "shallow")
  if !fs.is_file(path) {
    return []
  }
  let data = fs.read_file(path) catch { _ => Default::default() }
  let boundaries : Array[@object.ObjectId] = []
  for line_view in @utf8.decode_lossy(data[:]).split("\n") {
    let line = line_view.trim().to_owned()
    if line.length() != 40 {
      continue
    }
    let id = @object.ObjectId::from_hex(line) catch { _ => continue }
    boundaries.push(id)
  }
  boundaries
}

///|
pub fn apply_shallow_updates(
  fs : &@types.FileSystem,
  rfs : &@types.RepoFileSystem,
  git_dir : String,
  shallow : Array[@object.ObjectId],
  unshallow : Array[@object.ObjectId],
) -> Unit raise @object.GitError {
  if shallow.length() == 0 && unshallow.length() == 0 {
    return
  }
  let boundaries : Map[String, @object.ObjectId] = Map([])
  for id in read_shallow_boundaries(rfs, git_dir) {
    boundaries[id.to_hex()] = id
  }
  for id in unshallow {
    boundaries.remove(id.to_hex())
  }
  for id in shallow {
    boundaries[id.to_hex()] = id
  }
  let path = join_path(git_dir, "shallow")
  if boundaries.length() == 0 {
    if rfs.is_file(path) {
      fs.remove_file(path)
    }
    return
  }
  let lines = [ for _, id in boundaries => id.to_hex() ]
  fs.write_string(path, lines.join("\n") + "\n")
}

///|
/// Record the shallow boundary of a freshly cloned repository.
///
/// A clone starts with no `shallow` file, so there is nothing to merge and no
/// prior boundary an `unshallow` line could lift: writing the reported set is
/// the whole job. `apply_shallow_updates` covers the incremental fetch case,
/// which needs to read what is already there.
pub async fn[FS : @types.AsyncFileSystem] write_shallow_boundaries_async(
  fs : FS,
  git_dir : String,
  shallow : Array[@object.ObjectId],
) -> Unit raise @object.GitError {
  if shallow.length() == 0 {
    return
  }
  let seen : Map[String, Bool] = Map([])
  let lines : Array[String] = []
  for id in shallow {
    let hex = id.to_hex()
    if seen.contains(hex) {
      continue
    }
    seen[hex] = true
    lines.push(hex)
  }
  @types.AsyncFileSystem::write_string(
    fs,
    join_path(git_dir, "shallow"),
    lines.join("\n") + "\n",
  )
}
