///| Commit-graph command handler and utilities

///|
async fn handle_commit_graph(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut subcommand : String? = None
  let mut object_dir : String? = None
  let mut reachable = false
  let mut stdin_packs = false
  let mut stdin_commits = false
  let mut append = false
  let mut verify_shallow = false
  let mut progress = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "write" | "verify" => subcommand = Some(arg)
      "--reachable" => reachable = true
      "--stdin-packs" => stdin_packs = true
      "--stdin-commits" => stdin_commits = true
      "--append" => append = true
      "--shallow" => verify_shallow = true
      "--progress" => progress = true
      "--no-progress" => progress = false
      "--object-dir" if i + 1 < args.length() => {
        object_dir = Some(args[i + 1])
        i += 2
        continue
      }
      _ if arg.has_prefix("--object-dir=") =>
        object_dir = Some(arg[13:].to_owned())
      // Accepted but ignored options
      "--changed-paths" | "--no-changed-paths" => ()
      _ if arg.has_prefix("--max-new-filters") => ()
      _ if arg.has_prefix("--split") => ()
      _ if arg.has_prefix("--expire-time") => ()
      _ if arg.has_prefix("--no-expire-time") => ()
      _ if arg.has_prefix("-") => warn_unimplemented_arg("commit-graph", arg)
      _ => ()
    }
    i += 1
  }
  ignore(append)
  ignore(progress)
  ignore(verify_shallow)
  // --object-dir points to the objects directory; git_dir is one level up.
  // If not specified, use the detected git_dir.
  let effective_git_dir = match object_dir {
    Some(d) => {
      let resolved = resolve_in_cwd(d)
      // Strip trailing "/objects" suffix if present to get git_dir
      if resolved.has_suffix("/objects") {
        String::unsafe_substring(
          resolved,
          start=0,
          end=resolved.length() - 8,
        )
      } else {
        // Assume it IS the git_dir (e.g. bare repo)
        resolved
      }
    }
    None => git_dir
  }
  match subcommand {
    None | Some("write") => {
      if stdin_commits {
        write_commit_graph_from_stdin_commits(fs, effective_git_dir)
      } else if stdin_packs {
        write_commit_graph(fs, effective_git_dir, false)
      } else if reachable {
        write_commit_graph(fs, effective_git_dir, true)
      } else {
        write_commit_graph(fs, effective_git_dir, false)
      }
    }
    Some("verify") => cgraph_verify(fs, effective_git_dir)
    Some(other) => {
      eprint_line("error: unknown subcommand: " + other)
      @sys.exit(1)
    }
  }
}

///|
async fn write_commit_graph_from_stdin_commits(
  fs : OsFs,
  git_dir : String,
) -> Unit raise Error {
  // --stdin-commits: fall back to full reachable walk (stdin parsing not yet implemented)
  write_commit_graph(fs, git_dir, true)
}

///|
async fn cgraph_verify(fs : OsFs, git_dir : String) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let graph_path = git_dir + "/objects/info/commit-graph"
  if !rfs.is_file(graph_path) {
    eprint_line("error: commit-graph file not found")
    @sys.exit(1)
  }
  let data = rfs.read_file(graph_path)
  if data.length() < 8 {
    eprint_line("error: commit-graph file too small")
    @sys.exit(1)
  }
  let sig = (data[0].to_int() << 24) |
    (data[1].to_int() << 16) |
    (data[2].to_int() << 8) |
    data[3].to_int()
  if sig != 0x43475048 {
    eprint_line("error: commit-graph signature mismatch")
    @sys.exit(1)
  }
  let hash_version = data[5].to_int()
  let hash_size = if hash_version == 2 { 32 } else { 20 }
  let expected_hash_version = commit_graph_repo_hash_version(rfs, git_dir)
  if hash_version != expected_hash_version {
    eprint_line(
      "error: commit-graph hash version \{hash_version} does not match repository hash version \{expected_hash_version}",
    )
    @sys.exit(1)
  }
  // Verify checksum trailer
  if data.length() < hash_size {
    eprint_line("error: commit-graph file too small for checksum")
    @sys.exit(1)
  }
  let body_len = data.length() - hash_size
  let stored_trailer = @bitcore.ObjectId::from_bytes_at(
    data, body_len, hash_size~,
  )
  let expected_trailer = @bitcore.hash_prefix(data, body_len, hash_size~)
  if stored_trailer != expected_trailer {
    eprint_line("error: commit-graph checksum mismatch")
    @sys.exit(1)
  }
  // Verify all commits exist
  check_commit_graph_paranoia(fs, git_dir)
}

///| Commit-graph file reader (minimal: header validation + hash version check)

///|
async fn validate_commit_graph_hash_version(
  fs : OsFs,
  git_dir : String,
) -> Unit {
  let rfs : &@bitcore.RepoFileSystem = fs
  let graph_path = git_dir + "/objects/info/commit-graph"
  if !rfs.is_file(graph_path) {
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
  if !rfs.is_file(graph_path) {
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
    if !exists {
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
