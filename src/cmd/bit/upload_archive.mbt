///| git upload-archive — server-side command for git archive --remote

///|
async fn handle_upload_archive(args : Array[String]) -> Unit raise Error {
  // Handle -h/--help
  for arg in args {
    if arg == "-h" || arg == "--help" || arg == "--help-all" {
      print_line("usage: git upload-archive <repository>")
      @sys.exit(129)
    }
  }
  // Parse repository path from args (last non-flag argument)
  let mut repo_path = ""
  for arg in args {
    if !(arg.has_prefix("-")) {
      repo_path = arg
    }
  }
  if repo_path == "" {
    eprint_line("fatal: missing repository path")
    @sys.exit(1)
  }
  let root = if repo_path.has_suffix(".git") && !repo_path.has_suffix("/.git") {
    repo_path
  } else {
    normalize_repo_root(repo_path)
  }
  let fs = OsFs::new()
  let git_dir = if root.has_suffix(".git") && !root.has_suffix("/.git") {
    root
  } else if fs.is_file(root + "/HEAD") && !(fs.is_dir(root + "/.git")) {
    root
  } else {
    root + "/.git"
  }
  // Read pkt-line arguments from stdin
  let input = read_all_stdin()
  let archive_args : Array[String] = []
  let arg_prefix = "argument "
  let packets = @protocol.pktline_decode(input) catch {
    err => {
      upload_archive_send_nack("protocol error: " + err.to_string())
      @sys.exit(1)
      return
    }
  }
  for packet in packets {
    let (data, is_flush) = packet
    if is_flush {
      break
    }
    if data.length() == 0 {
      continue
    }
    // Convert to string and strip trailing newline
    let line = decode_bytes(data)
    let trimmed = if line.length() > 0 && line[line.length() - 1] == '\n' {
      line[:line.length() - 1].to_string()
    } else {
      line
    }
    if trimmed.has_prefix(arg_prefix) {
      archive_args.push(trimmed[arg_prefix.length():].to_string())
    } else {
      upload_archive_send_nack("'argument' token or flush expected")
      @sys.exit(1)
    }
  }
  if archive_args.length() > 64 {
    upload_archive_send_nack("Too many options (>64)")
    @sys.exit(1)
  }
  // Parse archive arguments
  let mut format = "tar"
  let mut prefix = ""
  let mut tree_ish = "HEAD"
  let path_filters : Array[String] = []
  let mut tree_ish_set = false
  let mut i = 0
  while i < archive_args.length() {
    let arg = archive_args[i]
    if arg.has_prefix("--format=") {
      format = arg[9:].to_string()
    } else if arg.has_prefix("--prefix=") {
      prefix = arg[9:].to_string()
    } else if arg == "--" {
      i += 1
      while i < archive_args.length() {
        path_filters.push(archive_args[i])
        i += 1
      }
      break
    } else if arg.has_prefix("-") {
      // Skip other flags silently
      ()
    } else if !(tree_ish_set) {
      tree_ish = arg
      tree_ish_set = true
    } else {
      path_filters.push(arg)
    }
    i += 1
  }
  if format != "tar" {
    upload_archive_send_nack("Unknown archive format '\{format}'")
    @sys.exit(1)
  }
  // Resolve tree-ish
  let resolved_id = @bitrepo.rev_parse(fs, git_dir, tree_ish)
  guard resolved_id is Some(oid) else {
    upload_archive_send_nack("not a valid object name: \{tree_ish}")
    @sys.exit(1)
  }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let obj = db.get(fs, oid)
  guard obj is Some(o) else {
    upload_archive_send_nack("not a valid object name: \{tree_ish}")
    @sys.exit(1)
  }
  let (tree_id, mtime) = match o.obj_type {
    @bitcore.ObjectType::Tree => (oid, 0L)
    @bitcore.ObjectType::Commit => {
      let info = @bitcore.parse_commit(o.data)
      let ts = @tar.tar_parse_committer_timestamp(o.data)
      (info.tree, ts)
    }
    _ => {
      upload_archive_send_nack("not a tree object")
      @sys.exit(1)
      return
    }
  }
  // Collect files from tree
  let files = @bitlib.collect_tree_files(db, fs, tree_id)
  let sorted_paths : Array[String] = []
  for item in files {
    sorted_paths.push(item.0)
  }
  sorted_paths.sort()
  // Apply path filters
  let filtered_paths = if path_filters.length() > 0 {
    let result : Array[String] = []
    for path in sorted_paths {
      for filter in path_filters {
        if path == filter ||
          path.has_prefix(filter + "/") ||
          path.has_prefix(filter) {
          result.push(path)
          break
        }
      }
    }
    result
  } else {
    sorted_paths
  }
  // Build tar archive
  let out : Array[Byte] = []
  let emitted_dirs : Map[String, Bool] = {}
  if prefix.length() > 0 && prefix[prefix.length() - 1] == '/' {
    let hdr = @tar.tar_make_header(prefix, 0o40755, 0, mtime, b'5', "")
    for b in hdr {
      out.push(b)
    }
    emitted_dirs[prefix] = true
  }
  for path in filtered_paths {
    let full_path = prefix + path
    let entry = files.get(path)
    guard entry is Some(fe) else { continue }
    @tar.tar_emit_parent_dirs(out, full_path, mtime, emitted_dirs)
    let mode = fe.mode
    if mode == 0o120000 {
      let blob = db.get(fs, fe.id)
      guard blob is Some(b) else { continue }
      let link_target = @utf8.decode_lossy(b.data[:])
      let hdr = @tar.tar_make_header(
        full_path, mode, 0, mtime, b'2', link_target,
      )
      for byte in hdr {
        out.push(byte)
      }
    } else {
      let blob = db.get(fs, fe.id)
      guard blob is Some(b) else { continue }
      let data = b.data
      let size = data.length()
      let typeflag : Byte = b'0'
      let hdr = @tar.tar_make_header(full_path, mode, size, mtime, typeflag, "")
      for byte in hdr {
        out.push(byte)
      }
      for j in 0..<size {
        out.push(data[j])
      }
      let remainder = size % 512
      if remainder > 0 {
        let pad = 512 - remainder
        for _k in 0..<pad {
          out.push(b'\x00')
        }
      }
    }
  }
  // End-of-archive: two 512-byte zero blocks
  for _k in 0..<1024 {
    out.push(b'\x00')
  }
  let archive_data = bytes_from_array(out)
  // Send ACK + flush via pkt-line
  @stdio.stdout.write(@protocol.pktline_encode("ACK\n"))
  @stdio.stdout.write(@protocol.pktline_flush())
  // Send archive data via sideband (band 1 = data)
  let chunk_size = 65515 // 65520 - 4 (pkt-line header) - 1 (band byte)
  let mut offset = 0
  let sb_out : Array[Byte] = []
  while offset < archive_data.length() {
    let end = if offset + chunk_size > archive_data.length() {
      archive_data.length()
    } else {
      offset + chunk_size
    }
    let data_len = end - offset
    let pkt_len = data_len + 5 // 4 (header) + 1 (band byte)
    let len_hex = @bithash.int_to_hex4(pkt_len)
    for c in len_hex {
      sb_out.push(c.to_int().to_byte())
    }
    sb_out.push(b'\x01') // band 1 = data
    for j in offset..<end {
      sb_out.push(archive_data[j])
    }
    offset = end
  }
  // Flush to end sideband
  for b in @protocol.pktline_flush() {
    sb_out.push(b)
  }
  @stdio.stdout.write(bytes_from_array(sb_out))
}

///|
async fn upload_archive_send_nack(msg : String) -> Unit raise Error {
  @stdio.stdout.write(@protocol.pktline_encode("NACK \{msg}\n"))
}
