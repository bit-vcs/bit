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
        match tail {
          [] | ['\n', ..] => {
            entries.push({ key, value: None, })
            continue tail, line, prefix
          }
          ['=', .. value] => {
            let (value, tail, line) = parse_config_entry_value(value, line)
            entries.push({ key, value: Some(value), })
            continue tail, line, prefix
          }
          _ => raise InvalidConfig(line~, reason="Expected '=' after key")
        }
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
  let tail = for tail = input
                 tail is [c, .. rest] &&
                (
                  c.is_ascii_alphabetic() ||
                  c.is_ascii_digit() ||
                  c == '-' ||
                  (section && c == '.')
                )
                 tail = rest {

  } nobreak {
    tail
  }
  (input[:input.length() - tail.length()], tail)
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
  for rest = input, line = line, quoted = false, spaces = 0 {
    match rest {
      [] | ['\n', ..] => {
        guard !quoted else {
          raise InvalidConfig(line~, reason="Unclosed quoted value")
        }
        break (value.to_string(), rest, line)
      }
      ['#' | ';', ..] if !quoted => break (value.to_string(), rest, line)
      [' ' | '\t' | '\r' | '\u000b' | '\u000c', .. tail] if !quoted =>
        continue tail,
          line,
          quoted,
          if value.is_empty() {
            0
          } else {
            spaces + 1
          }
      [c, .. tail] => {
        for _ in 0..<spaces {
          value.write_char(' ')
        }
        match c {
          '"' => continue tail, line, !quoted, 0
          '\\' =>
            match tail {
              ['\n', .. rest] => continue rest, line + 1, quoted, 0
              [] => continue tail, line, quoted, 0
              [escape, .. rest] => {
                value.write_char(
                  match escape {
                    't' => '\t'
                    'n' => '\n'
                    'b' => '\u0008'
                    '\\' | '"' => escape
                    _ =>
                      raise InvalidConfig(line~, reason="Invalid value escape")
                  },
                )
                continue rest, line, quoted, 0
              }
            }
          '\u0000' => raise InvalidConfig(line~, reason="NUL in value")
          _ => {
            value.write_char(c)
            continue tail, line, quoted, 0
          }
        }
      }
    }
  }
}
