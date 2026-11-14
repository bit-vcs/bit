///|
fn parse_json_schema(s : String) -> Json {
  @json.parse(s) catch {
    _ => panic()
  }
}

///|
fn has_error(errors : Array[String], needle : String) -> Bool {
  for err in errors {
    if err.contains(needle) {
      return true
    }
  }
  false
}

///|
fn sample_schema() -> Json {
  parse_json_schema(
    (
      #| {
      #|   "type": "object",
      #|   "properties": {
      #|     "query": { "type": "string", "minLength": 2 },
      #|     "count": { "type": "integer", "minimum": 1, "maximum": 10 },
      #|     "meta": {
      #|       "type": "object",
      #|       "properties": {
      #|         "tag": { "type": "string" },
      #|         "flags": { "type": "array", "items": { "type": "string" } }
      #|       },
      #|       "required": ["tag"]
      #|     }
      #|   },
      #|   "required": ["query", "count"]
      #| }
    ),
  )
}

///|
test "validate_tool_input checks required and type constraints" {
  let errors = validate_tool_input({ "query": ToJson::to_json("x") }, sample_schema())
  assert_true(has_error(errors, "missing required count"))
  assert_true(has_error(errors, "query must be at least 2 chars"))
}

///|
test "validate_tool_input checks nested array/object constraints" {
  let errors = validate_tool_input(
    {
      "query": ToJson::to_json("ok"),
      "count": ToJson::to_json((2)),
      "meta": { "flags": Json::array([ToJson::to_json((1))]) },
    },
    sample_schema(),
  )
  assert_true(has_error(errors, "missing required meta.tag"))
  assert_true(has_error(errors, "meta.flags[0] should be string"))
}

///|
test "ToolRegistry::execute_validated rejects invalid input" {
  let registry = ToolRegistry::new()
  registry.register("echo", "echo input", sample_schema(), fn(_input) { "ok" })
  let (result, is_error) = registry.execute_validated("echo", {
    "query": ToJson::to_json("x"),
  })
  assert_true(is_error)
  assert_true(result.contains("Invalid tool input"))
}

///|
test "ToolRegistry::execute_validated executes valid input" {
  let registry = ToolRegistry::new()
  registry.register("echo", "echo input", sample_schema(), fn(_input) { "ok" })
  let (result, is_error) = registry.execute_validated("echo", {
    "query": ToJson::to_json("ok"),
    "count": ToJson::to_json((2)),
  })
  assert_eq(result, "ok")
  assert_true(!is_error)
}
