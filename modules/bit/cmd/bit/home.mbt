///| `bit home`: the Home Repo pattern.
///
/// One repository (the Home Repo) holds AGENTS.md, skills and shared docs,
/// and points at every other repository a project spans (`bit-home.toml`).
/// `bit home` keeps those pointers in AGENTS.md and treats the whole set as
/// one virtual repository: `sync` clones what is missing and fast-forwards
/// the rest in one go, `status` summarizes all of them, and `wt` creates a
/// per-feature worktree inside any of them. An entry with `subdir` is a
/// sparse checkout of that one directory.

///|
async fn print_home_usage() -> Unit {
  let usage =
    #|Usage: bit home <command> [options]
    #|
    #|Home Repo pattern: one repository holds AGENTS.md, skills and shared docs
    #|and points at the other repositories a project spans (bit-home.toml).
    #|The whole set is handled like one virtual repository.
    #|
    #|Commands:
    #|  init [<dir>]          Create a Home Repo (bit-home.toml, AGENTS.md, CLAUDE.md)
    #|  add [<url>] --path <dir> [--name <n>] [--description <d>]
    #|                        [--branch <b>] [--subdir <d>] [--notes <text>]
    #|                        Add a repository pointer and re-render AGENTS.md
    #|  rm <name>...          Remove repository pointers (the clones stay on disk)
    #|  render [--check]      Regenerate the "Other Repos" section of AGENTS.md
    #|  sync [<name>...] [-j <n>]
    #|                        Clone missing repositories, fast-forward the rest
    #|                        (the Home Repo itself included); --subdir entries
    #|                        are sparse checkouts of that directory
    #|  status [<name>...] [--json]
    #|                        Branch / upstream / changes / worktrees of every repository
    #|  wt add <name>[,<name>...] <feature> [--base <ref>]
    #|  wt add --all <feature> [--base <ref>]
    #|                        Worktree for a feature inside each repository's clone
    #|                        (<path>/.worktrees/<feature>, branch <feature>)
    #|  wt list [<name>...] [--feature <f>] [--json]
    #|                        List worktrees (--feature: only those on branch <f>)
    #|  wt remove <name>[,<name>...] <feature> [--force]
    #|  wt remove --all <feature> [--force]
    #|                        Remove a feature worktree (--all: wherever it exists)
    #|  exec [<name>...] [--home] [-q] [-j <n>] -- <command> [<arg>...]
    #|  exec [<name>...] [--home] [-q] [-j <n>] -c '<shell command>'
    #|                        Run a command in each cloned repository (cwd = clone;
    #|                        BIT_HOME_REPO / BIT_HOME_REPO_PATH are set); exit 1
    #|                        if it fails in any. -j runs <n> at a time, output
    #|                        replayed per repository
    #|
    #|The Home Repo is found by walking up from the current directory to the
    #|first bit-home.toml (override with BIT_HOME_ROOT).
    #|
    #|Examples:
    #|  bit home init ~/repos/acme/home
    #|  bit home add git@github.com:acme/storefront.git --path ~/repos/acme/storefront \
    #|      --description "Next.js app" --notes "Read its AGENTS.md before changing it."
    #|  bit home add https://github.com/acme/mono.git --path ~/repos/acme/mono-web --subdir apps/web
    #|  bit home sync
    #|  bit home status
    #|  bit home wt add storefront checkout-redesign
    #|  bit home wt add storefront,payments-api checkout-redesign
    #|  bit home exec -- git log -1 --oneline
    #|  bit home exec storefront payments-api -c 'make test'
  print_line(usage)
}

///|
fn home_cwd() -> String {
  match @env.get_env_var("GIT_SHIM_CWD") {
    Some(dir) => dir
    None =>
      match @env.get_env_var("GIT_SHIM_PWD") {
        Some(dir) => dir
        None => @env.current_dir().unwrap_or(".")
      }
  }
}

///|
fn home_user_dir() -> String {
  @env.get_env_var("HOME").unwrap_or("/")
}

///|
/// `$HOME/x` -> `~/x` (other paths unchanged).
fn home_contract_user_dir(path : String) -> String {
  let home = normalize_path(home_user_dir())
  if home == "/" || home.length() == 0 {
    return path
  }
  if path == home {
    "~"
  } else if path.has_prefix(home + "/") {
    "~/" + path.unsafe_substring(start=home.length() + 1, end=path.length())
  } else {
    path
  }
}

///|
fn home_absolute(path : String) -> String {
  if path.has_prefix("/") {
    path
  } else if path == "~" || path.has_prefix("~/") {
    @home.resolve_repo_path(path, home=home_user_dir(), home_repo_root="/")
  } else {
    let cwd = home_cwd()
    let rel = if path.has_prefix("./") {
      String::unsafe_substring(path, start=2, end=path.length())
    } else {
      path
    }
    if rel == "." || rel.length() == 0 {
      cwd
    } else {
      cwd + "/" + rel
    }
  }
}

///|
/// The Home Repo root: BIT_HOME_ROOT, else the nearest ancestor of the
/// current directory holding `bit-home.toml`.
fn find_home_root(fs : OsFs) -> String? {
  let rfs : &@bitcore.RepoFileSystem = fs
  match @env.get_env_var("BIT_HOME_ROOT") {
    Some(root) if root.length() > 0 => return Some(home_absolute(root))
    _ => ()
  }
  let mut dir = normalize_path(home_cwd())
  while true {
    if rfs.is_file(dir + "/" + @home.manifest_file_name) {
      return Some(dir)
    }
    let parent = get_parent_dir(dir)
    if parent == dir || parent == "." {
      break
    }
    dir = parent
  }
  None
}

///|
async fn require_home_root(fs : OsFs) -> String raise Error {
  match find_home_root(fs) {
    Some(root) => root
    None => {
      eprint_line(
        "fatal: not inside a Home Repo (no \{@home.manifest_file_name} found); run `bit home init` or set BIT_HOME_ROOT",
      )
      @sys.exit(128)
      ""
    }
  }
}

///|
async fn load_home_manifest(
  fs : OsFs,
  root : String,
) -> @home.HomeManifest raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let content = decode_bytes(
    rfs.read_file(root + "/" + @home.manifest_file_name),
  )
  @home.parse_manifest(content) catch {
    err => {
      eprint_line("fatal: \{err.message()}")
      @sys.exit(128)
      { repos: [] }
    }
  }
}

///|
fn home_repo_abs(root : String, repo : @home.HomeRepo) -> String {
  normalize_path(
    @home.resolve_repo_path(repo.path, home=home_user_dir(), home_repo_root=root),
  )
}

///|
/// Repositories named on the command line, in manifest order; all of them
/// when none are named. Unknown names are fatal.
async fn home_select_repos(
  manifest : @home.HomeManifest,
  names : Array[String],
) -> Array[@home.HomeRepo] raise Error {
  if names.length() == 0 {
    return manifest.repos
  }
  for name in names {
    if manifest.find(name) is None {
      eprint_line("fatal: no repository named '\{name}' in \{@home.manifest_file_name}")
      @sys.exit(128)
    }
  }
  manifest.repos.filter(r => names.contains(r.name))
}

///|
/// Run `cmd` with captured stdout / stderr (no terminal input).
async fn home_run_captured(
  cmd : String,
  args : Array[String],
  cwd : String,
  env : Map[String, String],
) -> (Int, Bytes, Bytes) {
  let result = @process.run(
    cmd,
    args[:],
    extra_env=env,
    inherit_env=true,
    stdout=Collect,
    stderr=Collect,
    cwd~,
  ) catch {
    _ => return (127, b"", b"")
  }
  (result.exit_code, result.stdout_binary(), result.stderr_binary())
}

///|
/// Run `task(0..n)` with at most `jobs` running at once.
async fn home_parallel(jobs : Int, n : Int, task : async (Int) -> Unit) -> Unit {
  let width = if jobs < 1 { 1 } else { jobs }
  let mut start = 0
  while start < n {
    let end = if start + width < n { start + width } else { n }
    let first = start
    @async.with_task_group(group => {
      for i in first..<end {
        let _ = group.spawn(() => task(i))
      }
    })
    start = end
  }
}

///|
/// Split `-j N` / `-jN` / `--jobs N` / `--jobs=N` out of `args`.
async fn home_take_jobs(args : Array[String]) -> (Int, Array[String]) {
  let rest : Array[String] = []
  let mut jobs = 1
  let parse = async fn(v : String) -> Int {
    let n = @string.parse_int(v) catch { _ => 0 }
    if n < 1 {
      eprint_line("fatal: --jobs expects a positive number, got '\{v}'")
      @sys.exit(129)
    }
    n
  }
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    if (a == "-j" || a == "--jobs") && i + 1 < args.length() {
      jobs = parse(args[i + 1])
      i += 1
    } else if a.has_prefix("--jobs=") {
      jobs = parse(a.unsafe_substring(start=7, end=a.length()))
    } else if a.has_prefix("-j") && a.length() > 2 {
      jobs = parse(a.unsafe_substring(start=2, end=a.length()))
    } else {
      rest.push(a)
    }
    i += 1
  }
  (jobs, rest)
}

///|
async fn home_write_bytes(out : Bytes, err : Bytes) -> Unit {
  if out.length() > 0 {
    @stdio.stdout.write(out)
  }
  if err.length() > 0 {
    @stdio.stderr.write(err)
  }
}

///|
/// Worktrees of a clone from `worktree list --porcelain`, the main one
/// first: (absolute path, branch or None when detached).
async fn home_worktrees(abs : String) -> Array[(String, String?)] {
  let (code, out) = home_capture_bit(["-C", abs, "worktree", "list", "--porcelain"])
  let result : Array[(String, String?)] = []
  if code != 0 {
    return result
  }
  let mut path : String? = None
  let mut branch : String? = None
  let flush = fn() {
    match path {
      Some(p) => result.push((p, branch))
      None => ()
    }
  }
  for line_view in out.split("\n") {
    let line = line_view.to_owned()
    if line.has_prefix("worktree ") {
      flush()
      path = Some(line.unsafe_substring(start=9, end=line.length()))
      branch = None
    } else if line.has_prefix("branch refs/heads/") {
      branch = Some(line.unsafe_substring(start=18, end=line.length()))
    }
  }
  flush()
  result
}

///|
fn home_json_opt(v : String?) -> Json {
  match v {
    Some(s) => Json::string(s)
    None => Json::null()
  }
}

///|
/// Re-render the managed block of AGENTS.md. Returns whether it changed.
fn home_render_agents(
  fs : OsFs,
  root : String,
  manifest : @home.HomeManifest,
  write~ : Bool,
) -> Bool raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let agents_path = root + "/AGENTS.md"
  let existing = if rfs.is_file(agents_path) {
    decode_bytes(rfs.read_file(agents_path))
  } else {
    ""
  }
  let updated = if existing.length() == 0 {
    @home.agents_md_template(manifest)
  } else {
    @home.update_agents_md(existing, @home.render_agents_block(manifest))
  }
  if updated == existing {
    return false
  }
  if write {
    fs.write_string(agents_path, updated)
  }
  true
}

///|
async fn handle_home_init(fs : OsFs, args : Array[String]) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let positional = args.filter(a => !a.has_prefix("-"))
  let root = normalize_path(
    home_absolute(if positional.length() > 0 { positional[0] } else { "." }),
  )
  fs.mkdir_p(root)
  if !rfs.is_dir(root + "/.git") && !rfs.is_file(root + "/.git") {
    if home_run_bit(["init", "-q", root]) != 0 {
      eprint_line("fatal: failed to initialize \{root}")
      @sys.exit(128)
    }
  }
  let manifest_path = root + "/" + @home.manifest_file_name
  if !rfs.is_file(manifest_path) {
    fs.write_string(manifest_path, @home.manifest_template)
    print_line("created \{@home.manifest_file_name}")
  }
  let manifest = load_home_manifest(fs, root)
  let had_agents = rfs.is_file(root + "/AGENTS.md")
  if home_render_agents(fs, root, manifest, write=true) {
    print_line(if had_agents { "updated AGENTS.md" } else { "created AGENTS.md" })
  }
  let claude_path = root + "/CLAUDE.md"
  if !rfs.is_file(claude_path) {
    fs.write_string(claude_path, @home.claude_md_pointer)
    print_line("created CLAUDE.md (imports AGENTS.md)")
  } else if !decode_bytes(rfs.read_file(claude_path)).contains("AGENTS.md") {
    eprint_line(
      "hint: CLAUDE.md does not reference AGENTS.md; add a line `@AGENTS.md` so Claude Code loads the repo pointers",
    )
  }
  print_line("Home Repo ready at \{contract_path_hq(root)}")
  print_line("next: bit home add <url> --path <dir>")
}

///|
async fn handle_home_add(fs : OsFs, args : Array[String]) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let root = require_home_root(fs)
  let mut url : String? = None
  let mut path : String? = None
  let mut name : String? = None
  let mut description : String? = None
  let mut branch : String? = None
  let mut subdir : String? = None
  let mut notes : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    let value = fn() -> String? {
      if i + 1 < args.length() {
        Some(args[i + 1])
      } else {
        None
      }
    }
    match arg {
      "--path" | "--name" | "--description" | "--branch" | "--subdir" | "--notes" => {
        guard value() is Some(v) else {
          eprint_line("fatal: \{arg} requires a value")
          @sys.exit(129)
        }
        match arg {
          "--path" => path = Some(v)
          "--name" => name = Some(v)
          "--description" => description = Some(v)
          "--branch" => branch = Some(v)
          "--subdir" => subdir = Some(v)
          _ => notes = Some(v)
        }
        i += 1
      }
      _ if arg.has_prefix("-") => {
        eprint_line("fatal: unknown option '\{arg}'")
        @sys.exit(129)
      }
      _ =>
        if url is None {
          url = Some(arg)
        } else {
          eprint_line("fatal: unexpected argument '\{arg}'")
          @sys.exit(129)
        }
    }
    i += 1
  }
  guard path is Some(repo_path) else {
    eprint_line(
      "fatal: --path is required (where the clone lives, e.g. ~/repos/acme/storefront)",
    )
    @sys.exit(129)
    return
  }
  // A shell expands an unquoted `~/...`; store such paths as `~/...` again
  // so the manifest stays shareable across machines and users.
  let repo_path = home_contract_user_dir(repo_path)
  let repo : @home.HomeRepo = {
    name: name.unwrap_or(@home.path_basename(repo_path)),
    path: repo_path,
    url,
    description,
    branch,
    subdir,
    notes,
  }
  let manifest_path = root + "/" + @home.manifest_file_name
  let current = decode_bytes(rfs.read_file(manifest_path))
  let sep = if current.length() == 0 || current.has_suffix("\n\n") {
    ""
  } else if current.has_suffix("\n") {
    "\n"
  } else {
    "\n\n"
  }
  let updated = current + sep + @home.repo_toml_block(repo)
  // Validate the result (duplicate names, bad subdir, ...) before writing.
  let manifest = @home.parse_manifest(updated) catch {
    err => {
      eprint_line("fatal: \{err.message()}")
      @sys.exit(128)
      return
    }
  }
  fs.write_string(manifest_path, updated)
  ignore(home_render_agents(fs, root, manifest, write=true))
  print_line("added '\{repo.name}' -> \{repo.path}")
  print_line("run `bit home sync \{repo.name}` to clone it")
}

///|
/// `bit home rm <name>...`: drop repositories from bit-home.toml (their
/// `[[repo]]` table and the comment lines right above it) and re-render
/// AGENTS.md. Clones are left on disk.
async fn handle_home_rm(fs : OsFs, args : Array[String]) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let names = args.filter(a => !a.has_prefix("-"))
  for a in args {
    if a.has_prefix("-") {
      eprint_line("fatal: unknown option '\{a}'")
      @sys.exit(129)
    }
  }
  if names.length() == 0 {
    eprint_line("usage: bit home rm <name>...")
    @sys.exit(129)
  }
  let root = require_home_root(fs)
  let manifest = load_home_manifest(fs, root)
  let removed = home_select_repos(manifest, names)
  let manifest_path = root + "/" + @home.manifest_file_name
  let lines = decode_bytes(rfs.read_file(manifest_path))
    .split("\n")
    .map(l => l.to_owned())
    .to_array()
  // Split into chunks, each starting at the comment lines above a
  // `[[repo]]` header (the first chunk is the preamble).
  let chunks : Array[Array[String]] = [[]]
  for line in lines {
    if line.trim(chars=" \t").to_owned() == "[[repo]]" {
      // Move the trailing comment lines of the previous chunk along.
      let prev = chunks[chunks.length() - 1]
      let moved : Array[String] = []
      while prev.length() > 0 &&
        prev[prev.length() - 1].trim(chars=" \t").has_prefix("#") {
        moved.push(prev.unsafe_pop())
      }
      moved.rev_in_place()
      moved.push(line)
      chunks.push(moved)
    } else {
      chunks[chunks.length() - 1].push(line)
    }
  }
  let kept : Array[String] = []
  for idx, chunk in chunks {
    let drop = idx > 0 &&
      (
        @home.parse_manifest(chunk.join("\n")) catch {
          _ => { repos: [] }
        }
      ).repos
      .iter()
      .any(r => removed.iter().any(x => x.name == r.name))
    if !drop {
      kept.append(chunk)
    }
  }
  let updated = kept.join("\n")
  let next = @home.parse_manifest(updated) catch {
    err => {
      eprint_line("fatal: \{err.message()}")
      @sys.exit(128)
      return
    }
  }
  if next.repos.length() != manifest.repos.length() - removed.length() {
    eprint_line("fatal: could not remove the entries cleanly; edit \{@home.manifest_file_name} by hand")
    @sys.exit(128)
  }
  fs.write_string(manifest_path, updated)
  ignore(home_render_agents(fs, root, next, write=true))
  for repo in removed {
    print_line(
      "removed '\{repo.name}' (clone left at \{contract_path_hq(home_repo_abs(root, repo))})",
    )
  }
}

///|
async fn handle_home_render(fs : OsFs, args : Array[String]) -> Unit raise Error {
  let root = require_home_root(fs)
  let manifest = load_home_manifest(fs, root)
  let check = args.contains("--check")
  let changed = home_render_agents(fs, root, manifest, write=!check)
  if check {
    if changed {
      eprint_line(
        "AGENTS.md is out of date with \{@home.manifest_file_name}; run `bit home render`",
      )
      @sys.exit(1)
    }
    print_line("AGENTS.md is up to date")
  } else if changed {
    print_line("updated AGENTS.md")
  } else {
    print_line("AGENTS.md already up to date")
  }
}

///|
/// Run this bit binary as a child process and capture stdout (status
/// output cannot be captured from the in-process command runner).
async fn home_capture_bit(args : Array[String]) -> (Int, String) {
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
/// Run this bit binary as a child process with the terminal's stdio.
/// A child (rather than the in-process runner) supports every command and
/// keeps each repository's environment separate.
async fn home_run_bit(args : Array[String]) -> Int {
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
async fn home_capture_trimmed(args : Array[String]) -> String? {
  let (code, out) = home_capture_bit(args)
  if code != 0 {
    return None
  }
  let v = out.trim(chars=" \t\r\n").to_owned()
  if v.length() == 0 {
    None
  } else {
    Some(v)
  }
}

///|
async fn home_repo_status(abs : String) -> @home.RepoStatus? {
  let (code, out) = home_capture_bit([
    "-C", abs, "status", "--porcelain", "--branch",
  ])
  if code != 0 {
    return None
  }
  let status = @home.parse_porcelain_status(out)
  guard status.branch is Some(branch) else { return Some(status) }
  let remote = home_capture_trimmed([
    "-C", abs, "config", "branch.\{branch}.remote",
  ])
  let merge = home_capture_trimmed([
    "-C", abs, "config", "branch.\{branch}.merge",
  ])
  guard (remote, merge) is (Some(r), Some(m)) &&
    @home.upstream_from_config(r, m) is Some((name, upstream_ref)) else {
    return Some(status)
  }
  let count = async fn(range : String) -> Int? {
    match home_capture_trimmed(["-C", abs, "rev-list", "--count", range]) {
      Some(v) => Some(@string.parse_int(v) catch { _ => 0 })
      None => None
    }
  }
  match (count(upstream_ref + "..HEAD"), count("HEAD.." + upstream_ref)) {
    (Some(ahead), Some(behind)) =>
      Some({ ..status, upstream: Some(name), ahead, behind })
    // The upstream ref does not exist (never fetched, or deleted).
    _ => Some({ ..status, upstream: Some(name + " (gone)") })
  }
}

///|
fn home_is_git_worktree(fs : OsFs, abs : String) -> Bool {
  let rfs : &@bitcore.RepoFileSystem = fs
  rfs.is_dir(abs + "/.git") || rfs.is_file(abs + "/.git")
}

///|
/// Apply (or re-apply) the cone-mode sparse checkout of `subdir`.
async fn home_apply_sparse(abs : String, subdir : String) -> Bool {
  home_run_bit(["-C", abs, "sparse-checkout", "init", "--cone"]) ==
  0 &&
  // Cone mode takes directories, not patterns: git rejects "/dir/".
  home_run_bit(["-C", abs, "sparse-checkout", "set", "--", subdir]) == 0
}

///|
/// Number of tracked (staged or unstaged) changes, untracked files aside.
async fn home_tracked_changes(abs : String) -> Int? {
  let (code, out) = home_capture_bit([
    "-C", abs, "status", "--porcelain", "--untracked-files=no",
  ])
  if code != 0 {
    return None
  }
  let mut n = 0
  for line in out.split("\n") {
    if line.length() > 0 {
      n += 1
    }
  }
  Some(n)
}

///|
/// Whether `abs` currently is a sparse checkout.
async fn home_is_sparse(abs : String) -> Bool {
  // `sparse-checkout list` fails with "this worktree is not sparse".
  let (code, _) = home_capture_bit(["-C", abs, "sparse-checkout", "list"])
  code == 0
}

///|
/// Clone or fast-forward one repository. Returns false on failure.
async fn home_sync_one(
  fs : OsFs,
  name : String,
  abs : String,
  url : String?,
  branch : String?,
  subdir : String?,
) -> Bool {
  let rfs : &@bitcore.RepoFileSystem = fs
  if !rfs.is_dir(abs) {
    guard url is Some(clone_url) else {
      eprint_line("\{name}: missing at \{contract_path_hq(abs)} and no `url` to clone from")
      return false
    }
    print_line("\{name}: cloning \{clone_url} -> \{contract_path_hq(abs)}")
    fs.mkdir_p(get_parent_dir(abs)) catch {
      _ => ()
    }
    // A plain clone followed by `sparse-checkout set`: the checkout is
    // trimmed to `subdir` right after cloning.
    let clone_args = ["clone", "-q"]
    if branch is Some(b) {
      clone_args.push("--branch")
      clone_args.push(b)
    }
    clone_args.push(clone_url)
    clone_args.push(abs)
    if home_run_bit(clone_args) != 0 {
      eprint_line("\{name}: clone failed")
      return false
    }
    if subdir is Some(dir) {
      if !home_apply_sparse(abs, dir) {
        eprint_line("\{name}: sparse checkout of \{dir}/ failed")
        return false
      }
    }
    return true
  }
  if !home_is_git_worktree(fs, abs) {
    eprint_line("\{name}: \{contract_path_hq(abs)} exists but is not a git repository")
    return false
  }
  // Only tracked changes block a sync (untracked files are left alone and
  // never in the way of a fast-forward's checks). A dirty repository is not
  // touched at all -- not even its sparse checkout.
  match home_tracked_changes(abs) {
    Some(n) if n > 0 => {
      // Fetch anyway, so `status` reports how far behind it is.
      let fetched = home_capture_trimmed(["-C", abs, "remote"]) is Some(_) &&
        home_capture_bit(["-C", abs, "fetch", "-q"]).0 == 0
      let note = if fetched { "fetched; " } else { "" }
      print_line(
        "\{name}: \{n} local change(s); \{note}not updating the checkout (commit or stash first)",
      )
      return true
    }
    Some(_) => ()
    None => {
      eprint_line("\{name}: could not read status")
      return false
    }
  }
  // The checkout follows the manifest: a cone for `subdir`, a full
  // checkout without one (disabling an earlier sparse checkout).
  match subdir {
    Some(dir) =>
      if !home_apply_sparse(abs, dir) {
        eprint_line("\{name}: sparse checkout of \{dir}/ failed")
        return false
      }
    None =>
      if home_is_sparse(abs) &&
        home_run_bit(["-C", abs, "sparse-checkout", "disable"]) != 0 {
        eprint_line("\{name}: disabling the sparse checkout failed")
        return false
      }
  }
  match home_repo_status(abs) {
    None => {
      eprint_line("\{name}: could not read status")
      false
    }
    Some(status) =>
      if status.upstream is None {
        if home_capture_trimmed(["-C", abs, "remote"]) is None {
          print_line("\{name}: no remote; nothing to sync")
          true
        } else {
          print_line("\{name}: no upstream branch; fetching only")
          home_run_bit(["-C", abs, "fetch", "-q"]) == 0
        }
      } else if home_run_bit(["-C", abs, "pull", "-q", "--ff-only"]) ==
        0 {
        print_line("\{name}: up to date")
        true
      } else {
        eprint_line("\{name}: fast-forward failed (diverged from upstream?)")
        false
      }
  }
}

///|
async fn handle_home_sync(fs : OsFs, args : Array[String]) -> Unit raise Error {
  let root = require_home_root(fs)
  let manifest = load_home_manifest(fs, root)
  let (jobs, args) = home_take_jobs(args)
  for a in args {
    if a.has_prefix("-") {
      eprint_line("fatal: unknown option '\{a}'")
      @sys.exit(129)
    }
  }
  let names = args
  let repos = home_select_repos(manifest, names)
  let mut failed = 0
  // The Home Repo itself is part of the virtual repository.
  if names.length() == 0 {
    if !home_sync_one(fs, "(home)", root, None, None, None) {
      failed += 1
    }
  }
  if jobs > 1 && repos.length() > 1 {
    // Each repository is synced by a child `bit home sync <name>` whose
    // output is replayed in manifest order once it finishes.
    let codes = Array::make(repos.length(), 0)
    let outs = Array::make(repos.length(), b"")
    let errs = Array::make(repos.length(), b"")
    let env : Map[String, String] = Map([])
    env["BIT_HOME_ROOT"] = root
    env["BIT_HOME_SYNC_CHILD"] = "1"
    home_parallel(jobs, repos.length(), async fn(i) {
      let (code, out, err) = home_run_captured(
        @env.args()[0],
        ["home", "sync", repos[i].name],
        root,
        env,
      )
      codes[i] = code
      outs[i] = out
      errs[i] = err
    })
    for i, code in codes {
      home_write_bytes(outs[i], errs[i])
      if code != 0 {
        failed += 1
      }
    }
  } else {
    for repo in repos {
      let abs = home_repo_abs(root, repo)
      if !home_sync_one(fs, repo.name, abs, repo.url, repo.branch, repo.subdir) {
        failed += 1
      }
    }
  }
  if failed > 0 && @env.get_env_var("BIT_HOME_SYNC_CHILD") is Some(_) {
    @sys.exit(1)
  }
  if failed > 0 {
    eprint_line("bit home sync: \{failed} repositor\{if failed == 1 { "y" } else { "ies" }} failed")
    @sys.exit(1)
  }
}

///|
async fn handle_home_status(fs : OsFs, args : Array[String]) -> Unit raise Error {
  let root = require_home_root(fs)
  let manifest = load_home_manifest(fs, root)
  let json = args.contains("--json")
  for a in args {
    if a.has_prefix("-") && a != "--json" {
      eprint_line("fatal: unknown option '\{a}'")
      @sys.exit(129)
    }
  }
  let names = args.filter(a => !a.has_prefix("-"))
  let repos = home_select_repos(manifest, names)
  // (name, abs, subdir) of every row, the Home Repo first.
  let targets : Array[(String, String, String?)] = []
  if names.length() == 0 {
    targets.push(("(home)", root, None))
  }
  for repo in repos {
    targets.push((repo.name, home_repo_abs(root, repo), repo.subdir))
  }
  let rows : Array[(String, String, String)] = []
  let records : Array[Json] = []
  for target in targets {
    let (name, abs, subdir) = target
    let record : Map[String, Json] = Map([])
    record["name"] = Json::string(name)
    record["path"] = Json::string(abs)
    record["sparse"] = home_json_opt(subdir)
    let desc = if !fs.is_dir(abs) {
      record["state"] = Json::string("missing")
      "missing (run `bit home sync \{name}`)"
    } else if !home_is_git_worktree(fs, abs) {
      record["state"] = Json::string("not-a-repository")
      "not a git repository"
    } else {
      match home_repo_status(abs) {
        Some(st) => {
          record["state"] = Json::string("ok")
          record["branch"] = home_json_opt(st.branch)
          record["upstream"] = home_json_opt(st.upstream)
          record["ahead"] = Json::number(st.ahead.to_double())
          record["behind"] = Json::number(st.behind.to_double())
          record["changes"] = Json::number(st.changes.to_double())
          let wts = home_worktrees(abs)
          let linked : Array[Json] = []
          for idx, wt in wts {
            if idx == 0 {
              continue
            }
            let w : Map[String, Json] = Map([])
            w["path"] = Json::string(wt.0)
            w["branch"] = home_json_opt(wt.1)
            linked.push(Json::object(w))
          }
          record["worktrees"] = Json::array(linked)
          let parts = [@home.describe_status(st)]
          match subdir {
            Some(d) => parts.push("sparse \{d}/")
            None => ()
          }
          if linked.length() > 0 {
            parts.push(
              "\{linked.length()} worktree\{if linked.length() == 1 { "" } else { "s" }}",
            )
          }
          parts.join(", ")
        }
        None => {
          record["state"] = Json::string("error")
          "could not read status"
        }
      }
    }
    records.push(Json::object(record))
    rows.push((name, contract_path_hq(abs), desc))
  }
  if json {
    print_line(Json::array(records).stringify())
    return
  }
  home_print_table(rows)
}

///|
/// Print rows as aligned columns (the last one unpadded).
async fn home_print_table(rows : Array[(String, String, String)]) -> Unit {
  let mut name_w = 0
  let mut path_w = 0
  for row in rows {
    if row.0.length() > name_w {
      name_w = row.0.length()
    }
    if row.1.length() > path_w {
      path_w = row.1.length()
    }
  }
  let pad = fn(s : String, w : Int) -> String {
    let sb = StringBuilder()
    sb.write_string(s)
    for _ in s.length()..<w {
      sb.write_char(' ')
    }
    sb.to_string()
  }
  for row in rows {
    print_line("\{pad(row.0, name_w)}  \{pad(row.1, path_w)}  \{row.2}")
  }
}

///|
/// Keep `.worktrees/` out of `git status` in the repository without
/// touching tracked files: add it to `<git-dir>/info/exclude`.
fn home_exclude_worktrees_dir(fs : OsFs, abs : String) -> Unit {
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = @bitlib.resolve_gitdir(rfs, abs + "/.git")
  let common = @bitlib.resolve_common_git_dir(rfs, git_dir)
  let exclude_path = common + "/info/exclude"
  let pattern = "/" + @home.worktrees_dir_name + "/"
  let existing = if rfs.is_file(exclude_path) {
    decode_bytes(rfs.read_file(exclude_path) catch { _ => b"" })
  } else {
    ""
  }
  for line in existing.split("\n") {
    if line.to_owned().trim(chars=" \t").to_owned() == pattern {
      return
    }
  }
  let sep = if existing.length() == 0 || existing.has_suffix("\n") {
    ""
  } else {
    "\n"
  }
  fs.mkdir_p(common + "/info") catch {
    _ => ()
  }
  fs.write_string(exclude_path, existing + sep + pattern + "\n") catch {
    _ => ()
  }
}

///|
async fn handle_home_wt(fs : OsFs, args : Array[String]) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  if args.length() == 0 {
    print_home_usage()
    @sys.exit(129)
  }
  let sub = args[0]
  let rest = collect_args(args, 1)
  let root = require_home_root(fs)
  let manifest = load_home_manifest(fs, root)
  match sub {
    "add" => {
      let mut base : String? = None
      let mut all = false
      let positional : Array[String] = []
      let mut i = 0
      while i < rest.length() {
        if rest[i] == "--base" && i + 1 < rest.length() {
          base = Some(rest[i + 1])
          i += 1
        } else if rest[i] == "--all" {
          all = true
        } else if rest[i].has_prefix("-") {
          eprint_line("fatal: unknown option '\{rest[i]}'")
          @sys.exit(129)
        } else {
          positional.push(rest[i])
        }
        i += 1
      }
      let (names, feature) = home_wt_targets(positional, all, "add", "[--base <ref>]")
      let repos = home_select_repos(manifest, names)
      let mut failed = 0
      for repo in repos {
        if !home_wt_add_one(fs, root, repo, feature, base) {
          failed += 1
        }
      }
      if failed > 0 {
        if repos.length() > 1 {
          eprint_line("bit home wt add: \{failed} of \{repos.length()} repositories failed")
        }
        @sys.exit(128)
      }
    }
    "list" => {
      let json = rest.contains("--json")
      let mut feature : String? = None
      let names : Array[String] = []
      let mut i = 0
      while i < rest.length() {
        let a = rest[i]
        if a == "--feature" && i + 1 < rest.length() {
          feature = Some(rest[i + 1])
          i += 1
        } else if a == "--json" {
          ()
        } else if a.has_prefix("-") {
          eprint_line("fatal: unknown option '\{a}'")
          @sys.exit(129)
        } else {
          names.push(a)
        }
        i += 1
      }
      let rows : Array[(String, String, String)] = []
      let records : Array[Json] = []
      for repo in home_select_repos(manifest, names) {
        let abs = home_repo_abs(root, repo)
        if !home_is_git_worktree(fs, abs) {
          continue
        }
        for idx, wt in home_worktrees(abs) {
          let (path, branch) = wt
          // --feature: the repositories working on that feature only.
          if feature is Some(f) && branch != Some(f) {
            continue
          }
          let w : Map[String, Json] = Map([])
          w["repo"] = Json::string(repo.name)
          w["path"] = Json::string(path)
          w["branch"] = home_json_opt(branch)
          w["main"] = Json::boolean(idx == 0)
          records.push(Json::object(w))
          let label = match branch {
            Some(b) => "[\{b}]"
            None => "(detached)"
          }
          rows.push((repo.name, contract_path_hq(path), label))
        }
      }
      if json {
        print_line(Json::array(records).stringify())
      } else {
        home_print_table(rows)
      }
    }
    "remove" => {
      let force = rest.contains("--force") || rest.contains("-f")
      let all = rest.contains("--all")
      for a in rest {
        if a.has_prefix("-") && a != "--force" && a != "-f" && a != "--all" {
          eprint_line("fatal: unknown option '\{a}'")
          @sys.exit(129)
        }
      }
      let positional = rest.filter(a => !a.has_prefix("-"))
      let (names, feature) = home_wt_targets(positional, all, "remove", "[--force]")
      let repos = home_select_repos(manifest, names)
      let mut failed = 0
      let mut removed = 0
      for repo in repos {
        let abs = home_repo_abs(root, repo)
        // With --all, only the repositories that have this worktree.
        if all && !rfs.is_dir(@home.worktree_path(abs, feature)) {
          continue
        }
        if home_wt_remove_one(fs, root, repo, feature, force) {
          removed += 1
        } else {
          failed += 1
        }
      }
      if all && removed == 0 && failed == 0 {
        eprint_line("bit home wt remove: no repository has a worktree '\{feature}'")
        @sys.exit(128)
      }
      if failed > 0 {
        @sys.exit(128)
      }
    }
    _ => {
      eprint_line("bit home wt: unknown subcommand '\{sub}'")
      @sys.exit(129)
    }
  }
}

///|
/// `wt add|remove` targets: `<name>[,<name>...] <feature>`, or
/// `--all <feature>` for every repository in the manifest.
async fn home_wt_targets(
  positional : Array[String],
  all : Bool,
  sub : String,
  options : String,
) -> (Array[String], String) {
  let usage = "usage: bit home wt \{sub} <name>[,<name>...] <feature> \{options}\n" +
    "   or: bit home wt \{sub} --all <feature> \{options}"
  let (names, feature) = if all {
    if positional.length() != 1 {
      eprint_line(usage)
      @sys.exit(129)
    }
    ([], positional[0])
  } else {
    if positional.length() != 2 {
      eprint_line(usage)
      @sys.exit(129)
    }
    let names = positional[0]
      .split(",")
      .map(n => n.trim(chars=" ").to_owned())
      .filter(n => n.length() > 0)
      .to_array()
    if names.length() == 0 {
      eprint_line(usage)
      @sys.exit(129)
    }
    (names, positional[1])
  }
  if !@home.is_valid_feature_name(feature) {
    eprint_line("fatal: invalid feature name '\{feature}'")
    @sys.exit(128)
  }
  (names, feature)
}

///|
/// Create the `feature` worktree in one repository. Reports problems as
/// `<name>: ...` and returns false instead of exiting.
async fn home_wt_add_one(
  fs : OsFs,
  root : String,
  repo : @home.HomeRepo,
  feature : String,
  base : String?,
) -> Bool raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let abs = home_repo_abs(root, repo)
  if !home_is_git_worktree(fs, abs) {
    eprint_line("\{repo.name}: not cloned yet (run `bit home sync \{repo.name}`)")
    return false
  }
  let wt = @home.worktree_path(abs, feature)
  // Re-running is fine: an existing worktree for the feature is kept.
  if rfs.is_dir(wt) {
    print_line("\{repo.name}: worktree \{contract_path_hq(wt)} already exists")
    return true
  }
  home_exclude_worktrees_dir(fs, abs)
  let git_dir = @bitlib.resolve_common_git_dir(
    rfs,
    @bitlib.resolve_gitdir(rfs, abs + "/.git"),
  )
  let branch_exists = @bitlib.resolve_ref(rfs, git_dir, "refs/heads/" + feature)
    is Some(_)
  let wt_args = ["-C", abs, "worktree", "add"]
  if !branch_exists {
    wt_args.push("-b")
    wt_args.push(feature)
  }
  wt_args.push(wt)
  if branch_exists {
    wt_args.push(feature)
  } else if base is Some(b) {
    wt_args.push(b)
  }
  if home_run_bit(wt_args) != 0 {
    eprint_line("\{repo.name}: worktree add failed")
    return false
  }
  if repo.subdir is Some(dir) {
    // bit's sparse-checkout does not support linked worktrees yet.
    eprint_line(
      "note: the worktree is a full checkout (sparse checkout of \{dir}/ is not supported in linked worktrees yet)",
    )
  }
  print_line("\{repo.name}: worktree \{contract_path_hq(wt)} on branch \{feature}")
  true
}

///|
async fn home_wt_remove_one(
  fs : OsFs,
  root : String,
  repo : @home.HomeRepo,
  feature : String,
  force : Bool,
) -> Bool {
  let abs = home_repo_abs(root, repo)
  if !home_is_git_worktree(fs, abs) {
    eprint_line("\{repo.name}: not cloned")
    return false
  }
  let rm_args = ["-C", abs, "worktree", "remove"]
  if force {
    rm_args.push("--force")
  }
  rm_args.push(@home.worktree_path(abs, feature))
  if home_run_bit(rm_args) != 0 {
    eprint_line("\{repo.name}: worktree remove failed")
    return false
  }
  print_line("\{repo.name}: removed worktree \{feature}")
  true
}

///|
/// `bit home exec [<name>...] [--home] [-q] -- <command> [<arg>...]` and
/// `bit home exec [<name>...] [--home] [-q] -c '<shell command>'`: run a
/// command in every cloned repository (cwd = its clone), one after another.
/// BIT_HOME_REPO / BIT_HOME_REPO_PATH name the current repository. Fails
/// (exit 1) when the command fails in any of them.
async fn handle_home_exec(fs : OsFs, args : Array[String]) -> Unit raise Error {
  let usage = "usage: bit home exec [<name>...] [--home] [-q] [-j <n>] -- <command> [<arg>...]\n" +
    "   or: bit home exec [<name>...] [--home] [-q] [-j <n>] -c '<shell command>'"
  let dash = match args.search("--") {
    Some(d) => d
    None => args.length()
  }
  let (jobs, head) = home_take_jobs(args[:dash].to_array())
  let args = head + args[dash:].to_array()
  let names : Array[String] = []
  let mut include_home = false
  let mut quiet = false
  let mut shell_command : String? = None
  let command : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--" => {
        for j in (i + 1)..<args.length() {
          command.push(args[j])
        }
        break
      }
      "-c" if i + 1 < args.length() => {
        shell_command = Some(args[i + 1])
        i += 1
      }
      "--home" => include_home = true
      "-q" | "--quiet" => quiet = true
      _ if arg.has_prefix("-") => {
        eprint_line("fatal: unknown option '\{arg}'")
        eprint_line(usage)
        @sys.exit(129)
      }
      _ => names.push(arg)
    }
    i += 1
  }
  let sh_args = match shell_command {
    Some(cmd) if command.length() == 0 => ["-c", cmd]
    None if command.length() > 0 => {
      let a = ["-c", "exec \"$@\"", "bit-home-exec"]
      a.append(command)
      a
    }
    _ => {
      eprint_line(usage)
      @sys.exit(129)
      []
    }
  }
  let root = require_home_root(fs)
  let manifest = load_home_manifest(fs, root)
  let targets : Array[(String, String)] = []
  if include_home {
    targets.push(("(home)", root))
  }
  for repo in home_select_repos(manifest, names) {
    targets.push((repo.name, home_repo_abs(root, repo)))
  }
  let runnable = targets.filter(t => home_is_git_worktree(fs, t.1))
  for target in targets {
    if !home_is_git_worktree(fs, target.1) {
      eprint_line(
        "== \{target.0}: skipped (not cloned; run `bit home sync \{target.0}`)",
      )
    }
  }
  let env_for = fn(name : String, abs : String) -> Map[String, String] {
    let env : Map[String, String] = Map([])
    env["BIT_HOME_REPO"] = name
    env["BIT_HOME_REPO_PATH"] = abs
    env
  }
  let failed : Array[String] = []
  if jobs > 1 && runnable.length() > 1 {
    // Run in parallel with captured output, replayed in manifest order.
    let codes = Array::make(runnable.length(), 0)
    let outs = Array::make(runnable.length(), b"")
    let errs = Array::make(runnable.length(), b"")
    home_parallel(jobs, runnable.length(), async fn(i) {
      let (name, abs) = runnable[i]
      let (code, out, err) = home_run_captured(
        "/bin/sh",
        sh_args,
        abs,
        env_for(name, abs),
      )
      codes[i] = code
      outs[i] = out
      errs[i] = err
    })
    for i, target in runnable {
      if !quiet {
        print_line("== \{target.0} (\{contract_path_hq(target.1)})")
      }
      home_write_bytes(outs[i], errs[i])
      if codes[i] != 0 {
        eprint_line("== \{target.0}: exit \{codes[i]}")
        failed.push(target.0)
      }
    }
  } else {
    for target in runnable {
      let (name, abs) = target
      if !quiet {
        print_line("== \{name} (\{contract_path_hq(abs)})")
      }
      let code = @process.run(
        "/bin/sh",
        sh_args[:],
        extra_env=env_for(name, abs),
        inherit_env=true,
        stdin=Stdin,
        stdout=Stdout,
        stderr=Stderr,
        cwd=abs,
      ).exit_code catch {
        _ => 127
      }
      if code != 0 {
        eprint_line("== \{name}: exit \{code}")
        failed.push(name)
      }
    }
  }
  if failed.length() > 0 {
    eprint_line("bit home exec: failed in \{failed.join(", ")}")
    @sys.exit(1)
  }
}

///|
async fn handle_home(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 ||
    args[0] == "-h" ||
    args[0] == "--help" ||
    args[0] == "help" {
    print_home_usage()
    return
  }
  let fs = OsFs::new()
  let rest = collect_args(args, 1)
  match args[0] {
    "init" => handle_home_init(fs, rest)
    "add" => handle_home_add(fs, rest)
    "rm" | "remove" => handle_home_rm(fs, rest)
    "render" => handle_home_render(fs, rest)
    "sync" => handle_home_sync(fs, rest)
    "status" => handle_home_status(fs, rest)
    "wt" | "worktree" => handle_home_wt(fs, rest)
    "exec" => handle_home_exec(fs, rest)
    other => {
      eprint_line("bit home: unknown subcommand '\{other}'")
      print_home_usage()
      @sys.exit(129)
    }
  }
}
