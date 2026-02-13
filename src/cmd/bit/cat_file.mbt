///|
struct CatFilePathAttrs {
  eol_crlf : Bool
  diff_driver : String?
}

///|
async fn handle_cat_file(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let git_dir = resolve_git_dir(fs, root)
  let mut show_type = false
  let mut show_size = false
  let mut pretty_print = false
  let mut exists_check = false
  let mut filters_mode = false
  let mut textconv_mode = false
  let mut batch_mode = false
  let mut batch_check_mode = false
  let mut batch_all_objects_mode = false
  let mut batch_unordered = false
  let mut batch_format : String? = None
  let mut explicit_path : String? = None
  let positionals : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-t" => show_type = true
      "-s" => show_size = true
      "-p" => pretty_print = true
      "-e" => exists_check = true
      "--filters" => filters_mode = true
      "--textconv" => textconv_mode = true
      "--batch" => batch_mode = true
      "--batch-check" => {
        batch_mode = true
        batch_check_mode = true
      }
      "--batch-all-objects" => batch_all_objects_mode = true
      "--unordered" => batch_unordered = true
      "--path" if i + 1 < args.length() => {
        explicit_path = Some(args[i + 1])
        i += 2
        continue
      }
      _ if arg.has_prefix("--path=") =>
        explicit_path = Some(
          String::unsafe_substring(arg, start=7, end=arg.length()),
        )
      _ if arg.has_prefix("--batch=") => {
        batch_mode = true
        batch_format = Some(
          String::unsafe_substring(arg, start=8, end=arg.length()),
        )
      }
      _ if arg.has_prefix("--batch-check=") => {
        batch_mode = true
        batch_check_mode = true
        batch_format = Some(
          String::unsafe_substring(arg, start=14, end=arg.length()),
        )
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("cat-file", arg)
      _ => positionals.push(arg)
    }
    i += 1
  }
  let transform_mode = filters_mode || textconv_mode
  if explicit_path is Some(_) && !transform_mode {
    eprint_line("fatal: --path=<path> needs --filters or --textconv")
    @sys.exit(1)
  }
  if batch_mode {
    let dbs = cat_file_load_object_dbs(fs, git_dir)
    if batch_all_objects_mode {
      let object_dirs = cat_file_collect_object_dirs(fs, git_dir)
      for object_dir in object_dirs {
        if cat_file_validate_midx_large_offsets(fs, object_dir) {
          eprint_line("fatal: multi-pack-index large offset out of bounds")
          @sys.exit(1)
        }
      }
      let objects = cat_file_collect_batch_all_objects(
        fs, object_dirs, batch_unordered,
      )
      for o in objects {
        let id = o.id
        if batch_check_mode {
          print_line(cat_file_format_batch_check_line(batch_format, id, o))
          continue
        }
        let effective_path = explicit_path
        if transform_mode && effective_path is None {
          eprint_line("fatal: --textconv/--filters needs a path")
          @sys.exit(1)
        }
        let mut out = o.data
        if transform_mode {
          let path = effective_path.unwrap_or("")
          out = cat_file_apply_path_transforms(
            fs,
            git_dir,
            root,
            path,
            o.data,
            filters_mode,
            textconv_mode,
          )
        }
        print_line(
          id.to_hex() +
          " " +
          o.obj_type.to_string() +
          " " +
          o.data.length().to_string(),
        )
        @stdio.stdout.write(out)
        @stdio.stdout.write("\n")
      }
      return ()
    }
    let input = decode_bytes(read_all_stdin())
    let lines = input.split("\n")
    for line_view in lines {
      let raw_line = line_view.to_string()
      let line = trim_string(raw_line)
      if line.length() == 0 {
        continue
      }
      let mut spec = line
      let mut line_path : String? = None
      match line.find(" ") {
        Some(idx) => {
          spec = String::unsafe_substring(line, start=0, end=idx)
          let rest = trim_string(
            String::unsafe_substring(line, start=idx + 1, end=line.length()),
          )
          if rest.length() > 0 {
            line_path = Some(rest)
          }
        }
        None => ()
      }
      let effective_path = match line_path {
        Some(path) => Some(path)
        None =>
          match explicit_path {
            Some(path) => Some(path)
            None => cat_file_path_from_spec(spec)
          }
      }
      if transform_mode && effective_path is None {
        eprint_line("fatal: --textconv/--filters needs a path")
        @sys.exit(1)
      }
      let oid = @gitrepo.rev_parse(fs, git_dir, spec)
      guard oid is Some(id) else {
        print_line(spec + " missing")
        continue
      }
      let obj = cat_file_find_object_in_dbs(dbs, fs, id)
      guard obj is Some(o) else {
        print_line(spec + " missing")
        continue
      }
      if batch_check_mode {
        print_line(cat_file_format_batch_check_line(batch_format, id, o))
        continue
      }
      let mut out = o.data
      if transform_mode {
        let path = effective_path.unwrap_or("")
        out = cat_file_apply_path_transforms(
          fs,
          git_dir,
          root,
          path,
          o.data,
          filters_mode,
          textconv_mode,
        )
      }
      print_line(
        id.to_hex() +
        " " +
        o.obj_type.to_string() +
        " " +
        o.data.length().to_string(),
      )
      @stdio.stdout.write(out)
      @stdio.stdout.write("\n")
    }
    return ()
  }
  let mut expected_type : @git.ObjectType? = None
  let mut obj_spec : String? = None
  if not(show_type || show_size || pretty_print) && positionals.length() >= 2 {
    expected_type = Some(parse_object_type(positionals[0])) catch { _ => None }
    if expected_type is Some(_) {
      obj_spec = Some(positionals[1])
    }
  }
  if obj_spec is None && positionals.length() > 0 {
    obj_spec = Some(positionals[positionals.length() - 1])
  }
  guard obj_spec is Some(spec) else {
    raise @git.GitError::InvalidObject("object name required")
  }
  let effective_path = match explicit_path {
    Some(path) => Some(path)
    None => cat_file_path_from_spec(spec)
  }
  if transform_mode && effective_path is None {
    eprint_line("fatal: --textconv/--filters needs a path")
    @sys.exit(1)
  }
  let obj_id = @gitrepo.rev_parse(fs, git_dir, spec)
  let dbs = cat_file_load_object_dbs(fs, git_dir)
  let db = dbs[0]
  if exists_check {
    match obj_id {
      Some(oid) =>
        if cat_file_find_object_in_dbs(dbs, fs, oid) is Some(_) {
          return ()
        }
      None => ()
    }
    @sys.exit(1)
  }
  guard obj_id is Some(oid) else {
    raise @git.GitError::InvalidObject("Not a valid object name: \{spec}")
  }
  let obj = cat_file_find_object_in_dbs(dbs, fs, oid)
  guard obj is Some(o) else {
    raise @git.GitError::InvalidObject("Object not found: \{spec}")
  }
  if expected_type is Some(expected) {
    let data = peel_cat_file_object_to_type(db, fs, oid, expected) catch {
      _ => {
        guard o.obj_type == expected else {
          raise @git.GitError::InvalidObject(
            "object is of type \{o.obj_type.to_string()}, not \{expected.to_string()}",
          )
        }
        o.data
      }
    }
    @stdio.stdout.write(data)
    return ()
  }
  if show_type {
    print_line(o.obj_type.to_string())
    return ()
  }
  if show_size {
    print_line(o.data.length().to_string())
    return ()
  }
  if pretty_print {
    match o.obj_type {
      @git.ObjectType::Blob => @stdio.stdout.write(o.data)
      @git.ObjectType::Tree => {
        let entries = @git.parse_tree(o.data)
        for entry in entries {
          let mode_str = if entry.mode == "40000" {
            "040000"
          } else {
            entry.mode
          }
          let type_str = if entry.mode == "40000" { "tree" } else { "blob" }
          print_line(
            "\{mode_str} \{type_str} \{entry.id.to_hex()}\t\{entry.name}",
          )
        }
      }
      @git.ObjectType::Commit => {
        let text = decode_bytes(o.data)
        print_line(text)
      }
      @git.ObjectType::Tag => {
        let text = decode_bytes(o.data)
        print_line(text)
      }
    }
    return ()
  }
  if transform_mode {
    let path = effective_path.unwrap_or("")
    let out = cat_file_apply_path_transforms(
      fs,
      git_dir,
      root,
      path,
      o.data,
      filters_mode,
      textconv_mode,
    )
    @stdio.stdout.write(out)
    return ()
  }
  // Default: output raw content
  @stdio.stdout.write(o.data)
}

///|
fn cat_file_load_object_dbs(
  fs : OsFs,
  git_dir : String,
) -> Array[@gitlib.ObjectDb] {
  let out : Array[@gitlib.ObjectDb] = []
  let object_dirs = cat_file_collect_object_dirs(fs, git_dir)
  for object_dir in object_dirs {
    let alt_db = @gitlib.ObjectDb::load_from_objects_dir(fs, object_dir) catch {
      _ => continue
    }
    out.push(alt_db)
  }
  out
}

///|
fn cat_file_find_object_in_dbs(
  dbs : Array[@gitlib.ObjectDb],
  fs : OsFs,
  id : @git.ObjectId,
) -> @git.PackObject? raise Error {
  for db in dbs {
    let obj = db.get(fs, id)
    if obj is Some(o) {
      return Some(o)
    }
  }
  None
}

///|
fn cat_file_collect_batch_all_objects(
  fs : OsFs,
  object_dirs : Array[String],
  unordered : Bool,
) -> Array[@git.PackObject] {
  let by_id : Map[String, @git.PackObject] = {}
  for scan_object_dir in object_dirs {
    let objects = @gitlib.load_all_objects_from_object_dir(fs, scan_object_dir) catch {
      _ => []
    }
    for obj in objects {
      by_id[obj.id.to_hex()] = obj
    }
  }
  let ids : Array[String] = []
  for item in by_id.to_array() {
    let (hex, _) = item
    ids.push(hex)
  }
  if not(unordered) {
    ids.sort()
  }
  let out : Array[@git.PackObject] = []
  for hex in ids {
    match by_id.get(hex) {
      Some(obj) => out.push(obj)
      None => ()
    }
  }
  out
}

///|
fn cat_file_collect_object_dirs(fs : OsFs, git_dir : String) -> Array[String] {
  let primary_objects_dir = git_dir + "/objects"
  let out : Array[String] = [primary_objects_dir]
  let seen_object_dirs : Map[String, Bool] = {}
  seen_object_dirs[normalize_path(primary_objects_dir)] = true
  let alt_object_dirs = cat_file_read_alternate_object_dirs(fs, git_dir)
  for alt_object_dir in alt_object_dirs {
    let normalized = normalize_path(alt_object_dir)
    if seen_object_dirs.contains(normalized) {
      continue
    }
    seen_object_dirs[normalized] = true
    out.push(alt_object_dir)
  }
  out
}

///|
fn cat_file_read_alternate_object_dirs(
  fs : OsFs,
  git_dir : String,
) -> Array[String] {
  let out : Array[String] = []
  let alt_path = git_dir + "/objects/info/alternates"
  if not(fs.is_file(alt_path)) {
    return out
  }
  let data = fs.read_file(alt_path) catch { _ => return out }
  let base_dir = git_dir + "/objects/info"
  let seen : Map[String, Bool] = {}
  let text = decode_bytes(data)
  for line_view in text.split("\n") {
    let line = trim_string(line_view.to_string())
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let objects_dir = if line.has_prefix("/") {
      normalize_path(line)
    } else {
      normalize_path(base_dir + "/" + line)
    }
    if not(fs.is_dir(objects_dir)) {
      continue
    }
    if seen.contains(objects_dir) {
      continue
    }
    seen[objects_dir] = true
    out.push(objects_dir)
  }
  out
}

///|
fn cat_file_format_batch_check_line(
  format : String?,
  id : @git.ObjectId,
  obj : @git.PackObject,
) -> String {
  let mut out = match format {
    Some(fmt) if fmt.length() > 0 => fmt
    _ => "%(objectname) %(objecttype) %(objectsize)"
  }
  let id_hex = id.to_hex()
  let object_size = obj.data.length().to_string()
  let zero_oid = cat_file_zero_oid(id_hex.length())
  out = out.replace_all(old="%(objectname)", new=id_hex)
  out = out.replace_all(old="%(objecttype)", new=obj.obj_type.to_string())
  out = out.replace_all(old="%(objectsize:disk)", new=object_size)
  out = out.replace_all(old="%(objectsize)", new=object_size)
  out = out.replace_all(old="%(deltabase)", new=zero_oid)
  out
}

///|
fn cat_file_zero_oid(length : Int) -> String {
  let mut out = ""
  let mut i = 0
  while i < length {
    out = out + "0"
    i += 1
  }
  out
}

///|
fn cat_file_validate_midx_large_offsets(
  fs : OsFs,
  objects_dir : String,
) -> Bool {
  let midx_path = objects_dir + "/pack/multi-pack-index"
  if not(fs.is_file(midx_path)) {
    return false
  }
  let data = fs.read_file(midx_path) catch { _ => return false }
  if data.length() < 20 {
    return false
  }
  if data[0] != b'M' || data[1] != b'I' || data[2] != b'D' || data[3] != b'X' {
    return false
  }
  let num_chunks = data[6].to_int()
  if num_chunks <= 0 {
    return false
  }
  let table_size = 12 + (num_chunks + 1) * 12
  if table_size > data.length() {
    return false
  }
  let oidf_start = midx_find_chunk(data, num_chunks, "OIDF")
  let ooff_start = midx_find_chunk(data, num_chunks, "OOFF")
  let ooff_end = midx_find_chunk_end(data, num_chunks, "OOFF")
  if oidf_start <= 0 || ooff_start <= 0 || ooff_end <= ooff_start {
    return false
  }
  let fanout_end = oidf_start + 256 * 4
  if fanout_end > data.length() {
    return false
  }
  let object_count = midx_read_u32(data, oidf_start + 255 * 4)
  if object_count <= 0 {
    return false
  }
  let loff_start = midx_find_chunk(data, num_chunks, "LOFF")
  let loff_end = if loff_start > 0 {
    midx_find_chunk_end(data, num_chunks, "LOFF")
  } else {
    0
  }
  let max_objects = (ooff_end - ooff_start) / 8
  let limit = if object_count < max_objects {
    object_count
  } else {
    max_objects
  }
  let mut i = 0
  while i < limit {
    let entry_offset = ooff_start + i * 8
    if entry_offset + 8 > data.length() {
      break
    }
    let raw_offset = midx_read_u32(data, entry_offset + 4)
    if raw_offset < 0 {
      let large_idx = raw_offset & 2147483647
      if loff_start <= 0 {
        return true
      }
      let loff_pos = loff_start + large_idx * 8
      if loff_pos + 8 > loff_end || loff_pos + 8 > data.length() {
        return true
      }
    }
    i += 1
  }
  false
}

///|
fn cat_file_path_from_spec(spec : String) -> String? {
  match spec.find(":") {
    Some(idx) if idx + 1 < spec.length() =>
      Some(String::unsafe_substring(spec, start=idx + 1, end=spec.length()))
    _ => None
  }
}

///|
async fn cat_file_apply_path_transforms(
  fs : OsFs,
  git_dir : String,
  root : String,
  path : String,
  data : Bytes,
  filters_mode : Bool,
  textconv_mode : Bool,
) -> Bytes raise Error {
  let attrs = cat_file_read_path_attrs(fs, root, path)
  let mut out = if filters_mode || textconv_mode {
    if attrs.eol_crlf {
      cat_file_convert_lf_to_crlf(data)
    } else {
      data
    }
  } else {
    data
  }
  if textconv_mode {
    match attrs.diff_driver {
      Some(driver) => {
        let config_path = git_dir + "/config"
        let section = "diff \"" + driver + "\""
        match @gitlib.read_config_value(fs, config_path, section, "textconv") {
          Some(cmd) if trim_string(cmd).length() > 0 =>
            out = cat_file_run_textconv(fs, root, git_dir, cmd, out)
          _ => ()
        }
      }
      None => ()
    }
  }
  out
}

///|
async fn cat_file_run_textconv(
  fs : OsFs,
  root : String,
  git_dir : String,
  command : String,
  input : Bytes,
) -> Bytes raise Error {
  let temp_path = git_dir + "/bit-cat-file-textconv.tmp"
  fs.write_file(temp_path, input)
  let stdin = @process.redirect_from_file(temp_path) catch {
    err => {
      fs.remove_file(temp_path) catch {
        _ => ()
      }
      raise @git.GitError::IoError(err.to_string())
    }
  }
  let shell_cmd = cat_file_normalize_textconv_command(command)
  let (code, stdout) = @process.collect_stdout(
    "sh",
    ["-c", shell_cmd],
    inherit_env=true,
    stdin~,
    cwd=root,
  ) catch {
    err => {
      fs.remove_file(temp_path) catch {
        _ => ()
      }
      raise @git.GitError::IoError("textconv failed: \{err}")
    }
  }
  fs.remove_file(temp_path) catch {
    _ => ()
  }
  if code != 0 {
    raise @git.GitError::IoError("textconv failed with status \{code}")
  }
  let text = stdout.text() catch {
    err => raise @git.GitError::IoError(err.to_string())
  }
  cat_file_string_to_bytes(text)
}

///|
fn cat_file_normalize_textconv_command(command : String) -> String {
  let trimmed = trim_string(command)
  if trimmed.has_suffix("<") {
    let body = String::unsafe_substring(
      trimmed,
      start=0,
      end=trimmed.length() - 1,
    )
    trim_string(body)
  } else {
    trimmed
  }
}

///|
fn cat_file_read_path_attrs(
  fs : OsFs,
  root : String,
  path : String,
) -> CatFilePathAttrs {
  let normalized = if path.has_prefix("/") {
    String::unsafe_substring(path, start=1, end=path.length())
  } else if path.has_prefix("./") {
    String::unsafe_substring(path, start=2, end=path.length())
  } else {
    path
  }
  let mut eol_crlf = false
  let mut diff_driver : String? = None
  let attr_path = root + "/.gitattributes"
  if fs.is_file(attr_path) {
    let text = decode_bytes(
      fs.read_file(attr_path) catch {
        _ => Bytes::default()
      },
    )
    for line_view in text.split("\n") {
      let line = trim_string(line_view.to_string())
      if line.length() == 0 || line.has_prefix("#") {
        continue
      }
      let tokens = line.split(" ")
      let words : Array[String] = []
      for token_view in tokens {
        let token = trim_string(token_view.to_string())
        if token.length() > 0 {
          words.push(token)
        }
      }
      if words.length() < 2 {
        continue
      }
      if !cat_file_attr_pattern_matches(normalized, words[0]) {
        continue
      }
      let mut j = 1
      while j < words.length() {
        let token = words[j]
        if token.has_prefix("eol=") {
          let value = trim_string(
            String::unsafe_substring(token, start=4, end=token.length()),
          ).to_lower()
          eol_crlf = value == "crlf"
        } else if token.has_prefix("diff=") {
          let value = trim_string(
            String::unsafe_substring(token, start=5, end=token.length()),
          )
          if value.length() > 0 {
            diff_driver = Some(value)
          }
        }
        j += 1
      }
    }
  }
  { eol_crlf, diff_driver }
}

///|
fn cat_file_attr_pattern_matches(path : String, pattern : String) -> Bool {
  if pattern == path {
    return true
  }
  if pattern.has_prefix("*.") {
    return path.has_suffix(
      String::unsafe_substring(pattern, start=1, end=pattern.length()),
    )
  }
  match pattern.find("*") {
    Some(idx) => {
      let prefix = String::unsafe_substring(pattern, start=0, end=idx)
      let suffix = String::unsafe_substring(
        pattern,
        start=idx + 1,
        end=pattern.length(),
      )
      path.has_prefix(prefix) &&
      path.has_suffix(suffix) &&
      path.length() >= prefix.length() + suffix.length()
    }
    None => false
  }
}

///|
fn cat_file_convert_lf_to_crlf(data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  while i < data.length() {
    let b = data[i]
    if b == b'\n' && (i == 0 || data[i - 1] != b'\r') {
      out.push(b'\r')
      out.push(b'\n')
    } else {
      out.push(b)
    }
    i += 1
  }
  Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] }))
}

///|
fn cat_file_string_to_bytes(s : String) -> Bytes {
  Bytes::from_array(FixedArray::makei(s.length(), fn(i) { s[i].to_byte() }))
}

///|
