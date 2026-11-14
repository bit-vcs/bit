///|
fn chat_json_get_field(obj : Json, key : String) -> Json? {
  match obj {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn chat_json_get_string_field(obj : Json, key : String) -> String? {
  match chat_json_get_field(obj, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn chat_json_has_field(obj : Json, key : String) -> Bool {
  chat_json_get_field(obj, key) is Some(_)
}

///|
test "add_tool_result appends tool role payload" {
  let out = add_tool_result([], "id1", "read_file", "ok")
  assert_eq(out.length(), 1)
  @debug.debug_inspect(
    chat_json_get_string_field(out[0], "role"),
    content="Some(\"tool\")",
  )
  @debug.debug_inspect(
    chat_json_get_string_field(out[0], "tool_call_id"),
    content="Some(\"id1\")",
  )
  @debug.debug_inspect(
    chat_json_get_string_field(out[0], "name"),
    content="Some(\"read_file\")",
  )
  @debug.debug_inspect(
    chat_json_get_string_field(out[0], "content"),
    content="Some(\"ok\")",
  )
}

///|
test "add_assistant_message supports optional tool_calls and reasoning" {
  let tool_calls : Array[Json] = [
    { "id": ToJson::to_json("call_1"), "type": ToJson::to_json("function") },
  ]
  let out = add_assistant_message(
    [],
    Some("hello"),
    Some(tool_calls),
    Some("think"),
  )
  assert_eq(out.length(), 1)
  @debug.debug_inspect(
    chat_json_get_string_field(out[0], "role"),
    content="Some(\"assistant\")",
  )
  @debug.debug_inspect(
    chat_json_get_string_field(out[0], "content"),
    content="Some(\"hello\")",
  )
  assert_true(chat_json_has_field(out[0], "tool_calls"))
  @debug.debug_inspect(
    chat_json_get_string_field(out[0], "reasoning_content"),
    content="Some(\"think\")",
  )
  let out2 = add_assistant_message([], None, None, None)
  @debug.debug_inspect(
    chat_json_get_string_field(out2[0], "content"),
    content="Some(\"\")",
  )
  assert_true(!chat_json_has_field(out2[0], "tool_calls"))
  assert_true(!chat_json_has_field(out2[0], "reasoning_content"))
}
