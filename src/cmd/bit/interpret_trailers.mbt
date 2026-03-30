///| git interpret-trailers - add or parse trailers in commit messages

///|
async fn handle_interpret_trailers(args : Array[String]) -> Unit raise Error {
  let trailers : Array[String] = []
  let mut where_pos = "end" // before|after|start|end
  let mut if_exists = "add" // replace|addIfDifferent|add|doNothing
  let mut if_missing = "add" // add|doNothing
  let mut in_place = false
  let mut only_trailers = false
  let mut only_input = false
  let mut no_divider = false
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git interpret-trailers [--trailer <token>[(=|:)<value>]] [<file>...]",
          summary="Add or parse trailing meta-data in commit messages.",
        )
        return
      }
      "--trailer" => {
        i += 1
        if i < args.length() {
          trailers.push(args[i])
        }
      }
      "--where" => {
        i += 1
        if i < args.length() {
          where_pos = args[i]
        }
      }
      "--if-exists" => {
        i += 1
        if i < args.length() {
          if_exists = args[i]
        }
      }
      "--if-missing" => {
        i += 1
        if i < args.length() {
          if_missing = args[i]
        }
      }
      "--in-place" => in_place = true
      "--parse" => {
        only_trailers = true
        no_divider = true
      }
      "--only-trailers" => only_trailers = true
      "--only-input" => only_input = true
      "--no-divider" => no_divider = true
      _ if arg.has_prefix("--trailer=") => {
        let value = String::unsafe_substring(arg, start=10, end=arg.length())
        trailers.push(value)
      }
      _ if arg.has_prefix("--where=") =>
        where_pos = String::unsafe_substring(arg, start=8, end=arg.length())
      _ if arg.has_prefix("--if-exists=") =>
        if_exists = String::unsafe_substring(arg, start=12, end=arg.length())
      _ if arg.has_prefix("--if-missing=") =>
        if_missing = String::unsafe_substring(arg, start=13, end=arg.length())
      _ if arg.has_prefix("-") =>
        warn_unimplemented_arg("interpret-trailers", arg)
      _ => positional.push(arg)
    }
    i += 1
  }
  ignore(where_pos)
  ignore(if_exists)
  ignore(if_missing)
  ignore(only_input)
  // Read input
  let fs = OsFs::new()
  let input = if positional.length() > 0 {
    let file_bytes = fs.read_file(positional[0]) catch { err => raise err }
    decode_bytes(file_bytes)
  } else {
    decode_bytes(read_all_stdin())
  }
  if only_trailers {
    // Parse and print existing trailers only
    let existing = @trailers.parse_trailers(input)
    let result = StringBuilder::new()
    for trailer in existing {
      result.write_string(trailer.0)
      result.write_string(": ")
      result.write_string(trailer.1)
      result.write_char('\n')
    }
    if !(no_divider) && existing.length() > 0 {
      // With divider, print separator line before trailers
      // but --parse implies --no-divider
    }
    print_str(result.to_string())
    return
  }
  // Build output: add all new trailers to the message
  let mut output = input
  for trailer in trailers {
    let normalized = interpret_trailers_normalize(trailer)
    // Parse the normalized trailer into key and value
    match normalized.find(": ") {
      Some(idx) => {
        let key = String::unsafe_substring(normalized, start=0, end=idx)
        let value = String::unsafe_substring(
          normalized,
          start=idx + 2,
          end=normalized.length(),
        )
        output = @trailers.add_trailer(output, key, value)
      }
      None => output = @trailers.add_trailer(output, normalized, "")
    }
  }
  if in_place && positional.length() > 0 {
    fs.write_file(positional[0], str_to_bytes(output)) catch {
      err => raise err
    }
  } else {
    print_str(output)
  }
}

///|
fn interpret_trailers_normalize(trailer : String) -> String {
  // Normalize "Key=Value" or "Key:Value" to "Key: Value"
  match trailer.find(": ") {
    Some(_) => trailer // already normalized
    None =>
      match trailer.find(":") {
        Some(idx) => {
          let key = String::unsafe_substring(trailer, start=0, end=idx)
          let value = trim_string(
            String::unsafe_substring(
              trailer,
              start=idx + 1,
              end=trailer.length(),
            ),
          )
          "\{key}: \{value}"
        }
        None =>
          match trailer.find("=") {
            Some(idx) => {
              let key = trim_string(
                String::unsafe_substring(trailer, start=0, end=idx),
              )
              let value = trim_string(
                String::unsafe_substring(
                  trailer,
                  start=idx + 1,
                  end=trailer.length(),
                ),
              )
              "\{key}: \{value}"
            }
            None => trailer
          }
      }
  }
}
