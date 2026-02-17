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
    @runtime.StorageCommand::HashObject(hash_args) =>
      if hash_args.stdin_mode || hash_args.obj_type != @bitcore.ObjectType::Blob {
        None
      } else {
        Some(hash_args)
      }
    _ => None
  }
}

///|
fn hash_object_need_real_git(_args : Array[String]) -> Bool {
  let root = get_work_root()
  if hash_object_need_real_git_for_filtering(root) {
    return true
  }
  false
}

///|
fn hash_object_need_real_git_for_filtering(root : String) -> Bool {
  hash_object_need_real_git_for_autocrlf(root) ||
  hash_object_need_real_git_for_gitattributes(root)
}

///|
fn hash_object_need_real_git_for_autocrlf(root : String) -> Bool {
  let fs = OsFs::new()
  let git_dir = resolve_git_dir(fs, root)
  match @bitlib.read_config_value(fs, git_dir + "/config", "core", "autocrlf") {
    Some(value) =>
      match @bitlib.config_strip_quotes(value).to_lower() {
        "true" => true
        "input" => true
        "false" => false
        _ => true
      }
    None => false
  }
}

///|
fn hash_object_need_real_git_for_gitattributes(root : String) -> Bool {
  let fs = OsFs::new()
  let attr_path = root + "/.gitattributes"
  if not(fs.is_file(attr_path)) {
    return false
  }
  let content = decode_bytes(
    fs.read_file(attr_path) catch {
      _ => Bytes::default()
    },
  )
  for line_view in content.split("\n") {
    let line = trim_string(line_view.to_string())
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    for token_view in line.split(" ") {
      let token = trim_string(token_view.to_string())
      if token.length() == 0 {
        continue
      }
      if token == "crlf" ||
        token == "-crlf" ||
        token == "text" ||
        token == "-text" ||
        token == "eol" ||
        token == "filter" ||
        token.has_prefix("eol=") ||
        token.has_prefix("text=") ||
        token.has_prefix("filter=") ||
        token.has_prefix("working-tree-encoding=") {
        return true
      }
    }
  }
  false
}

///|
fn hash_object_should_use_storage_runtime(args : Array[String]) -> Bool {
  hash_object_storage_runtime_delegate_args(args) is Some(_)
}

///|
fn hash_object_real_git_binary() -> String {
  match @sys.get_env_var("SHIM_REAL_GIT") {
    Some(path) if path.length() > 0 => path
    _ =>
      match @sys.get_env_var("GIT_SHIM_REAL_GIT") {
        Some(path) if path.length() > 0 => path
        _ => "git"
      }
  }
}

///|
async fn hash_object_run_real_git(args : Array[String]) -> Unit raise Error {
  let real_args : Array[String] = ["hash-object"]
  for arg in args {
    real_args.push(arg)
  }
  let real_git = hash_object_real_git_binary()
  let code = @process.run(real_git, real_args, inherit_env=true) catch {
    err => {
      eprint_line(err.to_string())
      1
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}

///|
async fn handle_hash_object(args : Array[String]) -> Unit raise Error {
  if hash_object_should_use_storage_runtime(args) {
    match hash_object_storage_runtime_delegate_args(args) {
      Some(hash_args) => {
        let root = get_work_root()
        let fs = OsFs::new()
        @runtime.run_storage_command(
          fs,
          fs,
          root,
          @runtime.StorageCommand::HashObject(hash_args),
        )
        return
      }
      None => ()
    }
  }
  ignore(hash_object_run_real_git(args))
}
