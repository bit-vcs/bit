// Tests ported from `moonbitlang/core/json` (parse_test.mbt, parse_error_test.mbt
// and the parse/stringify cases of json_test.mbt), adapted to this package's
// surface (`@json.parse` / `@json.valid` / `@json.stringify`). They run on both
// native and JS. Value-context error tests that assert an exact source position
// live in `json_upstream_native_test.mbt` because the JS host `JSON.parse` does
// not expose a position for those (see that file).

///|
#callsite(autofill(loc))
fn test_parse(input : String, loc~ : SourceLoc) -> Json raise Error {
  @json.parse(input) catch {
    err => fail("Parse failed, \{loc}, \{err}")
  }
}

//region objects

///|
test "parses empty object" {
  debug_inspect(try_parse("{}"), content="Ok(Object({}))")
}

///|
test "parses object" {
  debug_inspect(
    try_parse("{\"a\":1}"),
    content=(
      #|Ok(Object({ "a": Number(1) }))
    ),
  )
  debug_inspect(
    try_parse("{\"a\":1,\"b\":2}"),
    content=(
      #|Ok(Object({ "a": Number(1), "b": Number(2) }))
    ),
  )
}

///|
test "parses multiple properties" {
  debug_inspect(
    try_parse("{\"abc\":1,\"def\":2}"),
    content=(
      #|Ok(Object({ "abc": Number(1), "def": Number(2) }))
    ),
  )
}

///|
test "parses nested objects" {
  debug_inspect(
    try_parse("{\"a\":{\"b\":2}}"),
    content=(
      #|Ok(Object({ "a": Object({ "b": Number(2) }) }))
    ),
  )
}
//endregion

//region arrays

///|
test "parses empty arrays" {
  let json = test_parse("[]")
  @debug.assert_eq(json, Json::array([]))
}

///|
test "parses array values" {
  let json = test_parse("[1]")
  @debug.assert_eq(json, Json::array([Json::number(1.0)]))
}

///|
test "parses multiple array values" {
  let json = test_parse("[1,2]")
  @debug.assert_eq(json, Json::array([Json::number(1.0), Json::number(2.0)]))
}

///|
test "parses nested arrays" {
  let json = test_parse("[1,[2,3]]")
  @debug.assert_eq(
    json,
    Json::array([
      Json::number(1.0),
      Json::array([Json::number(2.0), Json::number(3.0)]),
    ]),
  )
}
//endregion

//region nulls

///|
test "parses nulls" {
  let json = test_parse("null")
  @debug.assert_eq(json, null)
}
//endregion

//region booleans

///|
test "parses true" {
  let json = test_parse("true")
  debug_inspect(json, content="True")
}

///|
test "parses false" {
  let json = test_parse("false")
  debug_inspect(json, content="False")
}
//endregion

//region numbers

///|
test "parses leading zeroes" {
  let json = test_parse("[0,0.0,0e0]")
  @debug.assert_eq(
    json,
    Json::array([Json::number(0.0), Json::number(0.0), Json::number(0.0)]),
  )
}

///|
test "parses integers" {
  let json = test_parse("[1,23,456,7890]")
  @debug.assert_eq(
    json,
    Json::array([
      Json::number(1.0),
      Json::number(23.0),
      Json::number(456.0),
      Json::number(7890.0),
    ]),
  )
}

///|
test "parses signed numbers" {
  let json = test_parse("[-1,2,-0.1,-0]")
  @debug.assert_eq(
    json,
    Json::array([
      Json::number(-1.0),
      Json::number(2.0),
      Json::number(-0.1),
      Json::number(-0.0),
    ]),
  )
}

///|
test "parses fractional numbers" {
  let json = test_parse("[1.0,1.23]")
  @debug.assert_eq(json, Json::array([Json::number(1.0), Json::number(1.23)]))
}

///|
test "parses exponents" {
  let json = test_parse("[1e0,1e1,1e01,1.0e0,1.1e0,1e-1,1e+1]")
  @debug.assert_eq(
    json,
    Json::array([
      Json::number(1.0),
      Json::number(10.0),
      Json::number(10.0),
      Json::number(1.0),
      Json::number(1.1),
      Json::number(0.1),
      Json::number(10.0),
    ]),
  )
}

///|
test "parses 1" {
  let json = test_parse("1")
  @debug.assert_eq(json, Json::number(1.0))
}

///|
test "parses +1.23e100" {
  let json = test_parse("1.23e100")
  @debug.assert_eq(json, Json::number(1.23e100))
}

//endregion

//region strings

///|
test "parses string" {
  let json = test_parse("\"abc\"")
  @debug.assert_eq(json, Json::string("abc"))
}

///|
test "parses quotes in string" {
  let json = test_parse("[\"\\\"\",\"'\"]")
  @debug.assert_eq(json, Json::array([Json::string("\""), Json::string("'")]))
}

///|
test "parses escaped characters" {
  let json = test_parse("\"\\b\\f\\n\\r\\t\\u01fF\\\"\"")
  @debug.assert_eq(json, Json::string("\n\r\tǿ\""))
}
//endregion

//region whitespace

///|
test "parses whitespace" {
  let json = test_parse("{\t \n\r}")
  @debug.assert_eq(json, Json::object({}))
}

///|
test "parses leading and trailing whitespace" {
  let json = test_parse(" \n\t[1, 2]\r ")
  @debug.assert_eq(json, Json::array([Json::number(1.0), Json::number(2.0)]))
}

///|
test "parses whitespace around separators" {
  let json = test_parse("{\"a\" \n:\t1 ,\r\"b\" : [ true , false ] }")
  @debug.assert_eq(
    json,
    Json::object({
      "a": Json::number(1.0),
      "b": Json::array([Json::boolean(true), Json::boolean(false)]),
    }),
  )
}
//endregion

///|
test "valid" {
  debug_inspect(@json.valid("{\"a\": 1, \"b\":2}"), content="true")
  debug_inspect(@json.valid("{}"), content="true")
  debug_inspect(@json.valid("{a:1, b:2}"), content="false")
  debug_inspect(@json.valid("{"), content="false")
}

///|
test "parse unexpected token in value" {
  let result = try_parse("{a:1}")
  debug_inspect(
    result,
    content=(
      #|Err(InvalidChar({ line: 1, column: 1 }, 'a'))
    ),
  )
}

///|
test "parse unexpected token in object property name" {
  let result = try_parse("{\"a\":1, b:2}")
  debug_inspect(
    result,
    content=(
      #|Err(InvalidChar({ line: 1, column: 8 }, 'b'))
    ),
  )
}

///|
test "parse unexpected token after object property name" {
  let result = try_parse("{\"a\" b:2}")
  debug_inspect(
    result,
    content=(
      #|Err(InvalidChar({ line: 1, column: 5 }, 'b'))
    ),
  )
}

///|
test "parse unexpected token after object value" {
  let result = try_parse("{\"a\":1 b:2}")
  debug_inspect(
    result,
    content=(
      #|Err(InvalidChar({ line: 1, column: 7 }, 'b'))
    ),
  )
}

///|
test "parse unexpected token in array" {
  let result = try_parse("[1, 2 a]")
  debug_inspect(
    result,
    content=(
      #|Err(InvalidChar({ line: 1, column: 6 }, 'a'))
    ),
  )
}

///|
test "parse multi-lines json" {
  let result = try_parse(
    (
      #|{
      #|  "a":2,
      #|  "b":3
      #|}
    ),
  )
  debug_inspect(
    result,
    content=(
      #|Ok(Object({ "a": Number(2), "b": Number(3) }))
    ),
  )
}

///|
test "parser error" {
  debug_inspect(
    try_parse("]"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 0 }, ']'))
    ),
  )
  debug_inspect(
    try_parse("}"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 0 }, '}'))
    ),
  )
  debug_inspect(
    try_parse(","),
    content=(
      #|Err(InvalidChar({ line: 1, column: 0 }, ','))
    ),
  )
}

///|
test "emoji" {
  debug_inspect(
    // test first char is emoji
    try_parse("\u{1F600}"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 0 }, '😀'))
    ),
  )
  debug_inspect(
    try_parse("a😀"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 0 }, 'a'))
    ),
  )
  debug_inspect(
    try_parse("a"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 0 }, 'a'))
    ),
  )
  debug_inspect(
    // test first char is emoji (standalone emoji)
    try_parse("😀"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 0 }, '😀'))
    ),
  )
}

///|
test "parse error branches" {
  guard try_parse("") is Err(InvalidEof) else {
    fail("expected InvalidEof for empty input")
  }
  guard try_parse(" \t\r\n") is Err(InvalidEof) else {
    fail("expected InvalidEof for whitespace-only input")
  }
  guard try_parse("@") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for invalid start")
  }
  guard try_parse("nullx") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for trailing data")
  }
  guard try_parse("\u{00A0}null") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for leading non-breaking space")
  }
  guard try_parse("tx") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for invalid literal")
  }
  guard try_parse("-x") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for invalid minus")
  }
  guard try_parse("-") is Err(InvalidEof) else {
    fail("expected InvalidEof for dangling minus")
  }
  guard try_parse("1.") is Err(InvalidEof) else {
    fail("expected InvalidEof for trailing dot")
  }
  guard try_parse("1.a") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for bad fraction")
  }
  guard try_parse("1eA") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for bad exponent")
  }
  guard try_parse("1e+a") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for bad exponent sign")
  }
  guard try_parse("1e+") is Err(InvalidEof) else {
    fail("expected InvalidEof for missing exponent")
  }
  guard try_parse("\"line\nbreak\"") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for newline in string")
  }
  guard try_parse("\"\\q\"") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for invalid escape")
  }
  guard try_parse("\"a\u{1}b\"") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for control char")
  }
  guard try_parse("\"unterminated") is Err(InvalidEof) else {
    fail("expected InvalidEof for unterminated string")
  }
  guard try_parse("\"endswith\\") is Err(InvalidEof) else {
    fail("expected InvalidEof for trailing escape")
  }
  guard try_parse("\"\\u:000\"") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for invalid hex digit")
  }
  guard try_parse("\"\\u/000\"") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for invalid hex digit")
  }
  guard try_parse("\"\\uG000\"") is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for invalid hex letter")
  }
  guard try_parse("[1") is Err(InvalidEof) else {
    fail("expected InvalidEof for incomplete array")
  }
  guard try_parse("{\"a\"") is Err(InvalidEof) else {
    fail("expected InvalidEof for missing colon")
  }
  guard try_parse("{\"a\":1") is Err(InvalidEof) else {
    fail("expected InvalidEof for incomplete object")
  }
  guard try_parse("{\"a\":1,") is Err(InvalidEof) else {
    fail("expected InvalidEof after trailing comma")
  }
  let depth_result : Result[Json, _] = try_parse(
    String::make(1025, '[') + String::make(1025, ']'),
  )
  guard depth_result is Err(err) else { fail("expected DepthLimitExceeded") }
  guard err is DepthLimitExceeded else { fail("expected DepthLimitExceeded") }
  inspect(
    err.to_string(),
    content="Depth limit exceeded, please increase the max_nesting_depth parameter",
  )
  ignore(@json.parse("-999999999999999999999999999999999999"))
  ignore(@json.parse("-1e999999999999999999999999999999999999"))
}

///|
test "stringify" {
  let json : Json = {
    "key": [1.0, true, null, [], { "key": "value", "value": 100.0 }],
    "int": 12345,
    "double": 123.45,
    "null": null,
    "bool": false,
    "obj": {},
  }
  inspect(
    @json.stringify(json),
    content=(
      #|{"key":[1,true,null,[],{"key":"value","value":100}],"int":12345,"double":123.45,"null":null,"bool":false,"obj":{}}
    ),
  )
  let newjson = @json.parse(@json.stringify(json))
  @debug.assert_eq(newjson, json)
}

///|
test "stringify with custom indents" {
  let json : Json = { "a": 1 }
  inspect(@json.stringify(json, indent=5), content="{\n     \"a\": 1\n}")
  inspect(@json.stringify(json, indent=7), content="{\n       \"a\": 1\n}")
}

///|
#warnings("-result_error_return")
fn try_parse(input : String) -> Result[Json, @json.ParseError] {
  Ok(@json.parse(input)) catch {
    err => Err(err)
  }
}
