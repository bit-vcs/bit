///|
async fn handle_verify_pack(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let mut verbose = false
  let mut stat_only = false
  let pack_files : Array[String] = []
  for arg in args {
    match arg {
      "-v" | "--verbose" => verbose = true
      "-s" | "--stat-only" => stat_only = true
      _ if not(arg.has_prefix("-")) => pack_files.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("verify-pack", arg)
      _ => ()
    }
  }
  if pack_files.length() == 0 {
    eprint_line(
      "usage: git verify-pack [-v | --verbose] [-s | --stat-only] <pack>...",
    )
    @sys.exit(1)
  }
  for pack_path in pack_files {
    verify_single_pack(fs, pack_path, verbose, stat_only)
  }
}

///|
async fn verify_single_pack(
  fs : OsFs,
  pack_path : String,
  verbose : Bool,
  stat_only : Bool,
) -> Unit raise Error {
  // Normalize path - accept .pack, .idx or base name
  let base_path = if pack_path.has_suffix(".pack") {
    String::unsafe_substring(pack_path, start=0, end=pack_path.length() - 5)
  } else if pack_path.has_suffix(".idx") {
    String::unsafe_substring(pack_path, start=0, end=pack_path.length() - 4)
  } else {
    pack_path
  }
  let pack_file = base_path + ".pack"
  if not(fs.is_file(pack_file)) {
    raise @bitcore.GitError::InvalidObject("pack file not found: " + pack_file)
  }
  let data = fs.read_file(pack_file)
  // Parse and verify the packfile
  let objects = @pack.parse_packfile(data)
  // Count object types
  let mut _commits = 0
  let mut _trees = 0
  let mut _blobs = 0
  let mut _tags = 0
  let mut total_size = 0
  for obj in objects {
    match obj.obj_type {
      @bitcore.ObjectType::Commit => _commits += 1
      @bitcore.ObjectType::Tree => _trees += 1
      @bitcore.ObjectType::Blob => _blobs += 1
      @bitcore.ObjectType::Tag => _tags += 1
    }
    total_size += obj.data.length()
  }
  if verbose && not(stat_only) {
    // Print each object
    for obj in objects {
      let id = @bitcore.hash_object_content(obj.obj_type, obj.data)
      let type_str = match obj.obj_type {
        @bitcore.ObjectType::Commit => "commit"
        @bitcore.ObjectType::Tree => "tree"
        @bitcore.ObjectType::Blob => "blob"
        @bitcore.ObjectType::Tag => "tag"
      }
      print_line("\{id.to_hex()} \{type_str} \{obj.data.length()}")
    }
  }
  // Print summary
  if verbose || stat_only {
    print_line(
      "chain length = 0: \{objects.length()} objects, \{total_size} bytes",
    )
  }
  // Print final verification message with pack checksum
  let checksum = get_pack_checksum(data)
  print_line("\{pack_file}: ok (\{checksum})")
}

///|
fn get_pack_checksum(data : Bytes) -> String {
  if data.length() < 20 {
    return "invalid"
  }
  let start = data.length() - 20
  let bytes : FixedArray[Byte] = FixedArray::makei(20, i => data[start + i])
  @bitcore.ObjectId::new(bytes).to_hex()
}

///|
