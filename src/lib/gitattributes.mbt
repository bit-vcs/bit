///| Gitattributes text/eol attribute processing

///|
pub enum TextAttr {
  Auto
  Set
  Unset
  Unspecified
}

///|
pub enum EolAttr {
  Lf
  Crlf
  Unspecified
}

///|
pub struct FileEolAttrs {
  text : TextAttr
  eol : EolAttr
}

///|
/// Parse .gitattributes and resolve eol attributes for a given path.
pub fn resolve_eol_attrs(
  rfs : &@bit.RepoFileSystem,
  root : String,
  path : String,
) -> FileEolAttrs {
  let attr_path = join_path(root, ".gitattributes")
  if not(rfs.is_file(attr_path)) {
    return { text: TextAttr::Unspecified, eol: EolAttr::Unspecified }
  }
  let content = @utf8.decode_lossy(
    (rfs.read_file(attr_path) catch { _ => Bytes::default() })[:],
  )
  let normalized = if path.has_prefix("/") {
    String::unsafe_substring(path, start=1, end=path.length())
  } else if path.has_prefix("./") {
    String::unsafe_substring(path, start=2, end=path.length())
  } else {
    path
  }
  let mut text : TextAttr = TextAttr::Unspecified
  let mut eol : EolAttr = EolAttr::Unspecified
  for line_view in content.split("\n") {
    let line = line_view.to_string().trim().to_string()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let words : Array[String] = []
    for token_view in line.split(" ") {
      let token = token_view.to_string().trim().to_string()
      if token.length() > 0 {
        words.push(token)
      }
    }
    if words.length() < 2 {
      continue
    }
    if not(gitattr_pattern_matches(normalized, words[0])) {
      continue
    }
    let mut j = 1
    while j < words.length() {
      let token = words[j]
      if token == "text" {
        text = TextAttr::Set
      } else if token == "-text" {
        text = TextAttr::Unset
      } else if token.has_prefix("text=") {
        let value = String::unsafe_substring(token, start=5, end=token.length()).to_lower()
        if value == "auto" {
          text = TextAttr::Auto
        } else {
          text = TextAttr::Set
        }
      } else if token == "eol" || token.has_prefix("eol=") {
        if token.has_prefix("eol=") {
          let value = String::unsafe_substring(
            token,
            start=4,
            end=token.length(),
          ).to_lower()
          if value == "lf" {
            eol = EolAttr::Lf
          } else if value == "crlf" {
            eol = EolAttr::Crlf
          }
        }
      } else if token == "crlf" {
        // Legacy: crlf is equivalent to text
        text = TextAttr::Set
      } else if token == "-crlf" {
        // Legacy: -crlf is equivalent to -text
        text = TextAttr::Unset
      }
      j += 1
    }
  }
  { text, eol }
}

///|
/// Pattern matching for gitattributes (same as cat_file_attr_pattern_matches).
fn gitattr_pattern_matches(path : String, pattern : String) -> Bool {
  if pattern == path {
    return true
  }
  if pattern.has_prefix("*.") {
    return path.has_suffix(
      String::unsafe_substring(pattern, start=1, end=pattern.length()),
    )
  }
  match pattern.find("*") {
    Some(idx) => {
      let prefix = String::unsafe_substring(pattern, start=0, end=idx)
      let suffix = String::unsafe_substring(
        pattern,
        start=idx + 1,
        end=pattern.length(),
      )
      path.has_prefix(prefix) &&
      path.has_suffix(suffix) &&
      path.length() >= prefix.length() + suffix.length()
    }
    None => false
  }
}

///|
/// Clean: WT→blob normalization considering gitattributes text/eol.
pub fn clean_for_storage(
  content : Bytes,
  attrs : FileEolAttrs,
  autocrlf : AutoCrlf,
) -> Bytes {
  match attrs.text {
    Unset => content // -text: no conversion
    Set =>
      // text: always normalize CRLF→LF
      if is_binary_bytes(content) {
        content
      } else {
        normalize_crlf_to_lf(content)
      }
    Auto =>
      // text=auto: normalize only if not binary
      if is_binary_bytes(content) {
        content
      } else {
        normalize_crlf_to_lf(content)
      }
    Unspecified =>
      // No text attribute: fall back to core.autocrlf
      normalize_worktree_content(content, autocrlf)
  }
}

///|
/// Smudge: blob→WT expansion considering gitattributes text/eol.
pub fn smudge_for_checkout(
  content : Bytes,
  attrs : FileEolAttrs,
  autocrlf : AutoCrlf,
) -> Bytes {
  match attrs.text {
    Unset => content // -text: no conversion
    Set | Auto => {
      let is_bin = is_binary_bytes(content)
      if is_bin && attrs.text is Auto {
        return content
      }
      if is_bin {
        return content
      }
      match attrs.eol {
        Lf => content // eol=lf: keep LF
        Crlf => convert_lf_to_crlf(content) // eol=crlf: expand
        Unspecified =>
          // No eol attribute: use native line ending (on Windows CRLF, else LF)
          // For now, follow autocrlf setting as a proxy for platform
          smudge_worktree_content(content, autocrlf)
      }
    }
    Unspecified =>
      // No text attribute: fall back to core.autocrlf
      smudge_worktree_content(content, autocrlf)
  }
}

///|
/// Check if .gitattributes has filter= or working-tree-encoding= that needs real git.
pub fn has_unsupported_gitattributes(
  rfs : &@bit.RepoFileSystem,
  root : String,
) -> Bool {
  let attr_path = join_path(root, ".gitattributes")
  if not(rfs.is_file(attr_path)) {
    return false
  }
  let content = @utf8.decode_lossy(
    (rfs.read_file(attr_path) catch { _ => Bytes::default() })[:],
  )
  for line_view in content.split("\n") {
    let line = line_view.to_string().trim().to_string()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    for token_view in line.split(" ") {
      let token = token_view.to_string().trim().to_string()
      if token.length() == 0 {
        continue
      }
      if token == "filter" ||
        token.has_prefix("filter=") ||
        token.has_prefix("working-tree-encoding=") {
        return true
      }
    }
  }
  false
}
