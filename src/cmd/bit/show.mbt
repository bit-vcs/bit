///|

///|
async fn show_show_command_help() -> Unit {
  show_simple_command_help(
    "git show [<options>] [<object>...]",
    summary="Show various types of objects.",
  )
}

///|
priv struct ShowCommitInfo {
  author : String
  timestamp : Int64
  message : String
}

///|
fn parse_show_commit(data : Bytes) -> ShowCommitInfo {
  let text = decode_bytes(data)
  let mut author = ""
  let mut timestamp = 0L
  let mut in_message = false
  let message_lines : Array[String] = []
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if in_message {
      message_lines.push(line)
      continue
    }
    if line.length() == 0 {
      in_message = true
      continue
    }
    if line.has_prefix("author ") {
      let rest = String::unsafe_substring(line, start=7, end=line.length())
      // format: Name <email> 1700000000 +0000
      let mut last_space = rest.rev_find(" ")
      if last_space is Some(tz_idx) {
        let before_tz = String::unsafe_substring(rest, start=0, end=tz_idx)
        last_space = before_tz.rev_find(" ")
        if last_space is Some(time_idx) {
          author = String::unsafe_substring(before_tz, start=0, end=time_idx)
          let time_str = String::unsafe_substring(
            before_tz,
            start=time_idx + 1,
            end=before_tz.length(),
          )
          for c in time_str {
            if c >= '0' && c <= '9' {
              let digit = c.to_int() - '0'.to_int()
              timestamp = timestamp * 10L + digit.to_int64()
            }
          }
        } else {
          author = before_tz
        }
      } else {
        author = rest
      }
    }
  }
  let message = message_lines.join("\n")
  { author, timestamp, message }
}

///|
async fn handle_show(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let git_dir = resolve_git_dir(fs, root)
  // Parse: git show [--pretty=<format>] [<commit>]
  let mut rev = "HEAD"
  let mut pretty_raw = false
  let mut pretty_format : String? = None
  let mut quiet = false
  for arg in args {
    if arg == "--pretty=raw" || arg == "--format=raw" {
      pretty_raw = true
    } else if arg == "-q" || arg == "--quiet" {
      quiet = true
    } else if arg.has_prefix("--pretty=format:") {
      pretty_format = Some(
        String::unsafe_substring(arg, start=16, end=arg.length()),
      )
    } else if arg.has_prefix("--format=") {
      pretty_format = Some(
        String::unsafe_substring(arg, start=9, end=arg.length()),
      )
    } else if not(arg.has_prefix("-")) {
      rev = arg
    } else {
      warn_unimplemented_arg("show", arg)
    }
  }
  // Resolve revision
  let id = @gitrepo.rev_parse(fs, git_dir, rev)
  guard id is Some(commit_id) else {
    raise @git.GitError::InvalidObject("unknown revision: \{rev}")
  }
  // Load object
  let db = @gitlib.ObjectDb::load(fs, git_dir)
  let obj = db.get(fs, commit_id)
  guard obj is Some(o) else {
    raise @git.GitError::InvalidObject(
      "Object not found: \{commit_id.to_hex()}",
    )
  }
  // `git show <blob-ish>` should print blob contents directly.
  if o.obj_type == @git.ObjectType::Blob {
    @stdio.stdout.write(o.data)
    return ()
  }
  if o.obj_type != @git.ObjectType::Commit {
    raise @git.GitError::InvalidObject("Not a commit: \{commit_id.to_hex()}")
  }
  // Parse commit for tree/parents
  let commit_info = @git.parse_commit(o.data)
  // If --pretty=raw, output raw commit object content
  if pretty_raw {
    print_line("commit \{commit_id.to_hex()}")
    // Output the raw commit object as text
    let text = decode_bytes(o.data)
    print_str(text)
    if not(text.has_suffix("\n")) {
      print_line("")
    }
    return ()
  }
  if pretty_format is Some(fmt) {
    match fmt {
      "%h" => {
        let short = String::unsafe_substring(commit_id.to_hex(), start=0, end=7)
        print_line(short)
        return ()
      }
      "%H" => {
        print_line(commit_id.to_hex())
        return ()
      }
      _ => warn_unimplemented_arg("show", "--pretty=format:\{fmt}")
    }
  }
  // Parse full commit details
  let show_info = parse_show_commit(o.data)
  // Print commit info
  print_line("commit \{commit_id.to_hex()}")
  print_line("Author: \{show_info.author}")
  print_line("Date:   \{show_info.timestamp}")
  print_line("")
  // Print message with indentation
  for line_view in show_info.message.split("\n") {
    print_line("    \{line_view.to_string()}")
  }
  print_line("")
  // Show diff against parent (simplified)
  if not(quiet) && commit_info.parents.length() > 0 {
    let parent_id = commit_info.parents[0]
    let parent_files = @gitlib.collect_tree_files_from_commit(db, fs, parent_id)
    let current_files = @gitlib.collect_tree_files_from_commit(
      db, fs, commit_id,
    )
    // Show changed files
    for item in current_files.to_array() {
      let (path, entry) = item
      match parent_files.get(path) {
        None => print_line("diff --git a/\{path} b/\{path}\nnew file")
        Some(parent_entry) =>
          if entry.id != parent_entry.id {
            print_line("diff --git a/\{path} b/\{path}")
          }
      }
    }
    for item in parent_files.to_array() {
      let (path, _) = item
      if not(current_files.contains(path)) {
        print_line("diff --git a/\{path} b/\{path}\ndeleted file")
      }
    }
  }
}
