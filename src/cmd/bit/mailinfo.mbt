///| git mailinfo - extract patch info from a single email message

///|
async fn handle_mailinfo(args : Array[String]) -> Unit raise Error {
  let mut strip_patch_prefix = false
  let mut scissors = false
  let mut message_id = false
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-b" => strip_patch_prefix = true
      "--scissors" => scissors = true
      "--no-scissors" => scissors = false
      "-m" | "--message-id" => message_id = true
      "--no-message-id" => message_id = false
      "-u" | "-n" => ()
      "-h" | "--help" => {
        show_simple_command_help(
          "git mailinfo [-b] [--scissors | --no-scissors] <msg> <patch>",
          summary="Extracts patch and authorship from a single e-mail message.",
        )
        return
      }
      _ if arg.has_prefix("--encoding=") => ()
      _ if not(arg.has_prefix("-")) => positional.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("mailinfo", arg)
      _ => ()
    }
    i += 1
  }
  if positional.length() < 2 {
    eprint_line(
      "usage: git mailinfo [-b] [--scissors | --no-scissors] <msg> <patch>",
    )
    @sys.exit(1)
    return
  }
  let msg_file = positional[0]
  let patch_file = positional[1]
  // Read email from stdin
  let input = decode_bytes(read_all_stdin())
  // Parse email headers and body
  let mut author = ""
  let mut email = ""
  let mut subject = ""
  let mut date = ""
  let mut in_headers = true
  let body = StringBuilder::new()
  let patch = StringBuilder::new()
  let mut in_patch = false
  let mut past_scissors = false
  for line_view in input.split("\n") {
    let line = line_view.to_string()
    if in_headers {
      if line.length() == 0 {
        in_headers = false
        continue
      }
      if line.has_prefix("From:") || line.has_prefix("from:") {
        let from_value = trim_string(
          String::unsafe_substring(line, start=5, end=line.length()),
        )
        let parsed = mailinfo_parse_from(from_value)
        author = parsed.0
        email = parsed.1
      } else if line.has_prefix("Subject:") || line.has_prefix("subject:") {
        subject = trim_string(
          String::unsafe_substring(line, start=8, end=line.length()),
        )
        if strip_patch_prefix {
          subject = mailinfo_strip_patch_prefix(subject)
        }
      } else if line.has_prefix("Date:") || line.has_prefix("date:") {
        date = trim_string(
          String::unsafe_substring(line, start=5, end=line.length()),
        )
      }
      continue
    }
    // Handle scissors
    if scissors && not(past_scissors) {
      if mailinfo_is_scissors_line(line) {
        past_scissors = true
        continue
      }
    }
    // Detect patch start
    if not(in_patch) {
      if line.has_prefix("diff --git ") {
        in_patch = true
      }
    }
    if in_patch {
      patch.write_string(line)
      patch.write_char('\n')
    } else {
      body.write_string(line)
      body.write_char('\n')
    }
  }
  // Output headers to stdout (git mailinfo protocol)
  if author.length() > 0 {
    print_line("Author: \{author}")
  }
  if email.length() > 0 {
    print_line("Email: \{email}")
  }
  if subject.length() > 0 {
    print_line("Subject: \{subject}")
  }
  if date.length() > 0 {
    print_line("Date: \{date}")
  }
  if message_id {
    print_line("Message-Id: ")
  }
  print_str("\n")
  // Write message body to msg file
  let fs = OsFs::new()
  fs.write_string(msg_file, body.to_string())
  // Write patch to patch file
  fs.write_string(patch_file, patch.to_string())
}

///|
fn mailinfo_parse_from(from : String) -> (String, String) {
  // Parse "Name <email>" or just "email"
  match from.find("<") {
    Some(lt) =>
      match from.find(">") {
        Some(gt) => {
          let name = trim_string(
            String::unsafe_substring(from, start=0, end=lt),
          )
          let addr = String::unsafe_substring(from, start=lt + 1, end=gt)
          (name, addr)
        }
        None => ("", from)
      }
    None => ("", from)
  }
}

///|
fn mailinfo_strip_patch_prefix(subject : String) -> String {
  // Strip [PATCH ...] prefix
  match subject.find("]") {
    Some(idx) =>
      if subject.has_prefix("[") {
        trim_string(
          String::unsafe_substring(subject, start=idx + 1, end=subject.length()),
        )
      } else {
        subject
      }
    None => subject
  }
}

///|
fn mailinfo_is_scissors_line(line : String) -> Bool {
  // Scissors line: "-- >8 --" or similar
  let trimmed = trim_string(line)
  trimmed.find("-- >8 --") is Some(_)
}

///|
