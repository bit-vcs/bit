///|
test "ContentBlock::to_anthropic_json - Text" {
  let block : ContentBlock = Text("hello")
  @debug.debug_inspect(
    block.to_anthropic_json().stringify(),
    content=(
      #|"{\"type\":\"text\",\"text\":\"hello\"}"
    ),
  )
}

///|
test "ContentBlock::to_anthropic_json - ToolUse" {
  let block : ContentBlock = ToolUse(id="call_1", name="read_file", input={
    "path": ToJson::to_json("foo.txt"),
  })
  @debug.debug_inspect(
    block.to_anthropic_json().stringify(),
    content=(
      #|"{\"type\":\"tool_use\",\"id\":\"call_1\",\"name\":\"read_file\",\"input\":{\"path\":\"foo.txt\"}}"
    ),
  )
}

///|
test "ContentBlock::to_anthropic_json - ToolResult" {
  let block : ContentBlock = ToolResult(
    tool_use_id="call_1",
    content="file content",
    is_error=false,
  )
  @debug.debug_inspect(
    block.to_anthropic_json().stringify(),
    content=(
      #|"{\"type\":\"tool_result\",\"tool_use_id\":\"call_1\",\"content\":\"file content\",\"is_error\":false}"
    ),
  )
}

///|
test "Message::to_anthropic_json" {
  let msg = Message::user("hello")
  @debug.debug_inspect(
    msg.to_anthropic_json().stringify(),
    content=(
      #|"{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"hello\"}]}"
    ),
  )
}

///|
test "Message::to_openai_json - simple text" {
  let msg = Message::user("hello")
  @debug.debug_inspect(
    msg.to_openai_json().stringify(),
    content=(
      #|"{\"role\":\"user\",\"content\":\"hello\"}"
    ),
  )
}

///|
test "Message::to_openai_json - tool result" {
  let msg : Message = {
    role: Tool,
    content: [
      ToolResult(tool_use_id="call_1", content="result", is_error=false),
    ],
  }
  @debug.debug_inspect(
    msg.to_openai_json().stringify(),
    content=(
      #|"{\"role\":\"tool\",\"tool_call_id\":\"call_1\",\"content\":\"result\"}"
    ),
  )
}

///|
test "json_get_string" {
  let j : Json = { "name": ToJson::to_json("test"), "value": Json::number(42.0) }
  @debug.debug_inspect(json_get_string(j, "name"), content="Some(\"test\")")
  @debug.debug_inspect(json_get_string(j, "value"), content="None")
  @debug.debug_inspect(json_get_string(j, "missing"), content="None")
}

///|
test "json_get_int" {
  let j : Json = { "count": Json::number(42.0), "name": ToJson::to_json("test") }
  @debug.debug_inspect(json_get_int(j, "count"), content="Some(42)")
  @debug.debug_inspect(json_get_int(j, "name"), content="None")
  @debug.debug_inspect(json_get_int(j, "missing"), content="None")
}
