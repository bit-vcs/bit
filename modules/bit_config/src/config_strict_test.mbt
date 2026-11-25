///|
test "parse_config handles comments and both line endings" {
  for newline in ["\n", "\r\n"] {
    let content = [
      "\uFEFF[Init] # comment", "  defaultBranch = tr\\", "unk", "  templateDir = \"~/template #; \\\"quoted\\\"\" ; comment",
      "",
    ].join(newline)
    @test.assert_eq(@bit_config.parse_config(content), [
      { key: "init.defaultbranch", value: Some("trunk"), },
      { key: "init.templatedir", value: Some("~/template #; \"quoted\""), },
    ])
  }
}

///|
test "parse_config preserves ordered entries and literal single quotes" {
  let content =
    #|[remote "With]Case"] url = 'one'
    #|  url = two
    #|[remote.UPPER]
    #|  flag
    #|  empty =
  @test.assert_eq(@bit_config.parse_config(content), [
    { key: "remote.With]Case.url", value: Some("'one'"), },
    { key: "remote.With]Case.url", value: Some("two"), },
    { key: "remote.upper.flag", value: None, },
    { key: "remote.upper.empty", value: Some(""), },
  ])
}

///|
test "parse_config reports malformed syntax with a physical line number" {
  for
    (content, expected_line) in [
      ("# comment\n[broken\n", 2),
      ("[core]\nvalue = \"open\n", 2),
      ("[core]\r\nvalue = line\\\r\n\\q\r\n", 3),
      ("[core]\nkey extra\n", 2),
    ] {
    try @bit_config.parse_config(content) catch {
      InvalidConfig(line~, ..) => @test.assert_eq(line, expected_line)
    } noraise {
      _ => fail("Expected malformed config to fail")
    }
  }
}
