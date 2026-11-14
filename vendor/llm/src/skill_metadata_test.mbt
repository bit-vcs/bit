///|
fn skill_dummy_bins(values : Array[String]) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map([])
  for v in values {
    out[v] = true
  }
  out
}

///|
fn skill_dummy_env(values : Array[(String, String)]) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for entry in values {
    out[entry.0] = entry.1
  }
  out
}

///|
fn skill_with_frontmatter(meta_lines : String, body : String) -> String {
  "---\n" + meta_lines + "\n---\n\n" + body
}

///|
test "parse_skill_frontmatter and strip_skill_frontmatter" {
  let source = skill_with_frontmatter(
    "description: \"shell helper\"\nalways: true", "body text",
  )
  let (meta, _body) = parse_skill_frontmatter(source)
  match meta {
    Some(m) => {
      assert_eq(m["description"], "shell helper")
      assert_eq(m["always"], "true")
    }
    None => assert_true(false)
  }
  assert_eq(strip_skill_frontmatter(source), "body text")
}

///|
test "skill metadata availability and missing requirements" {
  let meta : Map[String, String] = Map([])
  meta["metadata"] = "{\"nanobot\":{\"requires\":{\"bins\":[\"tmux\"],\"env\":[\"OPENAI_API_KEY\"]}}}"
  assert_false(
    skill_metadata_is_available(
      Some(meta),
      bins=skill_dummy_bins([]),
      env=skill_dummy_env([]),
    ),
  )
  assert_eq(
    skill_metadata_missing_requirements(
      Some(meta),
      bins=skill_dummy_bins([]),
      env=skill_dummy_env([]),
    ),
    "CLI: tmux, ENV: OPENAI_API_KEY",
  )
  assert_true(
    skill_metadata_is_available(
      Some(meta),
      bins=skill_dummy_bins(["tmux"]),
      env=skill_dummy_env([("OPENAI_API_KEY", "x")]),
    ),
  )
}

///|
test "skill metadata always flag supports root and namespaced values" {
  let root_meta : Map[String, String] = Map([])
  root_meta["always"] = "yes"
  assert_true(skill_metadata_is_always(Some(root_meta)))
  let ns_meta : Map[String, String] = Map([])
  ns_meta["metadata"] = "{\"nanobot\":{\"always\":true}}"
  assert_true(skill_metadata_is_always(Some(ns_meta)))
  let none_meta : Map[String, String] = Map([])
  assert_false(skill_metadata_is_always(Some(none_meta)))
}
