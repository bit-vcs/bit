///|
fn hash_object_storage_runtime_delegate_args(
  args : Array[String],
) -> @runtime.StorageHashObjectArgs? {
  if hash_object_need_real_git(args) {
    return None
  }
  let parsed = storage_runtime_parse_command("hash-object", args) catch {
    _ => return None
  }
  match parsed {
    @runtime.StorageCommand::HashObject(hash_args) => Some(hash_args)
    _ => None
  }
}

///|
fn hash_object_need_real_git(_args : Array[String]) -> Bool {
  false
}

///|
async fn handle_hash_object(args : Array[String]) -> Unit raise Error {
  match hash_object_storage_runtime_delegate_args(args) {
    Some(hash_args) => {
      let root = get_work_root()
      let fs = OsFs::new()
      let git_dir = resolve_git_dir(fs, root)
      let algo = hash_object_resolve_algo(fs, git_dir, hash_args.object_format)
      let resolved_path_hint = hash_object_resolve_path_hint(
        root,
        hash_args.path_hint,
      )
      if hash_args.stdin_mode {
        let raw_content = read_all_stdin()
        let rfs : &@bitcore.RepoFileSystem = fs
        let content = if resolved_path_hint.length() > 0 &&
          not(hash_args.no_filters) {
          let autocrlf = @bitlib.read_autocrlf_setting(rfs, git_dir)
          let attrs = @bitlib.resolve_eol_attrs(rfs, root, resolved_path_hint)
          @bitlib.clean_for_storage(raw_content, attrs, autocrlf)
        } else {
          raw_content
        }
        if not(hash_args.literally) {
          hash_object_validate_content(hash_args.obj_type, content, algo~)
        }
        let id = @bitobject.hash_object_content_with_algo(
          algo,
          hash_args.obj_type,
          content,
        )
        if hash_args.write_object {
          let (_, compressed) = @bitobject.create_object_with_algo(
            algo,
            hash_args.obj_type,
            content,
          )
          @bitlib.write_object_bytes(fs, git_dir, id, compressed)
        }
        print_line(id.to_hex())
      }
      if hash_args.stdin_paths {
        let stdin_data = read_all_stdin()
        let text = @string_utils.decode_bytes(stdin_data)
        hash_object_process_stdin_paths(
          fs, root, git_dir, algo, hash_args, text,
        )
      }
      if not(hash_args.stdin_mode) &&
        not(hash_args.stdin_paths) &&
        hash_args.paths.length() == 0 {
        @runtime.run_storage_command(
          fs,
          fs,
          root,
          @runtime.StorageCommand::HashObject(hash_args),
        )
      } else {
        hash_object_process_file_paths(fs, root, git_dir, algo, hash_args)
      }
      return
    }
    None => ()
  }
  eprint_line(
    "fatal: hash-object with unsupported arguments is not available in standalone mode",
  )
  @sys.exit(128)
}

///|
async fn hash_object_process_file_paths(
  fs : OsFs,
  root : String,
  git_dir : String,
  algo : @bitobject.HashAlgorithm,
  hash_args : @runtime.StorageHashObjectArgs,
) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let autocrlf = @bitlib.read_autocrlf_setting(rfs, git_dir)
  let cwd = get_cwd_for_hash_object()
  for path in hash_args.paths {
    let abs = if path.has_prefix("/") {
      normalize_path(path)
    } else {
      normalize_path(cwd + "/" + path)
    }
    let content = rfs.read_file(abs)
    let prefix_len = root.length() + 1
    let rel_path = if abs.has_prefix(root + "/") {
      String::unsafe_substring(abs, start=prefix_len, end=abs.length())
    } else {
      abs
    }
    let resolved_hint = hash_object_resolve_path_hint(root, hash_args.path_hint)
    let filter_rel = if resolved_hint.length() > 0 {
      resolved_hint
    } else {
      rel_path
    }
    let normalized = if hash_args.no_filters {
      content
    } else {
      let attrs = @bitlib.resolve_eol_attrs(rfs, root, filter_rel)
      @bitlib.clean_for_storage(content, attrs, autocrlf)
    }
    if not(hash_args.literally) {
      hash_object_validate_content(hash_args.obj_type, normalized, algo~)
    }
    let id = @bitobject.hash_object_content_with_algo(
      algo,
      hash_args.obj_type,
      normalized,
    )
    if hash_args.write_object {
      let (_, compressed) = @bitobject.create_object_with_algo(
        algo,
        hash_args.obj_type,
        normalized,
      )
      @bitlib.write_object_bytes(fs, git_dir, id, compressed)
    }
    print_line(id.to_hex())
  }
}

///|
async fn hash_object_process_stdin_paths(
  fs : OsFs,
  root : String,
  git_dir : String,
  algo : @bitobject.HashAlgorithm,
  hash_args : @runtime.StorageHashObjectArgs,
  text : String,
) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let autocrlf = @bitlib.read_autocrlf_setting(rfs, git_dir)
  let cwd = get_cwd_for_hash_object()
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    let abs = if line.has_prefix("/") {
      normalize_path(line)
    } else {
      normalize_path(cwd + "/" + line)
    }
    let content = rfs.read_file(abs)
    let prefix_len = root.length() + 1
    let rel_path = if abs.has_prefix(root + "/") {
      String::unsafe_substring(abs, start=prefix_len, end=abs.length())
    } else {
      abs
    }
    let normalized = if hash_args.no_filters {
      content
    } else {
      let attrs = @bitlib.resolve_eol_attrs(rfs, root, rel_path)
      @bitlib.clean_for_storage(content, attrs, autocrlf)
    }
    let id = @bitobject.hash_object_content_with_algo(
      algo,
      hash_args.obj_type,
      normalized,
    )
    if hash_args.write_object {
      let (_, compressed) = @bitobject.create_object_with_algo(
        algo,
        hash_args.obj_type,
        normalized,
      )
      @bitlib.write_object_bytes(fs, git_dir, id, compressed)
    }
    print_line(id.to_hex())
  }
}

///|
fn hash_object_resolve_path_hint(root : String, hint : String) -> String {
  if hint.length() == 0 {
    return ""
  }
  let cwd = get_cwd_for_hash_object()
  let abs = if hint.has_prefix("/") {
    normalize_path(hint)
  } else {
    normalize_path(cwd + "/" + hint)
  }
  let prefix = root + "/"
  if abs.has_prefix(prefix) {
    String::unsafe_substring(abs, start=prefix.length(), end=abs.length())
  } else {
    hint
  }
}

///|
fn get_cwd_for_hash_object() -> String {
  match @sys.get_env_var("GIT_SHIM_PWD") {
    Some(path) => path
    None =>
      match @env.current_dir() {
        Some(path) => path
        None => ""
      }
  }
}

///|
fn hash_object_resolve_algo(
  fs : OsFs,
  git_dir : String,
  explicit_format : String,
) -> @bitobject.HashAlgorithm {
  if explicit_format.length() > 0 {
    return if explicit_format.to_lower() == "sha256" {
      @bitobject.HashAlgorithm::Sha256
    } else {
      @bitobject.HashAlgorithm::Sha1
    }
  }
  let rfs : &@bitcore.RepoFileSystem = fs
  match
    @bitlib.read_config_value(
      rfs,
      git_dir + "/config",
      "extensions",
      "objectformat",
    ) {
    Some(value) =>
      if value.to_lower() == "sha256" {
        @bitobject.HashAlgorithm::Sha256
      } else {
        @bitobject.HashAlgorithm::Sha1
      }
    None => @bitobject.HashAlgorithm::Sha1
  }
}

///|
async fn hash_object_validate_content(
  obj_type : @bitcore.ObjectType,
  content : Bytes,
  algo? : @bitobject.HashAlgorithm = @bitobject.HashAlgorithm::Sha1,
) -> Unit raise Error {
  match obj_type {
    @bitcore.ObjectType::Commit => {
      let text = @utf8.decode_lossy(content[:])
      if not(text.has_prefix("tree ")) {
        eprint_line("fatal: corrupt commit")
        @sys.exit(128)
      }
    }
    @bitcore.ObjectType::Tag => {
      let text = @utf8.decode_lossy(content[:])
      if not(text.has_prefix("object ")) {
        eprint_line("fatal: corrupt tag")
        @sys.exit(128)
      }
    }
    @bitcore.ObjectType::Tree => hash_object_validate_tree(content, algo)
    _ => ()
  }
}

///|
async fn hash_object_validate_tree(
  content : Bytes,
  algo : @bitobject.HashAlgorithm,
) -> Unit {
  let len = content.length()
  let oid_size = algo.hash_size()
  if len == 0 {
    return
  }
  if len < oid_size + 4 {
    eprint_line("error: too-short tree object")
    @sys.exit(128)
  }
  let mut pos = 0
  let seen_names : Map[String, Bool] = {}
  while pos < len {
    // Parse mode (digits followed by space)
    let mode_start = pos
    while pos < len && content[pos] != b' ' {
      let b = content[pos]
      if b < b'0' || b > b'7' {
        eprint_line("error: malformed mode in tree entry")
        @sys.exit(128)
      }
      pos += 1
    }
    if pos >= len || pos == mode_start {
      eprint_line("error: too-short tree object")
      @sys.exit(128)
    }
    // Check for leading zero in mode (e.g., "0100644" — git rejects modes
    // that start with an extra leading zero like "00644")
    let mode_len = pos - mode_start
    if mode_len > 1 && content[mode_start] == b'0' {
      eprint_line("error: malformed mode in tree entry")
      @sys.exit(128)
    }
    pos += 1 // skip space
    // Parse name (bytes until NUL)
    let name_start = pos
    while pos < len && content[pos] != b'\x00' {
      pos += 1
    }
    if pos >= len {
      eprint_line("error: too-short tree object")
      @sys.exit(128)
    }
    let name_len = pos - name_start
    if name_len == 0 {
      eprint_line("error: empty filename in tree entry")
      @sys.exit(128)
    }
    let name_buf = StringBuilder::new()
    for i in name_start..<pos {
      name_buf.write_char(content[i].to_int().unsafe_to_char())
    }
    let name = name_buf.to_string()
    if seen_names.contains(name) {
      eprint_line("error: duplicateEntries: contains duplicate file entries")
      @sys.exit(128)
    }
    seen_names[name] = true
    pos += 1 // skip NUL
    // Skip OID
    pos += oid_size
    if pos > len {
      eprint_line("error: too-short tree object")
      @sys.exit(128)
    }
  }
}
