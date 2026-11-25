///| Strict parsing of Git config file contents.

///|
/// An entry in source order. The section and variable names in the qualified
/// key are lowercase. Quoted subsections retain their case.
#derive(Eq, Debug)
pub(all) struct ConfigEntry {
  key : String
  /// A bare key has no value, while a key followed by '=' has an empty value.
  value : String?
}

///|
#derive(Eq, Debug)
pub(all) suberror ConfigParseError {
  InvalidConfig(line~ : Int32, reason~ : String)
}

///|
/// Parse one Git config file. Duplicate entries are preserved in source order.
/// The caller is responsible for resolving includes and config precedence.
pub fn parse_config(
  content : String,
) -> Array[ConfigEntry] raise ConfigParseError {
  let normalized = content.replace_all(old="\r\n", new="\n")
  let input = normalized.strip_prefix("\uFEFF").unwrap_or(normalized[:])
  let entries = []
  for rest = input, line = 1, prefix = "" {
    let rest = rest.trim_start(chars=" \t\r\u000b\u000c")
    match rest {
      [] => break
      ['\n', .. tail] => continue tail, line + 1, prefix
      ['#' | ';', ..] =>
        match rest.split_once("\n") {
          Some((_, tail)) => continue tail, line + 1, prefix
          None => break
        }
      ['[', .. tail] => {
        let (prefix, tail) = parse_config_section(tail, line)
        continue tail, line, prefix
      }
      [first, ..] if first.is_ascii_alphabetic() => {
        let (name, tail) = scan_config_name(rest)
        let key = prefix + name.to_lower().to_owned()
        let tail = tail.trim_start(chars=" \t")
        let (value, tail, line) = match tail {
          [] | ['\n', ..] => (None, tail, line)
          ['=', .. value] => {
            let (value, tail, line) = parse_config_entry_value(value, line)
            (Some(value), tail, line)
          }
          _ => raise InvalidConfig(line~, reason="Expected '=' after key")
        }
        entries.push({ key, value, })
        continue tail, line, prefix
      }
      _ => raise InvalidConfig(line~, reason="Expected a section or key")
    }
  }
  entries
}

///|
fn scan_config_name(
  input : StringView,
  section~ : Bool = false,
) -> (StringView, StringView) {
  let end = input
    .find_by(c => {
      !(c.is_ascii_alphabetic() ||
      c.is_ascii_digit() ||
      c == '-' ||
      (section && c == '.'))
    })
    .unwrap_or(input.length())
  (input[:end], input[end:])
}

///|
fn parse_config_section(
  input : StringView,
  line : Int32,
) -> (String, StringView) raise ConfigParseError {
  let (section, tail) = scan_config_name(input, section=true)
  guard !section.is_empty() else {
    raise InvalidConfig(line~, reason="Expected a section name")
  }
  let prefix = section.to_lower().to_owned() + "."
  if tail is [']', .. rest] {
    return (prefix, rest)
  }
  guard tail is [' ' | '\t' | '\r' | '\u000b' | '\u000c', ..] &&
    tail.trim_start(chars=" \t\r\u000b\u000c") is ['"', .. subsection] else {
    raise InvalidConfig(line~, reason="Invalid section header")
  }
  let name = StringBuilder()
  for rest = subsection {
    match rest {
      ['"', ']', .. tail] => break (prefix + name.to_string() + ".", tail)
      ['\\', c, .. tail] if !(c is ('\n' | '\u0000')) => {
        name.write_char(c)
        continue tail
      }
      [c, .. tail] if !(c is ('\\' | '"' | '\n' | '\u0000')) => {
        name.write_char(c)
        continue tail
      }
      _ => raise InvalidConfig(line~, reason="Invalid subsection header")
    }
  }
}

///|
fn parse_config_entry_value(
  input : StringView,
  line : Int32,
) -> (String, StringView, Int32) raise ConfigParseError {
  let value = StringBuilder()
  let mut rest = input
  let mut line = line
  let mut quoted = false
  let mut spaces = 0
  while rest is [c, .. tail] && c != '\n' {
    if !quoted && c is ('#' | ';') {
      break
    }
    rest = tail
    if !quoted && c is (' ' | '\t' | '\r' | '\u000b' | '\u000c') {
      if !value.is_empty() {
        spaces += 1
      }
      continue
    }
    for _ in 0..<spaces {
      value.write_char(' ')
    }
    spaces = 0
    match c {
      '"' => quoted = !quoted
      '\\' =>
        if rest is [escape, .. tail] {
          rest = tail
          if escape == '\n' {
            line += 1
            continue
          }
          value.write_char(
            match escape {
              't' => '\t'
              'n' => '\n'
              'b' => '\u0008'
              '\\' | '"' => escape
              _ => raise InvalidConfig(line~, reason="Invalid value escape")
            },
          )
        }
      '\u0000' => raise InvalidConfig(line~, reason="NUL in value")
      _ => value.write_char(c)
    }
  }
  guard !quoted else {
    raise InvalidConfig(line~, reason="Unclosed quoted value")
  }
  (value.to_string(), rest, line)
}
