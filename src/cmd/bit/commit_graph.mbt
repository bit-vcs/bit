///| Commit-graph file reader (minimal: header validation + hash version check)

///|
async fn validate_commit_graph_hash_version(
  fs : OsFs,
  git_dir : String,
) -> Unit {
  let rfs : &@bitcore.RepoFileSystem = fs
  let graph_path = git_dir + "/objects/info/commit-graph"
  if not(rfs.is_file(graph_path)) {
    return
  }
  let data = rfs.read_file(graph_path) catch { _ => return }
  if data.length() < 8 {
    return
  }
  // Header: signature(4) + version(1) + hash_version(1) + num_chunks(1) + num_base(1)
  let signature = (data[0].to_int() << 24) |
    (data[1].to_int() << 16) |
    (data[2].to_int() << 8) |
    data[3].to_int()
  if signature != 0x43475048 {
    return
  }
  let hash_version = data[5].to_int()
  let repo_hash_version = commit_graph_repo_hash_version(rfs, git_dir)
  if hash_version != repo_hash_version {
    eprint_line(
      "commit-graph hash version \{hash_version} does not match version \{repo_hash_version}",
    )
  }
}

///|
/// Check GIT_COMMIT_GRAPH_PARANOIA: verify that all commits in the
/// commit-graph file actually exist in the object database.
/// Exits with error if any are missing.
async fn check_commit_graph_paranoia(
  fs : OsFs,
  git_dir : String,
) -> Unit raise Error {
  match @sys.get_env_var("GIT_COMMIT_GRAPH_PARANOIA") {
    Some(value) => if value != "true" { return }
    None => return
  }
  let rfs : &@bitcore.RepoFileSystem = fs
  let graph_path = git_dir + "/objects/info/commit-graph"
  if not(rfs.is_file(graph_path)) {
    return
  }
  let data = rfs.read_file(graph_path) catch { _ => return }
  if data.length() < 8 {
    return
  }
  let signature = (data[0].to_int() << 24) |
    (data[1].to_int() << 16) |
    (data[2].to_int() << 8) |
    data[3].to_int()
  if signature != 0x43475048 {
    return
  }
  let hash_version = data[5].to_int()
  let hash_size = if hash_version == 2 { 32 } else { 20 }
  let num_chunks = data[6].to_int()
  // Parse chunk table to find OID lookup chunk
  let toc_start = 8
  let mut oidl_offset = 0
  let mut oidl_len = 0
  for i = 0; i < num_chunks; i = i + 1 {
    let entry_offset = toc_start + i * 12
    if entry_offset + 12 > data.length() {
      return
    }
    let chunk_id = (data[entry_offset].to_int() << 24) |
      (data[entry_offset + 1].to_int() << 16) |
      (data[entry_offset + 2].to_int() << 8) |
      data[entry_offset + 3].to_int()
    let offset_hi = (data[entry_offset + 4].to_int() << 24) |
      (data[entry_offset + 5].to_int() << 16) |
      (data[entry_offset + 6].to_int() << 8) |
      data[entry_offset + 7].to_int()
    let offset_lo = (data[entry_offset + 8].to_int() << 24) |
      (data[entry_offset + 9].to_int() << 16) |
      (data[entry_offset + 10].to_int() << 8) |
      data[entry_offset + 11].to_int()
    ignore(offset_hi)
    // OIDL = 0x4f49444c
    if chunk_id == 0x4f49444c {
      oidl_offset = offset_lo
      // Next chunk's offset gives us the length
      if i + 1 <= num_chunks {
        let next_off = toc_start + (i + 1) * 12
        if next_off + 12 <= data.length() {
          let next_lo = (data[next_off + 8].to_int() << 24) |
            (data[next_off + 9].to_int() << 16) |
            (data[next_off + 10].to_int() << 8) |
            data[next_off + 11].to_int()
          oidl_len = next_lo - offset_lo
        }
      }
    }
  }
  if oidl_offset == 0 || oidl_len == 0 {
    return
  }
  let num_commits = oidl_len / hash_size
  // Use ObjectDb WITHOUT commit-graph fallback for paranoia check
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  db.disable_commit_graph()
  for i = 0; i < num_commits; i = i + 1 {
    let oid_start = oidl_offset + i * hash_size
    if oid_start + hash_size > data.length() {
      break
    }
    let oid = @bitcore.ObjectId::from_bytes_at(data, oid_start, hash_size~)
    // Check if object exists in the database (loose or packed)
    let hex = oid.to_hex()
    let exists = commit_graph_object_exists(db, rfs, hex)
    if not(exists) {
      eprint_line(
        "error: commit \{hex} exists in commit-graph but not in the object database",
      )
      @sys.exit(1)
    }
  }
}

///|
fn commit_graph_object_exists(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  hex : String,
) -> Bool raise Error {
  let id = @bitcore.ObjectId::from_hex(hex)
  match db.get(fs, id) {
    Some(_) => true
    None => false
  }
}

///|
fn commit_graph_repo_hash_version(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Int {
  match
    @bitlib.read_config_value(
      rfs,
      git_dir + "/config",
      "extensions",
      "objectformat",
    ) {
    Some(value) => if value.to_lower() == "sha256" { 2 } else { 1 }
    None => 1
  }
}
