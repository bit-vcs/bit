///|
pub struct OsFs {
  dummy : Int
}

///|
pub fn OsFs::new() -> OsFs {
  { dummy: 0 }
}

///|
fn io_error(err : @fs.IOError) -> @git.GitError {
  @git.GitError::IoError(err.to_string())
}

///|
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), fn(i) { arr[i] }))
}

///|
fn str_to_bytes(s : String) -> Bytes {
  let arr : Array[Byte] = []
  for c in s {
    arr.push(c.to_int().to_byte())
  }
  bytes_from_array(arr)
}

///|
async fn print_line(s : String) -> Unit {
  @stdio.stdout.write(str_to_bytes(s + "\n"))
}

///|
async fn print_str(s : String) -> Unit {
  @stdio.stdout.write(str_to_bytes(s))
}

///|
async fn eprint_line(s : String) -> Unit {
  @stdio.stderr.write(str_to_bytes(s + "\n"))
}

///|
fn parent_dir(path : String) -> String {
  if path.length() == 0 || path == "/" {
    return "/"
  }
  let sep = @path.sep.to_string()
  match path.rev_find(sep) {
    None => ""
    Some(idx) => if idx == 0 { sep } else { (try! path[:idx]).to_string() }
  }
}

///|
fn ensure_dir(path : String) -> Unit raise @git.GitError {
  if path.length() == 0 || path == "/" || path == "." {
    return ()
  }
  if @fs.path_exists(path) {
    let is_dir = @fs.is_dir(path) catch { _ => false }
    if is_dir {
      return ()
    }
    raise @git.GitError::IoError("path exists and is not dir: " + path)
  }
  let parent = parent_dir(path)
  if parent.length() > 0 && parent != path {
    ensure_dir(parent)
  }
  @fs.create_dir(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.FileSystem for OsFs with mkdir_p(_self, path) {
  ensure_dir(path)
}

///|
pub impl @git.FileSystem for OsFs with write_file(_self, path, content) {
  @fs.write_bytes_to_file(path, content) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.FileSystem for OsFs with write_string(_self, path, content) {
  @fs.write_string_to_file(path, content) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.FileSystem for OsFs with remove_file(_self, path) {
  @fs.remove_file(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.RepoFileSystem for OsFs with read_file(_self, path) {
  @fs.read_file_to_bytes(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.RepoFileSystem for OsFs with readdir(_self, path) {
  @fs.read_dir(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.RepoFileSystem for OsFs with is_dir(_self, path) {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
pub impl @git.RepoFileSystem for OsFs with is_file(_self, path) {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
fn real_git_path() -> String {
  match @sys.get_env_var("SHIM_REAL_GIT") {
    Some(path) => path
    None =>
      match @sys.get_env_var("GIT_SHIM_REAL_GIT") {
        Some(path) => path
        None => "git"
      }
  }
}

///|
fn collect_args(args : Array[String], start : Int) -> Array[String] {
  let out : Array[String] = []
  let len = args.length()
  for i in start..<len {
    out.push(args[i])
  }
  out
}

///|
fn prepend_arg(first : String, rest : Array[String]) -> Array[String] {
  let out : Array[String] = [first]
  out.append(rest)
  out
}

///|
async fn read_all_stdin() -> Bytes {
  let out : Array[Byte] = []
  while true {
    let chunk = @stdio.stdin.read_some(max_len=8192)
    match chunk {
      None => break
      Some(bytes) =>
        for b in bytes {
          out.push(b)
        }
    }
  }
  bytes_from_array(out)
}

///|
async fn run_system_git(args : Array[String]) -> Unit {
  let git = real_git_path()
  let status = @process.run(
    git,
    args,
    inherit_env=true,
    stdin=@stdio.stdin,
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  @sys.exit(status)
}

///|
fn parse_receive_pack_args(args : Array[String]) -> (Bool, String)? {
  let mut advertise = false
  let mut repo : String? = None
  for arg in args {
    if arg == "--advertise-refs" {
      advertise = true
      continue
    }
    if arg == "--stateless-rpc" {
      continue
    }
    if arg.has_prefix("--") {
      continue
    }
    if repo is None {
      repo = Some(arg)
    }
  }
  match repo {
    None => None
    Some(path) => Some((advertise, path))
  }
}

///|
fn normalize_repo_root(path : String) -> String {
  if path == ".git" {
    return "."
  }
  if path.has_suffix("/.git") && path.length() > 5 {
    return (try! path[:path.length() - 5]).to_string()
  }
  path
}

///|
fn parse_upload_pack_args(args : Array[String]) -> (Bool, String)? {
  let mut advertise = false
  let mut repo : String? = None
  for arg in args {
    if arg == "--advertise-refs" {
      advertise = true
      continue
    }
    if arg == "--stateless-rpc" {
      continue
    }
    if arg.has_prefix("--") {
      continue
    }
    if repo is None {
      repo = Some(arg)
    }
  }
  match repo {
    None => None
    Some(path) => Some((advertise, path))
  }
}

///|
async fn handle_upload_pack(args : Array[String]) -> Unit {
  guard parse_upload_pack_args(args) is Some((advertise, repo_path)) else {
    raise @git.GitError::ProtocolError("missing repository path")
  }
  if repo_path.has_suffix(".git") && !repo_path.has_suffix("/.git") {
    run_system_git(prepend_arg("upload-pack", args))
    return ()
  }
  let root = normalize_repo_root(repo_path)
  let fs = OsFs::new()
  if advertise {
    let out = @gitlib.build_upload_pack_advertisement(fs, root)
    @stdio.stdout.write(out)
  } else {
    let input = read_all_stdin()
    let req = @gitlib.parse_upload_pack_request(input)
    let out = @gitlib.upload_pack(fs, root, req)
    @stdio.stdout.write(out)
  }
}

///|
async fn handle_receive_pack(args : Array[String]) -> Unit {
  guard parse_receive_pack_args(args) is Some((advertise, repo_path)) else {
    raise @git.GitError::ProtocolError("missing repository path")
  }
  if repo_path.has_suffix(".git") && !repo_path.has_suffix("/.git") {
    run_system_git(prepend_arg("receive-pack", args))
    return ()
  }
  let root = normalize_repo_root(repo_path)
  let fs = OsFs::new()
  if advertise {
    let out = @gitlib.build_receive_pack_advertisement(fs, root)
    @stdio.stdout.write(out)
  } else {
    let input = read_all_stdin()
    let out = @gitlib.receive_pack(fs, fs, root, input)
    @stdio.stdout.write(out)
  }
}

///|
fn get_work_root() -> String {
  match @sys.get_env_var("GIT_SHIM_CWD") {
    Some(dir) => dir
    None =>
      match @sys.get_env_var("GIT_WORK_TREE") {
        Some(dir) => dir
        None => "."
      }
  }
}

///|
async fn handle_init(args : Array[String]) -> Unit raise Error {
  let path = if args.length() > 0 { args[0] } else { "." }
  let fs = OsFs::new()
  @gitlib.init_repo(fs, path)
  print_line("Initialized empty Git repository in " + path + "/.git/")
}

///|
async fn handle_status(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let mut porcelain = false
  let mut short = false
  for arg in args {
    if arg == "--porcelain" || arg == "--porcelain=v1" {
      porcelain = true
    }
    if arg == "-s" || arg == "--short" {
      short = true
    }
  }
  if porcelain || short {
    let lines = @gitlib.status_porcelain(fs, root)
    for line in lines {
      print_line(line)
    }
  } else {
    let text = @gitlib.status_text(fs, root)
    print_str(text)
  }
}

///|
fn handle_add(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let paths : Array[String] = []
  for arg in args {
    if not(arg.has_prefix("-")) {
      paths.push(arg)
    }
  }
  if paths.length() == 0 {
    raise @git.GitError::InvalidObject("Nothing specified, nothing added.")
  }
  @gitlib.add_paths(fs, fs, root, paths)
}

///|
async fn handle_commit(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let mut message : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "-m" && i + 1 < args.length() {
      message = Some(args[i + 1])
      i += 2
      continue
    }
    if arg.has_prefix("-m") {
      message = Some((try! arg[2:]).to_string())
      i += 1
      continue
    }
    if arg.has_prefix("--message=") {
      message = Some((try! arg[10:]).to_string())
      i += 1
      continue
    }
    i += 1
  }
  guard message is Some(msg) else {
    raise @git.GitError::InvalidObject("No commit message specified")
  }
  let author = match @sys.get_env_var("GIT_AUTHOR_NAME") {
    Some(name) => {
      let email = @sys.get_env_var("GIT_AUTHOR_EMAIL").unwrap_or("unknown")
      name + " <" + email + ">"
    }
    None =>
      match @sys.get_env_var("USER") {
        Some(u) => u + " <" + u + "@localhost>"
        None => "Unknown <unknown@localhost>"
      }
  }
  // Use GIT_COMMITTER_DATE if set, otherwise use current time from FFI
  let timestamp : Int64 = match @sys.get_env_var("GIT_COMMITTER_DATE") {
    Some(s) => {
      // Simple parse: expect unix timestamp as string
      let n = @strconv.parse_int64(s) catch { _ => get_current_timestamp() }
      n
    }
    None => get_current_timestamp()
  }
  let commit_id = @gitlib.commit(fs, fs, root, msg, author, timestamp)
  let short_id = (try! commit_id.to_hex()[:7]).to_string()
  let first_line = match msg.find("\n") {
    Some(idx) => (try! msg[:idx]).to_string()
    None => msg
  }
  print_line("[" + short_id + "] " + first_line)
}

///|
async fn handle_log(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let mut oneline = false
  let mut max_count = 10
  for arg in args {
    if arg == "--oneline" {
      oneline = true
    }
    if arg.has_prefix("-n") {
      let num_str = (try! arg[2:]).to_string()
      max_count = @strconv.parse_int(num_str)
    }
    if arg.has_prefix("--max-count=") {
      let num_str = (try! arg[12:]).to_string()
      max_count = @strconv.parse_int(num_str)
    }
  }
  if oneline {
    let lines = @gitlib.log_head_oneline(fs, git_dir, max_count~)
    for line in lines {
      print_line(line)
    }
  } else {
    let entries = @gitlib.log_head(fs, git_dir, max_count~)
    for entry in entries {
      print_line("commit " + entry.id.to_hex())
      print_line("Author: " + entry.author)
      print_line("")
      print_line("    " + entry.message)
      print_line("")
    }
  }
}

///|
async fn handle_branch(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let mut list_mode = true
  let mut new_branch : String? = None
  let mut delete_branch : String? = None
  let mut force_delete = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "-d" || arg == "--delete" {
      if i + 1 < args.length() {
        delete_branch = Some(args[i + 1])
        list_mode = false
        i += 2
        continue
      }
    }
    if arg == "-D" {
      force_delete = true
      if i + 1 < args.length() {
        delete_branch = Some(args[i + 1])
        list_mode = false
        i += 2
        continue
      }
    }
    if not(arg.has_prefix("-")) {
      new_branch = Some(arg)
      list_mode = false
    }
    i += 1
  }
  match delete_branch {
    Some(name) => {
      @gitlib.delete_branch(fs, fs, root, name, force=force_delete)
      print_line("Deleted branch \{name}")
    }
    None =>
      match new_branch {
        Some(name) => @gitlib.create_branch(fs, fs, root, name)
        None =>
          if list_mode {
            let lines = @gitlib.list_branches_text(fs, git_dir)
            for line in lines {
              print_line(line)
            }
          }
      }
  }
}

///|
async fn handle_diff(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let mut cached = false
  for arg in args {
    if arg == "--cached" || arg == "--staged" {
      cached = true
    }
  }
  let files = if cached {
    @gitlib.diff_index(fs, root)
  } else {
    @gitlib.diff_worktree(fs, root)
  }
  let lines = @gitlib.diff_text(files)
  for line in lines {
    print_line(line)
  }
}

///|
fn handle_checkout(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  // Parse arguments: look for -- separator
  let mut saw_separator = false
  let targets : Array[String] = []
  for arg in args {
    if arg == "--" {
      saw_separator = true
      continue
    }
    if arg.has_prefix("-") {
      continue
    }
    targets.push(arg)
  }
  if targets.length() == 0 {
    raise @git.GitError::InvalidObject("No target specified for checkout")
  }
  // If -- was used, treat all targets as file paths
  if saw_separator {
    @gitlib.restore_paths(fs, fs, root, targets)
    return ()
  }
  // Single target: determine if it's a branch or file
  if targets.length() == 1 {
    let target = targets[0]
    let is_file = fs.is_file(root + "/" + target)
    let is_branch = @gitlib.resolve_ref(fs, git_dir, "refs/heads/" + target)
      is Some(_)
    if is_file && is_branch {
      // Ambiguous - default to branch (like git)
      let _ = @gitlib.checkout(fs, fs, root, target)

    } else if is_file {
      // Restore single file
      @gitlib.restore_paths(fs, fs, root, [target])
    } else {
      // Try as branch/commit
      let _ = @gitlib.checkout(fs, fs, root, target)

    }
  } else {
    // Multiple targets: treat as file paths
    @gitlib.restore_paths(fs, fs, root, targets)
  }
}

///|
async fn handle_rev_parse(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  for arg in args {
    if arg == "--git-dir" {
      print_line(git_dir)
      continue
    }
    if arg == "--show-toplevel" {
      let abs = if root == "." {
        match @sys.get_env_var("PWD") {
          Some(pwd) => pwd
          None => root
        }
      } else {
        root
      }
      print_line(abs)
      continue
    }
    if arg.has_prefix("-") {
      continue
    }
    let id = @gitlib.rev_parse(fs, git_dir, arg)
    match id {
      Some(oid) => print_line(oid.to_hex())
      None => raise @git.GitError::InvalidObject("unknown revision: " + arg)
    }
  }
}

///|
async fn main_async() -> Unit {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    eprint_line("git-shim: missing subcommand")
    @sys.exit(2)
  }
  let full_args = collect_args(args, 1)
  let mut i = 1
  let mut in_opts = true
  let mut cwd : String? = None
  let mut unsupported_global = false
  let mut subcmd : String? = None
  let mut rest : Array[String] = []
  while i < args.length() {
    let arg = args[i]
    if in_opts && arg == "--" {
      in_opts = false
      i += 1
      continue
    }
    if in_opts && arg == "-C" {
      if i + 1 >= args.length() {
        run_system_git(full_args)
      }
      let raw = args[i + 1]
      let resolved = if raw.has_prefix("/") {
        raw
      } else {
        match @sys.get_env_var("GIT_SHIM_PWD") {
          None => raw
          Some(base) => base + "/" + raw
        }
      }
      cwd = Some(resolved)
      i += 2
      continue
    }
    if in_opts && arg == "-c" {
      unsupported_global = true
      if i + 1 >= args.length() {
        run_system_git(full_args)
      }
      i += 2
      continue
    }
    if in_opts &&
      (
        arg == "--git-dir" ||
        arg == "--work-tree" ||
        arg == "--namespace" ||
        arg == "--super-prefix" ||
        arg == "--git-path"
      ) {
      unsupported_global = true
      if i + 1 >= args.length() {
        run_system_git(full_args)
      }
      i += 2
      continue
    }
    if in_opts &&
      (
        arg.has_prefix("--git-dir=") ||
        arg.has_prefix("--work-tree=") ||
        arg.has_prefix("--namespace=") ||
        arg.has_prefix("--super-prefix=") ||
        arg.has_prefix("--git-path=")
      ) {
      unsupported_global = true
      i += 1
      continue
    }
    if in_opts && arg.has_prefix("-") {
      i += 1
      continue
    }
    subcmd = Some(arg)
    rest = collect_args(args, i + 1)
    break
  }
  match subcmd {
    None => {
      eprint_line("git-shim: missing subcommand")
      @sys.exit(2)
    }
    Some(cmd) => {
      if unsupported_global {
        run_system_git(full_args)
      }
      match cwd {
        None => ()
        Some(dir) => {
          @sys.set_env_var("GIT_SHIM_CWD", dir)
          if @sys.get_env_var("GIT_DIR") is None {
            @sys.set_env_var("GIT_DIR", dir + "/.git")
          }
          if @sys.get_env_var("GIT_WORK_TREE") is None {
            @sys.set_env_var("GIT_WORK_TREE", dir)
          }
        }
      }
      let subcmd = cmd
      match subcmd {
        "receive-pack" =>
          handle_receive_pack(rest) catch {
            err => {
              eprint_line("receive-pack failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "git-receive-pack" =>
          handle_receive_pack(rest) catch {
            err => {
              eprint_line("receive-pack failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "pack-objects" =>
          handle_pack_objects(rest) catch {
            err => {
              eprint_line("pack-objects failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "index-pack" =>
          handle_index_pack(rest) catch {
            err => {
              eprint_line("index-pack failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "upload-pack" =>
          handle_upload_pack(rest) catch {
            err => {
              eprint_line("upload-pack failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "git-upload-pack" =>
          handle_upload_pack(rest) catch {
            err => {
              eprint_line("upload-pack failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "init" =>
          handle_init(rest) catch {
            err => {
              eprint_line("init failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "status" =>
          handle_status(rest) catch {
            err => {
              eprint_line("status failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "add" =>
          handle_add(rest) catch {
            err => {
              eprint_line("add failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "commit" =>
          handle_commit(rest) catch {
            err => {
              eprint_line("commit failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "log" =>
          handle_log(rest) catch {
            err => {
              eprint_line("log failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "branch" =>
          handle_branch(rest) catch {
            _ => run_system_git(prepend_arg("branch", rest))
          }
        "diff" =>
          handle_diff(rest) catch {
            err => {
              eprint_line("diff failed: " + err.to_string())
              @sys.exit(1)
            }
          }
        "checkout" =>
          handle_checkout(rest) catch {
            _ => run_system_git(prepend_arg("checkout", rest))
          }
        "rev-parse" =>
          handle_rev_parse(rest) catch {
            _ => run_system_git(prepend_arg("rev-parse", rest))
          }
        _ => run_system_git(prepend_arg(subcmd, rest))
      }
    }
  }
}

///|
fn main {
  @async.run_async_main(main_async)
}
