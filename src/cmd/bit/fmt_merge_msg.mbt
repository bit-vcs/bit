///| git fmt-merge-msg - produce a merge commit message

///|
async fn handle_fmt_merge_msg(args : Array[String]) -> Unit raise Error {
  let mut log_count = 0
  let mut custom_message : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git fmt-merge-msg [--log[=<n>]] [-m <message>] [--into-name <branch>]",
          summary="Produce a merge commit message from merge heads.",
        )
        return
      }
      "--log" => log_count = 20
      _ if arg.has_prefix("--log=") => {
        let num_str = String::unsafe_substring(arg, start=6, end=arg.length())
        log_count = parse_int(num_str)
      }
      "--no-log" => log_count = 0
      "-m" | "--message" => {
        i += 1
        if i < args.length() {
          custom_message = Some(args[i])
        }
      }
      _ if arg.has_prefix("--message=") =>
        custom_message = Some(
          String::unsafe_substring(arg, start=10, end=arg.length()),
        )
      _ if arg.has_prefix("--into-name") =>
        // Accept but ignore --into-name for now
        if arg == "--into-name" {
          i += 1
        }
      _ => ()
    }
    i += 1
  }
  let input = decode_bytes(read_all_stdin())
  let result = fmt_merge_msg_format(input, log_count, custom_message)
  if result.length() > 0 {
    print_str(result)
  }
}

///|
fn fmt_merge_msg_format(
  input : String,
  _log_count : Int,
  custom_message : String?,
) -> String {
  let merge_lines : Array[String] = []
  for line_view in input.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    // Skip comments
    if line.has_prefix("# ") || line == "#" {
      continue
    }
    merge_lines.push(line)
  }
  if merge_lines.length() == 0 {
    return match custom_message {
      Some(msg) => msg + "\n"
      None => ""
    }
  }
  let sb = StringBuilder::new()
  // Prepend custom message if given
  match custom_message {
    Some(msg) => {
      sb.write_string(msg)
      sb.write_string("\n\n")
    }
    None => ()
  }
  // Format merge lines
  // Lines like "branch 'name' of URL" → "Merge branch 'name' of URL"
  // Multiple branches → "Merge ..." with each on a line
  if merge_lines.length() == 1 {
    sb.write_string("Merge ")
    sb.write_string(merge_lines[0])
    sb.write_string("\n")
  } else {
    // Multiple merge heads
    sb.write_string("Merge ")
    sb.write_string(merge_lines[0])
    for i = 1; i < merge_lines.length(); i = i + 1 {
      sb.write_string(", ")
      sb.write_string(merge_lines[i])
    }
    sb.write_string("\n")
  }
  sb.to_string()
}
