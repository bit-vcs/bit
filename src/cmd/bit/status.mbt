///|

///|
async fn show_status_command_help() -> Unit {
  show_simple_command_help(
    "git status [<options>] [--] [<pathspec>...]",
    summary="Show the working tree status.",
  )
}

///|
async fn handle_status(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let mut root = get_work_root()
  let mut git_dir = resolve_git_dir(fs, root)
  let mut has_git_dir = fs.is_dir(git_dir)
  let mut has_git_file = if has_git_dir { false } else { fs.is_file(git_dir) }
  if not(has_git_dir) && not(has_git_file) {
    match find_repo_root(".") {
      Some(found) => {
        root = found
        git_dir = resolve_git_dir(fs, root)
        has_git_dir = fs.is_dir(git_dir)
        has_git_file = if has_git_dir { false } else { fs.is_file(git_dir) }
      }
      None =>
        raise @git.GitError::InvalidObject(
          "Not a git repository (or any of the parent directories): .git/.bit",
        )
    }
  }
  if not(has_git_dir) && not(has_git_file) {
    raise @git.GitError::InvalidObject(
      "Not a git repository (or any of the parent directories): .git/.bit",
    )
  }
  let mut porcelain = false
  let mut short = false
  let mut show_branch = false
  for arg in args {
    match arg {
      "--porcelain" | "--porcelain=v1" => porcelain = true
      "-s" | "--short" => short = true
      "-b" | "--branch" => show_branch = true
      "-sb" => {
        short = true
        show_branch = true
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("status", arg)
      _ => ()
    }
  }
  // Show subdir-clone info if applicable (only in non-porcelain mode)
  if not(porcelain) && not(short) {
    match get_subdir_info(fs, git_dir) {
      Some((remote, path, base)) => {
        print_line("# subdir-clone: \{path} from \{remote}")
        print_line("# base: \{base[:7].to_string()}")
        print_line("")
      }
      None => ()
    }
  }
  if porcelain || short {
    if show_branch {
      let head = @gitlib.read_head_ref(fs, git_dir) catch {
        err if @async.is_cancellation_error(err) => raise err
        _ => return ()
      }
      match head {
        @gitlib.HeadRef::Branch(name) => print_line("## \{name}")
        @gitlib.HeadRef::Detached(id) =>
          print_line("## HEAD (detached at \{id.to_hex()[:7].to_string()})")
      }
    }
    let lines = @gitlib.status_porcelain(fs, root)
    for line in lines {
      print_line(line)
    }
  } else {
    let text = @gitlib.status_text(fs, root)
    print_str(text)
  }
}
