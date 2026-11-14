///|
test "parse_openai_event - text delta" {
  let data =
    #|{"choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}
  let event = parse_openai_event(data)
  match event {
    Some(@llm.StreamEvent::TextDelta(text)) =>
      @debug.debug_inspect(
        text,
        content=(
          #|"Hello"
        ),
      )
    _ => fail("expected TextDelta")
  }
}

///|
test "parse_openai_event - finish_reason stop" {
  let data =
    #|{"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
  let event = parse_openai_event(data)
  match event {
    Some(@llm.StreamEvent::MessageEnd(finish_reason~, ..)) =>
      @debug.debug_inspect(finish_reason, content="Stop")
    _ => fail("expected MessageEnd")
  }
}

///|
test "parse_openai_event - tool call start" {
  let data =
    #|{"choices":[{"index":0,"delta":{"tool_calls":[{"id":"call_1","index":0,"function":{"name":"read_file","arguments":""}}]},"finish_reason":null}]}
  let event = parse_openai_event(data)
  match event {
    Some(@llm.StreamEvent::ToolCallStart(id~, name~)) => {
      @debug.debug_inspect(
        id,
        content=(
          #|"call_1"
        ),
      )
      @debug.debug_inspect(
        name,
        content=(
          #|"read_file"
        ),
      )
    }
    _ => fail("expected ToolCallStart")
  }
}

///|
test "parse_openai_event - tool call delta" {
  let data =
    #|{"choices":[{"index":0,"delta":{"tool_calls":[{"id":"","index":0,"function":{"name":"","arguments":"{\"path\":"}}]},"finish_reason":null}]}
  let event = parse_openai_event(data)
  match event {
    Some(@llm.StreamEvent::ToolCallDelta(input_delta~, ..)) =>
      @debug.debug_inspect(
        input_delta,
        content=(
          #|"{\"path\":"
        ),
      )
    _ => fail("expected ToolCallDelta")
  }
}

///|
test "parse_openai_event - finish_reason tool_calls" {
  let data =
    #|{"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
  let event = parse_openai_event(data)
  match event {
    Some(@llm.StreamEvent::MessageEnd(finish_reason~, ..)) =>
      @debug.debug_inspect(finish_reason, content="ToolUse")
    _ => fail("expected MessageEnd with ToolUse")
  }
}

///|
test "parse_openai_event - error" {
  let data =
    #|{"error":{"message":"rate limited","type":"rate_limit"}}
  let event = parse_openai_event(data)
  match event {
    Some(@llm.StreamEvent::Error(msg)) =>
      @debug.debug_inspect(
        msg,
        content=(
          #|"rate limited"
        ),
      )
    _ => fail("expected Error")
  }
}

///|
test "parse_openai_event - invalid json" {
  let event = parse_openai_event("not json")
  @debug.debug_inspect(event is None, content="true")
}

///|
test "parse_openai_event - empty choices" {
  let data =
    #|{"choices":[]}
  let event = parse_openai_event(data)
  @debug.debug_inspect(event is None, content="true")
}
