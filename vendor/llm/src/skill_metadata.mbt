///|
/// Parse a markdown skill file frontmatter and return `(metadata, body)`.
pub fn parse_skill_frontmatter(
  content : String,
) -> (Map[String, String]?, String) {
  if !content.has_prefix("---\n") {
    return (None, content)
  }
  match content.find("\n---\n") {
    Some(end_idx) => {
      let header = content.unsafe_substring(start=4, end=end_idx)
      let body_start = end_idx + 5
      let body = if body_start <= content.length() {
        content.unsafe_substring(start=body_start, end=content.length())
      } else {
        ""
      }
      (Some(parse_skill_frontmatter_map(header)), body)
    }
    None => (None, content)
  }
}

///|
/// Remove frontmatter and return trimmed skill markdown body.
pub fn strip_skill_frontmatter(content : String) -> String {
  parse_skill_frontmatter(content).1.trim().to_owned()
}

///|
/// Resolve human-readable skill description from metadata.
pub fn skill_metadata_description(
  metadata : Map[String, String]?,
  fallback : String,
) -> String {
  match metadata {
    Some(meta) =>
      match meta.get("description") {
        Some(desc) => desc
        None => fallback
      }
    None => fallback
  }
}

///|
/// Evaluate whether a skill is runnable in the current environment.
pub fn skill_metadata_is_available(
  metadata : Map[String, String]?,
  bins? : Map[String, Bool] = Map([]),
  env? : Map[String, String] = Map([]),
  scope_key? : String = "nanobot",
) -> Bool {
  match metadata {
    Some(meta) =>
      skill_check_requirements(
        parse_skill_namespace_metadata(meta.get("metadata"), scope_key),
        bins,
        env,
      )
    None => true
  }
}

///|
/// Collect missing requirement text (e.g. `CLI: tmux, ENV: OPENAI_API_KEY`).
pub fn skill_metadata_missing_requirements(
  metadata : Map[String, String]?,
  bins? : Map[String, Bool] = Map([]),
  env? : Map[String, String] = Map([]),
  scope_key? : String = "nanobot",
) -> String {
  match metadata {
    Some(meta) =>
      skill_collect_missing_requirements(
        parse_skill_namespace_metadata(meta.get("metadata"), scope_key),
        bins,
        env,
      )
    None => ""
  }
}

///|
/// `always` may be specified either at root frontmatter or namespaced metadata.
pub fn skill_metadata_is_always(
  metadata : Map[String, String]?,
  scope_key? : String = "nanobot",
) -> Bool {
  match metadata {
    Some(meta) => {
      let always_flag = skill_is_string_true(meta.get("always"))
      let scoped_meta = parse_skill_namespace_metadata(
        meta.get("metadata"),
        scope_key,
      )
      let always_scoped = match
        skill_json_get_bool_field(scoped_meta, "always") {
        Some(v) => v
        None => false
      }
      always_flag || always_scoped
    }
    None => false
  }
}

///|
fn parse_skill_frontmatter_map(header : String) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for line_view in header.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if line.is_empty() {
      continue
    }
    match line.find(":") {
      Some(idx) => {
        let key = line.unsafe_substring(start=0, end=idx).trim().to_owned()
        let value = line
          .unsafe_substring(start=idx + 1, end=line.length())
          .trim()
          .to_owned()
        out[key] = skill_unquote(value)
      }
      None => ()
    }
  }
  out
}

///|
fn parse_skill_namespace_metadata(raw : String?, scope_key : String) -> Json {
  let source = match raw {
    Some(s) => if s.is_empty() { return Json::object({}) } else { s }
    None => return Json::object({})
  }
  let parsed = @json.parse(source) catch { _ => Json::null() }
  match parsed {
    Object(map) =>
      match map.get(scope_key) {
        Some(Object(scoped)) => Json::object(scoped)
        _ => parsed
      }
    _ => Json::object({})
  }
}

///|
fn skill_check_requirements(
  scoped_meta : Json,
  bins : Map[String, Bool],
  env : Map[String, String],
) -> Bool {
  let requires = skill_json_get_object_field(scoped_meta, "requires")
  match requires {
    Some(requires_obj) => {
      for bin in skill_json_get_string_array(requires_obj, "bins") {
        if !bins.contains(bin) {
          return false
        }
      }
      for env_key in skill_json_get_string_array(requires_obj, "env") {
        match env.get(env_key) {
          Some(v) => if v.is_empty() { return false }
          None => return false
        }
      }
      true
    }
    None => true
  }
}

///|
fn skill_collect_missing_requirements(
  scoped_meta : Json,
  bins : Map[String, Bool],
  env : Map[String, String],
) -> String {
  let missing : Array[String] = []
  match skill_json_get_object_field(scoped_meta, "requires") {
    Some(requires_obj) => {
      for bin in skill_json_get_string_array(requires_obj, "bins") {
        if !bins.contains(bin) {
          missing.push("CLI: " + bin)
        }
      }
      for env_key in skill_json_get_string_array(requires_obj, "env") {
        match env.get(env_key) {
          Some(v) => if v.is_empty() { missing.push("ENV: " + env_key) }
          None => missing.push("ENV: " + env_key)
        }
      }
    }
    None => ()
  }
  missing.join(", ")
}

///|
fn skill_json_get_object_field(obj : Json, key : String) -> Map[String, Json]? {
  match obj {
    Object(map) =>
      match map.get(key) {
        Some(Object(sub)) => Some(sub)
        _ => None
      }
    _ => None
  }
}

///|
fn skill_json_get_string_array(
  obj : Map[String, Json],
  key : String,
) -> Array[String] {
  match obj.get(key) {
    Some(Array(items)) => {
      let out : Array[String] = []
      for item in items {
        match item {
          String(s) => out.push(s)
          _ => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
fn skill_json_get_bool_field(obj : Json, key : String) -> Bool? {
  match obj {
    Object(map) =>
      match map.get(key) {
        Some(True) => Some(true)
        Some(False) => Some(false)
        Some(String(s)) => Some(skill_is_string_true(Some(s)))
        _ => None
      }
    _ => None
  }
}

///|
fn skill_is_string_true(v : String?) -> Bool {
  match v {
    Some(raw) => {
      let s = raw.trim().to_owned().to_lower()
      s == "true" || s == "1" || s == "yes"
    }
    None => false
  }
}

///|
fn skill_unquote(s : String) -> String {
  if s.length() >= 2 {
    if (s.has_prefix("\"") && s.has_suffix("\"")) ||
      (s.has_prefix("'") && s.has_suffix("'")) {
      return s.unsafe_substring(start=1, end=s.length() - 1)
    }
  }
  s
}
