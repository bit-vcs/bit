///| git filter-branch — delegates to real git (deprecated command)

///|
async fn handle_filter_branch(args : Array[String]) -> Unit raise Error {
  if git_fallback_disabled() {
    exit_no_git_fallback("git filter-branch")
  }
  eprint_line(
    "WARNING: git filter-branch is deprecated. Use git-filter-repo instead.",
  )
  let argv : Array[String] = ["filter-branch"]
  for arg in args {
    argv.push(arg)
  }
  let cwd = @env.current_dir().unwrap_or(".")
  let code = @process.run(
    resolve_real_git_for_dispatch(),
    argv,
    inherit_env=true,
    cwd~,
    stdin=@stdio.stdin,
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  @sys.exit(code)
}
