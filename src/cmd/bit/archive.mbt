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
    } else if not(tree_ish_set) {
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
      let ts = archive_parse_committer_timestamp(o.data)
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
    let hdr = tar_make_header(prefix, 0o40755, 0, mtime, b'5', "")
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
    archive_emit_parent_dirs(out, full_path, mtime, emitted_dirs)
    let mode = fe.mode
    if mode == 0o120000 {
      // Symlink: blob content is the link target
      let blob = db.get(fs, fe.id)
      guard blob is Some(b) else { continue }
      let link_target = @utf8.decode_lossy(b.data[:])
      let hdr = tar_make_header(full_path, mode, 0, mtime, b'2', link_target)
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
      let hdr = tar_make_header(full_path, mode, size, mtime, typeflag, "")
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

///|
fn archive_parse_committer_timestamp(data : Bytes) -> Int64 {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("committer ") {
      // Format: "committer Name <email> timestamp tz"
      let rest = line[10:].to_string()
      // Find '>' to locate end of email
      let mut gt_pos = -1
      for ci in 0..<rest.length() {
        if rest[ci] == '>' {
          gt_pos = ci
        }
      }
      if gt_pos >= 0 && gt_pos + 2 < rest.length() {
        let after_email = rest[gt_pos + 2:].to_string()
        // "timestamp tz"
        let parts = after_email.split(" ")
        let parts_arr : Array[String] = []
        for p in parts {
          parts_arr.push(p.to_string())
        }
        if parts_arr.length() >= 1 {
          let ts_str = parts_arr[0]
          let ts = @strconv.parse_int64(ts_str) catch { _ => 0L }
          return ts
        }
      }
    }
  }
  0L
}

///|
fn archive_emit_parent_dirs(
  out : Array[Byte],
  path : String,
  mtime : Int64,
  emitted : Map[String, Bool],
) -> Unit {
  // Collect all parent directories
  let dirs : Array[String] = []
  let mut p = path
  while true {
    let mut slash_pos = -1
    for i in 0..<p.length() {
      if p[i] == '/' {
        slash_pos = i
      }
    }
    if slash_pos <= 0 {
      break
    }
    let dir = p[:slash_pos + 1].to_string() // include trailing /
    if emitted.contains(dir) {
      break
    }
    dirs.push(dir)
    p = p[:slash_pos].to_string()
  }
  // Emit in order from shallowest to deepest
  let mut di = dirs.length() - 1
  while di >= 0 {
    let dir = dirs[di]
    if not(emitted.contains(dir)) {
      emitted[dir] = true
      let hdr = tar_make_header(dir, 0o40755, 0, mtime, b'5', "")
      for b in hdr {
        out.push(b)
      }
    }
    di -= 1
  }
}

///|
fn tar_make_header(
  path : String,
  mode : Int,
  size : Int,
  mtime : Int64,
  typeflag : Byte,
  linkname : String,
) -> FixedArray[Byte] {
  let header = FixedArray::make(512, b'\x00')
  // Split path into prefix + name if needed
  let (name_str, prefix_str) = if path.length() > 100 {
    tar_split_path(path)
  } else {
    (path, "")
  }
  // name (offset 0, 100 bytes)
  tar_write_string(header, 0, name_str, 100)
  // mode (offset 100, 8 bytes) — octal NUL-terminated
  let mode_str = tar_format_octal(mode.to_int64(), 7)
  tar_write_string(header, 100, mode_str, 8)
  // uid (offset 108, 8 bytes)
  tar_write_string(header, 108, "0000000", 8)
  // gid (offset 116, 8 bytes)
  tar_write_string(header, 116, "0000000", 8)
  // size (offset 124, 12 bytes) — octal NUL-terminated
  let size_str = tar_format_octal(size.to_int64(), 11)
  tar_write_string(header, 124, size_str, 12)
  // mtime (offset 136, 12 bytes) — octal NUL-terminated
  let mtime_str = tar_format_octal(mtime, 11)
  tar_write_string(header, 136, mtime_str, 12)
  // checksum placeholder (offset 148, 8 bytes) — spaces for computation
  for ci in 0..<8 {
    header[148 + ci] = b' '
  }
  // typeflag (offset 156, 1 byte)
  header[156] = typeflag
  // linkname (offset 157, 100 bytes)
  if linkname.length() > 0 {
    tar_write_string(header, 157, linkname, 100)
  }
  // magic (offset 257, 6 bytes) "ustar\0"
  tar_write_string(header, 257, "ustar", 6)
  // version (offset 263, 2 bytes) "00"
  header[263] = b'0'
  header[264] = b'0'
  // uname (offset 265, 32 bytes)
  tar_write_string(header, 265, "root", 32)
  // gname (offset 297, 32 bytes)
  tar_write_string(header, 297, "root", 32)
  // devmajor (offset 329, 8 bytes)
  tar_write_string(header, 329, "0000000", 8)
  // devminor (offset 337, 8 bytes)
  tar_write_string(header, 337, "0000000", 8)
  // prefix (offset 345, 155 bytes)
  if prefix_str.length() > 0 {
    tar_write_string(header, 345, prefix_str, 155)
  }
  // Compute checksum
  let mut chksum = 0
  for ci in 0..<512 {
    chksum += header[ci].to_int()
  }
  // Write checksum as 6-digit octal + NUL + space
  let chksum_str = tar_format_octal(chksum.to_int64(), 6)
  for ci in 0..<6 {
    header[148 + ci] = chksum_str[ci].to_int().to_byte()
  }
  header[148 + 6] = b'\x00'
  header[148 + 7] = b' '
  header
}

///|
fn tar_write_string(
  buf : FixedArray[Byte],
  offset : Int,
  s : String,
  max_len : Int,
) -> Unit {
  let bytes = @utf8.encode(s)
  let len = if bytes.length() < max_len { bytes.length() } else { max_len }
  for i in 0..<len {
    buf[offset + i] = bytes[i]
  }
}

///|
fn tar_format_octal(value : Int64, width : Int) -> String {
  if value == 0L {
    let buf = StringBuilder::new()
    for _i in 0..<width {
      buf.write_char('0')
    }
    return buf.to_string()
  }
  // Convert to octal string
  let digits : Array[Char] = []
  let mut v = value
  while v > 0L {
    let d = (v % 8L).to_int()
    digits.push((d + '0'.to_int()).unsafe_to_char())
    v = v / 8L
  }
  // Reverse
  let buf = StringBuilder::new()
  let digit_len = digits.length()
  // Pad with leading zeros
  if digit_len < width {
    let pad_count = width - digit_len
    for _i in 0..<pad_count {
      buf.write_char('0')
    }
  }
  let mut di = digits.length() - 1
  while di >= 0 {
    buf.write_char(digits[di])
    di -= 1
  }
  buf.to_string()
}

///|
fn tar_split_path(path : String) -> (String, String) {
  // Find a '/' boundary to split into prefix (max 155) and name (max 100)
  let mut best_slash = -1
  for i in 0..<path.length() {
    if path[i] == '/' {
      let prefix_len = i
      let name_len = path.length() - i - 1
      if prefix_len <= 155 && name_len <= 100 {
        best_slash = i
      }
    }
  }
  if best_slash >= 0 {
    let prefix_part = path[:best_slash].to_string()
    let name_part = path[best_slash + 1:].to_string()
    (name_part, prefix_part)
  } else {
    // Can't split; truncate name
    (path[:100].to_string(), "")
  }
}
