///|
async fn handle_symbolic_ref(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let mut delete_mode = false
  let mut short_mode = false
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "-d" | "--delete" => delete_mode = true
      "--short" => short_mode = true
      _ if not(arg.has_prefix("-")) => positional.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("symbolic-ref", arg)
      _ => ()
    }
  }
  if positional.length() == 0 {
    raise @git.GitError::InvalidObject("usage: git symbolic-ref <name> [<ref>]")
  }
  let name = positional[0]
  let ref_path = if name == "HEAD" {
    git_dir + "/HEAD"
  } else {
    git_dir + "/" + name
  }
  if delete_mode {
    if fs.is_file(ref_path) {
      fs.remove_file(ref_path)
    }
    return ()
  }
  if positional.length() == 1 {
    // Read mode
    if not(fs.is_file(ref_path)) {
      raise @git.GitError::InvalidObject("ref \{name} not found")
    }
    let content = decode_bytes(fs.read_file(ref_path))
    let trimmed = content.trim_end(chars="\n\r ").to_string()
    if trimmed.has_prefix("ref: ") {
      let target = String::unsafe_substring(
        trimmed,
        start=5,
        end=trimmed.length(),
      )
      if short_mode && target.has_prefix("refs/heads/") {
        print_line(
          String::unsafe_substring(target, start=11, end=target.length()),
        )
      } else {
        print_line(target)
      }
    } else {
      raise @git.GitError::InvalidObject("ref \{name} is not a symbolic ref")
    }
  } else {
    // Write mode
    let target = positional[1]
    fs.write_string(ref_path, "ref: \{target}\n")
  }
}

///|
