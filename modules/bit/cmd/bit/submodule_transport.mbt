///| Submodule transport policy (git's `protocol.<name>.allow`).
///
/// Since CVE-2022-39253 git refuses the local `file` transport for
/// submodule clones and fetches unless `protocol.file.allow=always`: the
/// default policy `user` only admits a transport the user typed, and git
/// runs submodule transports with `GIT_PROTOCOL_FROM_USER=0`. A
/// `.gitmodules` can otherwise point a submodule at an arbitrary local
/// path (e.g. a repository whose `.git` is a symlink into the victim's
/// home), copying data the user never chose to share into the checkout.

///|
/// Last value of `key` across `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_<n>`
/// pairs, or `None`.
fn submodule_env_pair_config_value(key : String) -> String? {
  let count = match @env.get_env_var("GIT_CONFIG_COUNT") {
    Some(raw) => @string.parse_int(trim_string(raw)) catch { _ => 0 }
    None => 0
  }
  let mut found : String? = None
  for i in 0..<count {
    match @env.get_env_var("GIT_CONFIG_KEY_\{i}") {
      Some(k) if k.to_lower() == key =>
        found = Some(@env.get_env_var("GIT_CONFIG_VALUE_\{i}").unwrap_or(""))
      _ => ()
    }
  }
  found
}

///|
/// Config files in increasing precedence: system, global (XDG then
/// `~/.gitconfig`, or `GIT_CONFIG_GLOBAL`), repository.
fn submodule_config_files(fs : OsFs, root : String) -> Array[String] {
  let files : Array[String] = []
  if @env.get_env_var("GIT_CONFIG_NOSYSTEM") is None {
    files.push(
      @env.get_env_var("GIT_CONFIG_SYSTEM").unwrap_or("/etc/gitconfig"),
    )
  }
  match @env.get_env_var("GIT_CONFIG_GLOBAL") {
    Some(path) => files.push(path)
    None => {
      match @env.get_env_var("XDG_CONFIG_HOME") {
        Some(xdg) if xdg.length() > 0 => files.push(xdg + "/git/config")
        _ =>
          match @env.get_env_var("HOME") {
            Some(home) => files.push(home + "/.config/git/config")
            None => ()
          }
      }
      match find_global_gitconfig_path() {
        Some(path) => files.push(path)
        None => ()
      }
    }
  }
  let rfs : &@bitcore.RepoFileSystem = fs
  files.push(resolve_git_dir(rfs, root) + "/config")
  files
}

///|
/// Effective value of `key` (lower-case `section.name`): command-line `-c`
/// and `GIT_CONFIG_COUNT` pairs override the repository, global and system
/// files; within a source the last value wins.
fn submodule_effective_config_value(
  fs : OsFs,
  root : String,
  key : String,
) -> String? {
  match get_config_override(key) {
    Some(v) => return Some(v)
    None => ()
  }
  match submodule_env_pair_config_value(key) {
    Some(v) => return Some(v)
    None => ()
  }
  let rfs : &@bitcore.RepoFileSystem = fs
  let mut found : String? = None
  for path in submodule_config_files(fs, root) {
    let value = get_config_value(rfs, path, key, None, false) catch {
      _ => None
    }
    if value is Some(_) {
      found = value
    }
  }
  found
}

///|
/// Whether a submodule operation may use the local `file` transport, as
/// git decides it (`transport.c:get_protocol_config` /
/// `is_transport_allowed`) for a transport not initiated by the user.
fn submodule_file_transport_allowed(fs : OsFs, root : String) -> Bool {
  match @env.get_env_var("GIT_ALLOW_PROTOCOL") {
    Some(list) =>
      return list.split(":").any(p => p.to_owned() == "file")
    None => ()
  }
  let policy = match
    submodule_effective_config_value(fs, root, "protocol.file.allow") {
    Some(v) => Some(v)
    None => submodule_effective_config_value(fs, root, "protocol.allow")
  }
  match policy.map(v => trim_string(v).to_lower()) {
    Some("always") => true
    // `never`, and `user` (also the default for `file`): submodule
    // transports are never "from the user".
    _ => false
  }
}

///|
/// Exit like git (`fatal: transport 'file' not allowed`, status 128) when
/// `url` names a local repository and the file transport is not allowed.
async fn submodule_ensure_transport_allowed(
  fs : OsFs,
  root : String,
  url : String,
) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let is_local = url.has_prefix("file://") ||
    @bitlib.resolve_local_repo_path(rfs, root, url) is Some(_)
  if is_local && !submodule_file_transport_allowed(fs, root) {
    eprint_line("fatal: transport 'file' not allowed")
    @sys.exit(128)
  }
}
