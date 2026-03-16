///| git check-mailmap - show canonical names and email addresses of contacts

///|
async fn handle_check_mailmap(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let mut use_stdin = false
  let contacts : Array[String] = []
  for arg in args {
    match arg {
      "--stdin" => use_stdin = true
      "-h" | "--help" => {
        show_simple_command_help(
          "git check-mailmap [--stdin] <contact>...",
          summary="Show canonical names and email addresses of contacts.",
        )
        return
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("check-mailmap", arg)
      _ => contacts.push(arg)
    }
  }
  let root = get_work_root()
  let git_dir = resolve_git_dir(fs, root)
  let mailmap = check_mailmap_read_mailmap(fs, root, git_dir)
  if use_stdin {
    let input = decode_bytes(read_all_stdin())
    for line_view in input.split("\n") {
      let line = line_view.to_string()
      if line.length() > 0 {
        print_line(check_mailmap_map_contact(line, mailmap))
      }
    }
  } else {
    if contacts.length() == 0 {
      eprint_line("fatal: no contacts specified")
      @sys.exit(1)
    }
    for contact in contacts {
      print_line(check_mailmap_map_contact(contact, mailmap))
    }
  }
}

///|
fn check_mailmap_read_mailmap(
  fs : OsFs,
  root : String,
  git_dir : String,
) -> Array[MailmapEntry] {
  // Reuse the mailmap parser from for_each_ref
  let entries : Array[MailmapEntry] = []
  // Read .mailmap from worktree root
  let worktree = if git_dir.has_suffix("/.git") {
    String::unsafe_substring(git_dir, start=0, end=git_dir.length() - 5)
  } else {
    root
  }
  check_mailmap_parse_file(fs, worktree + "/.mailmap", entries)
  // Also check mailmap.file config if set
  let config_mailmap = check_mailmap_get_config_mailmap_file(fs, git_dir)
  match config_mailmap {
    Some(path) => check_mailmap_parse_file(fs, path, entries)
    None => ()
  }
  entries
}

///|
fn check_mailmap_get_config_mailmap_file(
  fs : OsFs,
  git_dir : String,
) -> String? {
  let config_path = git_dir + "/config"
  let data = fs.read_file(config_path) catch { _ => return None }
  let text = decode_bytes(data)
  // Simple parse: look for mailmap.file = <value>
  let mut in_mailmap = false
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    let trimmed = check_mailmap_trim(line)
    if trimmed.has_prefix("[mailmap") {
      in_mailmap = true
      continue
    }
    if trimmed.has_prefix("[") {
      in_mailmap = false
      continue
    }
    if in_mailmap {
      match trimmed.find("=") {
        Some(eq_pos) => {
          let key = check_mailmap_trim(
            String::unsafe_substring(trimmed, start=0, end=eq_pos),
          ).to_lower()
          if key == "file" {
            let value = check_mailmap_trim(
              String::unsafe_substring(
                trimmed,
                start=eq_pos + 1,
                end=trimmed.length(),
              ),
            )
            if value.length() > 0 {
              return Some(value)
            }
          }
        }
        None => ()
      }
    }
  }
  None
}

///|
fn check_mailmap_parse_file(
  fs : OsFs,
  path : String,
  entries : Array[MailmapEntry],
) -> Unit {
  let data = fs.read_file(path) catch { _ => return }
  let text = decode_bytes(data)
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    // Parse <email> occurrences
    let emails : Array[String] = []
    let email_positions : Array[(Int, Int)] = []
    let mut pos = 0
    while pos < line.length() {
      match
        String::unsafe_substring(line, start=pos, end=line.length()).find("<") {
        Some(rel_start) => {
          let abs_start = pos + rel_start
          match
            String::unsafe_substring(line, start=abs_start, end=line.length()).find(
              ">",
            ) {
            Some(rel_end) => {
              let abs_end = abs_start + rel_end
              emails.push(
                String::unsafe_substring(line, start=abs_start + 1, end=abs_end),
              )
              email_positions.push((abs_start, abs_end))
              pos = abs_end + 1
            }
            None => break
          }
        }
        None => break
      }
    }
    if emails.length() == 1 {
      let name_part = check_mailmap_trim(
        String::unsafe_substring(line, start=0, end=email_positions[0].0),
      )
      entries.push({
        old_email: emails[0].to_lower(),
        old_name: "",
        new_email: "",
        new_name: name_part,
      })
    } else if emails.length() == 2 {
      let name_before_first = check_mailmap_trim(
        String::unsafe_substring(line, start=0, end=email_positions[0].0),
      )
      let name_between = check_mailmap_trim(
        String::unsafe_substring(
          line,
          start=email_positions[0].1 + 1,
          end=email_positions[1].0,
        ),
      )
      if name_before_first.length() == 0 && name_between.length() == 0 {
        entries.push({
          old_email: emails[1].to_lower(),
          old_name: "",
          new_email: emails[0],
          new_name: "",
        })
      } else if name_before_first.length() > 0 && name_between.length() == 0 {
        entries.push({
          old_email: emails[1].to_lower(),
          old_name: "",
          new_email: emails[0],
          new_name: name_before_first,
        })
      } else if name_before_first.length() > 0 && name_between.length() > 0 {
        entries.push({
          old_email: emails[1].to_lower(),
          old_name: name_between,
          new_email: emails[0],
          new_name: name_before_first,
        })
      }
    }
  }
}

///|
fn check_mailmap_map_contact(
  contact : String,
  mailmap : Array[MailmapEntry],
) -> String {
  // Parse contact: "Name <email>" or just "<email>"
  let lt_pos = match contact.find("<") {
    Some(p) => p
    None => return contact
  }
  let gt_pos = match contact.find(">") {
    Some(p) => p
    None => return contact
  }
  let orig_name = check_mailmap_trim(
    String::unsafe_substring(contact, start=0, end=lt_pos),
  )
  let orig_email = String::unsafe_substring(
    contact,
    start=lt_pos + 1,
    end=gt_pos,
  )
  let orig_email_lower = orig_email.to_lower()
  for entry in mailmap {
    if entry.old_email == orig_email_lower {
      if entry.old_name.length() > 0 && entry.old_name != orig_name {
        continue
      }
      let new_name = if entry.new_name.length() > 0 {
        entry.new_name
      } else {
        orig_name
      }
      let new_email = if entry.new_email.length() > 0 {
        entry.new_email
      } else {
        orig_email
      }
      return new_name + " <" + new_email + ">"
    }
  }
  // No match: return as-is in canonical form
  if orig_name.length() > 0 {
    orig_name + " <" + orig_email + ">"
  } else {
    "<" + orig_email + ">"
  }
}

///|
fn check_mailmap_trim(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && (chars[start] == ' ' || chars[start] == '\t') {
    start += 1
  }
  while end > start && (chars[end - 1] == ' ' || chars[end - 1] == '\t') {
    end -= 1
  }
  if start == 0 && end == s.length() {
    s
  } else {
    String::unsafe_substring(s, start~, end~)
  }
}
