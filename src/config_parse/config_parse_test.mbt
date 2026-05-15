///|
test "parse_config_value simple" {
  assert_eq(@config_parse.parse_config_value(" hello "), "hello")
  assert_eq(@config_parse.parse_config_value("  world  "), "world")
}

///|
test "parse_config_value quoted" {
  assert_eq(@config_parse.parse_config_value("\"hello world\""), "hello world")
  assert_eq(
    @config_parse.parse_config_value("\"with \\n newline\""),
    "with \n newline",
  )
}

///|
test "parse_config_value comment stripping" {
  assert_eq(@config_parse.parse_config_value("value # comment"), "value")
  assert_eq(@config_parse.parse_config_value("value ; comment"), "value")
}

///|
test "parse_bool_keyword_value" {
  assert_eq(@config_parse.parse_bool_keyword_value("true"), Some(true))
  assert_eq(@config_parse.parse_bool_keyword_value("yes"), Some(true))
  assert_eq(@config_parse.parse_bool_keyword_value("on"), Some(true))
  assert_eq(@config_parse.parse_bool_keyword_value("1"), Some(true))
  assert_eq(@config_parse.parse_bool_keyword_value("false"), Some(false))
  assert_eq(@config_parse.parse_bool_keyword_value("no"), Some(false))
  assert_eq(@config_parse.parse_bool_keyword_value("off"), Some(false))
  assert_eq(@config_parse.parse_bool_keyword_value("0"), Some(false))
  assert_eq(@config_parse.parse_bool_keyword_value(""), Some(false))
  assert_eq(@config_parse.parse_bool_keyword_value("maybe"), None)
}

///|
test "config_parse_size_value" {
  assert_eq(@config_parse.config_parse_size_value("1024"), Some(1024L))
  assert_eq(@config_parse.config_parse_size_value("1k"), Some(1024L))
  assert_eq(@config_parse.config_parse_size_value("1m"), Some(1048576L))
  assert_eq(@config_parse.config_parse_size_value("1g"), Some(1073741824L))
  assert_eq(@config_parse.config_parse_size_value(""), None)
  assert_eq(@config_parse.config_parse_size_value("abc"), None)
}

///|
test "parse_config_key" {
  assert_eq(
    @config_parse.parse_config_key("core.bare"),
    Some(("core", None, "bare")),
  )
  assert_eq(
    @config_parse.parse_config_key("remote.origin.url"),
    Some(("remote", Some("origin"), "url")),
  )
  assert_eq(@config_parse.parse_config_key("nokey"), None)
  assert_eq(@config_parse.parse_config_key(""), None)
  assert_eq(@config_parse.parse_config_key("section."), None)
}

///|
test "get_config_value_from_content" {
  let content =
    #|[core]
    #|	bare = false
    #|	autocrlf = true
    #|[user]
    #|	name = Test User
  let bare = @config_parse.get_config_value_from_content(
    content,
    "core.bare",
    None,
    false,
  )
  assert_eq(bare, Some("false"))
  let name = @config_parse.get_config_value_from_content(
    content,
    "user.name",
    None,
    false,
  )
  assert_eq(name, Some("Test User"))
  let missing = @config_parse.get_config_value_from_content(
    content,
    "core.missing",
    None,
    false,
  )
  assert_eq(missing, None)
}

///|
test "parse_config_int_value" {
  let (val, err) = @config_parse.parse_config_int_value("42")
  assert_eq(val, Some(42L))
  assert_eq(err, None)
  let (val2, err2) = @config_parse.parse_config_int_value("2k")
  assert_eq(val2, Some(2048L))
  assert_eq(err2, None)
  let (val3, err3) = @config_parse.parse_config_int_value("abc")
  assert_eq(val3, None)
  assert_eq(err3, Some("invalid unit"))
}
