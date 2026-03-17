///| Trailer parsing and manipulation for commit messages

///|
/// Check if a line is a trailer line (format "Key: Value" or "Key = Value").
fn trailers_is_trailer(line : String) -> Bool {
  match line.find(": ") {
    Some(idx) => {
      if idx == 0 {
        return false
      }
      let key = String::unsafe_substring(line, start=0, end=idx)
      for c in key.to_array() {
        if c == ' ' || c == '\t' {
          return false
        }
      }
      true
    }
    None =>
      match line.find(" = ") {
        Some(idx) => {
          if idx == 0 {
            return false
          }
          let key = String::unsafe_substring(line, start=0, end=idx)
          for c in key.to_array() {
            if c == ' ' || c == '\t' {
              return false
            }
          }
          true
        }
        None => false
      }
  }
}

///|
fn trailers_trim(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = s[start]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start += 1
    } else {
      break
    }
  }
  while end > start {
    let c = s[end - 1]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end -= 1
    } else {
      break
    }
  }
  if start == 0 && end == s.length() {
    s
  } else {
    String::unsafe_substring(s, start~, end~)
  }
}

///|
/// Normalize a trailer string to "Key: Value" form.
fn trailers_normalize(trailer : String) -> String {
  match trailer.find(": ") {
    Some(_) => trailer
    None =>
      match trailer.find(":") {
        Some(idx) => {
          let key = String::unsafe_substring(trailer, start=0, end=idx)
          let value = trailers_trim(
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
              let key = trailers_trim(
                String::unsafe_substring(trailer, start=0, end=idx),
              )
              let value = trailers_trim(
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

///|
/// Parse trailer lines from the end of a commit message.
/// Returns an array of (key, value) pairs.
pub fn parse_trailers(message : String) -> Array[(String, String)] {
  let lines : Array[String] = []
  for line_view in message.split("\n") {
    lines.push(line_view.to_string())
  }
  // Remove trailing empty lines
  while lines.length() > 0 &&
        trailers_trim(lines[lines.length() - 1]).length() == 0 {
    ignore(lines.pop())
  }
  // Walk backwards to find trailer block
  let raw_trailers : Array[String] = []
  let mut i = lines.length() - 1
  while i >= 0 {
    let line = lines[i]
    if trailers_is_trailer(line) {
      raw_trailers.push(line)
      i -= 1
    } else {
      break
    }
  }
  let raw_trailers = raw_trailers.rev()
  // Parse each trailer into (key, value)
  let result : Array[(String, String)] = []
  for trailer in raw_trailers {
    match trailer.find(": ") {
      Some(idx) => {
        let key = String::unsafe_substring(trailer, start=0, end=idx)
        let value = String::unsafe_substring(
          trailer,
          start=idx + 2,
          end=trailer.length(),
        )
        result.push((key, value))
      }
      None =>
        match trailer.find(" = ") {
          Some(idx) => {
            let key = String::unsafe_substring(trailer, start=0, end=idx)
            let value = String::unsafe_substring(
              trailer,
              start=idx + 3,
              end=trailer.length(),
            )
            result.push((key, value))
          }
          None => ()
        }
    }
  }
  result
}

///|
/// Split a message into (body, trailer_lines).
fn trailers_split(input : String) -> (String, Array[String]) {
  let lines : Array[String] = []
  for line_view in input.split("\n") {
    lines.push(line_view.to_string())
  }
  // Remove trailing empty line from split
  if lines.length() > 0 && lines[lines.length() - 1].length() == 0 {
    ignore(lines.pop())
  }
  // Walk backwards to find trailer block
  let trailer_start = {
    let mut idx = lines.length()
    let mut i = lines.length() - 1
    while i >= 0 {
      let line = lines[i]
      if trailers_is_trailer(line) {
        idx = i
        i -= 1
      } else if trailers_trim(line).length() == 0 {
        break
      } else {
        break
      }
    }
    idx
  }
  let trailers : Array[String] = []
  let mut ti = trailer_start
  while ti < lines.length() {
    trailers.push(lines[ti])
    ti += 1
  }
  let body_sb = StringBuilder::new()
  let mut bi = 0
  while bi < trailer_start {
    body_sb.write_string(lines[bi])
    body_sb.write_char('\n')
    bi += 1
  }
  (body_sb.to_string(), trailers)
}

///|
/// Add a trailer to a commit message. If the message already has trailers,
/// the new trailer is appended after the existing ones.
pub fn add_trailer(message : String, key : String, value : String) -> String {
  let (body, existing) = trailers_split(message)
  let all_trailers : Array[String] = []
  all_trailers.append(existing)
  all_trailers.push(trailers_normalize("\{key}: \{value}"))
  let result = StringBuilder::new()
  result.write_string(body)
  // Ensure blank line before trailers if body doesn't end with one
  if body.length() > 0 && not(body.has_suffix("\n\n")) {
    if body.has_suffix("\n") {
      result.write_char('\n')
    } else {
      result.write_string("\n\n")
    }
  }
  for trailer in all_trailers {
    result.write_string(trailer)
    result.write_char('\n')
  }
  result.to_string()
}
