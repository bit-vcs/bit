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
    #|  render [--check]      Regenerate the "Other Repos" section of AGENTS.md
    #|  sync [<name>...]      Clone missing repositories, fast-forward the rest
    #|                        (the Home Repo itself included); --subdir entries
    #|                        are sparse checkouts of that directory
    #|  status [<name>...]    Branch / upstream / changes of every repository
    #|  wt add <name> <feature> [--base <ref>]
    #|                        Worktree for a feature inside the repository's clone
    #|                        (<path>/.worktrees/<feature>, branch <feature>)
    #|  wt list [<name>...]   List worktrees
    #|  wt remove <name> <feature> [--force]
    #|                        Remove a feature worktree
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
  home_run_bit(["-C", abs, "sparse-checkout", "set", @home.sparse_pattern(subdir)]) ==
  0
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
  if subdir is Some(dir) {
    if !home_apply_sparse(abs, dir) {
      eprint_line("\{name}: sparse checkout of \{dir}/ failed")
      return false
    }
  }
  match home_repo_status(abs) {
    None => {
      eprint_line("\{name}: could not read status")
      false
    }
    Some(status) =>
      if status.changes > 0 {
        print_line(
          "\{name}: \{status.changes} local change(s); not updating (commit or stash first)",
        )
        true
      } else if status.upstream is None {
        print_line("\{name}: no upstream branch; fetching only")
        home_run_bit(["-C", abs, "fetch", "-q"]) == 0
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
  let names = args.filter(a => !a.has_prefix("-"))
  let repos = home_select_repos(manifest, names)
  let mut failed = 0
  // The Home Repo itself is part of the virtual repository.
  if names.length() == 0 {
    if !home_sync_one(fs, "(home)", root, None, None, None) {
      failed += 1
    }
  }
  for repo in repos {
    let abs = home_repo_abs(root, repo)
    if !home_sync_one(fs, repo.name, abs, repo.url, repo.branch, repo.subdir) {
      failed += 1
    }
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
  let names = args.filter(a => !a.has_prefix("-"))
  let repos = home_select_repos(manifest, names)
  let rows : Array[(String, String, String)] = []
  if names.length() == 0 {
    let desc = match home_repo_status(root) {
      Some(s) => @home.describe_status(s)
      None => "not a git repository"
    }
    rows.push(("(home)", contract_path_hq(root), desc))
  }
  for repo in repos {
    let abs = home_repo_abs(root, repo)
    let desc = if !fs.is_dir(abs) {
      "missing (run `bit home sync \{repo.name}`)"
    } else if !home_is_git_worktree(fs, abs) {
      "not a git repository"
    } else {
      match home_repo_status(abs) {
        Some(s) => {
          let base = @home.describe_status(s)
          match repo.subdir {
            Some(d) => base + ", sparse \{d}/"
            None => base
          }
        }
        None => "could not read status"
      }
    }
    rows.push((repo.name, contract_path_hq(abs), desc))
  }
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
  let lookup = async fn(name : String) -> (@home.HomeRepo, String) raise Error {
    let repos = home_select_repos(manifest, [name])
    let repo = repos[0]
    let abs = home_repo_abs(root, repo)
    if !home_is_git_worktree(fs, abs) {
      eprint_line("fatal: '\{name}' is not cloned yet (run `bit home sync \{name}`)")
      @sys.exit(128)
    }
    (repo, abs)
  }
  match sub {
    "add" => {
      let mut base : String? = None
      let positional : Array[String] = []
      let mut i = 0
      while i < rest.length() {
        if rest[i] == "--base" && i + 1 < rest.length() {
          base = Some(rest[i + 1])
          i += 1
        } else if rest[i].has_prefix("-") {
          eprint_line("fatal: unknown option '\{rest[i]}'")
          @sys.exit(129)
        } else {
          positional.push(rest[i])
        }
        i += 1
      }
      if positional.length() != 2 {
        eprint_line("usage: bit home wt add <name> <feature> [--base <ref>]")
        @sys.exit(129)
      }
      let feature = positional[1]
      if !@home.is_valid_feature_name(feature) {
        eprint_line("fatal: invalid feature name '\{feature}'")
        @sys.exit(128)
      }
      let (repo, abs) = lookup(positional[0])
      let wt = @home.worktree_path(abs, feature)
      if rfs.is_dir(wt) {
        eprint_line("fatal: worktree already exists: \{contract_path_hq(wt)}")
        @sys.exit(128)
      }
      home_exclude_worktrees_dir(fs, abs)
      let git_dir = @bitlib.resolve_common_git_dir(
        rfs,
        @bitlib.resolve_gitdir(rfs, abs + "/.git"),
      )
      let branch_exists = @bitlib.resolve_ref(
          rfs,
          git_dir,
          "refs/heads/" + feature,
        )
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
        eprint_line("fatal: worktree add failed")
        @sys.exit(128)
      }
      if repo.subdir is Some(dir) {
        // bit's sparse-checkout does not support linked worktrees yet.
        eprint_line(
          "note: the worktree is a full checkout (sparse checkout of \{dir}/ is not supported in linked worktrees yet)",
        )
      }
      print_line("\{repo.name}: worktree \{contract_path_hq(wt)} on branch \{feature}")
    }
    "list" => {
      let names = rest.filter(a => !a.has_prefix("-"))
      for repo in home_select_repos(manifest, names) {
        let abs = home_repo_abs(root, repo)
        if !home_is_git_worktree(fs, abs) {
          continue
        }
        let (code, out) = home_capture_bit(["-C", abs, "worktree", "list"])
        if code != 0 {
          continue
        }
        for line in out.split("\n") {
          let l = line.to_owned()
          if l.length() > 0 {
            print_line("\{repo.name}\t\{l}")
          }
        }
      }
    }
    "remove" => {
      let force = rest.contains("--force") || rest.contains("-f")
      let positional = rest.filter(a => !a.has_prefix("-"))
      if positional.length() != 2 {
        eprint_line("usage: bit home wt remove <name> <feature> [--force]")
        @sys.exit(129)
      }
      let feature = positional[1]
      if !@home.is_valid_feature_name(feature) {
        eprint_line("fatal: invalid feature name '\{feature}'")
        @sys.exit(128)
      }
      let (repo, abs) = lookup(positional[0])
      let wt = @home.worktree_path(abs, feature)
      let rm_args = ["-C", abs, "worktree", "remove"]
      if force {
        rm_args.push("--force")
      }
      rm_args.push(wt)
      if home_run_bit(rm_args) != 0 {
        eprint_line("fatal: worktree remove failed")
        @sys.exit(128)
      }
      print_line("\{repo.name}: removed worktree \{feature}")
    }
    _ => {
      eprint_line("bit home wt: unknown subcommand '\{sub}'")
      @sys.exit(129)
    }
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
    "render" => handle_home_render(fs, rest)
    "sync" => handle_home_sync(fs, rest)
    "status" => handle_home_status(fs, rest)
    "wt" | "worktree" => handle_home_wt(fs, rest)
    other => {
      eprint_line("bit home: unknown subcommand '\{other}'")
      print_home_usage()
      @sys.exit(129)
    }
  }
}
