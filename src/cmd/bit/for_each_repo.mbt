///| git for-each-repo --config=<config> [--keep-going] [--] <arguments>

///|
async fn handle_for_each_repo(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let mut config_key : String? = None
  let mut keep_going = false
  let command_args : Array[String] = []
  let mut saw_dashdash = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if saw_dashdash {
      command_args.push(arg)
      i += 1
      continue
    }
    if arg == "--" {
      saw_dashdash = true
      i += 1
      continue
    }
    if arg == "--keep-going" {
      keep_going = true
      i += 1
      continue
    }
    if arg.has_prefix("--config=") {
      config_key = Some(
        String::unsafe_substring(arg, start=9, end=arg.length()),
      )
      i += 1
      continue
    }
    if arg == "--config" {
      if i + 1 < args.length() {
        config_key = Some(args[i + 1])
        i += 2
        continue
      } else {
        eprint_line("error: option '--config' requires a value")
        @sys.exit(129)
      }
    }
    // Non-option argument: start of command
    while i < args.length() {
      command_args.push(args[i])
      i += 1
    }
    break
  }
  // Validate --config is provided
  guard config_key is Some(key) else {
    eprint_line("fatal: missing --config=<config>")
    @sys.exit(129)
  }
  // Validate the config key is well-formed
  guard @config_parse.parse_config_key(key) is Some(_) else {
    eprint_line("error: got bad config --config=\{key}")
    @sys.exit(129)
  }
  // Read config values from all config sources (system, global, local)
  let values = for_each_repo_read_config_values(fs, rfs, key)
  // Check for NULL values (no-value config entries)
  for val in values {
    if @config_parse.is_config_novalue(val) {
      eprint_line("error: missing value for '\{key}'")
      @sys.exit(129)
    }
  }
  // If no values, exit successfully (nothing to do)
  if values.is_empty() {
    return
  }
  // Run the command in each repository
  let mut result = 0
  for val in values {
    // Expand ~ to HOME
    let path = for_each_repo_expand_path(val)
    // Check if directory exists
    if !(rfs.is_dir(path)) {
      eprint_line("error: cannot change to '\{path}'")
      if !(keep_going) {
        @sys.exit(1)
      }
      result = 1
      continue
    }
    let ret = run_git_command(command_args, cwd=Some(path))
    if ret != 0 {
      if !(keep_going) {
        @sys.exit(ret)
      }
      result = 1
    }
  }
  if result != 0 {
    @sys.exit(result)
  }
}

///|
fn for_each_repo_expand_path(path : String) -> String {
  if path.has_prefix("~/") {
    match @sys.get_env_var("HOME") {
      Some(home) =>
        home + String::unsafe_substring(path, start=1, end=path.length())
      None => path
    }
  } else {
    path
  }
}

///|
fn for_each_repo_read_config_values(
  fs : OsFs,
  rfs : &@bitcore.RepoFileSystem,
  key : String,
) -> Array[String] {
  let values : Array[String] = []
  // 1. System config
  let nosystem = @sys.get_env_var("GIT_CONFIG_NOSYSTEM")
  if nosystem is None || nosystem == Some("false") {
    let sys_path = @sys.get_env_var("GIT_CONFIG_SYSTEM").unwrap_or(
      "/etc/gitconfig",
    )
    if rfs.is_file(sys_path) {
      let vals = get_all_config_values(fs, sys_path, key, None, false) catch {
        _ => []
      }
      for v in vals {
        values.push(v)
      }
    }
  }
  // 2. Global config (XDG + ~/.gitconfig)
  let global_paths = match @sys.get_env_var("GIT_CONFIG_GLOBAL") {
    Some(p) => [p]
    None => {
      let paths : Array[String] = []
      match @sys.get_env_var("HOME") {
        Some(home) => {
          let xdg = home + "/.config/git/config"
          if rfs.is_file(xdg) {
            paths.push(xdg)
          }
          let gitconfig = home + "/.gitconfig"
          if rfs.is_file(gitconfig) {
            paths.push(gitconfig)
          }
        }
        None => ()
      }
      paths
    }
  }
  for gp in global_paths {
    if rfs.is_file(gp) {
      let vals = get_all_config_values(fs, gp, key, None, false) catch {
        _ => []
      }
      for v in vals {
        values.push(v)
      }
    }
  }
  // 3. Local repo config (if in a repo)
  let root = get_work_root()
  if find_repo_root(root) is Some(_) {
    let git_dir = resolve_git_dir(rfs, root)
    let local_path = git_dir + "/config"
    if rfs.is_file(local_path) {
      let vals = get_all_config_values(fs, local_path, key, None, false) catch {
        _ => []
      }
      for v in vals {
        values.push(v)
      }
    }
  }
  values
}
