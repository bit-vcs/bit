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
