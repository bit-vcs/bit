///|
async fn handle_fetch(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@git.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let (remotes, _) = @gitlib.read_repo_config(fs, git_dir)
  // Read remote URL - prefer subdir-clone remote, then config
  let mut remote_name = "origin"
  let mut remote_url : String? = get_effective_remote_url(fs, git_dir)
  let mut has_filter_flag = false
  let mut update_head_ok = false
  let positional_args : Array[String] = []
  // Override with command line argument
  for arg in args {
    if arg == "--no-ipv4" || arg == "--no-ipv6" {
      raise @git.GitError::InvalidObject(
        "unknown option '" + option_name_without_prefix(arg) + "'",
      )
    }
    if not(arg.has_prefix("-")) {
      positional_args.push(arg)
      continue
    }
    if arg.has_prefix("--filter") || arg == "--refetch" || arg == "--no-filter" {
      has_filter_flag = true
      continue
    }
    if arg == "-u" || arg == "--update-head-ok" {
      update_head_ok = true
      continue
    }
    if arg == "--prune" ||
      arg == "-p" ||
      arg == "--prune-tags" ||
      arg == "--tags" ||
      arg == "--no-tags" {
      continue
    }
    warn_unimplemented_arg("fetch", arg)
  }
  let explicit_refspecs : Array[String] = []
  let mut legacy_fetch_target : String? = None
  if positional_args.length() > 0 {
    let first = positional_args[0]
    match remotes.get(first) {
      Some(rc) => {
        remote_name = first
        if rc.urls.length() > 0 {
          remote_url = Some(rc.urls[0])
        }
      }
      None =>
        match parse_legacy_branches_entry(fs, git_dir, first) {
          Some((legacy_url, legacy_branch)) => {
            remote_name = first
            remote_url = Some(legacy_url)
            let branch = match legacy_branch {
              Some(name) => name
              None => legacy_default_branch_name()
            }
            legacy_fetch_target = Some(branch)
          }
          None => remote_url = Some(first)
        }
    }
    let mut i = 1
    while i < positional_args.length() {
      let token = positional_args[i]
      if token == "tag" {
        if i + 1 >= positional_args.length() {
          raise @git.GitError::InvalidObject("fetch tag requires tag name")
        }
        let tag_name = positional_args[i + 1]
        if tag_name.length() == 0 {
          raise @git.GitError::InvalidObject("fetch tag requires tag name")
        }
        let tag_ref = "refs/tags/" + tag_name
        explicit_refspecs.push(tag_ref + ":" + tag_ref)
        i += 2
        continue
      }
      explicit_refspecs.push(token)
      i += 1
    }
  }
  if explicit_refspecs.length() == 0 && legacy_fetch_target is Some(branch) {
    explicit_refspecs.push(
      "refs/heads/" + branch + ":refs/heads/" + remote_name,
    )
  }
  guard remote_url is Some(url) else {
    raise @git.GitError::InvalidObject("No remote configured")
  }
  let rewrite_rules = read_url_rewrite_rules(fs, git_dir)
  let resolved_url = rewrite_url_by_rules(url, rewrite_rules, false)
  let mut is_partial_clone = false
  match remotes.get(remote_name) {
    Some(rc) =>
      if rc.promisor || rc.partial_clone_filter is Some(_) {
        is_partial_clone = true
      }
    None => ()
  }
  let local_root = match @sys.get_env_var("GIT_SHIM_CWD") {
    Some(dir) => dir
    None => root
  }
  let local_promisor_remote = match
    @gitlib.resolve_local_repo_path(fs, local_root, resolved_url) {
    Some(src_path) => has_promisor_source_repo(fs, src_path)
    None => false
  }
  if has_filter_flag || is_partial_clone || local_promisor_remote {
    ()
  }
  fetch_from_remote(
    fs,
    git_dir,
    root,
    remote_name,
    resolved_url,
    explicit_refspecs,
    update_head_ok~,
  )
}

///|
fn find_submodule_replaced_with_non_submodule(
  from_modes : Map[String, Int],
  to_modes : Map[String, Int],
) -> String? {
  for path, mode in from_modes {
    if mode != 0o160000 {
      continue
    }
    match to_modes.get(path) {
      Some(next_mode) => if next_mode != 0o160000 { return Some(path) }
      None => ()
    }
  }
  None
}

///|
fn resolve_initial_pull_head_target(branch_name : String?) -> String {
  match branch_name {
    Some(branch) => "refs/heads/" + branch
    None => "HEAD"
  }
}

///|
fn collect_commit_tree_modes(
  db : @gitlib.ObjectDb,
  fs : &@git.RepoFileSystem,
  commit_id : @git.ObjectId,
) -> Map[String, Int] raise @git.GitError {
  let files = @gitlib.collect_tree_files_from_commit(db, fs, commit_id)
  let modes : Map[String, Int] = {}
  for path, entry in files {
    modes[path] = entry.mode
  }
  modes
}

///|
