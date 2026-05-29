///| git var - print git variables

///|
async fn handle_var(args : Array[String]) -> Unit raise Error {
  let mut list_all = false
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "-l" => list_all = true
      "-h" | "--help" => {
        show_simple_command_help(
          "git var [-l | <variable>]",
          summary="Print a Git logical variable.",
        )
        return
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("var", arg)
      _ => positional.push(arg)
    }
  }
  if list_all {
    var_print_all()
    return
  }
  if positional.length() == 0 {
    eprint_line("usage: git var [-l | <variable>]")
    @sys.exit(1)
  }
  let name = positional[0]
  match var_lookup(name) {
    Some(value) => print_line(value)
    None => {
      eprint_line("Unknown variable: '\{name}'")
      @sys.exit(1)
    }
  }
}

///|
fn var_author_ident() -> String {
  let author = get_author_string()
  let ts = get_author_timestamp()
  let tz = get_author_timezone()
  "\{author} \{ts} \{tz}"
}

///|
fn var_committer_ident() -> String {
  let committer = get_committer_string()
  let ts = get_commit_timestamp()
  let tz = get_commit_timezone()
  "\{committer} \{ts} \{tz}"
}

///|
fn var_default_branch() -> String {
  let fs : &@bitcore.RepoFileSystem = OsFs::new()
  let root = match var_try_get_work_root() {
    Some(r) => r
    None => return "main"
  }
  let git_dir = resolve_git_dir(fs, root)
  let config_path = git_dir + "/config"
  let value = get_config_value(
    fs,
    config_path,
    "init.defaultBranch",
    None,
    false,
  ) catch {
    _ => return "main"
  }
  match value {
    Some(v) => v
    None => "main"
  }
}

///|
fn var_editor() -> String {
  match @sys.get_env_var("GIT_EDITOR") {
    Some(e) => return e
    None => ()
  }
  let core_editor = var_get_config_string("core.editor")
  match core_editor {
    Some(e) => return e
    None => ()
  }
  match @sys.get_env_var("VISUAL") {
    Some(e) => return e
    None => ()
  }
  match @sys.get_env_var("EDITOR") {
    Some(e) => return e
    None => ()
  }
  "vi"
}

///|
fn var_pager() -> String {
  match @sys.get_env_var("GIT_PAGER") {
    Some(p) => return p
    None => ()
  }
  let core_pager = var_get_config_string("core.pager")
  match core_pager {
    Some(p) => return p
    None => ()
  }
  match @sys.get_env_var("PAGER") {
    Some(p) => return p
    None => ()
  }
  "less"
}

///|
fn var_get_config_string(key : String) -> String? {
  let fs : &@bitcore.RepoFileSystem = OsFs::new()
  let root = match var_try_get_work_root() {
    Some(r) => r
    None => return None
  }
  let git_dir = resolve_git_dir(fs, root)
  let value = get_config_value(fs, git_dir + "/config", key, None, false) catch {
    _ => return None
  }
  value
}

///|
fn var_lookup(name : String) -> String? {
  match name {
    "GIT_AUTHOR_IDENT" => Some(var_author_ident())
    "GIT_COMMITTER_IDENT" => Some(var_committer_ident())
    "GIT_DEFAULT_BRANCH" => Some(var_default_branch())
    "GIT_EDITOR" => Some(var_editor())
    "GIT_PAGER" => Some(var_pager())
    "GIT_SEQUENCE_EDITOR" => Some(var_editor())
    _ => None
  }
}

///|
async fn var_print_all() -> Unit {
  let vars = [
    ("GIT_AUTHOR_IDENT", var_author_ident()),
    ("GIT_COMMITTER_IDENT", var_committer_ident()),
    ("GIT_DEFAULT_BRANCH", var_default_branch()),
    ("GIT_EDITOR", var_editor()),
    ("GIT_PAGER", var_pager()),
    ("GIT_SEQUENCE_EDITOR", var_editor()),
  ]
  for pair in vars {
    print_line("\{pair.0}=\{pair.1}")
  }
}

///|
fn var_try_get_work_root() -> String? {
  // get_work_root() returns "." if no repo found; check if git_dir exists
  let root = get_work_root()
  let fs : &@bitcore.RepoFileSystem = OsFs::new()
  let git_dir = default_repo_marker_path(fs, root)
  if fs.is_dir(git_dir) || fs.is_file(git_dir) {
    Some(root)
  } else {
    None
  }
}
