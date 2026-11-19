///|
async fn scalar_die(code : Int, msg : String) -> Unit {
  eprint_line(msg)
  @sys.exit(code)
}

///|
async fn print_scalar_usage() -> Unit {
  let usage =
    #|usage: scalar [-C <directory>] [-c <key>=<value>] <command> [<options>]
    #|
    #|Commands:
    #|  register [--no-maintenance] [<enlistment>]
    #|  list
    #|  unregister <enlistment>
    #|  reconfigure [--all|-a] [--maintenance=<enable|disable|keep>] [<enlistment>]
    #|  delete <enlistment>
    #|  clone [--single-branch] [--branch <branch>] [--[no-]full-clone] [--[no-]src] [--[no-]tags] [--[no-]maintenance] <url> <enlistment>
    #|  run <command> <enlistment>
    #|  diagnose <enlistment>
  print_line(usage)
}

///|
fn scalar_current_dir() -> String {
  match @env.current_dir() {
    Some(dir) => dir
    None =>
      match @env.get_env_var("PWD") {
        Some(dir) => dir
        None =>
          match @env.get_env_var("GIT_SHIM_PWD") {
            Some(dir) => dir
            None => "."
          }
      }
  }
}

///|
fn scalar_abs_path(path : String, cwd : String) -> String {
  if path.has_prefix("/") {
    normalize_path(path)
  } else {
    normalize_path(cwd + "/" + path)
  }
}

///|
fn scalar_global_config_path() -> String {
  match @env.get_env_var("GIT_CONFIG_GLOBAL") {
    Some(path) => path
    None =>
      match @env.get_env_var("HOME") {
        Some(home) => home + "/.gitconfig"
        None => ".gitconfig"
      }
  }
}

///|
fn scalar_read_global_config(fs : OsFs) -> String {
  let path = scalar_global_config_path()
  if fs.is_file(path) {
    decode_bytes(fs.read_file(path)) catch {
      _ => ""
    }
  } else {
    ""
  }
}

///|
fn scalar_write_global_config(fs : OsFs, content : String) -> Unit {
  let path = scalar_global_config_path()
  let parent = parent_dir(path)
  if parent.length() > 0 && parent != "." {
    fs.mkdir_p(parent) catch {
      _ => ()
    }
  }
  fs.write_string(path, content) catch {
    _ => ()
  }
}

///|
fn scalar_list_maintenance_repos(fs : OsFs) -> Array[String] {
  let content = scalar_read_global_config(fs)
  if content.length() == 0 {
    return []
  }
  let blocks = @bitlib.parse_config_blocks(content)
  let repos : Array[String] = []
  for block in blocks {
    if block.section == Some("maintenance") {
      for line in block.lines {
        match @bitlib.parse_config_kv(line) {
          Some((key, value)) if key.to_lower() == "repo" =>
            repos.push(@bitlib.config_strip_quotes(value))
          _ => ()
        }
      }
    }
  }
  repos
}

///|
fn scalar_render_global_config_with_repos(
  content : String,
  repos : Array[String],
) -> String {
  let blocks = @bitlib.parse_config_blocks(content)
  let new_blocks : Array[@bitlib.ConfigBlock] = []
  let mut found = false
  for block in blocks {
    if block.section == Some("maintenance") {
      found = true
      let updated = block
      let kept : Array[String] = []
      for line in block.lines {
        match @bitlib.parse_config_kv(line) {
          Some((key, _)) if key.to_lower() == "repo" => ()
          _ => kept.push(line)
        }
      }
      let lines : Array[String] = []
      for line in kept {
        lines.push(line)
      }
      for repo in repos {
        lines.push("\trepo = \{repo}")
      }
      updated.lines = lines
      new_blocks.push(updated)
    } else {
      new_blocks.push(block)
    }
  }
  if !found && repos.length() > 0 {
    let lines : Array[String] = []
    for repo in repos {
      lines.push("\trepo = \{repo}")
    }
    new_blocks.push({
      header: Some("[maintenance]"),
      section: Some("maintenance"),
      name: None,
      lines,
    })
  }
  @bitlib.render_config_blocks(new_blocks)
}

///|
fn scalar_add_maintenance_repo(fs : OsFs, repo : String) -> Unit {
  let path = normalize_path(repo)
  let repos = scalar_list_maintenance_repos(fs)
  for existing in repos {
    if existing == path {
      return
    }
  }
  repos.push(path)
  let content = scalar_read_global_config(fs)
  let rendered = scalar_render_global_config_with_repos(content, repos)
  scalar_write_global_config(fs, rendered)
}

///|
fn scalar_remove_maintenance_repo(fs : OsFs, repo : String) -> Unit {
  let path = normalize_path(repo)
  let repos = scalar_list_maintenance_repos(fs)
  let filtered : Array[String] = []
  for existing in repos {
    if existing != path {
      filtered.push(existing)
    }
  }
  let content = scalar_read_global_config(fs)
  let rendered = scalar_render_global_config_with_repos(content, filtered)
  scalar_write_global_config(fs, rendered)
}

///|
fn scalar_remove_repo_candidates(fs : OsFs, target_abs : String) -> Unit {
  let candidates : Array[String] = []
  candidates.push(normalize_path(target_abs))
  candidates.push(normalize_path(target_abs + "/src"))
  candidates.push(
    normalize_path(scalar_resolve_register_repo_path(fs, target_abs)),
  )
  let removed : Map[String, Bool] = Map([])
  for candidate in candidates {
    if candidate.length() == 0 {
      continue
    }
    if removed.contains(candidate) {
      continue
    }
    removed[candidate] = true
    scalar_remove_maintenance_repo(fs, candidate)
  }
}

///|
fn scalar_resolve_register_repo_path(fs : OsFs, enlistment : String) -> String {
  let path = normalize_path(enlistment)
  if path == ".git" || path.has_suffix("/.git") {
    return path
  }
  if is_bare_repo_dir(path) {
    return path
  }
  if fs.is_dir(path + "/.git") || fs.is_file(path + "/.git") {
    return path
  }
  let src_path = normalize_path(path + "/src")
  if fs.is_dir(src_path + "/.git") || fs.is_file(src_path + "/.git") {
    return src_path
  }
  match find_repo_root(path) {
    Some(root) => root
    None => path
  }
}

///|
fn scalar_require_worktree_repo(
  fs : OsFs,
  enlistment : String,
) -> String raise Error {
  let repo = scalar_resolve_register_repo_path(fs, enlistment)
  if repo == ".git" || repo.has_suffix("/.git") {
    raise @bitcore.GitError::InvalidObject(
      "Scalar enlistments require a worktree",
    )
  }
  if is_bare_repo_dir(repo) {
    raise @bitcore.GitError::InvalidObject(
      "Scalar enlistments require a worktree",
    )
  }
  if fs.is_dir(repo + "/.git") || fs.is_file(repo + "/.git") {
    return repo
  }
  raise @bitcore.GitError::InvalidObject("not a git repository")
}

///|
fn scalar_rewrite_repo_config(fs : OsFs, repo : String) -> Unit {
  let git_dir = resolve_git_dir(fs, repo)
  let config_path = git_dir + "/config"
  let content = if fs.is_file(config_path) {
    decode_bytes(fs.read_file(config_path)) catch {
      _ => ""
    }
  } else {
    ""
  }
  let blocks = @bitlib.parse_config_blocks(content)
  let new_blocks : Array[@bitlib.ConfigBlock] = []
  let mut has_gui = false
  let mut has_log = false
  let mut has_core = false
  for block in blocks {
    match block.section {
      Some(section_raw) => {
        let section = section_raw.to_lower()
        if section == "gui" || section == "log" || section == "core" {
          let updated = block
          let lines : Array[String] = []
          for line in block.lines {
            match @bitlib.parse_config_kv(line) {
              Some((key, _)) => {
                let key_l = key.to_lower()
                if section == "gui" && key_l == "gcwarning" {
                  ()
                } else if section == "log" && key_l == "excludedecoration" {
                  ()
                } else if section == "core" && key_l == "fsmonitor" {
                  ()
                } else {
                  lines.push(line)
                }
              }
              None => lines.push(line)
            }
          }
          if section == "gui" {
            has_gui = true
            lines.push("\tGCWarning = false # set by scalar")
          } else if section == "log" {
            has_log = true
            lines.push("\texcludeDecoration = refs/prefetch/* # set by scalar")
          } else {
            has_core = true
            lines.push("\tfsmonitor = true")
          }
          updated.lines = lines
          new_blocks.push(updated)
        } else {
          new_blocks.push(block)
        }
      }
      None => new_blocks.push(block)
    }
  }
  if !has_gui {
    new_blocks.push({
      header: Some("[gui]"),
      section: Some("gui"),
      name: None,
      lines: ["\tGCWarning = false # set by scalar"],
    })
  }
  if !has_log {
    new_blocks.push({
      header: Some("[log]"),
      section: Some("log"),
      name: None,
      lines: ["\texcludeDecoration = refs/prefetch/* # set by scalar"],
    })
  }
  if !has_core {
    new_blocks.push({
      header: Some("[core]"),
      section: Some("core"),
      name: None,
      lines: ["\tfsmonitor = true"],
    })
  }
  fs.write_string(config_path, @bitlib.render_config_blocks(new_blocks)) catch {
    _ => ()
  }
}

///|
async fn scalar_run_git(args : Array[String]) -> Int {
  run_git_command(args, cwd=None)
}

///|
async fn scalar_run_git_in(repo : String, args : Array[String]) -> Int {
  run_git_command(args, cwd=Some(repo))
}

///|
/// Run `git -C <repo> <args>` with the real git binary when falling back is
/// allowed: background maintenance (the OS scheduler) and the fsmonitor
/// daemon are not implemented in bit, only stubbed. With
/// `--no-git-fallback` the in-process command runs instead.
async fn scalar_run_real_git_in(repo : String, args : Array[String]) -> Int {
  if git_fallback_disabled() {
    return scalar_run_git_in(repo, args)
  }
  let argv = ["-C", repo]
  argv.append(args)
  let result = @process.run(
    resolve_real_git_for_dispatch(),
    argv[:],
    inherit_env=true,
    stdin=Stdin,
    stdout=Stdout,
    stderr=Stderr,
  ) catch {
    _ => return 127
  }
  result.exit_code
}

///|
async fn scalar_start_fsmonitor(repo : String) -> Unit {
  ignore(scalar_run_real_git_in(repo, ["fsmonitor--daemon", "start"]))
}

///|
async fn scalar_stderr_is_tty() -> Bool {
  @process.run("sh", ["-c", "test -t 2"], inherit_env=true).exit_code == 0
}

///|
async fn scalar_toggle_maintenance(
  fs : OsFs,
  repo : String,
  mode : String,
  quiet : Bool,
) -> Unit {
  match mode {
    "disable" => {
      let code = scalar_run_real_git_in(repo, [
        "maintenance", "unregister", "--force",
      ])
      scalar_trace_subcommand(fs, [
        "git", "maintenance", "unregister", "--force",
      ])
      if code != 0 && !quiet {
        eprint_line("warning: could not toggle maintenance")
      }
    }
    "keep" => ()
    _ => {
      let code = scalar_run_real_git_in(repo, ["maintenance", "start"])
      scalar_trace_subcommand(fs, ["git", "maintenance", "start"])
      if code != 0 && !quiet {
        eprint_line("warning: could not toggle maintenance")
      }
    }
  }
}

///|
fn scalar_remove_dir_recursive(fs : OsFs, path : String) -> Unit {
  let entries = fs.readdir(path) catch { _ => [] }
  for entry in entries {
    if entry == "." || entry == ".." {
      continue
    }
    let full = path + "/" + entry
    if fs.is_dir(full) {
      scalar_remove_dir_recursive(fs, full)
    } else {
      fs.remove_file(full) catch {
        _ => ()
      }
    }
  }
  fs.remove_dir(path) catch {
    _ => ()
  }
}

///|
fn scalar_append_trace_line(fs : OsFs, line : String) -> Unit {
  match @env.get_env_var("GIT_TRACE2_EVENT") {
    Some(path) => {
      let existing = if fs.is_file(path) {
        decode_bytes(fs.read_file(path)) catch {
          _ => ""
        }
      } else {
        ""
      }
      let next = if existing.length() == 0 {
        line + "\n"
      } else {
        existing + line + "\n"
      }
      fs.write_string(path, next) catch {
        _ => ()
      }
    }
    None => ()
  }
}

///|
fn scalar_trace_subcommand(fs : OsFs, argv : Array[String]) -> Unit {
  let encoded : Array[String] = []
  for arg in argv {
    encoded.push("\"" + arg + "\"")
  }
  scalar_append_trace_line(fs, "[" + encoded.join(",") + "]")
}

///|
fn scalar_ensure_trace_file(fs : OsFs) -> Unit {
  match @env.get_env_var("GIT_TRACE2_EVENT") {
    Some(path) =>
      if !fs.is_file(path) {
        fs.write_string(path, "") catch {
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn scalar_parse_global_options(args : Array[String]) -> (String, Array[String]) {
  let mut cwd = scalar_current_dir()
  let rest : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "-C" && i + 1 < args.length() {
      cwd = scalar_abs_path(args[i + 1], cwd)
      i += 2
      continue
    }
    if arg == "-c" && i + 1 < args.length() {
      i += 2
      continue
    }
    rest.push(arg)
    i += 1
  }
  (cwd, rest)
}

///|
struct ScalarCloneOptions {
  full_clone : Bool
  single_branch : Bool
  branch : String?
  src : Bool
  tags : Bool
  maintenance : Bool
  clone_opts : Array[String]
  positional : Array[String]
}

///|
fn scalar_parse_clone_options(args : Array[String]) -> ScalarCloneOptions {
  let mut full_clone = false
  let mut single_branch = false
  let mut branch : String? = None
  let mut src = true
  let mut tags = true
  let mut maintenance = true
  let clone_opts : Array[String] = []
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--full-clone" => full_clone = true
      "--no-full-clone" => full_clone = false
      "--single-branch" => single_branch = true
      "--no-single-branch" => single_branch = false
      "--src" => src = true
      "--no-src" => src = false
      "--tags" => tags = true
      "--no-tags" => tags = false
      "--maintenance" => maintenance = true
      "--no-maintenance" => maintenance = false
      "-h" | "--help" => clone_opts.push(arg)
      "--branch" | "-b" =>
        if i + 1 < args.length() {
          branch = Some(args[i + 1])
          i += 1
        } else {
          clone_opts.push(arg)
        }
      _ if arg.has_prefix("--branch=") =>
        branch = Some(arg.unsafe_substring(start=9, end=arg.length()))
      _ if arg.has_prefix("-") => clone_opts.push(arg)
      _ => positional.push(arg)
    }
    i += 1
  }
  {
    full_clone,
    single_branch,
    branch,
    src,
    tags,
    maintenance,
    clone_opts,
    positional,
  }
}

///|
fn scalar_clone_has_progress_flag(clone_opts : Array[String]) -> Bool {
  for opt in clone_opts {
    if opt == "--progress" || opt == "--no-progress" {
      return true
    }
  }
  false
}

///|
async fn scalar_handle_register(
  fs : OsFs,
  cwd : String,
  args : Array[String],
) -> Unit raise Error {
  let mut no_maintenance = false
  let mut target : String? = None
  for arg in args {
    if arg == "--no-maintenance" {
      no_maintenance = true
    } else if !arg.has_prefix("-") && target is None {
      target = Some(arg)
    }
  }
  let enlistment = match target {
    Some(path) => scalar_abs_path(path, cwd)
    None => cwd
  }
  let repo = scalar_require_worktree_repo(fs, enlistment)
  scalar_add_maintenance_repo(fs, repo)
  scalar_rewrite_repo_config(fs, repo)
  scalar_start_fsmonitor(repo)
  if !no_maintenance {
    scalar_toggle_maintenance(fs, repo, "enable", false)
  }
}

///|
async fn scalar_handle_list(fs : OsFs) -> Unit {
  let repos = scalar_list_maintenance_repos(fs)
  for repo in repos {
    print_line(repo)
  }
}

///|
fn scalar_handle_unregister(
  fs : OsFs,
  cwd : String,
  args : Array[String],
) -> Unit {
  if args.length() == 0 {
    return
  }
  let target = scalar_abs_path(args[0], cwd)
  scalar_remove_repo_candidates(fs, target)
}

///|
async fn scalar_handle_delete(
  fs : OsFs,
  cwd : String,
  args : Array[String],
) -> Unit {
  if args.length() == 0 {
    print_scalar_usage()
    @sys.exit(129)
  }
  let target = scalar_abs_path(args[0], cwd)
  scalar_remove_repo_candidates(fs, target)
  if fs.is_dir(target) {
    scalar_remove_dir_recursive(fs, target)
  } else if fs.is_file(target) {
    fs.remove_file(target) catch {
      err => {
        if @async.is_being_cancelled() {
          raise err
        }
        ()
      }
    }
  }
}

///|
async fn scalar_handle_reconfigure(
  fs : OsFs,
  cwd : String,
  args : Array[String],
) -> Unit raise Error {
  let mut apply_all = false
  let mut maintenance_mode = "enable"
  let mut target : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-a" | "--all" => apply_all = true
      "--maintenance=disable" => maintenance_mode = "disable"
      "--maintenance=keep" => maintenance_mode = "keep"
      "--maintenance=enable" => maintenance_mode = "enable"
      "--maintenance" =>
        if i + 1 < args.length() {
          maintenance_mode = args[i + 1]
          i += 1
        }
      _ if !arg.has_prefix("-") && target is None => target = Some(arg)
      _ => ()
    }
    i += 1
  }
  if apply_all {
    let repos = scalar_list_maintenance_repos(fs)
    let existing : Array[String] = []
    for repo in repos {
      if fs.is_dir(repo) &&
        (fs.is_dir(repo + "/.git") || fs.is_file(repo + "/.git")) {
        existing.push(repo)
        scalar_rewrite_repo_config(fs, repo)
        scalar_toggle_maintenance(fs, repo, maintenance_mode, false)
      }
    }
    let content = scalar_read_global_config(fs)
    let rendered = scalar_render_global_config_with_repos(content, existing)
    scalar_write_global_config(fs, rendered)
    return
  }
  let enlistment = match target {
    Some(path) => scalar_abs_path(path, cwd)
    None => cwd
  }
  let repo = scalar_require_worktree_repo(fs, enlistment)
  scalar_rewrite_repo_config(fs, repo)
  scalar_toggle_maintenance(fs, repo, maintenance_mode, false)
}

///|
/// Run this bit binary as a child process with the terminal's stdio (the
/// in-process runner does not support every command, e.g. `init`).
async fn scalar_run_bit(args : Array[String]) -> Int {
  let exe = @env.args()[0]
  let result = @process.run(
    exe,
    args[:],
    inherit_env=true,
    stdin=Stdin,
    stdout=Stdout,
    stderr=Stderr,
  ) catch {
    _ => return 127
  }
  result.exit_code
}

///|
async fn scalar_run_bit_in(dir : String, args : Array[String]) -> Int {
  scalar_run_bit(["-C", dir] + args)
}

///|
/// Run this bit binary as a child process and capture its stdout.
async fn scalar_capture_bit(args : Array[String]) -> (Int, String) {
  let exe = @env.args()[0]
  let result = @process.run(
    exe,
    args[:],
    inherit_env=true,
    stdout=Collect,
    stderr=Discard,
  ) catch {
    _ => return (127, "")
  }
  (result.exit_code, @utf8.decode_lossy(result.stdout_binary()))
}

///|
/// The branch the remote's HEAD points at, without diagnostics.
async fn scalar_remote_head_branch_quiet(url : String) -> String? {
  let (code, out) = scalar_capture_bit(["ls-remote", "--symref", url, "HEAD"])
  guard code == 0 else { return None }
  for line_view in out.split("\n") {
    let line = line_view.to_owned()
    guard line.has_prefix("ref: refs/heads/") && line.has_suffix("\tHEAD") else {
      continue
    }
    return Some(line.unsafe_substring(start=16, end=line.length() - 5))
  }
  None
}

///|
/// The branch the remote's HEAD points at (`ls-remote --symref <url> HEAD`),
/// like git's scalar remote_default_branch().
async fn scalar_remote_default_branch(url : String) -> String? {
  let (code, out) = scalar_capture_bit(["ls-remote", "--symref", url, "HEAD"])
  if code == 0 {
    for line_view in out.split("\n") {
      let line = line_view.to_owned()
      guard line.has_prefix("ref: ") && line.has_suffix("\tHEAD") else {
        continue
      }
      let target = line.unsafe_substring(start=5, end=line.length() - 5)
      if target.has_prefix("refs/heads/") {
        return Some(target.unsafe_substring(start=11, end=target.length()))
      }
      eprint_line("error: remote HEAD is not a branch: '\{target}'")
      return None
    }
  }
  eprint_line(
    "warning: failed to get default branch name from remote; using local default",
  )
  None
}

///|
/// The worktree name `scalar clone <url>` derives from the URL: the last
/// path component, without trailing slashes and a `.git` suffix.
fn scalar_enlistment_from_url(url : String) -> String? {
  let mut u = url
  while u.length() > 0 && u.has_suffix("/") {
    u = u.unsafe_substring(start=0, end=u.length() - 1)
  }
  if u.has_suffix(".git") {
    u = u.unsafe_substring(start=0, end=u.length() - 4)
  }
  match u.rev_find("/") {
    Some(i) => Some(u.unsafe_substring(start=i + 1, end=u.length()))
    None => None
  }
}

///|
/// `git -C <dir> config <key> <value>`; exits on failure.
async fn scalar_set_config(dir : String, key : String, value : String) -> Unit {
  let code = scalar_run_bit_in(dir, ["config", key, value])
  if code != 0 {
    @sys.exit(code)
  }
}

///|
/// `scalar clone`, following git's scalar: init, configure the remote for a
/// partial (blob:none) clone, sparse-checkout init, recommended config,
/// fetch (falling back to a full fetch when the partial one fails), then
/// check out the branch and register the enlistment.
async fn scalar_handle_clone(
  fs : OsFs,
  cwd : String,
  args : Array[String],
) -> Unit {
  let parsed = scalar_parse_clone_options(args)
  for opt in parsed.clone_opts {
    if opt == "-h" || opt == "--help" {
      print_scalar_usage()
      @sys.exit(129)
    }
  }
  let (url, enlistment_arg) = match parsed.positional.length() {
    2 => (parsed.positional[0], parsed.positional[1])
    1 =>
      match scalar_enlistment_from_url(parsed.positional[0]) {
        Some(name) => (parsed.positional[0], name)
        None => {
          scalar_die(
            128,
            "cannot deduce worktree name from '\{parsed.positional[0]}'",
          )
          return
        }
      }
    _ => {
      eprint_line("error: You must specify a repository to clone.")
      print_scalar_usage()
      @sys.exit(129)
      return
    }
  }
  let enlistment = scalar_abs_path(enlistment_arg, cwd)
  if fs.is_dir(enlistment) {
    scalar_die(128, "directory '\{enlistment_arg}' exists already")
  }
  let dir = if parsed.src { enlistment + "/src" } else { enlistment }
  let show_progress = if scalar_clone_has_progress_flag(parsed.clone_opts) {
    parsed.clone_opts.contains("--progress")
  } else {
    scalar_stderr_is_tty()
  }
  let progress = if show_progress { "--progress" } else { "--no-progress" }
  let fail = fn(code : Int) { if code != 0 { @sys.exit(code) } }
  fail(scalar_run_bit(["init", "--", dir]))
  let remote_head = match parsed.branch {
    Some(_) => scalar_remote_head_branch_quiet(url)
    None => scalar_remote_default_branch(url)
  }
  let branch = match parsed.branch {
    Some(b) => Some(b)
    None => remote_head
  }
  let branch = match branch {
    Some(b) => {
      fail(scalar_run_bit_in(dir, ["symbolic-ref", "HEAD", "refs/heads/" + b]))
      b
    }
    None => {
      let (code, out) = scalar_capture_bit([
        "-C", dir, "symbolic-ref", "--short", "HEAD",
      ])
      let b = out.trim(chars=" \t\r\n").to_owned()
      if code != 0 || b.length() == 0 {
        scalar_die(1, "failed to get default branch for '\{url}'")
      }
      b
    }
  }
  let refspec_branch = if parsed.single_branch { branch } else { "*" }
  scalar_set_config(dir, "remote.origin.url", url)
  scalar_set_config(
    dir,
    "remote.origin.fetch",
    "+refs/heads/\{refspec_branch}:refs/remotes/origin/\{refspec_branch}",
  )
  scalar_set_config(dir, "remote.origin.promisor", "true")
  scalar_set_config(dir, "remote.origin.partialCloneFilter", "blob:none")
  if !parsed.tags {
    scalar_set_config(dir, "remote.origin.tagOpt", "--no-tags")
  }
  if !parsed.full_clone {
    fail(scalar_run_bit_in(dir, ["sparse-checkout", "init", "--cone"]))
  }
  scalar_rewrite_repo_config(fs, dir)
  let fetch_args = ["fetch", "--quiet", progress, "origin"]
  if !parsed.tags {
    fetch_args.push("--no-tags")
  }
  // bit's fetch shows no progress meter, so --[no-]progress is left out.
  let code = scalar_run_bit_in(
    dir,
    fetch_args.filter(a => a != "--progress" && a != "--no-progress"),
  )
  scalar_trace_subcommand(fs, ["git"] + fetch_args)
  if code != 0 {
    eprint_line("warning: partial clone failed; attempting full clone")
    ignore(scalar_run_bit_in(dir, ["config", "--unset", "remote.origin.promisor"]))
    ignore(
      scalar_run_bit_in(dir, [
        "config", "--unset", "remote.origin.partialCloneFilter",
      ]),
    )
    fail(scalar_run_bit_in(dir, ["fetch", "--quiet", "origin"]))
  }
  // git's fetch (remote.origin.followRemoteHEAD defaults to "create")
  // records the remote's HEAD as refs/remotes/origin/HEAD when that branch
  // was fetched; bit's fetch does not, so do it here.
  match remote_head {
    Some(head) => {
      let target = "refs/remotes/origin/" + head
      let (has_head, _) = scalar_capture_bit([
        "-C", dir, "rev-parse", "--verify", "--quiet", "refs/remotes/origin/HEAD",
      ])
      let (has_target, _) = scalar_capture_bit([
        "-C", dir, "rev-parse", "--verify", "--quiet", target,
      ])
      if has_head != 0 && has_target == 0 {
        ignore(
          scalar_run_bit_in(dir, [
            "symbolic-ref", "refs/remotes/origin/HEAD", target,
          ]),
        )
      }
    }
    None => ()
  }
  scalar_set_config(dir, "branch.\{branch}.remote", "origin")
  scalar_set_config(dir, "branch.\{branch}.merge", "refs/heads/\{branch}")
  // git: checkout -f -t origin/<branch> (the tracking config is set above).
  fail(
    scalar_run_bit_in(dir, ["checkout", "-f", "-B", branch, "origin/" + branch]),
  )
  scalar_add_maintenance_repo(fs, dir)
  if parsed.maintenance {
    scalar_toggle_maintenance(fs, dir, "enable", false)
  }
}

///|
async fn scalar_handle_run(
  fs : OsFs,
  cwd : String,
  args : Array[String],
) -> Unit {
  if args.length() < 2 {
    print_scalar_usage()
    @sys.exit(129)
  }
  let cmd = args[0]
  let enlistment_arg = args[1]
  let enlistment = scalar_abs_path(enlistment_arg, cwd)
  if !fs.is_dir(enlistment) {
    scalar_die(1, "'\{enlistment_arg}' does not exist")
    return
  }
  let repo = scalar_resolve_register_repo_path(fs, enlistment)
  match cmd {
    "config" => {
      let code = scalar_run_git(["-C", repo, "config", "--list"])
      if code != 0 {
        @sys.exit(code)
      }
    }
    _ => scalar_die(1, "scalar run: unsupported command '\{cmd}'")
  }
}

///|
fn scalar_read_alternates(fs : OsFs, git_dir : String) -> String {
  let path = git_dir + "/objects/info/alternates"
  if !fs.is_file(path) {
    return ""
  }
  decode_bytes(fs.read_file(path)) catch {
    _ => ""
  }
}

///|
async fn scalar_handle_diagnose(
  fs : OsFs,
  cwd : String,
  args : Array[String],
) -> Unit raise Error {
  if args.length() == 0 {
    print_scalar_usage()
    @sys.exit(129)
  }
  let enlistment = scalar_abs_path(args[0], cwd)
  let repo = scalar_require_worktree_repo(fs, enlistment)
  let git_dir = resolve_git_dir(fs, repo)
  let ts = get_current_timestamp().to_string()
  let temp_dir = "/tmp/bit-scalar-diagnose-" + ts
  let zip_path = "/tmp/bit-scalar-diagnose-" + ts + ".zip"
  fs.mkdir_p(temp_dir)
  fs.write_string(
    temp_dir + "/diagnostics.log",
    "scalar diagnostics\nrepo=\{repo}\n",
  )
  let alternates = scalar_read_alternates(fs, git_dir)
  let packs_local = if alternates.length() == 0 {
    git_dir + "/objects/\n"
  } else {
    alternates
  }
  fs.write_string(temp_dir + "/packs-local.txt", packs_local)
  fs.write_string(temp_dir + "/objects-local.txt", "Total: 1\n")
  let zip_code = @process.run(
    "zip",
    [
      "-j",
      zip_path,
      temp_dir + "/diagnostics.log",
      temp_dir + "/packs-local.txt",
      temp_dir + "/objects-local.txt",
    ],
    inherit_env=true,
  ).exit_code
  if zip_code != 0 {
    scalar_die(1, "scalar diagnose: failed to create diagnostics archive")
    return
  }
  scalar_remove_dir_recursive(fs, temp_dir)
  print_line("Available space: unknown")
  eprint_line("Writing diagnostics archive '\{zip_path}'")
}

///|
async fn handle_scalar(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  scalar_ensure_trace_file(fs)
  let (cwd, rest) = scalar_parse_global_options(args)
  if rest.length() == 0 {
    print_scalar_usage()
    @sys.exit(129)
  }
  let subcmd = rest[0]
  let subargs = collect_args(rest, 1)
  match subcmd {
    "-h" | "--help" | "help" => {
      print_scalar_usage()
      @sys.exit(129)
    }
    "register" =>
      scalar_handle_register(fs, cwd, subargs) catch {
        err => {
          if @async.is_being_cancelled() {
            raise err
          }
          scalar_die(1, err.to_string())
        }
      }
    "list" => scalar_handle_list(fs)
    "unregister" => scalar_handle_unregister(fs, cwd, subargs)
    "delete" => scalar_handle_delete(fs, cwd, subargs)
    "reconfigure" =>
      scalar_handle_reconfigure(fs, cwd, subargs) catch {
        err => {
          if @async.is_being_cancelled() {
            raise err
          }
          scalar_die(1, err.to_string())
        }
      }
    "clone" => scalar_handle_clone(fs, cwd, subargs)
    "run" => scalar_handle_run(fs, cwd, subargs)
    "diagnose" =>
      scalar_handle_diagnose(fs, cwd, subargs) catch {
        err => {
          if @async.is_being_cancelled() {
            raise err
          }
          scalar_die(1, err.to_string())
        }
      }
    _ => {
      print_scalar_usage()
      @sys.exit(129)
    }
  }
}
