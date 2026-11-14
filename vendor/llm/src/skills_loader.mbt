///|
/// Skills loader (in-memory) shared across apps.

///|
pub struct SkillsLoader {
  workspace_skills : Map[String, SkillEntry]
  builtin_skills : Map[String, SkillEntry]
}

///|
pub fn SkillsLoader::new() -> SkillsLoader {
  { workspace_skills: {}, builtin_skills: {} }
}

///|
pub fn SkillsLoader::register_workspace_skill(
  self : SkillsLoader,
  name : String,
  content : String,
  path? : String = "",
) -> Unit {
  let skill_path = if path.is_empty() {
    "skills/" + name + "/SKILL.md"
  } else {
    path
  }
  self.workspace_skills[name] = SkillEntry::new(
    name, skill_path, "workspace", content,
  )
}

///|
pub fn SkillsLoader::register_builtin_skill(
  self : SkillsLoader,
  name : String,
  content : String,
  path? : String = "",
) -> Unit {
  let skill_path = if path.is_empty() {
    "builtin/skills/" + name + "/SKILL.md"
  } else {
    path
  }
  self.builtin_skills[name] = SkillEntry::new(
    name, skill_path, "builtin", content,
  )
}

///|
pub fn SkillsLoader::list_skills(
  self : SkillsLoader,
  filter_unavailable? : Bool = true,
  bins? : Map[String, Bool] = Map([]),
  env? : Map[String, String] = Map([]),
) -> Array[SkillInfo] {
  let out : Array[SkillInfo] = []
  for entry in self.workspace_skills.to_array() {
    let skill = entry.1
    let available = self.is_skill_available(skill.name, bins, env)
    if !filter_unavailable || available {
      out.push(SkillInfo::new(skill.name, skill.path, skill.source, available))
    }
  }
  for entry in self.builtin_skills.to_array() {
    let name = entry.0
    if self.workspace_skills.contains(name) {
      continue
    }
    let skill = entry.1
    let available = self.is_skill_available(skill.name, bins, env)
    if !filter_unavailable || available {
      out.push(SkillInfo::new(skill.name, skill.path, skill.source, available))
    }
  }
  out
}

///|
pub fn SkillsLoader::load_skill(self : SkillsLoader, name : String) -> String? {
  match self.workspace_skills.get(name) {
    Some(skill) => Some(skill.content)
    None =>
      match self.builtin_skills.get(name) {
        Some(skill) => Some(skill.content)
        None => None
      }
  }
}

///|
pub fn SkillsLoader::load_skills_for_context(
  self : SkillsLoader,
  skill_names : Array[String],
) -> String {
  let parts : Array[String] = []
  for name in skill_names {
    match self.load_skill(name) {
      Some(content) => {
        let stripped = strip_skill_frontmatter(content)
        parts.push("### Skill: " + name + "\n\n" + stripped)
      }
      None => ()
    }
  }
  parts.join("\n\n---\n\n")
}

///|
pub fn SkillsLoader::build_skills_summary(
  self : SkillsLoader,
  bins? : Map[String, Bool] = Map([]),
  env? : Map[String, String] = Map([]),
) -> String {
  let all = self.list_skills(filter_unavailable=false, bins~, env~)
  if all.is_empty() {
    return ""
  }
  let lines : Array[String] = ["<skills>"]
  for skill in all {
    lines.push("  <skill available=\"" + bool_text(skill.available) + "\">")
    lines.push("    <name>" + escape_xml(skill.name) + "</name>")
    lines.push(
      "    <description>" +
      escape_xml(self.get_skill_description(skill.name)) +
      "</description>",
    )
    lines.push("    <location>" + escape_xml(skill.path) + "</location>")
    if !skill.available {
      let missing = self.get_missing_requirements(skill.name, bins, env)
      if !missing.is_empty() {
        lines.push("    <requires>" + escape_xml(missing) + "</requires>")
      }
    }
    lines.push("  </skill>")
  }
  lines.push("</skills>")
  lines.join("\n")
}

///|
pub fn SkillsLoader::get_always_skills(
  self : SkillsLoader,
  bins? : Map[String, Bool] = Map([]),
  env? : Map[String, String] = Map([]),
) -> Array[String] {
  let out : Array[String] = []
  for skill in self.list_skills(filter_unavailable=true, bins~, env~) {
    let metadata = self.get_skill_metadata(skill.name)
    match metadata {
      Some(meta) =>
        if skill_metadata_is_always(Some(meta)) {
          out.push(skill.name)
        }
      None => ()
    }
  }
  out
}

///|
pub fn SkillsLoader::get_skill_metadata(
  self : SkillsLoader,
  name : String,
) -> Map[String, String]? {
  match self.load_skill(name) {
    Some(content) => parse_skill_frontmatter(content).0
    None => None
  }
}

///|
pub fn SkillsLoader::get_skill_description(
  self : SkillsLoader,
  name : String,
) -> String {
  skill_metadata_description(self.get_skill_metadata(name), name)
}

///|
fn SkillsLoader::is_skill_available(
  self : SkillsLoader,
  name : String,
  bins : Map[String, Bool],
  env : Map[String, String],
) -> Bool {
  match self.get_skill_metadata(name) {
    Some(meta) => skill_metadata_is_available(Some(meta), bins~, env~)
    None => true
  }
}

///|
fn SkillsLoader::get_missing_requirements(
  self : SkillsLoader,
  name : String,
  bins : Map[String, Bool],
  env : Map[String, String],
) -> String {
  match self.get_skill_metadata(name) {
    Some(meta) => skill_metadata_missing_requirements(Some(meta), bins~, env~)
    None => ""
  }
}

///|
fn escape_xml(s : String) -> String {
  s
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
}

///|
fn bool_text(v : Bool) -> String {
  if v {
    "true"
  } else {
    "false"
  }
}
