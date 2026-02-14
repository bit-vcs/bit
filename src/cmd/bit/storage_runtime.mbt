///|
pub async fn run_storage_command(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  cmd : String,
  args : Array[String],
) -> Unit raise Error {
  match cmd {
    "init" => storage_handle_init(fs, rfs, root, args)
    "add" => storage_handle_add(fs, rfs, root, args)
    "commit" => storage_handle_commit(fs, rfs, root, args)
    "status" => storage_handle_status(rfs, root, args)
    "log" => storage_handle_log(rfs, root, args)
    "hash-object" => storage_handle_hash_object(fs, rfs, root, args)
    "write-tree" => storage_handle_write_tree(fs, rfs, root, args)
    "update-ref" => storage_handle_update_ref(fs, rfs, root, args)
    _ =>
      raise @git.GitError::InvalidObject("unsupported storage command: " + cmd)
  }
}

///|
fn storage_fail_unsupported_option(
  cmd : String,
  arg : String,
) -> Unit raise Error {
  raise @git.GitError::InvalidObject(
    cmd + ": option is not supported in storage runtime: " + arg,
  )
}

///|
fn storage_fail_unsupported_mode(
  cmd : String,
  detail : String,
) -> Unit raise Error {
  raise @git.GitError::InvalidObject(
    cmd + ": mode is not supported in storage runtime: " + detail,
  )
}

///|
fn storage_runtime_is_quiet() -> Bool {
  match @sys.get_env_var("BIT_STORAGE_RUNTIME_QUIET") {
    Some(value) => {
      let normalized = trim_string(value).to_lower()
      normalized == "1" || normalized == "true" || normalized == "yes"
    }
    None => false
  }
}

///|
async fn storage_print_line(text : String) -> Unit {
  if storage_runtime_is_quiet() {
    return
  }
  print_line(text)
}

///|
async fn storage_print_str(text : String) -> Unit {
  if storage_runtime_is_quiet() {
    return
  }
  print_str(text)
}

///|
fn storage_require_sha1_repo(
  cmd : String,
  rfs : &@git.RepoFileSystem,
  git_dir : String,
) -> Unit raise Error {
  if repo_object_format(rfs, git_dir) != "sha1" {
    storage_fail_unsupported_mode(cmd, "repository object format")
  }
  match repo_compat_object_format(rfs, git_dir) {
    Some(format) =>
      if format != "sha1" {
        storage_fail_unsupported_mode(cmd, "compatObjectFormat")
      }
    None => ()
  }
}

///|
async fn storage_handle_init(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  args : Array[String],
) -> Unit raise Error {
  let mut quiet = false
  let mut initial_branch : String? = None
  let mut ref_format = "files"
  let mut object_format = "sha1"
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-q" | "--quiet" => quiet = true
      "-b" if i + 1 < args.length() => {
        initial_branch = Some(args[i + 1])
        i += 2
        continue
      }
      "--initial-branch" if i + 1 < args.length() => {
        initial_branch = Some(args[i + 1])
        i += 2
        continue
      }
      "--ref-format" if i + 1 < args.length() => {
        let value = args[i + 1].to_lower()
        if value != "files" {
          storage_fail_unsupported_mode("init", "--ref-format=" + value)
        }
        ref_format = value
        i += 2
        continue
      }
      "--object-format" if i + 1 < args.length() => {
        let value = args[i + 1].to_lower()
        if value != "sha1" {
          storage_fail_unsupported_mode("init", "--object-format=" + value)
        }
        object_format = value
        i += 2
        continue
      }
      _ if arg.has_prefix("--initial-branch=") =>
        initial_branch = Some((try! arg[17:]).to_string())
      _ if arg.has_prefix("--ref-format=") => {
        let value = (try! arg[13:]).to_string().to_lower()
        if value != "files" {
          storage_fail_unsupported_mode("init", "--ref-format=" + value)
        }
        ref_format = value
      }
      _ if arg.has_prefix("--object-format=") => {
        let value = (try! arg[16:]).to_string().to_lower()
        if value != "sha1" {
          storage_fail_unsupported_mode("init", "--object-format=" + value)
        }
        object_format = value
      }
      _ if arg.has_prefix("-") => storage_fail_unsupported_option("init", arg)
      _ => storage_fail_unsupported_mode("init", "directory argument")
    }
    i += 1
  }
  let opts : @gitlib.InitOptions = {
    default_branch: initial_branch.unwrap_or("main"),
    bare: false,
    separate_git_dir: None,
    template_dir: None,
    ref_format,
    object_format,
  }
  @gitrepo.init_repo_with_options(fs, root, opts)
  if not(quiet) {
    let git_dir = resolve_git_dir(rfs, root)
    storage_print_line("Initialized empty Git repository in " + git_dir + "/")
  }
}

///|
async fn storage_handle_add(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  args : Array[String],
) -> Unit raise Error {
  let git_dir = resolve_git_dir(rfs, root)
  storage_require_sha1_repo("add", rfs, git_dir)
  let mut add_all = false
  let mut end_of_options = false
  let paths : Array[String] = []
  for arg in args {
    if not(end_of_options) && arg == "--" {
      end_of_options = true
      continue
    }
    match arg {
      "-A" | "--all" if not(end_of_options) => add_all = true
      _ if end_of_options || not(arg.has_prefix("-")) => paths.push(arg)
      _ if arg.has_prefix("-") => storage_fail_unsupported_option("add", arg)
      _ => ()
    }
  }
  if add_all {
    let status = @gitlib.status(rfs, root)
    let all_paths : Array[String] = []
    for p in status.untracked {
      all_paths.push(p)
    }
    for p in status.unstaged_modified {
      all_paths.push(p)
    }
    for p in status.unstaged_deleted {
      all_paths.push(p)
    }
    if all_paths.length() > 0 {
      @gitlib.add_paths_async(fs, rfs, root, all_paths)
    }
    return
  }
  if paths.length() == 0 {
    raise @git.GitError::InvalidObject("add requires pathspec")
  }
  @gitlib.add_paths_async(fs, rfs, root, paths)
}

///|
async fn storage_handle_commit(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  args : Array[String],
) -> Unit raise Error {
  let git_dir = resolve_git_dir(rfs, root)
  storage_require_sha1_repo("commit", rfs, git_dir)
  let mut message : String? = None
  let mut all_modified = false
  let mut allow_empty = false
  let mut quiet = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-m" if i + 1 < args.length() => {
        message = Some(args[i + 1])
        i += 2
        continue
      }
      "--message" if i + 1 < args.length() => {
        message = Some(args[i + 1])
        i += 2
        continue
      }
      "-am" | "-ma" if i + 1 < args.length() => {
        all_modified = true
        message = Some(args[i + 1])
        i += 2
        continue
      }
      _ if arg.has_prefix("-m") && arg.length() > 2 => {
        message = Some((try! arg[2:]).to_string())
        i += 1
        continue
      }
      _ if arg.has_prefix("-am") || arg.has_prefix("-ma") => {
        all_modified = true
        message = Some((try! arg[3:]).to_string())
        i += 1
        continue
      }
      _ if arg.has_prefix("--message=") => {
        message = Some((try! arg[10:]).to_string())
        i += 1
        continue
      }
      "-a" | "--all" => all_modified = true
      "--allow-empty" => allow_empty = true
      "-q" | "--quiet" => quiet = true
      "--no-verify" => ()
      _ if arg.has_prefix("-") => storage_fail_unsupported_option("commit", arg)
      _ => storage_fail_unsupported_mode("commit", "positional arguments")
    }
    i += 1
  }
  guard message is Some(msg) else {
    raise @git.GitError::InvalidObject(
      "storage runtime commit requires -m/--message",
    )
  }
  if all_modified {
    let status = @gitlib.status(rfs, root)
    let paths_to_add : Array[String] = []
    for p in status.unstaged_modified {
      paths_to_add.push(p)
    }
    for p in status.unstaged_deleted {
      paths_to_add.push(p)
    }
    if paths_to_add.length() > 0 {
      @gitlib.add_paths_async(fs, rfs, root, paths_to_add)
    }
  }
  let timestamp = get_commit_timestamp()
  let committer = get_committer_string()
  let committer_timestamp = timestamp
  let commit_id = @gitlib.commit(
    fs,
    rfs,
    root,
    msg,
    get_author_string(),
    timestamp,
    committer~,
    committer_timestamp~,
    allow_empty~,
  )
  if not(quiet) {
    let short_id = (try! commit_id.to_hex()[:7]).to_string()
    let first_line = match msg.find("\n") {
      Some(idx) => (try! msg[:idx]).to_string()
      None => msg
    }
    storage_print_line("[" + short_id + "] " + first_line)
  }
}

///|
async fn storage_handle_status(
  rfs : &@git.RepoFileSystem,
  root : String,
  args : Array[String],
) -> Unit raise Error {
  let mut porcelain = false
  let mut short = false
  let mut show_branch = false
  for arg in args {
    match arg {
      "--porcelain" | "--porcelain=v1" => porcelain = true
      "-s" | "--short" => short = true
      "-b" | "--branch" => show_branch = true
      "-sb" => {
        short = true
        show_branch = true
      }
      _ if arg.has_prefix("-") => storage_fail_unsupported_option("status", arg)
      _ => storage_fail_unsupported_mode("status", "pathspec")
    }
  }
  let git_dir = resolve_git_dir(rfs, root)
  if porcelain || short {
    if show_branch {
      let head = @gitlib.read_head_ref(rfs, git_dir)
      match head {
        @gitlib.HeadRef::Branch(name) => storage_print_line("## " + name)
        @gitlib.HeadRef::Detached(id) =>
          storage_print_line(
            "## HEAD (detached at \{id.to_hex()[:7].to_string()})",
          )
      }
    }
    let lines = @gitlib.status_porcelain(rfs, root)
    for line in lines {
      storage_print_line(line)
    }
    return
  }
  let text = @gitlib.status_text(rfs, root)
  storage_print_str(text)
}

///|
async fn storage_handle_log(
  rfs : &@git.RepoFileSystem,
  root : String,
  args : Array[String],
) -> Unit raise Error {
  let mut oneline = false
  let mut max_count = 10
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--oneline" => oneline = true
      "-n" if i + 1 < args.length() => {
        max_count = @strconv.parse_int(args[i + 1])
        i += 2
        continue
      }
      "--max-count" if i + 1 < args.length() => {
        max_count = @strconv.parse_int(args[i + 1])
        i += 2
        continue
      }
      _ if arg.has_prefix("-n") && arg.length() > 2 =>
        max_count = @strconv.parse_int((try! arg[2:]).to_string())
      _ if is_short_count_flag(arg) => {
        let num_str = String::unsafe_substring(arg, start=1, end=arg.length())
        max_count = @strconv.parse_int(num_str)
      }
      _ if arg.has_prefix("--max-count=") =>
        max_count = @strconv.parse_int((try! arg[12:]).to_string())
      _ if arg.has_prefix("-") => storage_fail_unsupported_option("log", arg)
      _ => storage_fail_unsupported_mode("log", "revision arguments")
    }
    i += 1
  }
  let git_dir = resolve_git_dir(rfs, root)
  if oneline {
    let lines = @gitlib.log_head_oneline(rfs, git_dir, max_count~)
    for line in lines {
      storage_print_line(line)
    }
    return
  }
  let entries = @gitlib.log_head(rfs, git_dir, max_count~)
  for entry in entries {
    storage_print_line("commit " + entry.id.to_hex())
    storage_print_line("Author: " + entry.author)
    storage_print_line("")
    storage_print_line("    " + entry.message)
    storage_print_line("")
  }
}

///|
async fn storage_handle_hash_object(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  args : Array[String],
) -> Unit raise Error {
  let mut write_object = false
  let mut stdin_mode = false
  let mut obj_type = "blob"
  let paths : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-w" => write_object = true
      "--stdin" => stdin_mode = true
      "--literally" => ()
      "-t" if i + 1 < args.length() => {
        obj_type = args[i + 1]
        i += 2
        continue
      }
      _ if arg.has_prefix("-t") && arg.length() > 2 =>
        obj_type = String::unsafe_substring(arg, start=2, end=arg.length())
      _ if not(arg.has_prefix("-")) => paths.push(arg)
      _ => storage_fail_unsupported_option("hash-object", arg)
    }
    i += 1
  }
  let git_dir = if write_object {
    resolve_git_dir(rfs, root)
  } else {
    root + "/.git"
  }
  let compat_object_format = storage_read_compat_object_format(rfs, git_dir)
  if hash_object_requires_standalone_error(write_object, compat_object_format) {
    storage_fail_unsupported_mode(
      "hash-object", "-w with compatObjectFormat=sha256",
    )
  }
  if stdin_mode {
    let content = read_all_stdin()
    let id = @git.hash_object_content(parse_object_type(obj_type), content)
    if write_object {
      ignore(
        @gitlib.write_loose_object(
          fs,
          git_dir,
          parse_object_type(obj_type),
          content,
        ),
      )
    }
    storage_print_line(id.to_hex())
    return
  }
  for path in paths {
    let abs = if path.has_prefix("/") { path } else { root + "/" + path }
    let content = rfs.read_file(abs)
    let id = @git.hash_object_content(parse_object_type(obj_type), content)
    if write_object {
      ignore(
        @gitlib.write_loose_object(
          fs,
          git_dir,
          parse_object_type(obj_type),
          content,
        ),
      )
    }
    storage_print_line(id.to_hex())
  }
}

///|
fn storage_read_compat_object_format(
  rfs : &@git.RepoFileSystem,
  git_dir : String,
) -> String? {
  let overrides = @gitlib.parse_config_overrides()
  match overrides.get("extensions.compatobjectformat") {
    Some(value) => Some(value)
    None =>
      @gitlib.read_config_value(
        rfs,
        git_dir + "/config",
        "extensions",
        "compatobjectformat",
      )
  }
}

///|
async fn storage_handle_write_tree(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  args : Array[String],
) -> Unit raise Error {
  let git_dir = resolve_git_dir(rfs, root)
  storage_require_sha1_repo("write-tree", rfs, git_dir)
  let mut prefix : String? = None
  for arg in args {
    if arg.has_prefix("--prefix=") {
      prefix = Some((try! arg[9:]).to_string())
      continue
    }
    if arg.has_prefix("-") {
      storage_fail_unsupported_option("write-tree", arg)
    }
    storage_fail_unsupported_mode("write-tree", "path arguments")
  }
  let entries = @gitlib.read_index_entries(rfs, git_dir)
  let tree_id = @gitlib.write_tree_from_index(fs, git_dir, entries, prefix~)
  storage_print_line(tree_id.to_hex())
}

///|
async fn storage_handle_update_ref(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  root : String,
  args : Array[String],
) -> Unit raise Error {
  let git_dir = resolve_git_dir(rfs, root)
  if is_reftable_repo(rfs, git_dir) {
    storage_fail_unsupported_mode("update-ref", "reftable repository")
  }
  let mut delete_mode = false
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "-d" | "--delete" => delete_mode = true
      _ if not(arg.has_prefix("-")) => positional.push(arg)
      _ => storage_fail_unsupported_option("update-ref", arg)
    }
  }
  if delete_mode {
    guard positional.length() >= 1 else {
      raise @git.GitError::InvalidObject(
        "usage: update-ref -d <refname> [<oldvalue>]",
      )
    }
    let refname = positional[0]
    let old_value : String? = if positional.length() >= 2 {
      Some(positional[1])
    } else {
      None
    }
    storage_verify_old_ref_value(rfs, git_dir, refname, old_value)
    let ref_path = git_dir + "/" + refname
    if rfs.is_file(ref_path) {
      fs.remove_file(ref_path)
    }
    return
  }
  guard positional.length() >= 2 else {
    raise @git.GitError::InvalidObject(
      "usage: update-ref <refname> <newvalue> [<oldvalue>]",
    )
  }
  let refname = positional[0]
  let new_value = if positional[1] == "@" { "HEAD" } else { positional[1] }
  let old_value : String? = if positional.length() >= 3 {
    Some(positional[2])
  } else {
    None
  }
  storage_verify_old_ref_value(rfs, git_dir, refname, old_value)
  let new_id = storage_resolve_object_id(rfs, git_dir, new_value)
  let ref_path = git_dir + "/" + refname
  let dir = parent_dir(ref_path)
  if dir.length() > 0 && not(rfs.is_dir(dir)) {
    fs.mkdir_p(dir)
  }
  fs.write_string(ref_path, new_id.to_hex() + "\n")
}

///|
fn storage_verify_old_ref_value(
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  refname : String,
  old_value : String?,
) -> Unit raise Error {
  match old_value {
    Some(expected_hex) => {
      let expected = @git.ObjectId::from_hex(expected_hex)
      let current = read_ref_value(rfs, git_dir, refname)
      match current {
        Some(cur_id) =>
          if cur_id.to_hex() != expected.to_hex() {
            raise @git.GitError::InvalidObject(
              "update-ref oldvalue mismatch for " + refname,
            )
          }
        None =>
          if expected.to_hex() != @git.ObjectId::zero().to_hex() {
            raise @git.GitError::InvalidObject(
              "update-ref expected existing ref: " + refname,
            )
          }
      }
    }
    None => ()
  }
}

///|
fn storage_resolve_object_id(
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  spec : String,
) -> @git.ObjectId raise Error {
  @git.ObjectId::from_hex(spec) catch {
    _ =>
      match @gitrepo.rev_parse(rfs, git_dir, spec) {
        Some(id) => id
        None => raise @git.GitError::InvalidObject("unknown revision: " + spec)
      }
  }
}
