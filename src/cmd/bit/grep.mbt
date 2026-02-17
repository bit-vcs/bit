///|
async fn handle_grep(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let mut show_line_numbers = false
  let mut ignore_case = false
  let mut files_only = false
  let mut count_only = false
  let mut invert_match = false
  let mut pattern : String? = None
  let paths : Array[String] = []
  let mut after_dashdash = false
  for arg in args {
    if after_dashdash {
      paths.push(arg)
      continue
    }
    match arg {
      "--" => after_dashdash = true
      "-n" | "--line-number" => show_line_numbers = true
      "-i" | "--ignore-case" => ignore_case = true
      "-l" | "--files-with-matches" | "--name-only" => files_only = true
      "-c" | "--count" => count_only = true
      "-v" | "--invert-match" => invert_match = true
      "-e" => () // next arg is pattern, handled below
      _ if arg.has_prefix("-e") =>
        pattern = Some(String::unsafe_substring(arg, start=2, end=arg.length()))
      _ if not(arg.has_prefix("-")) =>
        if pattern is None {
          pattern = Some(arg)
        } else {
          paths.push(arg)
        }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("grep", arg)
      _ => ()
    }
  }
  guard pattern is Some(pat) else {
    raise @bitcore.GitError::InvalidObject("fatal: no pattern given")
  }
  // Get files from index
  let index_entries = @bitlib.read_index_entries(fs, git_dir)
  let files_to_search : Array[String] = []
  if paths.length() == 0 {
    for e in index_entries {
      files_to_search.push(e.path)
    }
  } else {
    for e in index_entries {
      for p in paths {
        if e.path == p || e.path.has_prefix(p + "/") {
          files_to_search.push(e.path)
          break
        }
      }
    }
  }
  // Search each file
  let mut found_any = false
  for file_path in files_to_search {
    let abs_path = root + "/" + file_path
    if not(fs.is_file(abs_path)) {
      continue
    }
    let content = decode_bytes(fs.read_file(abs_path)) catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => continue
    }
    let lines = content.split("\n")
    let mut match_count = 0
    let mut line_num = 0
    let matches : Array[(Int, String)] = []
    for line_view in lines {
      line_num += 1
      let line = line_view.to_string()
      let matched = if ignore_case {
        line.to_lower().contains(pat.to_lower())
      } else {
        line.contains(pat)
      }
      let should_output = if invert_match { not(matched) } else { matched }
      if should_output {
        match_count += 1
        matches.push((line_num, line))
      }
    }
    if match_count > 0 {
      found_any = true
      if files_only {
        print_line(file_path)
      } else if count_only {
        print_line("\{file_path}:\{match_count}")
      } else {
        for item in matches {
          let (num, line) = item
          if show_line_numbers {
            print_line("\{file_path}:\{num}:\{line}")
          } else {
            print_line("\{file_path}:\{line}")
          }
        }
      }
    }
  }
  if not(found_any) {
    @sys.exit(1)
  }
}

///|
