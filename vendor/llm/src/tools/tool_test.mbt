///|
fn json_get_string(j : Json, field : String) -> String? {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
fn json_get_object(j : Json, field : String) -> Json? {
  match j {
    Object(m) => m.get(field)
    _ => None
  }
}

///|
test "ToolRegistry - register and execute" {
  let registry = ToolRegistry::new()
  let schema : Json = { "type": ToJson::to_json("object") }
  registry.register("greet", "Greet a person", schema, fn(input) {
    let name = match json_get_string(input, "name") {
      Some(n) => n
      None => "world"
    }
    "Hello, " + name + "!"
  })
  let defs = registry.get_defs()
  @debug.debug_inspect(defs.length(), content="1")
  @debug.debug_inspect(
    defs[0].name,
    content=(
      #|"greet"
    ),
  )
  let (result, is_error) = registry.execute("greet", {
    "name": ToJson::to_json("Alice"),
  })
  @debug.debug_inspect(
    result,
    content=(
      #|"Hello, Alice!"
    ),
  )
  @debug.debug_inspect(is_error, content="false")
}

///|
test "ToolRegistry - execute unknown tool" {
  let registry = ToolRegistry::new()
  let (result, is_error) = registry.execute("unknown", Json::null())
  @debug.debug_inspect(
    result,
    content=(
      #|"Tool not found: unknown"
    ),
  )
  @debug.debug_inspect(is_error, content="true")
}

///|
test "ToolDef::to_anthropic_json" {
  let schema : Json = {
    "type": ToJson::to_json("object"),
    "properties": { "path": { "type": ToJson::to_json("string") } },
  }
  let tool : ToolDef = {
    name: "read_file",
    description: "Read a file",
    input_schema: schema,
  }
  let j = tool.to_anthropic_json()
  @debug.debug_inspect(
    json_get_string(j, "name"),
    content=(
      #|Some("read_file")
    ),
  )
  @debug.debug_inspect(
    json_get_string(j, "description"),
    content=(
      #|Some("Read a file")
    ),
  )
}

///|
test "ToolDef::to_openai_json" {
  let schema : Json = {
    "type": ToJson::to_json("object"),
    "properties": { "path": { "type": ToJson::to_json("string") } },
  }
  let tool : ToolDef = {
    name: "read_file",
    description: "Read a file",
    input_schema: schema,
  }
  let j = tool.to_openai_json()
  @debug.debug_inspect(
    json_get_string(j, "type"),
    content=(
      #|Some("function")
    ),
  )
  let has_func = !(json_get_object(j, "function") is None)
  @debug.debug_inspect(has_func, content="true")
}

///|
test "ToolDef::new constructs definition" {
  let schema : Json = { "type": ToJson::to_json("object") }
  let tool = ToolDef::new("echo", "echo text", schema)
  @debug.debug_inspect(
    tool.name,
    content=(
      #|"echo"
    ),
  )
  @debug.debug_inspect(
    tool.description,
    content=(
      #|"echo text"
    ),
  )
}

///|
test "ToolRegistry::register_def and execute_result" {
  let registry = ToolRegistry::new()
  let tool = ToolDef::new("echo", "echo text", {
    "type": ToJson::to_json("object"),
    "properties": { "text": { "type": ToJson::to_json("string") } },
    "required": Json::array([ToJson::to_json("text")]),
  })
  registry.register_def(tool, fn(input) {
    let text = match input {
      Object(map) =>
        match map.get("text") {
          Some(String(s)) => s
          _ => ""
        }
      _ => ""
    }
    "ECHO:" + text
  })
  assert_true(registry.has("echo"))
  let ok = registry.execute_result("echo", { "text": ToJson::to_json("hi") })
  match ok {
    Ok(result) => assert_eq(result, "ECHO:hi")
    Err(_) => assert_true(false)
  }
  let invalid = registry.execute_result("echo", {})
  match invalid {
    Ok(_) => assert_true(false)
    Err(InvalidParams(tool_name~, errors~)) => {
      assert_eq(tool_name, "echo")
      assert_true(errors.length() > 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "ToolRegistry::definitions builds openai function array" {
  let registry = ToolRegistry::new()
  registry.register_def(
    ToolDef::new("sum", "sum numbers", {
      "type": ToJson::to_json("object"),
      "properties": { "a": { "type": ToJson::to_json("number") } },
    }),
    fn(_input) { "ok" },
  )
  let defs = registry.definitions()
  assert_eq(defs.length(), 1)
  @debug.debug_inspect(
    json_get_string(defs[0], "type"),
    content="Some(\"function\")",
  )
}
