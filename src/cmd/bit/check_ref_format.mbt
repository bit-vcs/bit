///| git check-ref-format - validate reference names

///|
async fn handle_check_ref_format(args : Array[String]) -> Unit raise Error {
  let mut allow_onelevel = false
  let mut normalize = false
  let mut branch_mode = false
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "--allow-onelevel" => allow_onelevel = true
      "--no-allow-onelevel" => allow_onelevel = false
      "--normalize" => normalize = true
      "--refspec-pattern" => () // accept but ignore
      "--branch" => branch_mode = true
      "-h" | "--help" => {
        show_simple_command_help(
          "git check-ref-format [--normalize] [--allow-onelevel] [--branch] <refname>",
          summary="Ensures that a reference name is well formed.",
        )
        return
      }
      _ if arg.has_prefix("-") =>
        warn_unimplemented_arg("check-ref-format", arg)
      _ => positional.push(arg)
    }
  }
  if positional.length() == 0 {
    eprint_line("fatal: No refname given")
    @sys.exit(1)
  }
  let refname = positional[0]
  if branch_mode {
    // --branch mode: resolve @{-N} or print branch name
    let name = check_ref_format_resolve_branch(refname)
    match name {
      Some(resolved) => print_line(resolved)
      None => {
        eprint_line("fatal: '\{refname}' is not a valid branch name")
        @sys.exit(1)
      }
    }
    return
  }
  if normalize {
    // Normalize first (collapse slashes), then validate
    let normalized = check_ref_format_normalize(refname)
    if !(check_ref_format_valid(normalized, allow_onelevel~)) {
      @sys.exit(1)
    }
    print_line(normalized)
  } else if !(check_ref_format_valid(refname, allow_onelevel~)) {
    @sys.exit(1)
  }
}

///|
fn check_ref_format_valid(
  refname : String,
  allow_onelevel? : Bool = false,
) -> Bool {
  if refname.length() == 0 {
    return false
  }
  let chars = refname.to_array()
  let len = chars.length()
  // Cannot start or end with slash
  if chars[0] == '/' || chars[len - 1] == '/' {
    return false
  }
  // Cannot start or end with dot
  if chars[0] == '.' || chars[len - 1] == '.' {
    return false
  }
  // Cannot be single @
  if refname == "@" {
    return false
  }
  // Cannot end with .lock
  if refname.has_suffix(".lock") {
    return false
  }
  let mut has_slash = false
  let mut i = 0
  while i < len {
    let c = chars[i]
    // No ASCII control chars (< 0x20) or DEL (0x7f)
    if c.to_int() < 0x20 || c.to_int() == 0x7f {
      return false
    }
    // No space, ~, ^, :, ?, *, [
    match c {
      ' ' | '~' | '^' | ':' | '?' | '*' | '[' | '\\' => return false
      _ => ()
    }
    // No double dots
    if c == '.' && i + 1 < len && chars[i + 1] == '.' {
      return false
    }
    // No @{
    if c == '@' && i + 1 < len && chars[i + 1] == '{' {
      return false
    }
    // No consecutive slashes
    if c == '/' && i + 1 < len && chars[i + 1] == '/' {
      return false
    }
    if c == '/' {
      has_slash = true
      // Component cannot start with dot
      if i + 1 < len && chars[i + 1] == '.' {
        return false
      }
      // Component cannot end with .lock
      // Check if the component before this slash ends with .lock
      if i >= 5 {
        let comp_end = String::unsafe_substring(refname, start=i - 5, end=i)
        if comp_end == ".lock" {
          return false
        }
      }
    }
    i += 1
  }
  // Must have at least one slash unless allow_onelevel
  if !(has_slash) && !(allow_onelevel) {
    return false
  }
  true
}

///|
fn check_ref_format_normalize(refname : String) -> String {
  // Collapse consecutive slashes (shouldn't exist if valid, but just in case)
  let result = StringBuilder::new()
  let chars = refname.to_array()
  let mut prev_slash = false
  for c in chars {
    if c == '/' {
      if !(prev_slash) {
        result.write_char('/')
      }
      prev_slash = true
    } else {
      result.write_char(c)
      prev_slash = false
    }
  }
  result.to_string()
}

///|
fn check_ref_format_resolve_branch(name : String) -> String? {
  // Handle @{-N} syntax
  if name.has_prefix("@{-") && name.has_suffix("}") {
    // For now, just validate it's a number and return None
    // (full implementation would read reflog)
    let inner = String::unsafe_substring(name, start=3, end=name.length() - 1)
    for c in inner.to_array() {
      if c < '0' || c > '9' {
        return None
      }
    }
    // Would need reflog access to resolve, return None for now
    return None
  }
  // Otherwise validate as branch name (allow onelevel)
  if check_ref_format_valid(name, allow_onelevel=true) {
    Some(name)
  } else {
    None
  }
}
