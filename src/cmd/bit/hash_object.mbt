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
          !hash_args.no_filters {
          let autocrlf = @bitlib.read_autocrlf_setting(rfs, git_dir)
          let attrs = @bitlib.resolve_eol_attrs(rfs, root, resolved_path_hint)
          @bitlib.clean_for_storage(raw_content, attrs, autocrlf)
        } else {
          raw_content
        }
        if !hash_args.literally {
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
      if !hash_args.stdin_mode &&
        !hash_args.stdin_paths &&
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
    if !hash_args.literally {
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
    let line = line_view.to_owned()
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
    @bitcore.ObjectType::Commit => hash_object_validate_commit(content, algo)
    @bitcore.ObjectType::Tag => hash_object_validate_tag(content, algo)
    @bitcore.ObjectType::Tree => hash_object_validate_tree(content, algo)
    _ => ()
  }
}

///| Walk a hash-id line ("tree <hex>\n", "parent <hex>\n", ...) and
/// emit a fsck-compatible error token on each well-defined failure
/// mode. Returns the byte index after the consumed line (one past
/// the trailing newline) on success. Test contract: `t1451`.
async fn hash_object_check_id_line(
  content : Bytes,
  start : Int,
  prefix : String,
  missing_token : String,
  bad_sha_token : String,
  algo : @bitobject.HashAlgorithm,
) -> Int {
  let len = content.length()
  // Does the buffer have enough room for "prefix"?
  for i in 0..<prefix.length() {
    let p = start + i
    if p >= len || content[p].to_int() != prefix.unsafe_get(i).to_int() {
      eprint_line("error: \{missing_token}: ...")
      @sys.exit(128)
    }
  }
  let after_prefix = start + prefix.length()
  // Need at least 2*hash_size hex chars + newline.
  let hex_len = algo.hash_size() * 2
  if after_prefix + hex_len > len {
    eprint_line("error: \{bad_sha_token}: invalid hash")
    @sys.exit(128)
  }
  for i in 0..<hex_len {
    let b = content[after_prefix + i]
    let c = b.to_int()
    let is_hex = (c >= 0x30 && c <= 0x39) || // 0-9
      (c >= 0x61 && c <= 0x66) || // a-f
      (c >= 0x41 && c <= 0x46) // A-F
    if !is_hex {
      eprint_line("error: \{bad_sha_token}: invalid hash")
      @sys.exit(128)
    }
  }
  let after_hex = after_prefix + hex_len
  // Optional trailing newline.
  if after_hex < len && content[after_hex] == b'\n' {
    after_hex + 1
  } else {
    after_hex
  }
}

///| ident line shape: "<name> <<email>> <ts> <tz>\n".  Mirrors
/// git's fsck token set: missingEmail / badEmail /
/// missingSpaceBeforeDate / badDate / badTimezone.
async fn hash_object_check_ident_line(
  content : Bytes,
  start : Int,
  prefix : String, // "author " or "committer " or "tagger "
) -> Int {
  let len = content.length()
  if start + prefix.length() > len {
    eprint_line("error: missingEmail: ident missing")
    @sys.exit(128)
  }
  // After the prefix, scan for '<'. If we hit newline or EOF first
  // → missingEmail.
  let mut pos = start + prefix.length()
  while pos < len && content[pos] != b'<' && content[pos] != b'\n' {
    pos += 1
  }
  if pos >= len || content[pos] == b'\n' {
    eprint_line("error: missingEmail: missing email in ident")
    @sys.exit(128)
  }
  // pos sits on '<'. Find matching '>'.
  pos += 1
  let email_start = pos
  while pos < len && content[pos] != b'>' && content[pos] != b'\n' {
    pos += 1
  }
  if pos >= len || content[pos] == b'\n' {
    eprint_line("error: badEmail: unterminated email")
    @sys.exit(128)
  }
  let _ = email_start
  // pos sits on '>'. Need space-then-date.
  pos += 1
  if pos >= len || content[pos] == b'\n' {
    eprint_line("error: missingSpaceBeforeDate: ident has no date")
    @sys.exit(128)
  }
  if content[pos] != b' ' {
    eprint_line("error: missingSpaceBeforeDate: ident has no space before date")
    @sys.exit(128)
  }
  pos += 1
  // Date: one-or-more digits. Then space. Then tz.
  let date_start = pos
  while pos < len && content[pos] != b' ' && content[pos] != b'\n' {
    let b = content[pos]
    if b < b'0' || b > b'9' {
      eprint_line("error: badDate: invalid date")
      @sys.exit(128)
    }
    pos += 1
  }
  if pos == date_start {
    eprint_line("error: badDate: empty date")
    @sys.exit(128)
  }
  if pos >= len || content[pos] == b'\n' {
    eprint_line("error: badDate: no space before timezone")
    @sys.exit(128)
  }
  pos += 1 // consume the space
  // Timezone: optional sign then 4 digits.
  if pos >= len || content[pos] == b'\n' {
    eprint_line("error: badTimezone: missing timezone")
    @sys.exit(128)
  }
  if content[pos] == b'+' || content[pos] == b'-' {
    pos += 1
  }
  let tz_digits_start = pos
  while pos < len && content[pos] != b'\n' {
    let b = content[pos]
    if b < b'0' || b > b'9' {
      eprint_line("error: badTimezone: invalid timezone digit")
      @sys.exit(128)
    }
    pos += 1
  }
  if pos - tz_digits_start < 4 {
    eprint_line("error: badTimezone: short timezone")
    @sys.exit(128)
  }
  // Skip trailing newline if present.
  if pos < len && content[pos] == b'\n' {
    pos + 1
  } else {
    pos
  }
}

///| Commit object validator. Walks the header fields in order:
///   tree <hex>\n
///   (parent <hex>\n)*
///   author <ident>\n
///   committer <ident>\n
///   ...body...
async fn hash_object_validate_commit(
  content : Bytes,
  algo : @bitobject.HashAlgorithm,
) -> Unit {
  let len = content.length()
  // Tree
  if len < 5 || !hash_object_bytes_have_prefix(content, 0, "tree ") {
    eprint_line("error: missingTree: invalid commit object")
    @sys.exit(128)
  }
  let mut pos = hash_object_check_id_line(
    content, 0, "tree ", "missingTree", "badTreeSha1", algo,
  )
  // Parents (zero or more)
  while pos < len && hash_object_bytes_have_prefix(content, pos, "parent ") {
    pos = hash_object_check_id_line(
      content, pos, "parent ", "missingAuthor", "badParentSha1", algo,
    )
  }
  // Author: required
  if !hash_object_bytes_have_prefix(content, pos, "author ") {
    eprint_line("error: missingAuthor: commit is missing author")
    @sys.exit(128)
  }
  pos = hash_object_check_ident_line(content, pos, "author ")
  // Committer: required
  if !hash_object_bytes_have_prefix(content, pos, "committer ") {
    eprint_line("error: missingCommitter: commit is missing committer")
    @sys.exit(128)
  }
  pos = hash_object_check_ident_line(content, pos, "committer ")
  let _ = pos
  // Anything after committer is the (optional) header tail and
  // commit message.  Git's fsck does not require any further
  // structure here.
}

///| Tag object validator. Same approach as commit but the header
/// set differs.
async fn hash_object_validate_tag(
  content : Bytes,
  algo : @bitobject.HashAlgorithm,
) -> Unit {
  let len = content.length()
  if !hash_object_bytes_have_prefix(content, 0, "object ") {
    eprint_line("error: missingObject: tag is missing object")
    @sys.exit(128)
  }
  let mut pos = hash_object_check_id_line(
    content, 0, "object ", "missingObject", "badObjectSha1", algo,
  )
  // type <name>\n
  if !hash_object_bytes_have_prefix(content, pos, "type ") {
    eprint_line("error: missingType: tag is missing type")
    @sys.exit(128)
  }
  pos += 5
  let type_start = pos
  while pos < len && content[pos] != b'\n' {
    pos += 1
  }
  let type_len = pos - type_start
  if type_len == 0 {
    eprint_line("error: badType: empty type")
    @sys.exit(128)
  }
  let type_buf = StringBuilder::new()
  for i in type_start..<(type_start + type_len) {
    type_buf.write_char(content[i].to_int().unsafe_to_char())
  }
  let type_str = type_buf.to_string()
  if type_str != "commit" &&
    type_str != "tree" &&
    type_str != "blob" &&
    type_str != "tag" {
    eprint_line("error: badType: invalid type '\{type_str}'")
    @sys.exit(128)
  }
  if pos >= len {
    eprint_line("error: missingTagEntry: tag is missing tag entry")
    @sys.exit(128)
  }
  pos += 1 // skip newline
  // tag <name>\n
  if !hash_object_bytes_have_prefix(content, pos, "tag ") {
    eprint_line("error: missingTagEntry: tag is missing tag entry")
    @sys.exit(128)
  }
  pos += 4
  let name_start = pos
  while pos < len && content[pos] != b'\n' {
    pos += 1
  }
  if pos == name_start {
    eprint_line("error: badTagName: empty tag name")
    @sys.exit(128)
  }
  if pos < len {
    pos += 1
  }
  // tagger <ident>\n
  if !hash_object_bytes_have_prefix(content, pos, "tagger ") {
    eprint_line("error: missingTagger: tag is missing tagger")
    @sys.exit(128)
  }
  pos = hash_object_check_ident_line(content, pos, "tagger ")
  let _ = pos
}

///| Byte-level prefix match — `String::has_prefix` only works on
/// `String`, and lossy-decoding short / truncated input first
/// risks losing information needed by the validator.
fn hash_object_bytes_have_prefix(
  content : Bytes,
  start : Int,
  prefix : String,
) -> Bool {
  if start + prefix.length() > content.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if content[start + i].to_int() != prefix.unsafe_get(i).to_int() {
      return false
    }
  }
  true
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
    eprint_line("error: badTree: too-short tree object")
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
        eprint_line("error: badTree: malformed mode in tree entry")
        @sys.exit(128)
      }
      pos += 1
    }
    if pos >= len || pos == mode_start {
      eprint_line("error: badTree: tree object truncated")
      @sys.exit(128)
    }
    // Check for leading zero in mode (e.g., "0100644" — git rejects modes
    // that start with an extra leading zero like "00644")
    let mode_len = pos - mode_start
    if mode_len > 1 && content[mode_start] == b'0' {
      eprint_line("error: badTree: malformed mode in tree entry")
      @sys.exit(128)
    }
    pos += 1 // skip space
    // Parse name (bytes until NUL)
    let name_start = pos
    while pos < len && content[pos] != b'\x00' {
      pos += 1
    }
    if pos >= len {
      // Walked off the end without finding NUL — classic "missing nul"
      // truncation. Test t1451 grep's for badTree here.
      eprint_line("error: badTree: missing nul in tree entry")
      @sys.exit(128)
    }
    let name_len = pos - name_start
    if name_len == 0 {
      eprint_line("error: badTree: empty filename in tree entry")
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
    // Need oid_size bytes of OID.
    if pos + oid_size > len {
      eprint_line("error: badTree: tree entry has short hash")
      @sys.exit(128)
    }
    pos += oid_size
  }
}
