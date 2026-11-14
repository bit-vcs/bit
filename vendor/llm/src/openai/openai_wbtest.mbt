///| Whitebox tests for robust OpenAI tool-call fragment handling.

///|
fn tool_buf_text(
  active_tools : Map[String, (String, StringBuilder)],
  tool_id : String,
) -> String {
  match active_tools.get(tool_id) {
    Some((_, buf)) => buf.to_string()
    None => ""
  }
}

///|
fn tool_name_text(
  active_tools : Map[String, (String, StringBuilder)],
  tool_id : String,
) -> String {
  match active_tools.get(tool_id) {
    Some((name, _)) => name
    None => ""
  }
}

///|
test "apply_openai_tool_fragments keeps arguments from start chunk and later deltas" {
  let active_tools : Map[String, (String, StringBuilder)] = Map([])
  let start_line =
    #|{"choices":[{"index":0,"delta":{"tool_calls":[{"id":"call_abc","index":0,"function":{"name":"write_file","arguments":"{\"path\":\"a.txt\""}}]},"finish_reason":null}]}
  let events1 = apply_openai_tool_fragments(start_line, active_tools)
  assert_eq(events1.length(), 2)
  match events1[0] {
    @llm.StreamEvent::ToolCallStart(id~, name~) => {
      assert_eq(id, "0")
      assert_eq(name, "write_file")
    }
    _ => fail("expected ToolCallStart")
  }
  match events1[1] {
    @llm.StreamEvent::ToolCallDelta(id~, input_delta~) => {
      assert_eq(id, "0")
      assert_eq(input_delta, "{\"path\":\"a.txt\"")
    }
    _ => fail("expected ToolCallDelta")
  }
  assert_eq(tool_name_text(active_tools, "0"), "write_file")
  assert_eq(tool_buf_text(active_tools, "0"), "{\"path\":\"a.txt\"")
  let delta_line =
    #|{"choices":[{"index":0,"delta":{"tool_calls":[{"id":"","index":0,"function":{"name":"","arguments":",\"content\":\"A\"}"}}]},"finish_reason":null}]}
  let events2 = apply_openai_tool_fragments(delta_line, active_tools)
  assert_eq(events2.length(), 1)
  match events2[0] {
    @llm.StreamEvent::ToolCallDelta(id~, input_delta~) => {
      assert_eq(id, "0")
      assert_eq(input_delta, ",\"content\":\"A\"}")
    }
    _ => fail("expected ToolCallDelta")
  }
  let merged = tool_buf_text(active_tools, "0")
  assert_eq(merged, "{\"path\":\"a.txt\",\"content\":\"A\"}")
  let parsed = @json.parse(merged) catch { _ => Json::null() }
  assert_true(parsed != Json::null())
}

///|
test "extract_openai_tool_fragments handles multiple tool indexes in one chunk" {
  let line =
    #|{"choices":[{"index":0,"delta":{"tool_calls":[{"id":"call_1","index":0,"function":{"name":"tool_a","arguments":"{\"a\":1}"}},{"id":"call_2","index":1,"function":{"name":"tool_b","arguments":"{\"b\":2}"}}]},"finish_reason":null}]}
  let fragments = extract_openai_tool_fragments(line)
  assert_eq(fragments.length(), 2)
  let (id0, name0, args0) = fragments[0]
  assert_eq(id0, "0")
  assert_eq(name0, "tool_a")
  assert_eq(args0, "{\"a\":1}")
  let (id1, name1, args1) = fragments[1]
  assert_eq(id1, "1")
  assert_eq(name1, "tool_b")
  assert_eq(args1, "{\"b\":2}")
}

///|
test "parse_openai_collect_text_response extracts assistant content" {
  let response =
    #|{"choices":[{"message":{"role":"assistant","content":"Hello async"}}]}
  assert_eq(parse_openai_collect_text_response(response), "Hello async")
}

///|
test "parse_openai_collect_text_response rejects malformed responses" {
  let empty_choices =
    #|{"choices":[]}
  let null_content =
    #|{"choices":[{"message":{"content":null}}]}
  assert_eq(parse_openai_collect_text_response("not json"), "")
  assert_eq(parse_openai_collect_text_response(empty_choices), "")
  assert_eq(parse_openai_collect_text_response(null_content), "")
}
