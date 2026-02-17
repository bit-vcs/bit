///|
async fn handle_request_pull(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut i = 0
  let positional : Array[String] = []
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-p" => ()
      _ if arg.has_prefix("--signoff=") => ()
      _ if not(arg.has_prefix("-")) => positional.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("request-pull", arg)
      _ => ()
    }
    i += 1
  }
  // Expected: start url [end]
  if positional.length() < 2 {
    eprint_line("usage: git request-pull <start> <url> [<end>]")
    @sys.exit(1)
    return
  }
  let start = positional[0]
  let url = positional[1]
  let end = if positional.length() > 2 { positional[2] } else { "HEAD" }
  // Resolve start and end commits
  let start_id = match @bitrepo.rev_parse(fs, git_dir, start) {
    Some(id) => id
    None => {
      eprint_line("fatal: Not a valid revision: " + start)
      @sys.exit(128)
      return
    }
  }
  let end_id = match @bitrepo.rev_parse(fs, git_dir, end) {
    Some(id) => id
    None => {
      eprint_line("fatal: Not a valid revision: " + end)
      @sys.exit(128)
      return
    }
  }
  // Verify end is a commit
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let end_obj = db.get(fs, end_id)
  match end_obj {
    Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit => ()
    _ => {
      eprint_line("fatal: Not a commit: " + end)
      @sys.exit(128)
      return
    }
  }
  // Count commits
  let mut commit_count = 0
  let mut current : @bitcore.ObjectId? = Some(end_id)
  let start_hex = start_id.to_hex()
  while current is Some(id) {
    if id.to_hex() == start_hex {
      break
    }
    commit_count += 1
    match db.get(fs, id) {
      Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit => {
        let info = @bitcore.parse_commit(obj.data)
        current = if info.parents.length() > 0 {
          Some(info.parents[0])
        } else {
          None
        }
      }
      _ => current = None
    }
  }
  // Get current branch name
  let head_content = decode_bytes(fs.read_file(git_dir + "/HEAD"))
  let branch = if head_content.has_prefix("ref: refs/heads/") {
    trim_string(head_content[16:].to_string())
  } else {
    end_id.to_hex()[:7].to_string()
  }
  // Print request-pull output
  print_line("The following changes since commit " + start_id.to_hex() + ":")
  print_line("")
  // Get start commit message
  match db.get(fs, start_id) {
    Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit => {
      let first_line = plumb_get_first_line_of_commit(obj.data)
      print_line(
        "  " + first_line + " (" + start_id.to_hex()[:10].to_string() + ")",
      )
    }
    _ => ()
  }
  print_line("")
  print_line("are available in the Git repository at:")
  print_line("")
  print_line("  " + url + " " + branch)
  print_line("")
  print_line("for you to fetch changes up to " + end_id.to_hex() + ":")
  print_line("")
  // Get end commit message
  match db.get(fs, end_id) {
    Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit => {
      let first_line = plumb_get_first_line_of_commit(obj.data)
      print_line(
        "  " + first_line + " (" + end_id.to_hex()[:10].to_string() + ")",
      )
    }
    _ => ()
  }
  print_line("")
  print_line("----------------------------------------------------------------")
  print_line("")
  print_line(commit_count.to_string() + " commit(s) since " + start)
  print_line("")
}

///|
fn plumb_get_first_line_of_commit(data : Bytes) -> String {
  let text = decode_bytes(data)
  // Skip header lines until empty line
  let mut in_body = false
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if not(in_body) {
      if line.length() == 0 {
        in_body = true
      }
      continue
    }
    // Return first non-empty body line
    if line.length() > 0 {
      return line
    }
  }
  ""
}

///|
