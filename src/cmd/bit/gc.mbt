///|
async fn handle_gc(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let mut prune_only = false
  let mut aggressive = false
  let mut quiet = false
  for arg in args {
    match arg {
      "--prune" => prune_only = true
      "--aggressive" => aggressive = true
      "-q" | "--quiet" => quiet = true
      _ if arg.has_prefix("-") => warn_unimplemented_arg("gc", arg)
      _ => ()
    }
  }
  ignore(aggressive) // Not yet implemented, treat as regular gc
  if prune_only {
    let result = @bitlib.prune_repo(fs, fs, root)
    if not(quiet) && result.pruned.length() > 0 {
      print_line("Pruned \{result.pruned.length()} unreachable objects")
    }
    return
  }
  let result = @bitlib.gc_repo(fs, fs, root)
  if not(quiet) {
    match result.pack {
      Some(pack) =>
        print_line(
          "Repacked \{pack.object_count} objects into pack-\{pack.pack_id.to_hex()[:8].to_string()}",
        )
      None => ()
    }
    if result.dangling.length() > 0 {
      print_line("Found \{result.dangling.length()} dangling objects")
    }
  }
  // Update commit-graph after gc (delegate to real git)
  let git_dir = resolve_git_dir(fs, root)
  let real_git = resolve_real_git_for_dispatch()
  ignore(
    @process.run(
      real_git,
      ["commit-graph", "write", "--reachable", "--changed-paths"],
      cwd=root,
      extra_env={ "GIT_DIR": git_dir },
    ),
  )
}

///|
