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
fn parent_dir(path : String) -> String {
  if path.length() == 0 || path == "/" {
    return "/"
  }
  let sep = @path.sep.to_string()
  match path.rev_find(sep) {
    None => ""
    Some(idx) => {
      if idx == 0 {
        sep
      } else {
        (try! path[:idx]).to_string()
      }
    }
  }
}

///|
fn ensure_dir(path : String) -> Unit raise @git.GitError {
  if path.length() == 0 || path == "/" || path == "." {
    return ()
  }
  if @fs.path_exists(path) {
    let is_dir = try @fs.is_dir(path) catch { _ => false }
    if is_dir {
      return ()
    }
    raise @git.GitError::IoError("path exists and is not dir: " + path)
  }
  let parent = parent_dir(path)
  if parent.length() > 0 && parent != path {
    ensure_dir(parent)
  }
  try @fs.create_dir(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.FileSystem for OsFs with mkdir_p(_self, path) {
  ensure_dir(path)
}

///|
pub impl @git.FileSystem for OsFs with write_file(_self, path, content) {
  try @fs.write_bytes_to_file(path, content) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.FileSystem for OsFs with write_string(_self, path, content) {
  try @fs.write_string_to_file(path, content) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.FileSystem for OsFs with remove_file(_self, path) {
  try @fs.remove_file(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.RepoFileSystem for OsFs with read_file(_self, path) {
  try @fs.read_file_to_bytes(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.RepoFileSystem for OsFs with readdir(_self, path) {
  try @fs.read_dir(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @git.RepoFileSystem for OsFs with is_dir(_self, path) {
  try @fs.is_dir(path) catch { _ => false }
}

///|
pub impl @git.RepoFileSystem for OsFs with is_file(_self, path) {
  try @fs.is_file(path) catch { _ => false }
}

///|
fn real_git_path() -> String {
  match @sys.get_env_var("SHIM_REAL_GIT") {
    Some(path) => path
    None => match @sys.get_env_var("GIT_SHIM_REAL_GIT") {
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
async fn read_all_stdin() -> Bytes raise {
  let out : Array[Byte] = []
  while true {
    let chunk = @stdio.stdin.read_some(max_len=8192)
    match chunk {
      None => break
      Some(bytes) => {
        for b in bytes {
          out.push(b)
        }
      }
    }
  }
  bytes_from_array(out)
}

///|
async fn run_system_git(args : Array[String]) -> Unit raise {
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
async fn handle_receive_pack(args : Array[String]) -> Unit raise {
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
async fn main_async() -> Unit {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    @stdio.stderr.write("git-shim: missing subcommand\n")
    @sys.exit(2)
  }
  let subcmd = args[1]
  let rest = collect_args(args, 2)
  match subcmd {
    "receive-pack" => {
      handle_receive_pack(rest) catch {
        err => {
          @stdio.stderr.write("receive-pack failed: " + err.to_string() + "\n")
          @sys.exit(1)
        }
      }
    }
    "git-receive-pack" => {
      handle_receive_pack(rest) catch {
        err => {
          @stdio.stderr.write("receive-pack failed: " + err.to_string() + "\n")
          @sys.exit(1)
        }
      }
    }
    _ => {
      run_system_git(prepend_arg(subcmd, rest))
    }
  }
}

///|
fn main {
  @async.run_async_main(main_async)
}
