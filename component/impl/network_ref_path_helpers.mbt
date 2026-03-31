///| WASM Component network ref path helpers

///|
fn net_remote_refname(refname : String) -> String raise @bit.GitError {
  let normalized = @bitlib.normalize_repo_path(refname)
  if normalized == "HEAD" || normalized.has_prefix("refs/") {
    if normalized.has_prefix("refs/heads/") {
      let name = String::unsafe_substring(
        normalized,
        start=11,
        end=normalized.length(),
      )
      "refs/remotes/origin/" + name
    } else if normalized == "HEAD" {
      "refs/remotes/origin/HEAD"
    } else {
      "refs/remotes/origin/" + normalized
    }
  } else {
    raise @bit.GitError::InvalidObject("invalid refname: " + refname)
  }
}

///|
fn net_parent_dir(path : String) -> String {
  match path.rev_find("/") {
    None => "/"
    Some(0) => "/"
    Some(i) => String::unsafe_substring(path, start=0, end=i)
  }
}
