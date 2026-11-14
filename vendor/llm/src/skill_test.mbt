///|
test "SkillEntry::new builds raw skill definition" {
  let entry = SkillEntry::new(
    "shell", "skills/shell/SKILL.md", "workspace", "# shell skill",
  )
  assert_eq(entry.name, "shell")
  assert_eq(entry.path, "skills/shell/SKILL.md")
  assert_eq(entry.source, "workspace")
  assert_eq(entry.content, "# shell skill")
}

///|
test "SkillInfo::new builds listing metadata" {
  let info = SkillInfo::new(
    "git", "builtin/skills/git/SKILL.md", "builtin", true,
  )
  assert_eq(info.name, "git")
  assert_eq(info.path, "builtin/skills/git/SKILL.md")
  assert_eq(info.source, "builtin")
  assert_true(info.available)
}
