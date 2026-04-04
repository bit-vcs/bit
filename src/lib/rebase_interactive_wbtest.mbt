///|
test "parse_interactive_todo: basic pick entries" {
  let text = "pick abc123def456abc123def456abc123def456abcd first commit\npick 1234567890abcdef1234567890abcdef12345678 second commit\n"
  let entries = parse_interactive_todo(text)
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].command, TodoCommand::Pick)
  assert_eq(entries[0].commit_hex, "abc123def456abc123def456abc123def456abcd")
  assert_eq(entries[0].subject, "first commit")
  assert_eq(entries[1].command, TodoCommand::Pick)
}

///|
test "parse_interactive_todo: abbreviations" {
  let text = "p aaa first\nr bbb second\ne ccc third\ns ddd fourth\nf eee fifth\nd fff sixth\n"
  let entries = parse_interactive_todo(text)
  assert_eq(entries.length(), 6)
  assert_eq(entries[0].command, TodoCommand::Pick)
  assert_eq(entries[1].command, TodoCommand::Reword)
  assert_eq(entries[2].command, TodoCommand::Edit)
  assert_eq(entries[3].command, TodoCommand::Squash)
  assert_eq(entries[4].command, TodoCommand::Fixup)
  assert_eq(entries[5].command, TodoCommand::Drop)
}

///|
test "parse_interactive_todo: comments and blank lines ignored" {
  let text = "# This is a comment\n\npick abc commit\n# Another comment\n"
  let entries = parse_interactive_todo(text)
  assert_eq(entries.length(), 1)
}

///|
test "parse_interactive_todo: empty input" {
  let entries = parse_interactive_todo("")
  assert_eq(entries.length(), 0)
}

///|
test "serialize_interactive_todo: roundtrip" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "abc123", subject: "first" },
    { command: TodoCommand::Squash, commit_hex: "def456", subject: "second" },
  ]
  let text = serialize_interactive_todo(entries)
  let parsed = parse_interactive_todo(text)
  assert_eq(parsed.length(), 2)
  assert_eq(parsed[0].command, TodoCommand::Pick)
  assert_eq(parsed[0].commit_hex, "abc123")
  assert_eq(parsed[1].command, TodoCommand::Squash)
}

///|
test "autosquash_interactive_todo: fixup! moves after target" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "aaa", subject: "base feature" },
    { command: TodoCommand::Pick, commit_hex: "bbb", subject: "other work" },
    { command: TodoCommand::Pick, commit_hex: "ccc", subject: "fixup! base feature" },
  ]
  let result = autosquash_interactive_todo(entries)
  assert_eq(result.length(), 3)
  assert_eq(result[0].commit_hex, "aaa")
  assert_eq(result[1].commit_hex, "ccc")
  assert_eq(result[1].command, TodoCommand::Fixup)
  assert_eq(result[2].commit_hex, "bbb")
}

///|
test "autosquash_interactive_todo: squash! moves after target" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "aaa", subject: "implement X" },
    { command: TodoCommand::Pick, commit_hex: "bbb", subject: "squash! implement X" },
  ]
  let result = autosquash_interactive_todo(entries)
  assert_eq(result.length(), 2)
  assert_eq(result[0].commit_hex, "aaa")
  assert_eq(result[1].commit_hex, "bbb")
  assert_eq(result[1].command, TodoCommand::Squash)
}

///|
test "autosquash_interactive_todo: no match leaves in place" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "aaa", subject: "first" },
    { command: TodoCommand::Pick, commit_hex: "bbb", subject: "fixup! nonexistent" },
  ]
  let result = autosquash_interactive_todo(entries)
  assert_eq(result.length(), 2)
  assert_eq(result[0].commit_hex, "aaa")
  assert_eq(result[1].commit_hex, "bbb")
  assert_eq(result[1].command, TodoCommand::Pick)
}

///|
test "autosquash_interactive_todo: multiple fixups for same target" {
  let entries : Array[InteractiveTodoEntry] = [
    { command: TodoCommand::Pick, commit_hex: "aaa", subject: "feature" },
    { command: TodoCommand::Pick, commit_hex: "bbb", subject: "unrelated" },
    { command: TodoCommand::Pick, commit_hex: "ccc", subject: "fixup! feature" },
    { command: TodoCommand::Pick, commit_hex: "ddd", subject: "fixup! feature" },
  ]
  let result = autosquash_interactive_todo(entries)
  assert_eq(result.length(), 4)
  assert_eq(result[0].commit_hex, "aaa")
  assert_eq(result[1].commit_hex, "ccc")
  assert_eq(result[1].command, TodoCommand::Fixup)
  assert_eq(result[2].commit_hex, "ddd")
  assert_eq(result[2].command, TodoCommand::Fixup)
  assert_eq(result[3].commit_hex, "bbb")
}
