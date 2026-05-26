///|
test "parse_config_value simple" {
  @test.assert_eq(@bit_config.parse_config_value(" hello "), "hello")
  @test.assert_eq(@bit_config.parse_config_value("  world  "), "world")
}

///|
test "parse_config_value quoted" {
  @test.assert_eq(@bit_config.parse_config_value("\"hello world\""), "hello world")
  @test.assert_eq(
    @bit_config.parse_config_value("\"with \\n newline\""),
    "with \n newline",
  )
}

///|
test "parse_config_value comment stripping" {
  @test.assert_eq(@bit_config.parse_config_value("value # comment"), "value")
  @test.assert_eq(@bit_config.parse_config_value("value ; comment"), "value")
}

///|
test "parse_bool_keyword_value" {
  @test.assert_eq(@bit_config.parse_bool_keyword_value("true"), Some(true))
  @test.assert_eq(@bit_config.parse_bool_keyword_value("yes"), Some(true))
  @test.assert_eq(@bit_config.parse_bool_keyword_value("on"), Some(true))
  @test.assert_eq(@bit_config.parse_bool_keyword_value("1"), Some(true))
  @test.assert_eq(@bit_config.parse_bool_keyword_value("false"), Some(false))
  @test.assert_eq(@bit_config.parse_bool_keyword_value("no"), Some(false))
  @test.assert_eq(@bit_config.parse_bool_keyword_value("off"), Some(false))
  @test.assert_eq(@bit_config.parse_bool_keyword_value("0"), Some(false))
  @test.assert_eq(@bit_config.parse_bool_keyword_value(""), Some(false))
  @test.assert_eq(@bit_config.parse_bool_keyword_value("maybe"), None)
}

///|
test "config_parse_size_value" {
  @test.assert_eq(@bit_config.config_parse_size_value("1024"), Some(1024L))
  @test.assert_eq(@bit_config.config_parse_size_value("1k"), Some(1024L))
  @test.assert_eq(@bit_config.config_parse_size_value("1m"), Some(1048576L))
  @test.assert_eq(@bit_config.config_parse_size_value("1g"), Some(1073741824L))
  @test.assert_eq(@bit_config.config_parse_size_value(""), None)
  @test.assert_eq(@bit_config.config_parse_size_value("abc"), None)
}

///|
test "parse_config_key" {
  @test.assert_eq(
    @bit_config.parse_config_key("core.bare"),
    Some(("core", None, "bare")),
  )
  @test.assert_eq(
    @bit_config.parse_config_key("remote.origin.url"),
    Some(("remote", Some("origin"), "url")),
  )
  @test.assert_eq(@bit_config.parse_config_key("nokey"), None)
  @test.assert_eq(@bit_config.parse_config_key(""), None)
  @test.assert_eq(@bit_config.parse_config_key("section."), None)
}

///|
test "get_config_value_from_content" {
  let content =
    #|[core]
    #|	bare = false
    #|	autocrlf = true
    #|[user]
    #|	name = Test User
  let bare = @bit_config.get_config_value_from_content(
    content,
    "core.bare",
    None,
    false,
  )
  @test.assert_eq(bare, Some("false"))
  let name = @bit_config.get_config_value_from_content(
    content,
    "user.name",
    None,
    false,
  )
  @test.assert_eq(name, Some("Test User"))
  let missing = @bit_config.get_config_value_from_content(
    content,
    "core.missing",
    None,
    false,
  )
  @test.assert_eq(missing, None)
}

///|
test "parse_config_int_value" {
  let (val, err) = @bit_config.parse_config_int_value("42")
  @test.assert_eq(val, Some(42L))
  @test.assert_eq(err, None)
  let (val2, err2) = @bit_config.parse_config_int_value("2k")
  @test.assert_eq(val2, Some(2048L))
  @test.assert_eq(err2, None)
  let (val3, err3) = @bit_config.parse_config_int_value("abc")
  @test.assert_eq(val3, None)
  @test.assert_eq(err3, Some("invalid unit"))
}
