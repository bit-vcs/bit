///|
/// Hooks command for bit.

///|
async fn print_x_hooks_usage() -> Unit {
  let usage =
    #|Usage: bit/x/hooks <subcommand> [<args>]
    #|
    #|bit/x/hooks list [<prefix>]
    #|  List hooks under .git/hooks (enabled) and .bit/hooks (available).
    #|  Optional <prefix> filters hook names.
    #|
    #|bit/x/hooks set <name> <source_file>
    #|  Save hook source as an available hook under .bit/hooks.
    #|
    #|bit/x/hooks approve <name>
    #|  Enable a hook by copying from .bit/hooks to .git/hooks.
    #|
    #|bit/x/hooks unapprove <name>
    #|  Disable a hook by removing it from .git/hooks.
    #|
    #|bit/x/hooks remove <name>
    #|  Remove an available hook from .bit/hooks.
    #|
    #|Examples:
    #|  bit/x/hooks list
    #|  bit/x/hooks set pre-add /tmp/pre-add
    #|  bit/x/hooks approve pre-add
    #|  bit/x/hooks unapprove pre-add
    #|  bit/x/hooks remove pre-add
  print_line(usage)
}

///|
fn hooks_dir(git_dir : String) -> String {
  git_dir + "/hooks"
}

///|
fn bit_hooks_dir(root : String) -> String {
  join_repo_marker(root, ".bit/hooks")
}

///|
fn hooks_file_path(git_dir : String, name : String) -> String {
  hooks_dir(git_dir) + "/" + name
}

///|
fn bit_hooks_file_path(root : String, name : String) -> String {
  bit_hooks_dir(root) + "/" + name
}

///|
fn is_valid_hook_name(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  if name == "." || name == ".." {
    return false
  }
  match name.find(" ") {
    Some(_) => return false
    None => ()
  }
  match name.find("/") {
    Some(_) => return false
    None => ()
  }
  match name.find("\\") {
    Some(_) => return false
    None => ()
  }
  match name.find("\n") {
    Some(_) => return false
    None => ()
  }
  match name.find("\r") {
    Some(_) => return false
    None => ()
  }
  match name.find("\t") {
    Some(_) => return false
    None => ()
  }
  true
}

///|
fn list_hooks_in_dir(fs : OsFs, dir : String, prefix : String?) -> Array[String] {
  if not(fs.is_dir(dir)) {
    return []
  }
  let names : Array[String] = []
  let entries = fs.readdir(dir) catch {
    _ => []
  }
  for entry in entries {
    if entry == "." || entry == ".." {
      continue
    }
    let path = dir + "/" + entry
    if fs.is_dir(path) {
      continue
    }
    match prefix {
      Some(p) if not(entry.has_prefix(p)) => continue
      _ => ()
    }
    names.push(entry)
  }
  names.sort_by((a, b) => a.compare(b))
  names
}

///|
fn list_hooks(fs : OsFs, git_dir : String, prefix : String?) -> Array[String] {
  list_hooks_in_dir(fs, hooks_dir(git_dir), prefix)
}

///|
fn list_available_hooks(
  fs : OsFs,
  root : String,
  prefix : String?,
) -> Array[String] {
  list_hooks_in_dir(fs, bit_hooks_dir(root), prefix)
}

///|
fn list_hooks_with_status(
  fs : OsFs,
  root : String,
  git_dir : String,
  prefix : String?,
) -> Array[String] {
  let active = list_hooks(fs, git_dir, prefix)
  let available = list_available_hooks(fs, root, prefix)
  let names = []
  for name in active {
    if not(names.contains(name)) {
      names.push(name)
    }
  }
  for name in available {
    if not(names.contains(name)) {
      names.push(name)
    }
  }
  names.sort_by((a, b) => a.compare(b))
  let out : Array[String] = []
  for name in names {
    if available.contains(name) {
      if active.contains(name) {
        out.push("\{name} (available, enabled)")
      } else {
        out.push("\{name} (available)")
      }
    } else {
      out.push("\{name} (enabled)")
    }
  }
  out
}

///|
async fn handle_x_hooks_list(
  root : String,
  git_dir : String,
  args : Array[String],
) -> Unit {
  if args.length() > 0 && (args[0] == "-h" || args[0] == "--help") {
    print_x_hooks_usage()
    return
  }
  if args.length() > 1 {
    eprint_line("usage: bit/x/hooks list [<prefix>]")
    @sys.exit(1)
  }
  let filter = if args.length() > 0 { Some(args[0]) } else { None }
  let fs = OsFs::new()
  let hooks = list_hooks_with_status(fs, root, git_dir, filter)
  if hooks.length() == 0 {
    print_line("No hooks configured.")
    return
  }
  for hook in hooks {
    print_line(hook)
  }
}

///|
async fn handle_x_hooks_set(fs : OsFs, root : String, args : Array[String]) -> Unit {
  if args.length() == 1 && (args[0] == "-h" || args[0] == "--help") {
    print_x_hooks_usage()
    return
  }
  if args.length() != 2 {
    eprint_line(
      "usage: bit/x/hooks set <name> <source_file>",
    )
    @sys.exit(1)
  }
  let name = args[0]
  let source = args[1]
  if not(is_valid_hook_name(name)) {
    eprint_line("fatal: invalid hook name '\{name}'")
    @sys.exit(1)
  }
  let source_path = abs_path(source)
  if not(fs.is_file(source_path)) {
    eprint_line("fatal: cannot read hook source '\{source_path}'")
    @sys.exit(1)
  }
  let dir = bit_hooks_dir(root)
  if not(fs.is_dir(dir)) {
    fs.mkdir_p(dir)
  }
  let target = bit_hooks_file_path(root, name)
  let content = fs.read_file(source_path)
  fs.write_file(target, content)
  @asyncfs.chmod(target[:], 0o755) catch {
    _ => ()
  }
}

///|
async fn handle_x_hooks_approve(
  fs : OsFs,
  root : String,
  git_dir : String,
  args : Array[String],
) -> Unit {
  if args.length() == 1 && (args[0] == "-h" || args[0] == "--help") {
    print_x_hooks_usage()
    return
  }
  if args.length() != 1 {
    eprint_line("usage: bit/x/hooks approve <name>")
    @sys.exit(1)
  }
  let name = args[0]
  if not(is_valid_hook_name(name)) {
    eprint_line("fatal: invalid hook name '\{name}'")
    @sys.exit(1)
  }
  let source = bit_hooks_file_path(root, name)
  if not(fs.is_file(source)) {
    eprint_line("fatal: hook '\{name}' is not available")
    @sys.exit(1)
  }
  let target_dir = hooks_dir(git_dir)
  if not(fs.is_dir(target_dir)) {
    fs.mkdir_p(target_dir)
  }
  let target = hooks_file_path(git_dir, name)
  let content = fs.read_file(source)
  fs.write_file(target, content)
  @asyncfs.chmod(target[:], 0o755) catch {
    _ => ()
  }
}

///|
async fn handle_x_hooks_unapprove(git_dir : String, args : Array[String]) -> Unit {
  let fs = OsFs::new()
  if args.length() == 1 && (args[0] == "-h" || args[0] == "--help") {
    print_x_hooks_usage()
    return
  }
  if args.length() != 1 {
    eprint_line("usage: bit/x/hooks unapprove <name>")
    @sys.exit(1)
  }
  let name = args[0]
  if not(is_valid_hook_name(name)) {
    eprint_line("fatal: invalid hook name '\{name}'")
    @sys.exit(1)
  }
  let path = hooks_file_path(git_dir, name)
  if fs.is_file(path) {
    fs.remove_file(path)
    return
  }
  if fs.is_dir(path) {
    fs.remove_dir(path)
    return
  }
  eprint_line("fatal: hook '\{name}' is not enabled")
  @sys.exit(1)
}

///|
async fn handle_x_hooks_remove(fs : OsFs, root : String, args : Array[String]) -> Unit {
  if args.length() == 1 && (args[0] == "-h" || args[0] == "--help") {
    print_x_hooks_usage()
    return
  }
  if args.length() != 1 {
    eprint_line("usage: bit/x/hooks remove <name>")
    @sys.exit(1)
  }
  let name = args[0]
  if not(is_valid_hook_name(name)) {
    eprint_line("fatal: invalid hook name '\{name}'")
    @sys.exit(1)
  }
  let path = bit_hooks_file_path(root, name)
  if fs.is_file(path) {
    fs.remove_file(path)
    return
  }
  if fs.is_dir(path) {
    fs.remove_dir(path)
    return
  }
  eprint_line("fatal: hook '\{name}' is not available")
  @sys.exit(1)
}

///|
async fn handle_x_hooks(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  if not(fs.is_dir(git_dir)) {
    eprint_line("fatal: not a git repository")
    @sys.exit(1)
  }
  if args.length() == 0 {
    print_x_hooks_usage()
    return
  }
  let subcmd = args[0]
  let rest = collect_args(args, 1)
  match subcmd {
    "list" => handle_x_hooks_list(root, git_dir, rest)
    "set" => handle_x_hooks_set(fs, root, rest)
    "approve" => handle_x_hooks_approve(fs, root, git_dir, rest)
    "unapprove" => handle_x_hooks_unapprove(git_dir, rest)
    "remove" => handle_x_hooks_remove(fs, root, rest)
    "-h" | "--help" | "help" => print_x_hooks_usage()
    _ => {
      eprint_line("fatal: unknown subcommand '\{subcmd}'")
      print_x_hooks_usage()
      @sys.exit(1)
    }
  }
}
