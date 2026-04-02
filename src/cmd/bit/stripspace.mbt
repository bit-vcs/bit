///| git stripspace - clean up whitespace in text

///|
async fn handle_stripspace(args : Array[String]) -> Unit raise Error {
  let mut strip_comments = false
  let mut comment_lines = false
  for arg in args {
    match arg {
      "--strip-comments" | "-s" => strip_comments = true
      "--comment-lines" | "-c" => comment_lines = true
      "-h" | "--help" => {
        show_simple_command_help(
          "git stripspace [-s | -c]",
          summary="Read text on stdin and clean up the formatting.",
        )
        return
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("stripspace", arg)
      _ => ()
    }
  }
  let input = decode_bytes(read_all_stdin())
  if comment_lines {
    // Prefix each line with "# "
    let result = StringBuilder::new()
    let lines = stripspace_split_lines(input)
    for i, line in lines {
      if i > 0 {
        result.write_char('\n')
      }
      if line.length() == 0 {
        result.write_string("#")
      } else {
        result.write_string("# ")
        result.write_string(line)
      }
    }
    result.write_char('\n')
    print_str(result.to_string())
    return
  }
  let output = stripspace_clean(input, strip_comments)
  print_str(output)
}

///|
fn stripspace_split_lines(input : String) -> Array[String] {
  let lines : Array[String] = []
  for line_view in input.split("\n") {
    lines.push(line_view.to_string())
  }
  // Remove the trailing empty string from final newline
  if lines.length() > 0 && lines[lines.length() - 1].length() == 0 {
    ignore(lines.pop())
  }
  lines
}

///|
fn stripspace_clean(input : String, strip_comments : Bool) -> String {
  let lines : Array[String] = []
  for line_view in input.split("\n") {
    lines.push(line_view.to_string())
  }
  // Process lines
  let processed : Array[String] = []
  for line in lines {
    // Strip trailing whitespace
    let trimmed = stripspace_rtrim(line)
    // Skip comment lines if requested
    if strip_comments && stripspace_is_comment(trimmed) {
      continue
    }
    processed.push(trimmed)
  }
  // Collapse consecutive blank lines to one, strip leading/trailing blanks
  let result : Array[String] = []
  let mut prev_blank = true // Start true to strip leading blanks
  for line in processed {
    if line.length() == 0 {
      if !prev_blank {
        result.push("")
      }
      prev_blank = true
    } else {
      result.push(line)
      prev_blank = false
    }
  }
  // Strip trailing blank lines
  while result.length() > 0 && result[result.length() - 1].length() == 0 {
    ignore(result.pop())
  }
  // Build output
  if result.length() == 0 {
    return ""
  }
  let sb = StringBuilder::new()
  for i, line in result {
    if i > 0 {
      sb.write_char('\n')
    }
    sb.write_string(line)
  }
  sb.write_char('\n')
  sb.to_string()
}

///|
fn stripspace_rtrim(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 {
    let c = chars[end - 1]
    if c == ' ' || c == '\t' || c == '\r' {
      end -= 1
    } else {
      break
    }
  }
  if end == chars.length() {
    return s
  }
  String::unsafe_substring(s, start=0, end~)
}

///|
fn stripspace_is_comment(line : String) -> Bool {
  // A comment line starts with '#' (optionally after leading whitespace? No — git checks first char)
  if line.length() == 0 {
    return false
  }
  let chars = line.to_array()
  chars[0] == '#'
}
