///|
/// Pure config parsing functions extracted from cmd/bit/config.mbt.
/// No IO, no eprint_line, no @sys.exit, no OsFs, no @stdio.

///|
/// Sentinel value for config keys with no value (bare keys without =).
pub fn config_novalue() -> String {
  "\u0001"
}

///|
pub fn is_config_novalue(s : String) -> Bool {
  s == config_novalue()
}

///|
/// Split config content into logical lines (handling continuation lines).
pub fn config_lines_from_content(content : String) -> Array[String] {
  config_preprocess_lines(config_split_lines_preserve_cr(content))
}

///|
/// Split content by newline, preserving \r if present.
fn config_split_lines_preserve_cr(content : String) -> Array[String] {
  let lines : Array[String] = []
  let mut start = 0
  for i, c in content {
    if c == '\n' {
      lines.push(String::unsafe_substring(content, start~, end=i))
      start = i + 1
    }
  }
  if start <= content.length() {
    lines.push(String::unsafe_substring(content, start~, end=content.length()))
  }
  lines
}

///|
/// Join continuation lines (lines ending with unescaped backslash).
fn config_preprocess_lines(raw_lines : Array[String]) -> Array[String] {
  let line_info = config_preprocess_lines_with_line_numbers(raw_lines)
  let result : Array[String] = []
  for info in line_info {
    let (line, _line_num) = info
    result.push(line)
  }
  result
}

///|
/// Join continuation lines while keeping their original starting line number.
pub fn config_preprocess_lines_with_line_numbers(
  raw_lines : Array[String],
) -> Array[(String, Int)] {
  let result : Array[(String, Int)] = []
  let mut i = 0
  while i < raw_lines.length() {
    let mut line = raw_lines[i]
    let start_line = i + 1
    while config_ends_with_unescaped_backslash(line) &&
          config_is_continuation_context(line) &&
          i + 1 < raw_lines.length() {
      line = String::unsafe_substring(line, start=0, end=line.length() - 1)
      i += 1
      line = line + raw_lines[i]
    }
    result.push((line, start_line))
    i += 1
  }
  result
}

///|
fn config_ends_with_unescaped_backslash(s : String) -> Bool {
  let len = s.length()
  if len == 0 {
    return false
  }
  if s[len - 1] != '\\' {
    return false
  }
  let mut count = 0
  let mut idx = len - 1
  while idx >= 0 && s[idx] == '\\' {
    count += 1
    if idx == 0 {
      break
    }
    idx -= 1
  }
  count % 2 == 1
}

///|
fn config_is_continuation_context(line : String) -> Bool {
  let trimmed = config_trim(line)
  if trimmed.length() > 0 && (trimmed[0] == '#' || trimmed[0] == ';') {
    return false
  }
  let eq_idx = line.find("=")
  match eq_idx {
    None => true
    Some(ei) => {
      let after_eq = String::unsafe_substring(
        line,
        start=ei + 1,
        end=line.length(),
      )
      !(config_has_unquoted_comment_before_backslash(after_eq))
    }
  }
}

///|
fn config_has_unquoted_comment_before_backslash(value : String) -> Bool {
  let mut in_quote = false
  let mut last_comment_pos = -1
  for i, c in value {
    if c == '"' {
      let escaped = if i > 0 { value[i - 1] == '\\' } else { false }
      if !(escaped) {
        in_quote = !(in_quote)
      }
    } else if !(in_quote) && (c == '#' || c == ';') {
      last_comment_pos = i
      break
    }
  }
  last_comment_pos >= 0
}

///|
/// Trim whitespace (space, tab, newline, carriage return) from both ends.
fn config_trim(s : String) -> String {
  @string_utils.trim_string(s)
}

///|
fn config_trim_chars(s : String, chars : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = s.unsafe_get(start)
    if config_code_in_string(c, chars) {
      start += 1
    } else {
      break
    }
  }
  while end > start {
    let c = s.unsafe_get(end - 1)
    if config_code_in_string(c, chars) {
      end -= 1
    } else {
      break
    }
  }
  String::unsafe_substring(s, start~, end~)
}

///|
fn config_code_in_string(c : UInt16, s : String) -> Bool {
  for i in 0..<s.length() {
    if s.unsafe_get(i) == c {
      return true
    }
  }
  false
}

///|
/// Parse a section header line like `[section]`, `[section "sub"]`,
/// `[section.sub]` (dot notation), or `[section] rest`.
/// Returns (section_name, subsection?, rest_after_bracket, is_dot_form) or None.
/// For dot notation `[section.Sub]`, the subsection is LOWERCASED (git compat).
/// For quoted `[section "Sub"]`, the subsection is preserved as-is.
pub fn parse_section_header_line(
  line : String,
) -> (String, String?, String, Bool)? {
  if !(line.has_prefix("[")) {
    return None
  }
  match line.find("]") {
    None => None
    Some(close_i) => {
      let header = String::unsafe_substring(line, start=1, end=close_i)
      let rest = config_trim_chars(
        String::unsafe_substring(line, start=close_i + 1, end=line.length()),
        " \t",
      )
      match header.find(" ") {
        None =>
          match header.find(".") {
            Some(dot_i) => {
              let sec = String::unsafe_substring(header, start=0, end=dot_i)
              let sub = String::unsafe_substring(
                header,
                start=dot_i + 1,
                end=header.length(),
              ).to_lower()
              Some((sec, Some(sub), rest, true))
            }
            None => Some((header, None, rest, false))
          }
        Some(space_i) => {
          let sec = String::unsafe_substring(header, start=0, end=space_i)
          let raw_sub = config_trim_chars(
            String::unsafe_substring(
              header,
              start=space_i + 1,
              end=header.length(),
            ),
            " \t",
          )
          let sub = if raw_sub.length() >= 2 &&
            raw_sub[0] == '"' &&
            raw_sub[raw_sub.length() - 1] == '"' {
            String::unsafe_substring(raw_sub, start=1, end=raw_sub.length() - 1)
          } else {
            raw_sub
          }
          Some((sec, Some(sub), rest, false))
        }
      }
    }
  }
}

///|
pub fn is_valid_section_name(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  for c in name {
    if !(
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '-',
      ) {
      return false
    }
  }
  true
}

///|
/// Compare section header against query for KEY matching.
fn config_section_header_matches(
  header_section : String,
  header_subsection : String?,
  query_section : String,
  query_subsection : String?,
) -> Bool {
  if header_section.to_lower() != query_section.to_lower() {
    return false
  }
  match (header_subsection, query_subsection) {
    (None, None) => true
    (Some(hs), Some(qs)) => hs == qs
    _ => false
  }
}

///|
/// Compare section header against query for SECTION matching (for insert).
/// For dot-form headers, uses case-insensitive matching for the subsection.
/// For quoted headers, uses case-sensitive subsection matching.
pub fn section_matches_for_insert(
  header_section : String,
  header_subsection : String?,
  query_section : String,
  query_subsection : String?,
  is_dot_form : Bool,
) -> Bool {
  if header_section.to_lower() != query_section.to_lower() {
    return false
  }
  match (header_subsection, query_subsection) {
    (None, None) => true
    (Some(hs), Some(qs)) =>
      if is_dot_form {
        hs.to_lower() == qs.to_lower()
      } else {
        hs == qs
      }
    _ => false
  }
}

///|
/// Parse a config key like "section.key" or "section.subsection.key".
/// Returns (section, subsection?, key_name) or None.
/// Validates that the key name starts with an alphabetic character (git compat).
pub fn parse_config_key(key : String) -> (String, String?, String)? {
  if key.contains("\n") {
    return None
  }
  let parts : Array[String] = []
  for p in key.split(".") {
    parts.push(p.to_string())
  }
  if parts.length() < 2 {
    return None
  }
  if parts[0].length() == 0 {
    return None
  }
  let key_name = parts[parts.length() - 1]
  if key_name.length() == 0 {
    return None
  }
  let first = key_name[0]
  if !((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z')) {
    return None
  }
  if parts.length() == 2 {
    Some((parts[0], None, key_name))
  } else {
    let sub : Array[String] = []
    for i in 1..<(parts.length() - 1) {
      sub.push(parts[i])
    }
    Some((parts[0], Some(sub.join(".")), key_name))
  }
}

///|
/// Find the line number (1-based) of a config key in content.
pub fn find_config_key_line_from_content(
  content : String,
  key : String,
) -> Int? {
  let target = parse_config_key(key)
  guard target is Some((sec, sub, name)) else { return None }
  let sec_l = sec.to_lower()
  let name_l = name.to_lower()
  let lines = config_split_lines_preserve_cr(content)
  let mut current_section = ""
  let mut current_subsection : String? = None
  for i, line in lines {
    let trimmed = config_trim(line)
    if trimmed.length() == 0 || trimmed[0] == '#' || trimmed[0] == ';' {
      continue
    }
    match parse_section_header_line(trimmed) {
      Some((hs, hsub, rest, _)) => {
        current_section = hs.to_lower()
        current_subsection = hsub
        if config_section_header_matches(
            current_section, current_subsection, sec_l, sub,
          ) &&
          rest.length() > 0 {
          let eq = rest.find("=")
          let key_part = match eq {
            Some(ei) =>
              config_trim_chars(
                String::unsafe_substring(rest, start=0, end=ei),
                " \t",
              )
            None => config_trim_chars(rest, " \t")
          }
          if key_part.to_lower() == name_l {
            return Some(i + 1)
          }
        }
      }
      None => {
        if !(
            config_section_header_matches(
              current_section, current_subsection, sec_l, sub,
            ),
          ) {
          continue
        }
        let eq = trimmed.find("=")
        let key_part = match eq {
          Some(ei) =>
            config_trim_chars(
              String::unsafe_substring(trimmed, start=0, end=ei),
              " \t",
            )
          None => config_trim_chars(trimmed, " \t")
        }
        if key_part.to_lower() == name_l {
          return Some(i + 1)
        }
      }
    }
  }
  None
}

///|
/// Extract a config value for a given key from content string.
/// Returns the last matching value (git semantics: last wins).
pub fn get_config_value_from_content(
  content : String,
  key : String,
  value_pattern : String?,
  fixed_value : Bool,
) -> String? {
  let lines = config_lines_from_content(content)
  guard parse_config_key(key) is Some((section, subsection, name)) else {
    return None
  }
  let name_l = name.to_lower()
  let mut in_section = false
  let mut found : String? = None
  for line in lines {
    let trimmed = config_trim(line)
    if trimmed.length() == 0 || trimmed[0] == '#' || trimmed[0] == ';' {
      continue
    }
    match parse_section_header_line(trimmed) {
      Some((hs, hsub, rest, _dot_form)) => {
        in_section = config_section_header_matches(
          hs, hsub, section, subsection,
        )
        if in_section && rest.length() > 0 {
          let eq_idx = rest.find("=")
          match eq_idx {
            Some(ei) => {
              let key_part = config_trim_chars(
                String::unsafe_substring(rest, start=0, end=ei),
                " \t",
              )
              if key_part.to_lower() == name_l {
                let val = parse_config_value(
                  String::unsafe_substring(
                    rest,
                    start=ei + 1,
                    end=rest.length(),
                  ),
                )
                if config_matches_value_filter(val, value_pattern, fixed_value) {
                  found = Some(val)
                }
              }
            }
            None => {
              let key_part = config_trim_chars(rest, " \t")
              if key_part.to_lower() == name_l {
                let val = config_novalue()
                if config_matches_value_filter("", value_pattern, fixed_value) {
                  found = Some(val)
                }
              }
            }
          }
        }
      }
      None =>
        if in_section {
          let eq_idx = trimmed.find("=")
          match eq_idx {
            Some(i) => {
              let key_part = config_trim_chars(
                String::unsafe_substring(trimmed, start=0, end=i),
                " \t",
              )
              if key_part.to_lower() == name_l {
                let raw_val = match line.find("=") {
                  Some(raw_i) =>
                    String::unsafe_substring(
                      line,
                      start=raw_i + 1,
                      end=line.length(),
                    )
                  None =>
                    String::unsafe_substring(
                      trimmed,
                      start=i + 1,
                      end=trimmed.length(),
                    )
                }
                let val = parse_config_value(raw_val)
                if config_matches_value_filter(val, value_pattern, fixed_value) {
                  found = Some(val)
                }
              }
            }
            None => {
              let key_part = config_trim_chars(trimmed, " \t")
              if key_part.to_lower() == name_l {
                let val = config_novalue()
                if config_matches_value_filter("", value_pattern, fixed_value) {
                  found = Some(val)
                }
              }
            }
          }
        }
    }
  }
  found
}

///|
/// Extract all values for a given key from content string.
pub fn get_all_config_values_from_content(
  content : String,
  key : String,
  value_pattern : String?,
  fixed_value : Bool,
) -> Array[String] {
  let lines = config_lines_from_content(content)
  guard parse_config_key(key) is Some((section, subsection, name)) else {
    return []
  }
  let name_l = name.to_lower()
  let mut in_section = false
  let result : Array[String] = []
  for line in lines {
    let trimmed = config_trim(line)
    if trimmed.length() == 0 || trimmed[0] == '#' || trimmed[0] == ';' {
      continue
    }
    match parse_section_header_line(trimmed) {
      Some((hs, hsub, rest, _dot_form)) => {
        in_section = config_section_header_matches(
          hs, hsub, section, subsection,
        )
        if in_section && rest.length() > 0 {
          let eq_idx = rest.find("=")
          match eq_idx {
            Some(ei) => {
              let key_part = config_trim_chars(
                String::unsafe_substring(rest, start=0, end=ei),
                " \t",
              )
              if key_part.to_lower() == name_l {
                let val = parse_config_value(
                  String::unsafe_substring(
                    rest,
                    start=ei + 1,
                    end=rest.length(),
                  ),
                )
                if config_matches_value_filter(val, value_pattern, fixed_value) {
                  result.push(val)
                }
              }
            }
            None => {
              let key_part = config_trim_chars(rest, " \t")
              if key_part.to_lower() == name_l {
                if config_matches_value_filter("", value_pattern, fixed_value) {
                  result.push(config_novalue())
                }
              }
            }
          }
        }
      }
      None =>
        if in_section {
          let eq_idx = trimmed.find("=")
          match eq_idx {
            Some(i) => {
              let key_part = config_trim_chars(
                String::unsafe_substring(trimmed, start=0, end=i),
                " \t",
              )
              if key_part.to_lower() == name_l {
                let raw_val = match line.find("=") {
                  Some(raw_i) =>
                    String::unsafe_substring(
                      line,
                      start=raw_i + 1,
                      end=line.length(),
                    )
                  None =>
                    String::unsafe_substring(
                      trimmed,
                      start=i + 1,
                      end=trimmed.length(),
                    )
                }
                let val = parse_config_value(raw_val)
                if config_matches_value_filter(val, value_pattern, fixed_value) {
                  result.push(val)
                }
              }
            }
            None => {
              let key_part = config_trim_chars(trimmed, " \t")
              if key_part.to_lower() == name_l {
                if config_matches_value_filter("", value_pattern, fixed_value) {
                  result.push(config_novalue())
                }
              }
            }
          }
        }
    }
  }
  result
}

///|
fn config_matches_value_filter(
  val : String,
  pattern : String?,
  fixed_value : Bool,
) -> Bool {
  match pattern {
    None => true
    Some(p) =>
      if fixed_value {
        val == p
      } else {
        config_value_pattern_matches(val, p)
      }
  }
}

///|
fn config_is_horizontal_space(c : Char) -> Bool {
  c == ' ' || c == '\t'
}

///|
fn config_decode_escape(c : Char) -> Char {
  match c {
    'n' => '\n'
    't' => '\t'
    'r' => '\r'
    _ => c
  }
}

///|
/// Parse a quoted/escaped config value string.
pub fn parse_config_value(raw : String) -> String {
  let sb = StringBuilder::new()
  let mut in_single = false
  let mut in_double = false
  let mut escape = false
  let mut started = false
  let mut trailing_ws = 0
  for c in raw {
    if escape {
      sb.write_char(config_decode_escape(c))
      started = true
      trailing_ws = 0
      escape = false
      continue
    }
    if in_double {
      if c == '\\' {
        escape = true
        continue
      }
      if c == '"' {
        in_double = false
        started = true
        trailing_ws = 0
        continue
      }
      sb.write_char(c)
      started = true
      trailing_ws = 0
      continue
    }
    if in_single {
      if c == '\'' {
        in_single = false
        started = true
        trailing_ws = 0
        continue
      }
      sb.write_char(c)
      started = true
      trailing_ws = 0
      continue
    }
    if !(started) && config_is_horizontal_space(c) {
      continue
    }
    if c == '"' {
      in_double = true
      started = true
      continue
    }
    if c == '\'' {
      in_single = true
      started = true
      continue
    }
    if c == '\\' {
      escape = true
      started = true
      trailing_ws = 0
      continue
    }
    if c == '#' || c == ';' {
      if !(started) || trailing_ws > 0 {
        break
      }
    }
    sb.write_char(c)
    started = true
    if config_is_horizontal_space(c) {
      trailing_ws += 1
    } else {
      trailing_ws = 0
    }
  }
  let parsed = sb.to_string()
  if trailing_ws > 0 && parsed.length() >= trailing_ws {
    String::unsafe_substring(parsed, start=0, end=parsed.length() - trailing_ws)
  } else {
    parsed
  }
}

///|
/// Encode a value for writing to a config file, adding
/// quoting when needed (leading/trailing space, #, ;).
pub fn encode_config_value(value : String) -> String {
  let len = value.length()
  let needs_quoting = len > 0 &&
    (
      value[0] == ' ' ||
      value[0] == '\t' ||
      value[len - 1] == ' ' ||
      value[len - 1] == '\t' ||
      value.contains("#") ||
      value.contains(";")
    )
  let sb = StringBuilder::new()
  if needs_quoting {
    sb.write_char('"')
  }
  for c in value {
    match c {
      '\n' => sb.write_string("\\n")
      '\t' => sb.write_string("\\t")
      '\r' => sb.write_string("\\r")
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      _ => sb.write_char(c)
    }
  }
  if needs_quoting {
    sb.write_char('"')
  }
  sb.to_string()
}

///|
/// Parse boolean keyword values: true/false/yes/no/on/off.
pub fn parse_bool_keyword_value(value : String) -> Bool? {
  let trimmed = value.trim().to_string().to_lower()
  match trimmed {
    "true" | "yes" | "on" | "1" => Some(true)
    "false" | "no" | "off" | "0" | "" => Some(false)
    _ => None
  }
}

///|
/// Parse an integer config value with optional k/m/g suffix.
pub fn parse_config_int_value(val : String) -> (Int64?, String?) {
  match config_parse_size_value(val) {
    Some(n) => (Some(n), (None : String?))
    None => {
      let trimmed = val.trim().to_string().to_lower()
      if trimmed.length() == 0 {
        return ((None : Int64?), (None : String?))
      }
      let last = trimmed[trimmed.length() - 1]
      let invalid_unit = !(last >= '0' && last <= '9') &&
        last != 'k' &&
        last != 'm' &&
        last != 'g'
      if invalid_unit {
        ((None : Int64?), Some("invalid unit"))
      } else {
        ((None : Int64?), (None : String?))
      }
    }
  }
}

///|
/// Parse a size value with optional k/m/g suffix.
pub fn config_parse_size_value(value : String) -> Int64? {
  let trimmed = value.trim().to_string().to_lower()
  if trimmed.length() == 0 {
    return None
  }
  let len = trimmed.length()
  let last_char = trimmed[len - 1]
  let (num_str, multiplier) : (String, Int64) = if last_char >= '0' &&
    last_char <= '9' {
    (trimmed, 1L)
  } else {
    let num_part = String::unsafe_substring(trimmed, start=0, end=len - 1)
    let mult : Int64 = match last_char {
      'k' => 1024L
      'm' => 1024L * 1024L
      'g' => 1024L * 1024L * 1024L
      _ => return None
    }
    (num_part, mult)
  }
  let num = @string.parse_int64(num_str) catch { _ => return None }
  Some(num * multiplier)
}

// --- Regex helpers for config value pattern matching ---

///|
/// Match a value against a pattern, supporting ! prefix for negation.
fn config_value_pattern_matches(text : String, pattern : String) -> Bool {
  let negate = pattern.length() > 0 && pattern[0] == '!'
  let actual = if negate {
    String::unsafe_substring(pattern, start=1, end=pattern.length())
  } else {
    pattern
  }
  let result = config_regex_matches(text, actual)
  if negate {
    !(result)
  } else {
    result
  }
}

///|
fn config_regex_matches(text : String, pattern : String) -> Bool {
  let tc = text.to_array()
  let pc = pattern.to_array()
  if pc.length() == 0 {
    return true
  }
  let anchored_start = pc[0] == '^'
  let pi_start = if anchored_start { 1 } else { 0 }
  if anchored_start {
    return config_regex_match_here(tc, 0, pc, pi_start)
  }
  let mut i = 0
  while i <= tc.length() {
    if config_regex_match_here(tc, i, pc, pi_start) {
      return true
    }
    i += 1
  }
  false
}

///|
fn config_regex_match_here(
  tc : Array[Char],
  ti : Int,
  pc : Array[Char],
  pi : Int,
) -> Bool {
  if pi >= pc.length() {
    return true
  }
  if pc[pi] == '$' && pi + 1 >= pc.length() {
    return ti >= tc.length()
  }
  let atom_end = config_regex_atom_end(pc, pi)
  if atom_end < pc.length() {
    let q = pc[atom_end]
    if q == '*' {
      return config_regex_match_star(tc, ti, pc, pi, atom_end, atom_end + 1)
    }
    if q == '+' {
      if ti < tc.length() && config_regex_atom_matches_char(pc, pi, tc[ti]) {
        return config_regex_match_star(
          tc,
          ti + 1,
          pc,
          pi,
          atom_end,
          atom_end + 1,
        )
      }
      return false
    }
    if q == '?' {
      if ti < tc.length() && config_regex_atom_matches_char(pc, pi, tc[ti]) {
        if config_regex_match_here(tc, ti + 1, pc, atom_end + 1) {
          return true
        }
      }
      return config_regex_match_here(tc, ti, pc, atom_end + 1)
    }
  }
  if ti < tc.length() && config_regex_atom_matches_char(pc, pi, tc[ti]) {
    return config_regex_match_here(tc, ti + 1, pc, atom_end)
  }
  false
}

///|
fn config_regex_match_star(
  tc : Array[Char],
  ti : Int,
  pc : Array[Char],
  atom_pi : Int,
  _atom_end : Int,
  rest_pi : Int,
) -> Bool {
  let mut max_ti = ti
  while max_ti < tc.length() &&
        config_regex_atom_matches_char(pc, atom_pi, tc[max_ti]) {
    max_ti += 1
  }
  let mut t = max_ti
  while t >= ti {
    if config_regex_match_here(tc, t, pc, rest_pi) {
      return true
    }
    t -= 1
  }
  false
}

///|
fn config_regex_atom_end(pc : Array[Char], pi : Int) -> Int {
  if pc[pi] == '\\' && pi + 1 < pc.length() {
    pi + 2
  } else if pc[pi] == '[' {
    let mut i = pi + 1
    if i < pc.length() && pc[i] == '^' {
      i += 1
    }
    if i < pc.length() && pc[i] == ']' {
      i += 1
    }
    while i < pc.length() && pc[i] != ']' {
      i += 1
    }
    if i < pc.length() {
      i + 1
    } else {
      pc.length()
    }
  } else {
    pi + 1
  }
}

///|
fn config_regex_atom_matches_char(pc : Array[Char], pi : Int, c : Char) -> Bool {
  if pc[pi] == '.' {
    true
  } else if pc[pi] == '\\' && pi + 1 < pc.length() {
    c == pc[pi + 1]
  } else if pc[pi] == '[' {
    config_regex_char_class_matches(pc, pi, c)
  } else {
    c == pc[pi]
  }
}

///|
fn config_regex_char_class_matches(
  pc : Array[Char],
  pi : Int,
  c : Char,
) -> Bool {
  let mut i = pi + 1
  let negate = i < pc.length() && pc[i] == '^'
  if negate {
    i += 1
  }
  let class_start = i
  let mut matched = false
  while i < pc.length() {
    if pc[i] == ']' && i > class_start {
      break
    }
    if i + 2 < pc.length() && pc[i + 1] == '-' && pc[i + 2] != ']' {
      if c >= pc[i] && c <= pc[i + 2] {
        matched = true
      }
      i += 3
      continue
    }
    if c == pc[i] {
      matched = true
    }
    i += 1
  }
  if negate {
    !(matched)
  } else {
    matched
  }
}
