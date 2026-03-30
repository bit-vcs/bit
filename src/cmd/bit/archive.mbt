///| git archive — create a tar archive of files from a named tree

///|
async fn handle_archive(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let git_dir = resolve_git_dir(fs, root)
  let mut format = "tar"
  let mut prefix = ""
  let mut output_file : String? = None
  let mut list_formats = false
  let mut tree_ish = "HEAD"
  let path_filters : Array[String] = []
  let mut tree_ish_set = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "-l" || arg == "--list" {
      list_formats = true
    } else if arg.has_prefix("--format=") {
      format = arg[9:].to_string()
    } else if arg.has_prefix("--prefix=") {
      prefix = arg[9:].to_string()
    } else if arg == "--output" || arg == "-o" {
      i += 1
      if i < args.length() {
        output_file = Some(args[i])
      } else {
        eprint_line("fatal: option requires an argument -- 'o'")
        @sys.exit(1)
      }
    } else if arg.has_prefix("--output=") {
      output_file = Some(arg[9:].to_string())
    } else if arg == "--" {
      // remaining args are path filters
      i += 1
      while i < args.length() {
        path_filters.push(args[i])
        i += 1
      }
      break
    } else if arg.has_prefix("-") {
      warn_unimplemented_arg("archive", arg)
    } else if !(tree_ish_set) {
      tree_ish = arg
      tree_ish_set = true
    } else {
      path_filters.push(arg)
    }
    i += 1
  }
  if list_formats {
    print_line("tar")
    return
  }
  if format != "tar" {
    eprint_line("fatal: Unknown archive format '\{format}'")
    @sys.exit(1)
  }
  // Resolve tree-ish
  let resolved_id = @bitrepo.rev_parse(fs, git_dir, tree_ish)
  guard resolved_id is Some(oid) else {
    eprint_line("fatal: not a valid object name: \{tree_ish}")
    @sys.exit(128)
  }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  // Determine tree id and mtime from commit
  let obj = db.get(fs, oid)
  guard obj is Some(o) else {
    eprint_line("fatal: not a valid object name: \{tree_ish}")
    @sys.exit(128)
  }
  let (tree_id, mtime) = match o.obj_type {
    @bitcore.ObjectType::Tree => (oid, 0L)
    @bitcore.ObjectType::Commit => {
      let info = @bitcore.parse_commit(o.data)
      let ts = @tar.tar_parse_committer_timestamp(o.data)
      (info.tree, ts)
    }
    _ => {
      eprint_line("fatal: not a tree object")
      @sys.exit(128)
      // unreachable
      (
        @bitcore.ObjectId::from_hex("0000000000000000000000000000000000000000"),
        0L,
      )
    }
  }
  // Collect files from tree
  let files = @bitlib.collect_tree_files(db, fs, tree_id)
  // Sort paths
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
  // Build tar output
  let out : Array[Byte] = []
  // Track emitted directories for prefix directory entries
  let emitted_dirs : Map[String, Bool] = {}
  // If prefix ends with '/', emit a directory entry for it
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
    // Emit parent directory entries as needed
    @tar.tar_emit_parent_dirs(out, full_path, mtime, emitted_dirs)
    let mode = fe.mode
    if mode == 0o120000 {
      // Symlink: blob content is the link target
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
      // Regular file
      let blob = db.get(fs, fe.id)
      guard blob is Some(b) else { continue }
      let data = b.data
      let size = data.length()
      let typeflag : Byte = b'0'
      let hdr = @tar.tar_make_header(full_path, mode, size, mtime, typeflag, "")
      for byte in hdr {
        out.push(byte)
      }
      // Write file content
      for j in 0..<size {
        out.push(data[j])
      }
      // Pad to 512-byte boundary
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
  let result = bytes_from_array(out)
  match output_file {
    Some(path) =>
      @fs.write_bytes_to_file(path, result) catch {
        err => raise io_error(err)
      }
    None => @stdio.stdout.write(result)
  }
}
