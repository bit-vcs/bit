///|
fn loader_dummy_bins(values : Array[String]) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map([])
  for v in values {
    out[v] = true
  }
  out
}

///|
fn loader_dummy_env(values : Array[(String, String)]) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for entry in values {
    out[entry.0] = entry.1
  }
  out
}

///|
fn loader_skill_with_meta(meta_lines : String, body : String) -> String {
  "---\n" + meta_lines + "\n---\n\n" + body
}

///|
test "skills loader prefers workspace skill over builtin" {
  let loader = SkillsLoader::new()
  loader.register_builtin_skill(
    "weather",
    loader_skill_with_meta("description: weather", "builtin"),
  )
  loader.register_workspace_skill(
    "weather",
    loader_skill_with_meta("description: weather", "workspace"),
  )
  let loaded = loader.load_skill("weather")
  @debug.debug_inspect(
    loaded,
    content="Some(\"---\\ndescription: weather\\n---\\n\\nworkspace\")",
  )
}

///|
test "skills loader filters unavailable skills by requirements" {
  let loader = SkillsLoader::new()
  loader.register_workspace_skill(
    "tmux",
    loader_skill_with_meta(
      "description: tmux\nmetadata: {\"nanobot\":{\"requires\":{\"bins\":[\"tmux\"],\"env\":[\"OPENAI_API_KEY\"]}}}",
      "body",
    ),
  )
  let none = loader.list_skills(
    bins=loader_dummy_bins([]),
    env=loader_dummy_env([]),
  )
  assert_eq(none.length(), 0)
  let available = loader.list_skills(
    bins=loader_dummy_bins(["tmux"]),
    env=loader_dummy_env([("OPENAI_API_KEY", "x")]),
  )
  assert_eq(available.length(), 1)
}

///|
test "skills loader builds summary and always skills" {
  let loader = SkillsLoader::new()
  loader.register_workspace_skill(
    "cron",
    loader_skill_with_meta(
      "description: cron helper\nmetadata: {\"nanobot\":{\"always\":true}}", "cron body",
    ),
  )
  let summary = loader.build_skills_summary()
  assert_true(summary.contains("<skills>"))
  assert_true(summary.contains("<name>cron</name>"))
  let always = loader.get_always_skills()
  @debug.debug_inspect(always, content="[\"cron\"]")
}
