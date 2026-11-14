///|
test "parse_anthropic_event - message_start" {
  let data =
    #|{"type":"message_start","message":{"id":"msg_1"}}
  let event = parse_anthropic_event(data)
  @debug.debug_inspect(!(event is None), content="true")
}

///|
test "parse_anthropic_event - text_delta" {
  let data =
    #|{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
  let event = parse_anthropic_event(data)
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
test "parse_anthropic_event - tool_use_start" {
  let data =
    #|{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"call_1","name":"read_file","input":{}}}
  let event = parse_anthropic_event(data)
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
test "parse_anthropic_event - input_json_delta" {
  let data =
    #|{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"path\":"}}
  let event = parse_anthropic_event(data)
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
test "parse_anthropic_event - message_delta stop" {
  let data =
    #|{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":42}}
  let event = parse_anthropic_event(data)
  match event {
    Some(@llm.StreamEvent::MessageEnd(finish_reason~, ..)) =>
      @debug.debug_inspect(finish_reason, content="Stop")
    _ => fail("expected MessageEnd")
  }
}

///|
test "parse_anthropic_event - message_delta tool_use" {
  let data =
    #|{"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":10}}
  let event = parse_anthropic_event(data)
  match event {
    Some(@llm.StreamEvent::MessageEnd(finish_reason~, ..)) =>
      @debug.debug_inspect(finish_reason, content="ToolUse")
    _ => fail("expected MessageEnd")
  }
}

///|
test "parse_anthropic_event - error" {
  let data =
    #|{"type":"error","error":{"type":"invalid_request_error","message":"model not found"}}
  let event = parse_anthropic_event(data)
  match event {
    Some(@llm.StreamEvent::Error(msg)) =>
      @debug.debug_inspect(
        msg,
        content=(
          #|"model not found"
        ),
      )
    _ => fail("expected Error")
  }
}

///|
test "parse_anthropic_event - invalid json" {
  let event = parse_anthropic_event("not json")
  @debug.debug_inspect(event is None, content="true")
}

///|
test "parse_anthropic_event - unknown type" {
  let data =
    #|{"type":"ping"}
  let event = parse_anthropic_event(data)
  @debug.debug_inspect(event is None, content="true")
}
