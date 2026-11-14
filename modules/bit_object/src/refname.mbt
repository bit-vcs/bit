///| Reference-name validation (git check-ref-format rules).

///|
/// Whether `refname` is a well-formed reference name under git's
/// check-ref-format rules: no `..`, `@{`, control characters, space, `~`, `^`,
/// `:`, `?`, `*`, `[` or `\`; no component starting with `.` or ending with
/// `.lock`; no empty component, leading or trailing `/`, or trailing `.`; not
/// `@`. Unless `allow_onelevel`, it must contain at least one `/`.
pub fn check_refname_format(
  refname : String,
  allow_onelevel? : Bool = false,
) -> Bool {
  let len = refname.length()
  if len == 0 || refname == "@" || refname.has_suffix(".lock") {
    return false
  }
  let first = refname.unsafe_get(0)
  let last = refname.unsafe_get(len - 1)
  if first == '/' || last == '/' || first == '.' || last == '.' {
    return false
  }
  let mut has_slash = false
  for i in 0..<len {
    let c = refname.unsafe_get(i)
    let next = if i + 1 < len { refname.unsafe_get(i + 1) } else { 0 }
    if c < 0x20 || c == 0x7f {
      return false
    }
    match c {
      ' ' | '~' | '^' | ':' | '?' | '*' | '[' | '\\' => return false
      _ => ()
    }
    if (c == '.' && next == '.') ||
      (c == '@' && next == '{') ||
      (c == '/' && next == '/') {
      return false
    }
    if c == '/' {
      has_slash = true
      if next == '.' {
        return false
      }
      if i >= 5 && refname.unsafe_substring(start=i - 5, end=i) == ".lock" {
        return false
      }
    }
  }
  has_slash || allow_onelevel
}

///|
/// Whether a reference name received from a remote is safe to store or use as
/// a path: `HEAD`, or a well-formed name under `refs/`, optionally followed
/// by `^{}` (a peeled tag in a v0 advertisement). Anything else (`..`
/// traversal, control characters, names outside `refs/`) must be dropped
/// before it reaches a ref store, HEAD or the config (cf. CVE-2026-113408).
pub fn is_valid_remote_refname(refname : String) -> Bool {
  if refname == "HEAD" {
    return true
  }
  let name = if refname.has_suffix("^{}") {
    refname.unsafe_substring(start=0, end=refname.length() - 3)
  } else {
    refname
  }
  name.has_prefix("refs/") && check_refname_format(name)
}

///|
/// Whether a symbolic-ref target received from a remote is safe: a
/// well-formed name under `refs/`.
pub fn is_valid_remote_symref_target(target : String) -> Bool {
  target.has_prefix("refs/") && check_refname_format(target)
}

///|
/// Raise unless `refname` (received from a remote) is safe to write into
/// HEAD or join into a path under the git directory.
pub fn ensure_valid_remote_refname(refname : String) -> Unit raise GitError {
  if !is_valid_remote_refname(refname) || refname.has_suffix("^{}") {
    raise GitError::ProtocolError("refusing unsafe ref name from remote: \{refname}")
  }
}
