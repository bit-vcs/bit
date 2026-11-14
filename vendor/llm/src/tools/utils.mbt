///|
/// Pure utility helpers for tool handlers.

///|
pub fn required_string(obj : Json, key : String) -> String? {
  match obj {
    Object(map) =>
      match map.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
pub fn optional_string(obj : Json, key : String) -> String? {
  required_string(obj, key)
}

///|
pub fn optional_int(obj : Json, key : String) -> Int? {
  match obj {
    Object(map) =>
      match map.get(key) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

///|
pub fn count_occurrences(text : String, needle : String) -> Int {
  if needle.is_empty() {
    return 0
  }
  let mut count = 0
  let mut offset = 0
  while offset <= text.length() {
    let rest = text.unsafe_substring(start=offset, end=text.length())
    match rest.find(needle) {
      Some(idx) => {
        count = count + 1
        offset = offset + idx + needle.length()
      }
      None => break
    }
  }
  count
}

///|
pub fn clamp(v : Int, min_v : Int, max_v : Int) -> Int {
  if v < min_v {
    min_v
  } else if v > max_v {
    max_v
  } else {
    v
  }
}

///|
pub fn normalize_path(path : String) -> String {
  let mut out = path.trim().to_owned().replace_all(old="\\", new="/")
  while out.contains("//") {
    out = out.replace_all(old="//", new="/")
  }
  if out.has_suffix("/") && out.length() > 1 {
    out.unsafe_substring(start=0, end=out.length() - 1)
  } else {
    out
  }
}

///|
pub fn resolve_path(
  path : String,
  allowed_dir : String?,
) -> Result[String, String] {
  let normalized = normalize_path(path)
  if normalized.contains("../") || normalized.contains("..\\") {
    return Err("Path traversal detected")
  }
  match allowed_dir {
    Some(dir) => {
      let base = normalize_path(dir)
      if normalized == base || normalized.has_prefix(base + "/") {
        Ok(normalized)
      } else {
        Err("Path " + path + " is outside allowed directory " + dir)
      }
    }
    None => Ok(normalized)
  }
}

///|
pub fn guard_command(command : String, restrict_to_workspace : Bool) -> String? {
  let lower = command.trim().to_owned().to_lower()
  let deny_fragments = [
    "rm -rf", "rm -fr", "del /f", "del /q", "rmdir /s", "format", "mkfs", "diskpart",
    "dd if=", "> /dev/sd", "shutdown", "reboot", "poweroff", ":(){",
  ]
  for frag in deny_fragments {
    if lower.contains(frag) {
      return Some(
        "Error: Command blocked by safety guard (dangerous pattern detected)",
      )
    }
  }
  if restrict_to_workspace {
    if lower.contains("../") || lower.contains("..\\") {
      return Some(
        "Error: Command blocked by safety guard (path traversal detected)",
      )
    }
  }
  None
}

///|
pub fn validate_url(url : String) -> Result[Unit, String] {
  if !(url.has_prefix("http://") || url.has_prefix("https://")) {
    return Err("Only http/https allowed")
  }
  let rest = if url.has_prefix("https://") {
    url.unsafe_substring(start=8, end=url.length())
  } else {
    url.unsafe_substring(start=7, end=url.length())
  }
  if rest.is_empty() || rest.has_prefix("/") {
    return Err("Missing domain")
  }
  Ok(())
}

///|
pub fn web_fetch_result_json(
  url : String,
  final_url : String,
  status : Int,
  extractor : String,
  text : String,
  truncated : Bool,
) -> String {
  Json::object({
    "url": ToJson::to_json(url),
    "finalUrl": ToJson::to_json(final_url),
    "status": ToJson::to_json(status),
    "extractor": ToJson::to_json(extractor),
    "truncated": ToJson::to_json(truncated),
    "length": ToJson::to_json(text.length()),
    "text": ToJson::to_json(text),
  }).stringify()
}
