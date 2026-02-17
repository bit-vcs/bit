///| Maintenance handlers: am, apply, fsck, prune, pack-refs, repack, maintenance

///|
async fn handle_am(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let git_dir = find_git_dir(fs)
  let mut abort = false
  let mut skip = false
  let mut continue_am = false
  let mut three_way = false
  let mut signoff = false
  let mut keep = false
  let mut keep_cr = false
  let mut no_keep_cr = false
  let mut quiet = false
  let mut directory : String? = None
  let mbox_files : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--abort" => abort = true
      "--skip" => skip = true
      "--continue" | "--resolved" => continue_am = true
      "-3" | "--3way" => three_way = true
      "-s" | "--signoff" => signoff = true
      "-k" | "--keep" => keep = true
      "--keep-cr" => keep_cr = true
      "--no-keep-cr" => no_keep_cr = true
      "-q" | "--quiet" => quiet = true
      "--directory" => {
        i += 1
        if i < args.length() {
          directory = Some(args[i])
        }
      }
      _ if arg.has_prefix("--directory=") =>
        directory = Some(
          String::unsafe_substring(arg, start=12, end=arg.length()),
        )
      _ if not(arg.has_prefix("-")) => mbox_files.push(arg)
      _ => ()
    }
    i += 1
  }
  let am_dir = git_dir + "/rebase-apply"
  // Handle --abort
  if abort {
    if fs.is_dir(am_dir) {
      // Restore original HEAD
      let orig_head_file = am_dir + "/orig-head"
      if fs.is_file(orig_head_file) {
        let orig_head = fs.read_file(orig_head_file)
          |> decode_bytes
          |> trim_string
        fs.write_string(git_dir + "/HEAD", orig_head + "\n")
      }
      remove_dir_recursive(fs, am_dir)
      if not(quiet) {
        print_line("Aborting.")
      }
    }
    return
  }
  // Handle --skip
  if skip {
    if not(fs.is_dir(am_dir)) {
      raise @bitcore.GitError::InvalidObject("No am in progress")
    }
    let next_file = am_dir + "/next"
    if fs.is_file(next_file) {
      let next = fs.read_file(next_file) |> decode_bytes |> trim_string
      let n = @strconv.parse_int(next) catch {
        err if @async.is_cancellation_error(err) => raise err
        _ => 1
      }
      fs.write_string(next_file, (n + 1).to_string())
    }
    continue_am = true
  }
  // Handle --continue or apply new patches
  if continue_am {
    if not(fs.is_dir(am_dir)) {
      raise @bitcore.GitError::InvalidObject("No am in progress")
    }
    apply_remaining_patches(
      fs, root, git_dir, am_dir, three_way, signoff, quiet,
    )
    return
  }
  // Start new am session
  if mbox_files.length() == 0 {
    let input_bytes = read_all_stdin()
    let input = decode_bytes(input_bytes)
    if input.length() > 0 {
      fs.mkdir_p(am_dir)
      let patches = parse_mbox(input, keep_cr && not(no_keep_cr))
      if patches.length() == 0 {
        remove_dir_recursive(fs, am_dir)
        raise @bitcore.GitError::InvalidObject("No patches found in input")
      }
      let head = @bitlib.resolve_ref(fs, git_dir, "HEAD")
      if head is Some(id) {
        fs.write_string(am_dir + "/orig-head", id.to_hex())
      }
      fs.write_string(am_dir + "/last", patches.length().to_string())
      fs.write_string(am_dir + "/next", "1")
      for idx, patch in patches {
        let patch_file = am_dir + "/" + zero_pad(idx + 1, 4)
        fs.write_string(patch_file, patch.content)
        let msg_file = am_dir + "/msg-" + zero_pad(idx + 1, 4)
        fs.write_string(msg_file, patch.message)
        let info_file = am_dir + "/info-" + zero_pad(idx + 1, 4)
        let info = "Author: \{patch.author}\nDate: \{patch.date}\nSubject: \{patch.subject}\n"
        fs.write_string(info_file, info)
      }
      apply_remaining_patches(
        fs, root, git_dir, am_dir, three_way, signoff, quiet,
      )
    }
  } else {
    fs.mkdir_p(am_dir)
    let all_patches : Array[MboxPatch] = []
    for file in mbox_files {
      let content = decode_bytes(fs.read_file(file))
      let patches = parse_mbox(content, keep_cr && not(no_keep_cr))
      for p in patches {
        all_patches.push(p)
      }
    }
    if all_patches.length() == 0 {
      remove_dir_recursive(fs, am_dir)
      raise @bitcore.GitError::InvalidObject("No patches found")
    }
    let head = @bitlib.resolve_ref(fs, git_dir, "HEAD")
    if head is Some(id) {
      fs.write_string(am_dir + "/orig-head", id.to_hex())
    }
    fs.write_string(am_dir + "/last", all_patches.length().to_string())
    fs.write_string(am_dir + "/next", "1")
    for idx, patch in all_patches {
      let patch_file = am_dir + "/" + zero_pad(idx + 1, 4)
      fs.write_string(patch_file, patch.content)
      let msg_file = am_dir + "/msg-" + zero_pad(idx + 1, 4)
      fs.write_string(msg_file, patch.message)
      let info_file = am_dir + "/info-" + zero_pad(idx + 1, 4)
      let info = "Author: \{patch.author}\nDate: \{patch.date}\nSubject: \{patch.subject}\n"
      fs.write_string(info_file, info)
    }
    apply_remaining_patches(
      fs, root, git_dir, am_dir, three_way, signoff, quiet,
    )
  }
  ignore(directory)
  ignore(keep)
}

///|
struct MboxPatch {
  author : String
  date : String
  subject : String
  message : String
  content : String
}

///|
fn parse_mbox(input : String, keep_cr : Bool) -> Array[MboxPatch] {
  let patches : Array[MboxPatch] = []
  let lines : Array[String] = []
  for v in input.split("\n") {
    let s = v.to_string()
    if keep_cr {
      lines.push(s)
    } else {
      lines.push(s.trim_end(chars="\r").to_string())
    }
  }
  let mut in_header = false
  let mut in_body = false
  let mut in_diff = false
  let mut author = ""
  let mut date = ""
  let mut subject = ""
  let message_lines : Array[String] = []
  let diff_lines : Array[String] = []
  for line in lines {
    if line.has_prefix("From ") && line.length() > 40 {
      if diff_lines.length() > 0 {
        patches.push({
          author,
          date,
          subject,
          message: message_lines.join("\n"),
          content: diff_lines.join("\n"),
        })
      }
      in_header = true
      in_body = false
      in_diff = false
      author = ""
      date = ""
      subject = ""
      message_lines.clear()
      diff_lines.clear()
    } else if in_header {
      if line == "" {
        in_header = false
        in_body = true
      } else if line.has_prefix("From: ") {
        author = String::unsafe_substring(line, start=6, end=line.length())
      } else if line.has_prefix("Date: ") {
        date = String::unsafe_substring(line, start=6, end=line.length())
      } else if line.has_prefix("Subject: ") {
        subject = String::unsafe_substring(line, start=9, end=line.length())
        if subject.has_prefix("[PATCH") {
          match subject.find("]") {
            Some(idx) =>
              subject = String::unsafe_substring(
                  subject,
                  start=idx + 1,
                  end=subject.length(),
                )
                .trim()
                .to_string()
            None => ()
          }
        }
      }
    } else if in_body {
      if line.has_prefix("diff --git ") ||
        (line.has_prefix("---") && line.length() <= 4) {
        in_body = false
        in_diff = true
        if line.has_prefix("diff --git ") {
          diff_lines.push(line)
        }
      } else {
        message_lines.push(line)
      }
    } else if in_diff {
      diff_lines.push(line)
    }
  }
  if diff_lines.length() > 0 {
    patches.push({
      author,
      date,
      subject,
      message: message_lines.join("\n"),
      content: diff_lines.join("\n"),
    })
  }
  patches
}

///|
fn zero_pad(n : Int, width : Int) -> String {
  let s = n.to_string()
  if s.length() >= width {
    return s
  }
  let padding = "0".repeat(width - s.length())
  padding + s
}

///|
async fn apply_remaining_patches(
  fs : OsFs,
  root : String,
  git_dir : String,
  am_dir : String,
  three_way : Bool,
  signoff : Bool,
  quiet : Bool,
) -> Unit raise Error {
  let last_str = fs.read_file(am_dir + "/last") |> decode_bytes |> trim_string
  let next_str = fs.read_file(am_dir + "/next") |> decode_bytes |> trim_string
  let last = @strconv.parse_int(last_str) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => 0
  }
  let mut next = @strconv.parse_int(next_str) catch {
    err if @async.is_cancellation_error(err) => raise err
    _ => 1
  }
  while next <= last {
    let patch_file = am_dir + "/" + zero_pad(next, 4)
    let msg_file = am_dir + "/msg-" + zero_pad(next, 4)
    let info_file = am_dir + "/info-" + zero_pad(next, 4)
    if not(fs.is_file(patch_file)) {
      next += 1
      fs.write_string(am_dir + "/next", next.to_string())
      continue
    }
    let patch_content = decode_bytes(fs.read_file(patch_file))
    let message = if fs.is_file(msg_file) {
      fs.read_file(msg_file) |> decode_bytes |> trim_string
    } else {
      ""
    }
    let mut author = ""
    let mut author_date = ""
    let mut subject = ""
    if fs.is_file(info_file) {
      let info = decode_bytes(fs.read_file(info_file))
      for line_view in info.split("\n") {
        let line = line_view.to_string()
        if line.has_prefix("Author: ") {
          author = String::unsafe_substring(line, start=8, end=line.length())
        } else if line.has_prefix("Date: ") {
          author_date = String::unsafe_substring(
            line,
            start=6,
            end=line.length(),
          )
        } else if line.has_prefix("Subject: ") {
          subject = String::unsafe_substring(line, start=9, end=line.length())
        }
      }
    }
    if not(quiet) {
      print_line("Applying: \{subject}")
    }
    apply_patch_to_worktree(fs, root, patch_content, three_way)
    let commit_msg = if signoff {
      let config_path = git_dir + "/config"
      let user = get_config_value_simple(fs, config_path, "user.name").unwrap_or(
        "",
      )
      let email = get_config_value_simple(fs, config_path, "user.email").unwrap_or(
        "",
      )
      if message.length() > 0 {
        "\{subject}\n\n\{message}\n\nSigned-off-by: \{user} <\{email}>"
      } else {
        "\{subject}\n\nSigned-off-by: \{user} <\{email}>"
      }
    } else if message.length() > 0 {
      "\{subject}\n\n\{message}"
    } else {
      subject
    }
    stage_all_changes(fs, root)
    if author.length() > 0 {
      @sys.set_env_var("GIT_AUTHOR_NAME", extract_name_str(author))
      @sys.set_env_var("GIT_AUTHOR_EMAIL", extract_email_str(author))
    }
    if author_date.length() > 0 {
      @sys.set_env_var("GIT_AUTHOR_DATE", author_date)
    }
    let commit_author = get_author_string()
    let commit_timestamp = get_commit_timestamp()
    let _ = @bitlib.commit(
      fs, fs, root, commit_msg, commit_author, commit_timestamp,
    )
    next += 1
    fs.write_string(am_dir + "/next", next.to_string())
  }
  remove_dir_recursive(fs, am_dir)
}

///|
fn extract_name_str(author : String) -> String {
  match author.find("<") {
    Some(idx) =>
      String::unsafe_substring(author, start=0, end=idx).trim().to_string()
    None => author.trim().to_string()
  }
}

///|
fn extract_email_str(author : String) -> String {
  match author.find("<") {
    Some(start) =>
      match author.find(">") {
        Some(end) => String::unsafe_substring(author, start=start + 1, end~)
        None => ""
      }
    None => ""
  }
}

///|
fn apply_patch_to_worktree(
  fs : OsFs,
  root : String,
  patch : String,
  _three_way : Bool,
) -> Unit raise Error {
  let mut current_file = ""
  let mut old_file = ""
  let mut new_file = ""
  let hunks : Array[(Int, Int, Array[String])] = []
  let mut hunk_old_start = 0
  let mut hunk_old_count = 0
  let mut hunk_lines : Array[String] = []
  let mut in_hunk = false
  for line_view in patch.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("diff --git ") {
      if current_file.length() > 0 && hunks.length() > 0 {
        apply_hunks_to_file(fs, root, current_file, hunks, old_file, new_file)
        hunks.clear()
      }
      let parts : Array[String] = String::unsafe_substring(
          line,
          start=11,
          end=line.length(),
        )
        .split(" ")
        .map(v => v.to_string())
        .collect()
      if parts.length() >= 2 {
        old_file = parts[0]
        new_file = parts[1]
        if old_file.has_prefix("a/") {
          old_file = String::unsafe_substring(
            old_file,
            start=2,
            end=old_file.length(),
          )
        }
        if new_file.has_prefix("b/") {
          new_file = String::unsafe_substring(
            new_file,
            start=2,
            end=new_file.length(),
          )
        }
        current_file = new_file
      }
      in_hunk = false
    } else if line.has_prefix("--- ") {
      let path = String::unsafe_substring(line, start=4, end=line.length())
      if path.has_prefix("a/") {
        old_file = String::unsafe_substring(path, start=2, end=path.length())
      } else if path != "/dev/null" {
        old_file = path
      }
    } else if line.has_prefix("+++ ") {
      let path = String::unsafe_substring(line, start=4, end=line.length())
      if path.has_prefix("b/") {
        new_file = String::unsafe_substring(path, start=2, end=path.length())
        current_file = new_file
      } else if path != "/dev/null" {
        new_file = path
        current_file = new_file
      }
    } else if line.has_prefix("@@ ") {
      if in_hunk && hunk_lines.length() > 0 {
        hunks.push((hunk_old_start, hunk_old_count, hunk_lines))
        hunk_lines = []
      }
      match parse_hunk_header(line) {
        Some((os, oc, _, _)) => {
          hunk_old_start = os
          hunk_old_count = oc
          in_hunk = true
        }
        None => ()
      }
    } else if in_hunk {
      hunk_lines.push(line)
    }
  }
  if current_file.length() > 0 &&
    (hunks.length() > 0 || hunk_lines.length() > 0) {
    if hunk_lines.length() > 0 {
      hunks.push((hunk_old_start, hunk_old_count, hunk_lines))
    }
    apply_hunks_to_file(fs, root, current_file, hunks, old_file, new_file)
  }
}

///|
fn parse_hunk_header(line : String) -> (Int, Int, Int, Int)? {
  if not(line.has_prefix("@@ ")) {
    return None
  }
  let content = String::unsafe_substring(line, start=3, end=line.length())
  match content.find(" @@") {
    None => return None
    Some(end) => {
      let range_part = String::unsafe_substring(content, start=0, end~)
      let parts : Array[String] = range_part
        .split(" ")
        .map(v => v.to_string())
        .collect()
      if parts.length() < 2 {
        return None
      }
      let old_part = parts[0]
      let new_part = parts[1]
      let (old_start, old_count) = parse_range(
        String::unsafe_substring(old_part, start=1, end=old_part.length()),
      )
      let (new_start, new_count) = parse_range(
        String::unsafe_substring(new_part, start=1, end=new_part.length()),
      )
      Some((old_start, old_count, new_start, new_count))
    }
  }
}

///|
fn parse_range(s : String) -> (Int, Int) {
  match s.find(",") {
    Some(idx) => {
      let start_str = String::unsafe_substring(s, start=0, end=idx)
      let count_str = String::unsafe_substring(s, start=idx + 1, end=s.length())
      let start = @strconv.parse_int(start_str) catch { _ => 1 }
      let count = @strconv.parse_int(count_str) catch { _ => 1 }
      (start, count)
    }
    None => {
      let start = @strconv.parse_int(s) catch { _ => 1 }
      (start, 1)
    }
  }
}

///|
fn apply_hunks_to_file(
  fs : OsFs,
  root : String,
  file : String,
  hunks : Array[(Int, Int, Array[String])],
  _old_file : String,
  _new_file : String,
) -> Unit raise Error {
  let path = root + "/" + file
  let original_lines : Array[String] = if fs.is_file(path) {
    decode_bytes(fs.read_file(path))
    .split("\n")
    .map(v => v.to_string())
    .collect()
  } else {
    match file.rev_find("/") {
      Some(idx) => {
        let dir = root + "/" + String::unsafe_substring(file, start=0, end=idx)
        fs.mkdir_p(dir)
      }
      None => ()
    }
    []
  }
  let result_lines : Array[String] = []
  let mut line_idx = 0
  for hunk in hunks {
    let (old_start, _old_count, hunk_lines) = hunk
    while line_idx < old_start - 1 && line_idx < original_lines.length() {
      result_lines.push(original_lines[line_idx])
      line_idx += 1
    }
    for hl in hunk_lines {
      if hl.has_prefix("+") {
        result_lines.push(
          String::unsafe_substring(hl, start=1, end=hl.length()),
        )
      } else if hl.has_prefix("-") {
        line_idx += 1
      } else if hl.has_prefix(" ") || hl == "" {
        if line_idx < original_lines.length() {
          result_lines.push(original_lines[line_idx])
        } else {
          result_lines.push(
            String::unsafe_substring(hl, start=1, end=hl.length()),
          )
        }
        line_idx += 1
      }
    }
  }
  while line_idx < original_lines.length() {
    result_lines.push(original_lines[line_idx])
    line_idx += 1
  }
  fs.write_string(path, result_lines.join("\n"))
}

///|
