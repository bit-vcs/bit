///| Home Repo manifest (`bit-home.toml`).
///
/// A Home Repo is one repository that holds the agent steering files
/// (AGENTS.md, CLAUDE.md, skills, shared docs) and *points at* the other
/// repositories a project spans. The manifest is the machine-readable list
/// of those pointers; `bit home render` turns it into the "Other Repos"
/// section of AGENTS.md, and `bit home sync` / `status` / `wt` act on every
/// listed repository at once, so the set behaves like one virtual repo.
///
/// ```toml
/// [[repo]]
/// name = "storefront"                          # optional, defaults to path basename
/// path = "~/repos/acme/storefront"             # required: where the clone lives
/// url = "git@github.com:acme/storefront.git"   # clone source (needed to clone)
/// description = "Next.js app"
/// branch = "main"                              # optional: branch to clone
/// subdir = "apps/web"                          # optional: sparse checkout of one dir
/// notes = "Read its AGENTS.md before changing it."
/// ```

///|
/// The manifest file name, at the root of the Home Repo.
pub let manifest_file_name : String = "bit-home.toml"

///|
pub suberror HomeError {
  HomeError(String)
} derive(Debug)

///|
pub extend HomeError with Debug::{to_repr}

///|
/// The error text, for display.
pub fn HomeError::message(self : HomeError) -> String {
  match self {
    HomeError(msg) => msg
  }
}

///|
/// One repository the Home Repo points at.
pub(all) struct HomeRepo {
  name : String
  /// Clone location as written in the manifest (`~/` and relative paths
  /// are resolved by `resolve_repo_path`).
  path : String
  url : String?
  description : String?
  branch : String?
  /// Sparse-checkout this directory only (normalized, no leading or
  /// trailing `/`).
  subdir : String?
  notes : String?
} derive(Debug, Eq)

///|
pub extend HomeRepo with Debug::{to_repr}

///|
pub extend HomeRepo with Eq::{not_equal, equal}

///|
pub(all) struct HomeManifest {
  repos : Array[HomeRepo]
} derive(Debug, Eq)

///|
pub extend HomeManifest with Debug::{to_repr}

///|
pub extend HomeManifest with Eq::{not_equal, equal}

///|
let known_repo_keys : Array[String] = [
  "name", "path", "url", "description", "branch", "subdir", "notes",
]

///|
fn home_err(msg : String) -> HomeError {
  HomeError::HomeError(msg)
}

///|
fn toml_string_field(
  table : Map[String, @toml.TomlValue],
  key : String,
  index : Int,
) -> String? raise HomeError {
  match table.get(key) {
    None => None
    Some(@toml.TomlValue::TomlString(v)) => {
      let trimmed = v.trim(chars=" \t").to_owned()
      if trimmed.length() == 0 {
        None
      } else {
        Some(trimmed)
      }
    }
    Some(_) => raise home_err("repo[\{index}]: `\{key}` must be a string")
  }
}

///|
/// Last path component of `path` (ignoring trailing slashes), with a
/// trailing `.git` dropped.
pub fn path_basename(path : String) -> String {
  let mut end = path.length()
  while end > 0 && (path.unsafe_get(end - 1) == '/' || path.unsafe_get(end - 1) == ':') {
    end -= 1
  }
  let mut start = end
  while start > 0 &&
        path.unsafe_get(start - 1) != '/' &&
        path.unsafe_get(start - 1) != ':' {
    start -= 1
  }
  let base = String::unsafe_substring(path, start~, end~)
  if base.has_suffix(".git") && base.length() > 4 {
    String::unsafe_substring(base, start=0, end=base.length() - 4)
  } else {
    base
  }
}

///|
/// Repository names become worktree / display keys: ASCII letters, digits,
/// `.`, `_` and `-`, not `.` or `..`.
pub fn is_valid_repo_name(name : String) -> Bool {
  if name.length() == 0 || name == "." || name == ".." {
    return false
  }
  for c in name {
    if !(
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '.' ||
        c == '_' ||
        c == '-'
      ) {
      return false
    }
  }
  true
}

///|
/// Normalize a sparse-checkout subdirectory: strip surrounding `/`, reject
/// empty, `.`/`..` components and backslashes.
pub fn normalize_subdir(subdir : String) -> String raise HomeError {
  let parts : Array[String] = []
  for part in subdir.split("/") {
    let p = part.to_owned()
    if p.length() == 0 {
      continue
    }
    if p == "." || p == ".." || p.contains("\\") {
      raise home_err("invalid subdir '\{subdir}'")
    }
    parts.push(p)
  }
  if parts.length() == 0 {
    raise home_err("invalid subdir '\{subdir}'")
  }
  parts.join("/")
}

///|
fn validate_branch(branch : String) -> Unit raise HomeError {
  if branch.has_prefix("-") ||
    branch.contains(" ") ||
    branch.contains("\t") ||
    branch.contains("..") {
    raise home_err("invalid branch '\{branch}'")
  }
}

///|
/// Parse and validate `bit-home.toml`. Unknown keys are rejected so a typo
/// (`subdirs = ...`) is not silently ignored.
pub fn parse_manifest(content : String) -> HomeManifest raise HomeError {
  let root = @toml.parse(content) catch {
    err => raise home_err("\{manifest_file_name}: \{err.to_string()}")
  }
  guard root is @toml.TomlValue::TomlTable(top) else {
    raise home_err("\{manifest_file_name}: expected a table")
  }
  for key, _ in top {
    if key != "repo" {
      raise home_err("\{manifest_file_name}: unknown top-level key `\{key}`")
    }
  }
  let entries : Array[@toml.TomlValue] = match top.get("repo") {
    None => []
    Some(@toml.TomlValue::TomlArray(items)) => items
    Some(_) =>
      raise home_err("\{manifest_file_name}: `repo` must be an array of tables ([[repo]])")
  }
  let repos : Array[HomeRepo] = []
  let seen : Map[String, Bool] = Map([])
  for index, entry in entries {
    guard entry is @toml.TomlValue::TomlTable(table) else {
      raise home_err("repo[\{index}]: expected a table")
    }
    for key, _ in table {
      if !known_repo_keys.contains(key) {
        raise home_err("repo[\{index}]: unknown key `\{key}`")
      }
    }
    guard toml_string_field(table, "path", index) is Some(path) else {
      raise home_err("repo[\{index}]: `path` is required")
    }
    let name = match toml_string_field(table, "name", index) {
      Some(n) => n
      None => path_basename(path)
    }
    if !is_valid_repo_name(name) {
      raise home_err(
        "repo[\{index}]: invalid name '\{name}' (use letters, digits, '.', '_', '-')",
      )
    }
    if seen.contains(name) {
      raise home_err("repo[\{index}]: duplicate name '\{name}'")
    }
    seen[name] = true
    let branch = toml_string_field(table, "branch", index)
    if branch is Some(b) {
      validate_branch(b)
    }
    let subdir = match toml_string_field(table, "subdir", index) {
      Some(s) => Some(normalize_subdir(s))
      None => None
    }
    let url = toml_string_field(table, "url", index)
    if url is Some(u) && u.has_prefix("-") {
      raise home_err("repo[\{index}]: invalid url '\{u}'")
    }
    repos.push({
      name,
      path,
      url,
      description: toml_string_field(table, "description", index),
      branch,
      subdir,
      notes: toml_string_field(table, "notes", index),
    })
  }
  { repos, }
}

///|
pub fn HomeManifest::find(self : HomeManifest, name : String) -> HomeRepo? {
  for repo in self.repos {
    if repo.name == name {
      return Some(repo)
    }
  }
  None
}

///|
/// Absolute location of a repository: `~/x` is under `home`, a relative
/// path is relative to the Home Repo root, an absolute path is kept.
pub fn resolve_repo_path(
  path : String,
  home~ : String,
  home_repo_root~ : String,
) -> String {
  if path == "~" {
    home
  } else if path.has_prefix("~/") {
    home + String::unsafe_substring(path, start=1, end=path.length())
  } else if path.has_prefix("/") {
    path
  } else {
    let rel = if path.has_prefix("./") {
      String::unsafe_substring(path, start=2, end=path.length())
    } else {
      path
    }
    if home_repo_root.has_suffix("/") {
      home_repo_root + rel
    } else {
      home_repo_root + "/" + rel
    }
  }
}

///|
/// Cone-mode sparse-checkout pattern for a normalized subdir.
pub fn sparse_pattern(subdir : String) -> String {
  "/" + subdir + "/"
}

///|
/// Quote a TOML basic string.
pub fn toml_quote(value : String) -> String {
  let sb = StringBuilder()
  sb.write_char('"')
  for c in value {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.write_char('"')
  sb.to_string()
}

///|
/// The `[[repo]]` block `bit home add` appends to the manifest. Appending
/// (rather than re-serializing the file) keeps the user's comments.
pub fn repo_toml_block(repo : HomeRepo) -> String {
  let sb = StringBuilder()
  sb.write_string("[[repo]]\n")
  sb.write_string("name = \{toml_quote(repo.name)}\n")
  sb.write_string("path = \{toml_quote(repo.path)}\n")
  let opt = fn(key : String, v : String?) {
    if v is Some(s) {
      sb.write_string("\{key} = \{toml_quote(s)}\n")
    }
  }
  opt("url", repo.url)
  opt("description", repo.description)
  opt("branch", repo.branch)
  opt("subdir", repo.subdir)
  opt("notes", repo.notes)
  sb.to_string()
}

///|
/// Initial manifest written by `bit home init`.
pub let manifest_template : String =
  #|# bit home manifest: the repositories this Home Repo points at.
  #|# `bit home render` turns it into the "Other Repos" section of AGENTS.md;
  #|# `bit home sync` / `bit home status` act on every entry at once.
  #|#
  #|# [[repo]]
  #|# name = "storefront"                          # optional, defaults to the path basename
  #|# path = "~/repos/acme/storefront"             # required: where the clone lives
  #|# url = "git@github.com:acme/storefront.git"   # clone source
  #|# description = "Next.js app"
  #|# branch = "main"                              # optional: branch to clone
  #|# subdir = "apps/web"                          # optional: sparse checkout of one directory
  #|# notes = "Read its AGENTS.md before changing it."
  #|
