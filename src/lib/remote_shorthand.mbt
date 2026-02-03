///|
/// Clone target result
pub(all) enum GitHubShorthand {
  /// Full repo clone: user/repo → https://github.com/user/repo
  Repo(String, String?) // github_url, ref?
  /// Subdir clone: user/repo:path → https://github.com/user/repo, path
  Subdir(String, String, String?) // github_url, subdir_path, ref?
  /// Single file fetch: raw URL, filename
  File(String, String) // raw_url, filename
} derive(Eq, Show)

///|
/// Parse clone shorthand or GitHub browser URL
///
/// Supports:
/// 1. user/repo → Repo clone (GitHub)
/// 2. user/repo:path → Subdir clone with sparse checkout
/// 3. user/repo@ref → Repo clone at ref
/// 4. user/repo@ref:path → Subdir clone at ref
/// 5. gitlab.com/user/repo → Repo clone (other hosts)
/// 6. gitlab.com/user/repo:path → Subdir clone (other hosts)
/// 7. https://github.com/user/repo/tree/branch/path → Subdir clone
/// 8. https://github.com/user/repo/blob/branch/path → Single file fetch
///
/// Examples:
/// - "user/repo" → Repo("https://github.com/user/repo")
/// - "user/repo:src" → Subdir("https://github.com/user/repo", "src")
/// - "user/repo@main" → Repo("https://github.com/user/repo", Some("main"))
/// - "user/repo@main:src" → Subdir("https://github.com/user/repo", "src", Some("main"))
/// - "gitlab.com/user/repo" → Repo("https://gitlab.com/user/repo")
/// - "https://github.com/user/repo/tree/main/src" → Subdir(url, "src")
pub fn parse_github_shorthand(url : String) -> GitHubShorthand? {
  // Check for GitHub browser URL first
  if url.has_prefix("https://github.com/") {
    return parse_github_browser_url(url)
  }
  // Skip if it looks like a local path or full URL
  if url.has_prefix("./") ||
    url.has_prefix("/") ||
    url.has_prefix("../") ||
    url.has_prefix("https://") ||
    url.has_prefix("http://") ||
    url.has_prefix("git@") ||
    url.has_suffix(".git") {
    return None
  }
  // Check for subdir separator ':'
  let (repo_part, subdir) = match url.find(":") {
    Some(idx) => {
      let rp = String::unsafe_substring(url, start=0, end=idx)
      let sd = String::unsafe_substring(url, start=idx + 1, end=url.length())
      (rp, if sd.is_empty() { None } else { Some(sd) })
    }
    None => (url, None)
  }
  // Extract @ref from repo part
  let (repo_base, ref_spec) = match repo_part.rev_find("@") {
    Some(idx) => {
      let base = String::unsafe_substring(repo_part, start=0, end=idx)
      let rf = String::unsafe_substring(
        repo_part,
        start=idx + 1,
        end=repo_part.length(),
      )
      (base, if rf.is_empty() { None } else { Some(rf) })
    }
    None => (repo_part, None)
  }
  // Split repo part by /
  let parts : Array[String] = repo_base
    .split("/")
    .filter(fn(s) { s.length() > 0 })
    .map(fn(s) { s.to_string() })
    .collect()
  // Determine host and user/repo
  let (host, owner, repo) = if parts.length() == 2 {
    // user/repo → GitHub
    ("github.com", parts[0], parts[1])
  } else if parts.length() == 3 && parts[0].contains(".") {
    // host.com/user/repo
    (parts[0], parts[1], parts[2])
  } else {
    return None
  }
  let clone_url = "https://\{host}/\{owner}/\{repo}"
  match subdir {
    Some(sd) => Some(Subdir(clone_url, sd, ref_spec))
    None => Some(Repo(clone_url, ref_spec))
  }
}

///|
/// Check if shorthand conflicts with local directory
/// Returns the conflicting path if ambiguous
pub fn check_shorthand_ambiguity(
  url : String,
  dir_exists : (String) -> Bool,
) -> String? {
  // Only check for shorthand patterns (not full URLs)
  if url.has_prefix("https://") ||
    url.has_prefix("http://") ||
    url.has_prefix("git@") ||
    url.has_prefix("file://") ||
    url.has_prefix("./") ||
    url.has_prefix("/") ||
    url.has_prefix("../") ||
    url.has_suffix(".git") {
    return None
  }
  if url.find("/") is None && url.find(":") is None {
    return None
  }
  // Extract repo part (before ':' if present)
  let repo_part = match url.find(":") {
    Some(idx) => String::unsafe_substring(url, start=0, end=idx)
    None => url
  }
  // Strip @ref if present
  let repo_base = match repo_part.rev_find("@") {
    Some(idx) => String::unsafe_substring(repo_part, start=0, end=idx)
    None => repo_part
  }
  // Check first component
  let first_slash = repo_base.find("/")
  let first_part = match first_slash {
    Some(idx) => String::unsafe_substring(repo_base, start=0, end=idx)
    None => repo_base
  }
  if dir_exists(first_part) {
    return Some(first_part)
  }
  // Check full repo path (user/repo part)
  let parts : Array[String] = repo_base
    .split("/")
    .filter(fn(s) { s.length() > 0 })
    .map(fn(s) { s.to_string() })
    .collect()
  if parts.length() >= 2 {
    let two_parts = parts[0] + "/" + parts[1]
    if dir_exists(two_parts) {
      return Some(two_parts)
    }
  }
  None
}

///|
/// Parse GitHub browser URL (tree/blob)
/// https://github.com/user/repo/tree/branch/path → Subdir
/// https://github.com/user/repo/blob/branch/path → File
fn parse_github_browser_url(url : String) -> GitHubShorthand? {
  // Remove https://github.com/
  let path = String::unsafe_substring(url, start=19, end=url.length())
  let parts : Array[String] = path
    .split("/")
    .filter(fn(s) { s.length() > 0 })
    .map(fn(s) { s.to_string() })
    .collect()
  // Need at least: user/repo/tree|blob/branch/path
  // parts[0] = user, parts[1] = repo, parts[2] = tree|blob, parts[3] = branch, parts[4+] = path
  if parts.length() < 5 {
    return None
  }
  let owner = parts[0]
  let repo = parts[1]
  let kind = parts[2] // "tree" or "blob"
  let branch = parts[3]
  // Build path from remaining parts
  let path_parts : Array[String] = []
  for i = 4; i < parts.length(); i = i + 1 {
    path_parts.push(parts[i])
  }
  let subpath = path_parts.join("/")
  let github_url = "https://github.com/\{owner}/\{repo}"
  if kind == "tree" {
    // Directory → subdir clone
    Some(Subdir(github_url, subpath, Some(branch)))
  } else if kind == "blob" {
    // File → raw fetch
    let raw_url = "https://raw.githubusercontent.com/\{owner}/\{repo}/\{branch}/\{subpath}"
    let filename = parts[parts.length() - 1]
    Some(File(raw_url, filename))
  } else {
    None
  }
}
