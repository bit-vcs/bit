///| git unpack-file - extract a blob to a temp file

///|
async fn handle_unpack_file(args : Array[String]) -> Unit raise Error {
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git unpack-file <blob-id>",
          summary="Creates a file holding the contents of the blob specified by <blob-id>,\nand prints the name of the temporary file on stdout.",
        )
        return
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("unpack-file", arg)
      _ => positional.push(arg)
    }
  }
  if positional.length() == 0 {
    eprint_line("usage: git unpack-file <blob-id>")
    @sys.exit(1)
  }
  let blob_spec = positional[0]
  let fs = OsFs::new()
  let root = get_work_root()
  let git_dir = resolve_git_dir(fs, root)
  // Resolve the blob ID
  let oid = match @bitrepo.rev_parse(fs, git_dir, blob_spec) {
    Some(id) => id
    None => {
      eprint_line("fatal: Not a valid object name \{blob_spec}")
      @sys.exit(128)
      return
    }
  }
  // Load object databases
  let dbs = unpack_file_load_dbs(fs, git_dir)
  // Find the object
  let obj = match unpack_file_find_object(dbs, fs, oid) {
    Some(o) => o
    None => {
      eprint_line("fatal: Not a valid blob object \{blob_spec}")
      @sys.exit(128)
      return
    }
  }
  // Verify it's a blob
  if obj.obj_type != @bitcore.ObjectType::Blob {
    eprint_line("fatal: Not a valid blob object \{blob_spec}")
    @sys.exit(128)
    return
  }
  // Write content to temp file
  let temp_path = unpack_file_make_temp(fs)
  fs.write_file(temp_path, obj.data) catch {
    _ => {
      eprint_line("fatal: unable to write temp file")
      @sys.exit(128)
      return
    }
  }
  print_line(temp_path)
}

///|
fn unpack_file_load_dbs(fs : OsFs, git_dir : String) -> Array[@bitlib.ObjectDb] {
  let out : Array[@bitlib.ObjectDb] = []
  let primary = @bitlib.ObjectDb::load_lazy_from_objects_dir(
    fs,
    git_dir + "/objects",
  ) catch {
    _ => return out
  }
  primary.set_skip_verify(true)
  out.push(primary)
  // Check alternates
  let alt_data = fs.read_file(git_dir + "/objects/info/alternates") catch {
    _ => return out
  }
  let alt_text = decode_bytes(alt_data)
  for line_view in alt_text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let alt_db = @bitlib.ObjectDb::load_lazy_from_objects_dir(fs, line) catch {
      _ => continue
    }
    alt_db.set_skip_verify(true)
    out.push(alt_db)
  }
  out
}

///|
fn unpack_file_find_object(
  dbs : Array[@bitlib.ObjectDb],
  fs : OsFs,
  id : @bitcore.ObjectId,
) -> @bitcore.PackObject? raise Error {
  for db in dbs {
    let obj = db.get(fs, id)
    if obj is Some(o) {
      return Some(o)
    }
  }
  None
}

///|
fn unpack_file_make_temp(fs : OsFs) -> String {
  let base_dir = match @sys.get_env_var("TMPDIR") {
    Some(dir) =>
      if dir.has_suffix("/") && dir.length() > 1 {
        String::unsafe_substring(dir, start=0, end=dir.length() - 1)
      } else {
        dir
      }
    None => @sys.get_env_var("TMP").unwrap_or("/tmp")
  }
  let ts = get_current_timestamp()
  let base = base_dir + "/git-blob-" + "\{ts}"
  let mut candidate = base
  let mut i = 0
  while fs.is_file(candidate) {
    i += 1
    candidate = base + "-" + "\{i}"
  }
  candidate
}
