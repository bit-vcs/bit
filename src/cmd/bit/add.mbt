///|

///|
async fn show_add_command_help() -> Unit {
  show_simple_command_help(
    "git add [<options>] [--] <pathspec>...",
    summary="Add file contents to the index.",
  )
}

///|
async fn handle_add(args : Array[String]) -> Unit raise Error {
  if has_interactive_add_flag(args) {
    run_add_interactive(args)
    return
  }
  let root = get_work_root()
  let fs = OsFs::new()
  let mut add_all = false
  let mut force = false
  let mut end_of_options = false
  let paths : Array[String] = []
  for raw_arg in args {
    let arg = raw_arg
    if not(end_of_options) && arg == "--" {
      end_of_options = true
      continue
    }
    match arg {
      "-A" | "--all" if not(end_of_options) => add_all = true
      "-f" | "--force" if not(end_of_options) => force = true
      _ if end_of_options || not(arg.has_prefix("-")) => paths.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("add", arg)
      _ => ()
    }
  }
  if add_all {
    // Stage all: untracked, modified, and deleted
    let status = @gitlib.status(fs, root)
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
      @gitlib.add_paths_async(fs, fs, root, all_paths)
      stage_submodule_gitlinks(fs, root, all_paths)
    }
    return
  }
  if paths.length() == 0 {
    eprint_line("Nothing specified, nothing added.")
    if add_should_show_empty_pathspec_hint(fs, root) {
      eprint_line("hint: Maybe you wanted to say 'git add .'?")
      eprint_line(
        "hint: Disable this message with \"git config set advice.addEmptyPathspec false\"",
      )
    }
    return
  }
  let stage_paths = expand_add_stage_paths(fs, root, paths, force)
  if stage_paths.length() > 0 {
    @gitlib.add_paths_async(fs, fs, root, stage_paths)
    stage_submodule_gitlinks(fs, root, stage_paths)
  }
  if not(force) && add_has_explicit_ignored_path(fs, root, paths) {
    eprint_line(
      "The following paths are ignored by one of your .gitignore files.",
    )
    eprint_line("hint: Use -f if you really want to add them.")
    @sys.exit(1)
  }
}

///|
fn normalize_add_path(path : String) -> String {
  let mut out = path
  while out.has_prefix("./") {
    out = String::unsafe_substring(out, start=2, end=out.length())
  }
  while out.length() > 1 && out.has_suffix("/") {
    out = String::unsafe_substring(out, start=0, end=out.length() - 1)
  }
  out
}

///|
fn add_should_show_empty_pathspec_hint(
  fs : &@git.RepoFileSystem,
  root : String,
) -> Bool {
  let git_dir = resolve_git_dir(fs, root)
  match get_config_override("advice.addEmptyPathspec") {
    Some(value) => add_parse_bool(value).unwrap_or(true)
    None =>
      @gitlib.read_config_bool(
        fs,
        git_dir + "/config",
        "advice",
        "addemptypathspec",
      ).unwrap_or(true)
  }
}

///|
fn add_parse_bool(value : String) -> Bool? {
  let lowered = trim_string(value).to_lower()
  if lowered == "true" || lowered == "yes" || lowered == "on" || lowered == "1" {
    Some(true)
  } else if lowered == "false" ||
    lowered == "no" ||
    lowered == "off" ||
    lowered == "0" {
    Some(false)
  } else {
    None
  }
}

///|
async fn expand_add_stage_paths(
  fs : &@git.RepoFileSystem,
  root : String,
  paths : Array[String],
  force : Bool,
) -> Array[String] raise Error {
  let out : Array[String] = []
  let visible_paths = if force {
    []
  } else {
    @ignore.list_working_files_async(fs, root)
  }
  let visible_map : Map[String, Bool] = {}
  for p in visible_paths {
    visible_map[p] = true
  }
  for raw_path in paths {
    let path = normalize_add_path(raw_path)
    if path.length() == 0 {
      continue
    }
    if force {
      expand_force_add_path(fs, root, path, out)
      continue
    }
    if path == "." {
      for p in visible_paths {
        out.push(p)
      }
      continue
    }
    let abs = root + "/" + path
    if fs.is_dir(abs) {
      let prefix = path + "/"
      for p in visible_paths {
        if p.has_prefix(prefix) {
          out.push(p)
        }
      }
      continue
    }
    if visible_map.get(path) is Some(_) {
      out.push(path)
      continue
    }
    if not(fs.is_file(abs)) && not(fs.is_dir(abs)) {
      out.push(path)
    }
  }
  out
}

///|
fn expand_force_add_path(
  fs : &@git.RepoFileSystem,
  root : String,
  path : String,
  out : Array[String],
) -> Unit raise Error {
  if path == "." {
    collect_all_addable_paths(fs, root, "", out)
    return
  }
  let abs = root + "/" + path
  if fs.is_dir(abs) {
    collect_all_addable_paths(fs, root, path, out)
  } else {
    out.push(path)
  }
}

///|
fn collect_all_addable_paths(
  fs : &@git.RepoFileSystem,
  root : String,
  rel : String,
  out : Array[String],
) -> Unit raise Error {
  let dir = if rel.length() == 0 { root } else { root + "/" + rel }
  if not(fs.is_dir(dir)) {
    return
  }
  for name in fs.readdir(dir) {
    if name == "." ||
      name == ".." ||
      name == ".git" ||
      name == ".bit" ||
      name == ".jj" {
      continue
    }
    let child_rel = if rel.length() == 0 { name } else { rel + "/" + name }
    let child_abs = root + "/" + child_rel
    if fs.is_dir(child_abs) {
      collect_all_addable_paths(fs, root, child_rel, out)
    } else {
      out.push(child_rel)
    }
  }
}

///|
fn add_has_explicit_ignored_path(
  fs : &@git.RepoFileSystem,
  root : String,
  paths : Array[String],
) -> Bool raise Error {
  for raw_path in paths {
    let rel = normalize_add_path(raw_path)
    if rel.length() == 0 {
      continue
    }
    if rel == "." {
      continue
    }
    let abs = root + "/" + rel
    if fs.is_dir(abs) {
      if add_has_ignored_under(fs, root, rel) {
        return true
      }
    } else if @ignore.is_ignored_path(fs, root, rel, false) {
      return true
    }
  }
  false
}

///|
fn add_has_ignored_under(
  fs : &@git.RepoFileSystem,
  root : String,
  rel : String,
) -> Bool raise Error {
  let dir = if rel.length() == 0 { root } else { root + "/" + rel }
  if not(fs.is_dir(dir)) {
    return false
  }
  for name in fs.readdir(dir) {
    if name == "." ||
      name == ".." ||
      name == ".git" ||
      name == ".bit" ||
      name == ".jj" {
      continue
    }
    let child_rel = if rel.length() == 0 { name } else { rel + "/" + name }
    let child_abs = root + "/" + child_rel
    let is_dir = fs.is_dir(child_abs)
    if @ignore.is_ignored_path(fs, root, child_rel, is_dir) {
      return true
    }
    if is_dir && add_has_ignored_under(fs, root, child_rel) {
      return true
    }
  }
  false
}

///|
fn stage_submodule_gitlinks(
  fs : OsFs,
  root : String,
  paths : Array[String],
) -> Unit raise Error {
  let rfs : &@git.RepoFileSystem = fs
  let git_dir = resolve_git_dir(fs, root)
  for raw_path in paths {
    let rel_path = normalize_add_path(raw_path)
    if rel_path == "." || rel_path.length() == 0 {
      continue
    }
    let sub_path = root + "/" + rel_path
    let sub_git = sub_path + "/.git"
    let sub_git_dir = if rfs.is_file(sub_git) {
      @gitlib.resolve_gitdir(rfs, sub_git)
    } else if rfs.is_dir(sub_git) {
      sub_git
    } else {
      continue
    }
    match @gitlib.resolve_head_commit(rfs, sub_git_dir) {
      Some(id) => update_submodule_index_entry(fs, git_dir, rel_path, id)
      None => ()
    }
  }
}
