///|
fn chat_test_get_string_field(obj : Json, key : String) -> String {
  match obj {
    Object(map) =>
      match map.get(key) {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
}

///|
test "run_json_chat_loop returns direct response without tools" {
  let calls = Ref(0)
  let result = run_json_chat_loop(
    [{ "role": ToJson::to_json("user"), "content": ToJson::to_json("hello") }],
    [],
    5,
    fn(_messages, _tools) {
      calls.val = calls.val + 1
      JsonChatResponse::new("answer", [], None)
    },
    fn(_name, _args) { "unused" },
  )
  assert_eq(result.final_content, "answer")
  assert_eq(result.iterations, 1)
  assert_eq(calls.val, 1)
}

///|
test "run_json_chat_loop executes tool call and appends tool result messages" {
  let calls = Ref(0)
  let seen_tool_result = Ref(false)
  let result = run_json_chat_loop(
    [{ "role": ToJson::to_json("user"), "content": ToJson::to_json("hi") }],
    [{ "type": ToJson::to_json("function") }],
    5,
    fn(messages, _tools) {
      if calls.val == 0 {
        calls.val = 1
        JsonChatResponse::new(
          "",
          [JsonChatToolCall::new("call_1", "echo", { "text": ToJson::to_json("x") })],
          None,
        )
      } else {
        for msg in messages {
          if chat_test_get_string_field(msg, "role") == "tool" &&
            chat_test_get_string_field(msg, "tool_call_id") == "call_1" &&
            chat_test_get_string_field(msg, "content") == "ECHO:x" {
            seen_tool_result.val = true
          }
        }
        JsonChatResponse::new("done", [], None)
      }
    },
    fn(name, args) {
      if name == "echo" {
        "ECHO:" + json_get_string(args, "text").unwrap_or("")
      } else {
        "bad"
      }
    },
  )
  assert_eq(result.final_content, "done")
  assert_eq(result.iterations, 2)
  assert_true(seen_tool_result.val)
}

///|
test "run_json_chat_loop returns fallback on max iterations" {
  let result = run_json_chat_loop(
    [{ "role": ToJson::to_json("user"), "content": ToJson::to_json("loop") }],
    [],
    1,
    fn(_messages, _tools) {
      JsonChatResponse::new(
        "",
        [JsonChatToolCall::new("call_1", "noop", Json::null())],
        None,
      )
    },
    fn(_name, _args) { "ok" },
  )
  assert_eq(
    result.final_content,
    "I've completed processing but have no response to give.",
  )
  assert_eq(result.iterations, 1)
}
